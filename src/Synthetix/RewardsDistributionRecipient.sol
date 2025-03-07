// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Inheritance
import "./Owned.sol";

// https://docs.synthetix.io/contracts/source/contracts/rewardsdistributionrecipient
abstract contract RewardsDistributionRecipient is Owned {
    address public rewardsDistribution;

    constructor() {}

    function notifyRewardAmount(uint256 reward) external virtual;

    modifier onlyRewardsDistribution() {
        require(
            msg.sender == rewardsDistribution,
            "Caller is not RewardsDistribution contract"
        );
        _;
    }

    function setRewardsDistribution(
        address _rewardsDistribution
    ) external onlyOwner {
        require(_rewardsDistribution != address(0), "Invalid address");
        rewardsDistribution = _rewardsDistribution;
    }
}
