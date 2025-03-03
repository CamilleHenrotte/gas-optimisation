// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract TokenVesting2 is Ownable {
    using SafeERC20 for IERC20;

    event TokensReleased(address token, uint256 amount);
    event TokenVestingRevoked(address token);

    address private immutable _beneficiary;
    uint256 private immutable _cliff;
    uint256 private immutable _start;
    uint256 private immutable _duration;
    bool private immutable _revocable;

    mapping(address => TokenInfo) private _tokenInfo;

    struct TokenInfo {
        uint128 totalBalance;
        uint96 lastReleasedTime;
        uint8 revoked;
    }

    constructor(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        bool revocable
    ) Ownable(msg.sender) {
        require(
            beneficiary != address(0),
            "TokenVesting: beneficiary is the zero address"
        );
        require(
            cliffDuration <= duration,
            "TokenVesting: cliff is longer than duration"
        );
        require(duration > 0, "TokenVesting: duration is 0");
        require(
            start + duration > block.timestamp,
            "TokenVesting: final time is before current time"
        );

        _beneficiary = beneficiary;
        _revocable = revocable;
        _duration = duration;
        _cliff = start + cliffDuration;
        _start = start;
    }
    function setTokenInfo(
        address token,
        uint128 totalBalance
    ) public onlyOwner {
        _tokenInfo[token] = TokenInfo({
            totalBalance: totalBalance,
            lastReleasedTime: uint96(_start),
            revoked: 0
        });
    }

    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    function cliff() public view returns (uint256) {
        return _cliff;
    }

    function start() public view returns (uint256) {
        return _start;
    }

    function duration() public view returns (uint256) {
        return _duration;
    }

    function revocable() public view returns (bool) {
        return _revocable;
    }

    function lastReasedTime(address token) public view returns (uint256) {
        return _tokenInfo[token].lastReleasedTime;
    }

    function revoked(address token) public view returns (bool) {
        return _tokenInfo[token].revoked == 1;
    }

    function release(IERC20 token) public {
        uint256 unreleased = _releasableAmount(token);
        require(unreleased > 0, "TokenVesting: no tokens are due");
        _tokenInfo[address(token)].lastReleasedTime = uint96(block.timestamp);
        token.safeTransfer(_beneficiary, unreleased);
        emit TokensReleased(address(token), unreleased);
    }

    function revoke(IERC20 token) public onlyOwner {
        TokenInfo storage tokenInfo = _tokenInfo[address(token)];
        require(_revocable, "TokenVesting: cannot revoke");
        require(
            !(tokenInfo.revoked == 1),
            "TokenVesting: token already revoked"
        );

        uint256 refund = ((_start + _duration - block.timestamp) *
            uint256(tokenInfo.totalBalance)) / _duration;

        tokenInfo.revoked = 1;
        token.safeTransfer(owner(), refund);
        emit TokenVestingRevoked(address(token));
    }

    function emergencyRevoke(IERC20 token) public onlyOwner {
        require(_revocable, "TokenVesting: cannot revoke");
        require(
            !(_tokenInfo[address(token)].revoked == 1),
            "TokenVesting: token already revoked"
        );

        uint256 balance = token.balanceOf(address(this));
        _tokenInfo[address(token)].revoked = 1;
        token.safeTransfer(owner(), balance);
        emit TokenVestingRevoked(address(token));
    }

    function _releasableAmount(IERC20 token) private view returns (uint256) {
        TokenInfo memory tokenInfo = _tokenInfo[address(token)];
        if (block.timestamp < _cliff) {
            return 0;
        } else if (
            block.timestamp >= _start + _duration || tokenInfo.revoked == 1
        ) {
            return token.balanceOf(address(this));
        } else {
            return
                ((block.timestamp - tokenInfo.lastReleasedTime) *
                    tokenInfo.totalBalance) / _duration;
        }
    }
}
