// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILooksRareToken} from "./ILooksRareToken.sol";

/**
 * @title TokenDistributor
 * @notice It handles the distribution of LOOKS token.
 * It auto-adjusts block rewards over a set number of periods.
 */
contract TokenDistributor2 is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILooksRareToken;

    struct StakingPeriod {
        uint96 rewardPerBlockForStaking;
        uint96 rewardPerBlockForOthers;
        uint64 endPeriodBlock;
    }

    struct UserInfo {
        uint128 amount; // Amount of staked tokens provided by user
        uint128 rewardDebt; // Reward debt
    }
    struct State {
        uint128 currentPhase;
        uint128 lastRewardBlock;
    }
    struct PendingRewards {
        uint128 pendingTokenRewardForOthers;
        uint128 pendingTokenRewardForStaking;
    }

    // Precision factor for calculating rewards
    uint256 public constant PRECISION_FACTOR = 10 ** 12;

    ILooksRareToken public immutable looksRareToken;

    address public immutable tokenSplitter;

    // Number of reward periods
    uint256 public immutable NUMBER_PERIODS;

    // Block number when rewards start
    uint256 public immutable START_BLOCK;

    // Accumulated tokens per share
    uint256 public accTokenPerShare;

    // Total amount staked
    uint256 public totalAmountStaked;

    State public state;

    PendingRewards public pendingRewards;

    mapping(uint256 => StakingPeriod) public stakingPeriod;

    mapping(address => UserInfo) public userInfo;

    event Compound(address indexed user, uint256 harvestedAmount);
    event Deposit(
        address indexed user,
        uint256 amount,
        uint256 harvestedAmount
    );
    event NewRewardsPerBlock(
        uint256 indexed currentPhase,
        uint256 startBlock,
        uint256 rewardPerBlockForStaking,
        uint256 rewardPerBlockForOthers
    );
    event Withdraw(
        address indexed user,
        uint256 amount,
        uint256 harvestedAmount
    );

    /**
     * @notice Constructor
     * @param _looksRareToken LOOKS token address
     * @param _tokenSplitter token splitter contract address (for team and trading rewards)
     * @param _startBlock start block for reward program
     * @param _rewardsPerBlockForStaking array of rewards per block for staking
     * @param _rewardsPerBlockForOthers array of rewards per block for other purposes (team + treasury + trading rewards)
     * @param _periodLengthesInBlocks array of period lengthes
     * @param _numberPeriods number of periods with different rewards/lengthes (e.g., if 3 changes --> 4 periods)
     */
    constructor(
        address _looksRareToken,
        address _tokenSplitter,
        uint256 _startBlock,
        uint256[] memory _rewardsPerBlockForStaking,
        uint256[] memory _rewardsPerBlockForOthers,
        uint256[] memory _periodLengthesInBlocks,
        uint256 _numberPeriods
    ) {
        require(
            (_periodLengthesInBlocks.length == _numberPeriods) &&
                (_rewardsPerBlockForStaking.length == _numberPeriods) &&
                (_rewardsPerBlockForStaking.length == _numberPeriods),
            "Distributor: Lengthes must match numberPeriods"
        );

        // 1. Operational checks for supply
        uint256 nonCirculatingSupply = ILooksRareToken(_looksRareToken)
            .SUPPLY_CAP() - ILooksRareToken(_looksRareToken).totalSupply();

        uint256 amountTokensToBeMinted;
        uint64 endPeriodBlock_ = uint64(START_BLOCK);
        for (uint256 i = 0; i < _numberPeriods; i++) {
            endPeriodBlock_ += uint64(_periodLengthesInBlocks[i]);
            amountTokensToBeMinted +=
                (_rewardsPerBlockForStaking[i] * _periodLengthesInBlocks[i]) +
                (_rewardsPerBlockForOthers[i] * _periodLengthesInBlocks[i]);

            stakingPeriod[i] = StakingPeriod({
                rewardPerBlockForStaking: uint96(_rewardsPerBlockForStaking[i]),
                rewardPerBlockForOthers: uint96(_rewardsPerBlockForOthers[i]),
                endPeriodBlock: endPeriodBlock_
            });
        }

        require(
            amountTokensToBeMinted == nonCirculatingSupply,
            "Distributor: Wrong reward parameters"
        );

        // 2. Store values
        looksRareToken = ILooksRareToken(_looksRareToken);
        tokenSplitter = _tokenSplitter;

        START_BLOCK = _startBlock;

        NUMBER_PERIODS = _numberPeriods;

        // Set the lastRewardBlock as the startBlock
        state.lastRewardBlock = uint128(_startBlock);
    }

    /**
     * @notice Deposit staked tokens and compounds pending rewards
     * @param amount amount to deposit (in LOOKS)
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit: Amount must be > 0");

        // Update pool information
        _updatePool();

        // Transfer LOOKS tokens to this contract
        looksRareToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 pendingRewards;
        UserInfo memory userInfo_ = userInfo[msg.sender];
        // If not new deposit, calculate pending rewards (for auto-compounding)
        if (userInfo_.amount > 0) {
            pendingRewards =
                ((userInfo_.amount * accTokenPerShare) / PRECISION_FACTOR) -
                userInfo_.rewardDebt;
        }

        // Adjust user information
        uint128 userNewAmount = userInfo_.amount +
            uint128(amount + pendingRewards);
        userInfo_.amount = userNewAmount;
        userInfo_.rewardDebt = uint128(
            (userNewAmount * accTokenPerShare) / PRECISION_FACTOR
        );
        userInfo[msg.sender] = userInfo_;
        // Increase totalAmountStaked
        totalAmountStaked += (amount + pendingRewards);

        emit Deposit(msg.sender, amount, pendingRewards);
    }

    /**
     * @notice Compound based on pending rewards
     */
    function harvestAndCompound() external nonReentrant {
        // Update pool information
        _updatePool();
        UserInfo memory userInfo_ = userInfo[msg.sender];

        // Calculate pending rewards
        uint256 pendingRewards = ((userInfo_.amount * accTokenPerShare) /
            PRECISION_FACTOR) - userInfo_.rewardDebt;

        // Return if no pending rewards
        if (pendingRewards == 0) {
            // It doesn't throw revertion (to help with the fee-sharing auto-compounding contract)
            return;
        }

        // Adjust user amount for pending rewards

        // Adjust totalAmountStaked
        totalAmountStaked += pendingRewards;

        userInfo_.amount = userInfo_.amount + uint128(pendingRewards);
        // Recalculate reward debt based on new user amount
        userInfo_.rewardDebt = uint128(
            (userInfo_.amount * accTokenPerShare) / PRECISION_FACTOR
        );
        userInfo[msg.sender] = userInfo_;

        emit Compound(msg.sender, pendingRewards);
    }

    /**
     * @notice Update pool rewards
     */
    function updatePool() external nonReentrant {
        _updatePool();
    }

    /**
     * @notice Withdraw staked tokens and compound pending rewards
     * @param amount amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        UserInfo memory userInfo_ = userInfo[msg.sender];
        require(
            (userInfo_.amount >= amount) && (amount > 0),
            "Withdraw: Amount must be > 0 or lower than user balance"
        );

        // Update pool
        _updatePool();

        // Calculate pending rewards
        uint256 pendingRewards = ((userInfo_.amount * accTokenPerShare) /
            PRECISION_FACTOR) - userInfo_.rewardDebt;

        // Adjust user information

        userInfo_.amount = uint128(userInfo_.amount + pendingRewards - amount);
        userInfo_.rewardDebt = uint128(
            (userInfo_.amount * accTokenPerShare) / PRECISION_FACTOR
        );

        userInfo[msg.sender] = userInfo_;
        // Adjust total amount staked
        totalAmountStaked = totalAmountStaked + pendingRewards - amount;

        // Transfer LOOKS tokens to the sender
        mintRewardsForStaking();
        looksRareToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, pendingRewards);
    }

    /**
     * @notice Withdraw all staked tokens and collect tokens
     */
    function withdrawAll() external nonReentrant {
        UserInfo memory userInfo_ = userInfo[msg.sender];
        require(userInfo_.amount > 0, "Withdraw: Amount must be > 0");

        // Update pool
        _updatePool();

        // Calculate pending rewards and amount to transfer (to the sender)
        uint256 pendingRewards = ((userInfo_.amount * accTokenPerShare) /
            PRECISION_FACTOR) - userInfo_.rewardDebt;

        uint256 amountToTransfer = userInfo_.amount + pendingRewards;

        // Adjust total amount staked
        totalAmountStaked = totalAmountStaked - userInfo_.amount;

        // Transfer LOOKS tokens to the sender
        mintRewardsForStaking();
        looksRareToken.safeTransfer(msg.sender, userInfo_.amount);

        // Adjust user information
        userInfo_.amount = 0;
        userInfo_.rewardDebt = 0;

        userInfo[msg.sender] = userInfo_;

        emit Withdraw(msg.sender, amountToTransfer, pendingRewards);
    }

    /**
     * @notice Calculate pending rewards for a user
     * @param user address of the user
     * @return Pending rewards
     */
    function calculatePendingRewards(
        address user
    ) external view returns (uint256) {
        State memory state_ = state;
        UserInfo memory userInfo_ = userInfo[user];
        if (
            (block.number > state_.lastRewardBlock) && (totalAmountStaked != 0)
        ) {
            uint256 multiplier = _getMultiplier(
                state_.lastRewardBlock,
                block.number,
                getEndBlock(state_.currentPhase)
            );

            uint256 tokenRewardForStaking = multiplier *
                getRewardPerBlockForStaking(state_.currentPhase);

            uint256 adjustedEndBlock = getEndBlock(state_.currentPhase);
            uint256 adjustedCurrentPhase = state_.currentPhase;

            // Check whether to adjust multipliers and reward per block
            while (
                (block.number > adjustedEndBlock) &&
                (adjustedCurrentPhase < (NUMBER_PERIODS - 1))
            ) {
                // Update current phase
                adjustedCurrentPhase++;

                // Update rewards per block
                uint256 adjustedRewardPerBlockForStaking = stakingPeriod[
                    adjustedCurrentPhase
                ].rewardPerBlockForStaking;

                // Calculate adjusted block number
                uint256 previousEndBlock = adjustedEndBlock;

                // Update end block
                adjustedEndBlock = getEndBlock(uint128(adjustedCurrentPhase));
                // Calculate new multiplier
                uint256 newMultiplier = (block.number <= adjustedEndBlock)
                    ? (block.number - previousEndBlock)
                    : getEndBlock(uint128(adjustedCurrentPhase)) -
                        getEndBlock(uint128(adjustedCurrentPhase) - 1);

                // Adjust token rewards for staking
                tokenRewardForStaking += (newMultiplier *
                    adjustedRewardPerBlockForStaking);
            }

            uint256 adjustedTokenPerShare = accTokenPerShare +
                (tokenRewardForStaking * PRECISION_FACTOR) /
                totalAmountStaked;

            return
                (userInfo_.amount * adjustedTokenPerShare) /
                PRECISION_FACTOR -
                userInfo_.rewardDebt;
        } else {
            return
                (userInfo[user].amount * accTokenPerShare) /
                PRECISION_FACTOR -
                userInfo[user].rewardDebt;
        }
    }

    /**
     * @notice Update reward variables of the pool
     */
    function _updatePool() internal {
        State memory state_ = state;
        if (block.number <= state_.lastRewardBlock) {
            return;
        }

        if (totalAmountStaked == 0) {
            state.lastRewardBlock = uint128(block.number);
            return;
        }

        // Calculate multiplier
        uint256 multiplier = _getMultiplier(
            state_.lastRewardBlock,
            block.number,
            getEndBlock(state_.currentPhase)
        );

        // Calculate rewards for staking and others
        uint256 tokenRewardForStaking = multiplier *
            getRewardPerBlockForStaking(state_.currentPhase);
        uint256 tokenRewardForOthers = multiplier *
            getRewardPerBlockForOthers(state_.currentPhase);

        // Check whether to adjust multipliers and reward per block
        while (
            (block.number > getEndBlock(state_.currentPhase)) &&
            (state_.currentPhase < (NUMBER_PERIODS - 1))
        ) {
            // Update rewards per block

            emit NewRewardsPerBlock(
                state_.currentPhase + 1,
                state_.lastRewardBlock,
                getRewardPerBlockForStaking(state_.currentPhase + 1),
                getRewardPerBlockForOthers(state_.currentPhase + 1)
            );

            // Adjust multiplier to cover the missing periods with other lower inflation schedule
            uint256 newMultiplier = _getMultiplier(
                getEndBlock(state_.currentPhase),
                block.number,
                getEndBlock(state_.currentPhase + 1)
            );

            state_.currentPhase++;

            // Adjust token rewards
            tokenRewardForStaking += (newMultiplier *
                getRewardPerBlockForStaking(state_.currentPhase));
            tokenRewardForOthers += (newMultiplier *
                getRewardPerBlockForOthers(state_.currentPhase));
        }

        // Mint tokens only if token rewards for staking are not null
        if (tokenRewardForStaking > 0) {
            // It allows protection against potential issues to prevent funds from being locked
            PendingRewards memory pendingRewards_ = pendingRewards;
            accTokenPerShare =
                accTokenPerShare +
                ((tokenRewardForStaking * PRECISION_FACTOR) /
                    totalAmountStaked);
            pendingRewards_.pendingTokenRewardForStaking += uint128(
                tokenRewardForStaking
            );
            pendingRewards_.pendingTokenRewardForOthers += uint128(
                tokenRewardForOthers
            );
            pendingRewards = pendingRewards_;
        }

        // Update last reward block only if it wasn't updated after or at the end block
        if (state_.lastRewardBlock <= getEndBlock(state_.currentPhase)) {
            state_.lastRewardBlock = uint128(block.number);
        }
        state = state_;
    }

    function mintRewardsForStaking() public {
        looksRareToken.mint(
            address(this),
            pendingRewards.pendingTokenRewardForStaking
        );
        pendingRewards.pendingTokenRewardForStaking = 0;
    }

    function mintRewardsForOthers() external {
        looksRareToken.mint(
            tokenSplitter,
            pendingRewards.pendingTokenRewardForOthers
        );
        pendingRewards.pendingTokenRewardForOthers = 0;
    }

    /**
     * @notice Return reward multiplier over the given "from" to "to" block.
     * @param from block to start calculating reward
     * @param to block to finish calculating reward
     * @return the multiplier for the period
     */
    function _getMultiplier(
        uint256 from,
        uint256 to,
        uint256 endBlock
    ) internal view returns (uint256) {
        if (to <= endBlock) {
            return to - from;
        } else if (from >= endBlock) {
            return 0;
        } else {
            return endBlock - from;
        }
    }

    function getEndBlock(
        uint128 currentPhase
    ) public view returns (uint256 endBlock) {
        return stakingPeriod[currentPhase].endPeriodBlock;
    }
    function getRewardPerBlockForStaking(
        uint128 currentPhase
    ) public view returns (uint256 rewardPerBlockForStaking) {
        return stakingPeriod[currentPhase].rewardPerBlockForStaking;
    }

    function getRewardPerBlockForOthers(
        uint128 currentPhase
    ) public view returns (uint256 rewardPerBlockForOthers) {
        return stakingPeriod[currentPhase].rewardPerBlockForOthers;
    }
}
