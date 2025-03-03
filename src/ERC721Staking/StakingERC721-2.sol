// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author thirdweb

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IMintable} from "./IMintable.sol";
import {IERC721} from "./IERC721.sol";
import {SafeMath} from "./SafeMath.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract Staking721_2 is ReentrancyGuard, IERC721Receiver {
    /*///////////////////////////////////////////////////////////////
                            State variables / Mappings
    //////////////////////////////////////////////////////////////*/
    struct Staker {
        int160 rewardDebt;
        uint88 numberOfNftsStaked;
    }
    struct RewardState {
        uint64 rewardsPerSecond;
        uint56 lastRewardTime;
        uint136 accRewardPerNft;
    }
    ///@dev Address of ERC721 NFT contract -- staked tokens belong to this contract.
    address public immutable rewardToken;

    ///@dev Address of ERC721 NFT contract -- staked tokens belong to this contract.
    address public immutable stakingToken;

    /// @dev Flag to check direct transfers of staking tokens.
    uint8 internal isStaking = 1;

    /// @dev List of accounts that have staked their NFTs.
    address[] public stakersArray;

    /// @dev Tracks the current rate of reward per second, last reward time, and accumulated reward per NFT from beginning of time.
    RewardState public rewardState;

    ///@dev Mapping from staker address to Staker struct. See {struct IStaking721.Staker}.
    mapping(address => Staker) public stakers;

    /// @dev Mapping from staked token-id to staker address.
    mapping(uint256 => address) public tokenStaker;

    constructor(address _stakingToken, address _rewardToken) ReentrancyGuard() {
        require(address(_stakingToken) != address(0), "collection address 0");
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }

    /*///////////////////////////////////////////////////////////////
                               Events
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when a set of token-ids are staked.
    event TokensStaked(address indexed staker, uint256[] indexed tokenIds);

    /// @dev Emitted when a set of staked token-ids are withdrawn.
    event TokensWithdrawn(address indexed staker, uint256[] indexed tokenIds);

    /// @dev Emitted when a staker claims staking rewards.
    event RewardsClaimed(address indexed staker, uint256 rewardAmount);

    /// @dev Emitted when contract admin updates rewardsPerUnitTime.
    event UpdatedRewardsPerUnitTime(
        uint256 oldRewardsPerUnitTime,
        uint256 newRewardsPerUnitTime
    );
    /*///////////////////////////////////////////////////////////////
                               Mofifiers
    //////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        External/Public Functions
    //////////////////////////////////////////////////////////////*/

    function stake(uint256[] calldata _tokenIds) external nonReentrant {
        _stake(_tokenIds);
    }

    function withdraw(uint256[] calldata _tokenIds) external nonReentrant {
        _withdraw(_tokenIds);
    }

    function claimRewards() external nonReentrant {
        Staker memory staker = stakers[_stakeMsgSender()];
        RewardState memory rewardState_ = _getRewardStateUpdated();
        _claimRewards(staker, rewardState_);
        staker.rewardDebt = SafeCast.toInt160(
            int256(
                uint256(
                    staker.numberOfNftsStaked * rewardState_.accRewardPerNft
                )
            )
        );
        stakers[_stakeMsgSender()] = staker;
    }

    function setRewardsPerSecond(uint64 rewardsPerSecond) external virtual {
        if (!_canSetStakeConditions()) {
            revert("Not authorized");
        }
        RewardState memory rewardState_ = _getRewardStateUpdated();
        require(
            rewardsPerSecond != rewardState_.rewardsPerSecond,
            "Reward unchanged."
        );
        emit UpdatedRewardsPerUnitTime(
            rewardState_.rewardsPerSecond,
            rewardsPerSecond
        );

        rewardState_.rewardsPerSecond = rewardsPerSecond;
        rewardState = rewardState_;
    }

    function getStakeInfo(
        address _staker
    )
        external
        view
        virtual
        returns (uint256 numberOfNftsStaked, uint256 _rewards)
    {
        Staker memory staker = stakers[_staker];
        numberOfNftsStaked = staker.numberOfNftsStaked;
        _rewards = _pendingRewards(staker, rewardState);
    }

    function getRewardsPerSecond() public view returns (uint256) {
        return rewardState.rewardsPerSecond;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _updatePool() internal returns (RewardState memory rewardState_) {
        rewardState_ = _getRewardStateUpdated();
        rewardState = rewardState_;
    }
    function _getRewardStateUpdated()
        internal
        view
        returns (RewardState memory rewardState_)
    {
        rewardState_ = rewardState;
        rewardState_.accRewardPerNft += SafeCast.toUint136(
            (block.timestamp - rewardState_.lastRewardTime) *
                rewardState_.rewardsPerSecond
        );
        rewardState_.lastRewardTime = SafeCast.toUint56(block.timestamp);
    }

    function _stake(uint256[] calldata _tokenIds) internal virtual {
        RewardState memory rewardState_ = _getRewardStateUpdated();
        uint64 len = uint64(_tokenIds.length);
        require(len != 0, "Staking 0 tokens");

        address _stakingToken = stakingToken;
        uint256 pendingRewards;
        Staker memory staker = stakers[_stakeMsgSender()];

        if (staker.numberOfNftsStaked > 0) {
            pendingRewards = _pendingRewards(staker, rewardState_);
        } else {
            stakersArray.push(_stakeMsgSender());
        }
        for (uint256 i = 0; i < len; ++i) {
            isStaking = 2;
            IERC721(_stakingToken).safeTransferFrom(
                _stakeMsgSender(),
                address(this),
                _tokenIds[i]
            );
            isStaking = 1;
            tokenStaker[_tokenIds[i]] = _stakeMsgSender();
        }
        staker.numberOfNftsStaked += len;
        staker.rewardDebt = SafeCast.toInt160(
            SafeCast.toInt256(uint256(staker.numberOfNftsStaked)) *
                SafeCast.toInt256(uint256(rewardState_.accRewardPerNft)) -
                SafeCast.toInt256(pendingRewards)
        );
        stakers[_stakeMsgSender()] = staker;

        emit TokensStaked(_stakeMsgSender(), _tokenIds);
    }

    function _withdraw(uint256[] calldata _tokenIds) internal virtual {
        RewardState memory rewardState_ = _getRewardStateUpdated();
        Staker memory staker = stakers[_stakeMsgSender()];
        require(_tokenIds.length != 0, "Withdrawing 0 tokens");

        address _stakingToken = stakingToken;

        if (staker.numberOfNftsStaked == _tokenIds.length) {
            address[] memory _stakersArray = stakersArray;
            for (uint256 i = 0; i < _stakersArray.length; ++i) {
                if (_stakersArray[i] == _stakeMsgSender()) {
                    stakersArray[i] = _stakersArray[_stakersArray.length - 1];
                    stakersArray.pop();
                    break;
                }
            }
            _claimRewards(staker, rewardState_);
            stakers[_stakeMsgSender()] = Staker(0, 0);
        } else {
            uint256 pendingRewards = _pendingRewards(staker, rewardState_);
            staker.numberOfNftsStaked -= uint88(_tokenIds.length);
            staker.rewardDebt = SafeCast.toInt160(
                SafeCast.toInt256(uint256(staker.numberOfNftsStaked)) *
                    SafeCast.toInt256(uint256(rewardState_.accRewardPerNft)) -
                    SafeCast.toInt256(pendingRewards)
            );
            stakers[_stakeMsgSender()] = staker;
        }

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            require(
                tokenStaker[_tokenIds[i]] == _stakeMsgSender(),
                "Not staker"
            );
            tokenStaker[_tokenIds[i]] = address(0);
            IERC721(_stakingToken).safeTransferFrom(
                address(this),
                _stakeMsgSender(),
                _tokenIds[i]
            );
        }

        emit TokensWithdrawn(_stakeMsgSender(), _tokenIds);
    }

    /// @dev Logic for claiming rewards. Override to add custom logic.
    function _claimRewards(
        Staker memory staker,
        RewardState memory rewardState_
    ) internal virtual {
        uint256 rewards = _pendingRewards(staker, rewardState_);
        _mintRewards(_stakeMsgSender(), rewards);

        emit RewardsClaimed(_stakeMsgSender(), rewards);
    }

    /// @dev View available rewards for a user.
    function _pendingRewards(
        Staker memory staker,
        RewardState memory rewardState_
    ) internal view virtual returns (uint256 rewards) {
        int256 accumulated = SafeCast.toInt256(
            uint256(staker.numberOfNftsStaked)
        ) *
            SafeCast.toInt256(uint256(rewardState_.accRewardPerNft)) -
            int256(staker.rewardDebt);
        require(accumulated >= 0, "Negative rewards");
        rewards = SafeCast.toUint256(accumulated);
    }

    /*////////////////////////////////////////////////////////////////////
        Optional hooks that can be implemented in the derived contract
    ///////////////////////////////////////////////////////////////////*/

    /// @dev Exposes the ability to override the msg sender -- support ERC2771.
    function _stakeMsgSender() internal virtual returns (address) {
        return msg.sender;
    }

    function _mintRewards(address _staker, uint256 _rewards) internal virtual {
        IMintable(rewardToken).mint(_staker, _rewards);
    }

    function _canSetStakeConditions() internal view virtual returns (bool) {
        return true;
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
