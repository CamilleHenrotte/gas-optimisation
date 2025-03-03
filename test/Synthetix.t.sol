// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {MockERC20} from "src/Synthetix/MockERC20.sol";
import {StakingRewards} from "src/Synthetix/StakingRewards.sol";
import {StakingRewards2} from "src/Synthetix/StakingRewards2.sol";
import {Test, console} from "forge-std/Test.sol";

contract TestSynthetix is Test {
    address rewardsDistribution = makeAddr("rewardsDistribution");
    address staker1 = makeAddr("staker1");
    address staker2 = makeAddr("staker2");
    MockERC20 rewardsToken;
    MockERC20 stakingToken;
    StakingRewards stakingRewards;
    StakingRewards2 stakingRewards2;

    uint256 rewardAmount = 1000 ether;
    uint256 staker1Amount = 100 ether;
    uint256 staker2Amount = 200 ether;

    function setUp() public {
        rewardsToken = new MockERC20();
        stakingToken = new MockERC20();

        stakingRewards = new StakingRewards(
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );
        stakingRewards2 = new StakingRewards2(
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );
        rewardsToken.mint(address(stakingRewards), rewardAmount);
        rewardsToken.mint(address(stakingRewards2), rewardAmount);
        stakingToken.mint(staker1, staker1Amount);
        stakingToken.mint(staker2, staker2Amount);
    }

    function testScenario() public {
        vm.prank(rewardsDistribution);
        stakingRewards.notifyRewardAmount(rewardAmount);

        vm.startPrank(staker1);

        stakingToken.approve(address(stakingRewards), staker1Amount);
        stakingRewards.stake(staker1Amount);
        vm.warp(block.timestamp + 3 days);
        vm.stopPrank();

        vm.startPrank(staker2);
        stakingToken.approve(address(stakingRewards), staker2Amount);
        stakingRewards.stake(staker2Amount);
        vm.warp(block.timestamp + 3 days);
        stakingRewards.withdraw(staker2Amount);
        stakingRewards.getReward();
        vm.stopPrank();

        vm.startPrank(staker1);
        stakingRewards.withdraw(staker1Amount);
        stakingRewards.getReward();
        vm.stopPrank();

        uint256 rewardsStaker1 = rewardsToken.balanceOf(staker1);
        uint256 rewardsStaker2 = rewardsToken.balanceOf(staker2);
        assertApproxEqAbs(
            rewardsStaker1,
            (rewardAmount * 3) / 7 + (rewardAmount * 3) / 7 / 3,
            1e13
        );
        assertApproxEqAbs(
            rewardsStaker2,
            (((rewardAmount * 3) / 7) * 2) / 3,
            1e13
        );
    }
    function testScenario2() public {
        vm.prank(rewardsDistribution);
        stakingRewards2.notifyRewardAmount(rewardAmount);

        vm.startPrank(staker1);

        stakingToken.approve(address(stakingRewards2), staker1Amount);
        stakingRewards2.stake(staker1Amount);
        vm.warp(block.timestamp + 3 days);
        vm.stopPrank();

        vm.startPrank(staker2);
        stakingToken.approve(address(stakingRewards2), staker2Amount);
        stakingRewards2.stake(staker2Amount);
        vm.warp(block.timestamp + 3 days);
        stakingRewards2.withdraw(staker2Amount);
        vm.stopPrank();

        vm.startPrank(staker1);
        stakingRewards2.withdraw(staker1Amount);
        vm.stopPrank();

        uint256 rewardsStaker1 = rewardsToken.balanceOf(staker1);
        uint256 rewardsStaker2 = rewardsToken.balanceOf(staker2);
        assertApproxEqAbs(
            rewardsStaker1,
            (rewardAmount * 3) / 7 + (rewardAmount * 3) / 7 / 3,
            1e13
        );
        assertApproxEqAbs(
            rewardsStaker2,
            (((rewardAmount * 3) / 7) * 2) / 3,
            1e13
        );
    }
    function printInfo() public view {
        console.log("--                                      --");
        console.log("------------------------------------------");
        console.log("--                                      --");
        console.log("Period finish: ", stakingRewards.periodFinish());
        console.log("Reward rate: ", stakingRewards.rewardRate());
        console.log("Rewards duration: ", stakingRewards.rewardsDuration());
        console.log("Last update time: ", stakingRewards.lastUpdateTime());
        console.log(
            "Reward per token stored: ",
            stakingRewards.rewardPerTokenStored()
        );
        console.log("-------Staker 1-------");
        console.log(
            "User reward per token paid: ",
            stakingRewards.userRewardPerTokenPaid(staker1)
        );
        console.log("Rewards: ", stakingRewards.rewards(staker1));
        console.log("-------Staker 2-------");
        console.log(
            "User reward per token paid: ",
            stakingRewards.userRewardPerTokenPaid(staker2)
        );
        console.log("Rewards: ", stakingRewards.rewards(staker2));
    }
}
