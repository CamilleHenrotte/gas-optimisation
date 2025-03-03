// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Staking721} from "../src/ERC721Staking/StakingERC721.sol";
import {Staking721_2} from "../src/ERC721Staking/StakingERC721-2.sol";
import {MockERC721} from "../src/ERC721Staking/MockERC721.sol";
import {MockERC20} from "../src/ERC721Staking/MockERC20.sol";
/// @dev Foundry test to run the scenario and log gas used.
contract Staking721GasTest is Test {
    Staking721 staking;
    Staking721_2 staking2;
    MockERC721 stakingToken;
    MockERC20 rewardToken;
    address[] stakers;

    function setUp() public {
        stakingToken = new MockERC721();
        rewardToken = new MockERC20();
        staking = new Staking721(address(stakingToken), address(rewardToken));
        staking2 = new Staking721_2(
            address(stakingToken),
            address(rewardToken)
        );

        // Create 5 staker addresses (for example: 0x1, 0x2, …)
        for (uint i = 0; i < 5; i++) {
            stakers.push(address(uint160(i + 1)));
        }

        // Mint tokens for each staker.
        // Each staker gets 10 tokens.
        uint256 tokenId = 1;
        for (uint i = 0; i < stakers.length; i++) {
            for (uint j = 0; j < 10; j++) {
                stakingToken.mint(stakers[i], tokenId);
                tokenId++;
            }
        }
    }

    function testGasScenario1() public {
        uint256 depositCalls = 20;
        uint256 tokenId = 1; // tokens 1 to 20 will be staked
        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            vm.startPrank(staker);
            for (uint j = 0; j < 10; j++) {
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                stakingToken.approve(address(staking), tokenId);
                staking.stake(tokenIds);

                tokenId++;
            }
            vm.stopPrank();
            vm.warp(block.timestamp + (3 * i) * 1 days);
            staking.setRewardsPerUnitTime((i + 2) * 100);
        }
        vm.warp(block.timestamp + 1000 days);
        tokenId = 1;
        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            vm.startPrank(staker);
            for (uint j = 0; j < 10; j++) {
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                staking.withdraw(tokenIds);
                tokenId++;
            }
        }
    }
    function testGasScenario2() public {
        uint256 depositCalls = 20;
        uint256 tokenId = 1; // tokens 1 to 20 will be staked
        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            vm.startPrank(staker);
            for (uint j = 0; j < 10; j++) {
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                stakingToken.approve(address(staking2), tokenId);
                staking2.stake(tokenIds);

                tokenId++;
            }
            vm.stopPrank();
            vm.warp(block.timestamp + (3 * i) * 1 days);
            staking2.setRewardsPerSecond(uint64((i + 2) * 100));
        }
        vm.warp(block.timestamp + 1000 days);
        tokenId = 1;
        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            vm.startPrank(staker);
            for (uint j = 0; j < 10; j++) {
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                staking2.withdraw(tokenIds);
                tokenId++;
            }
        }
    }
}
