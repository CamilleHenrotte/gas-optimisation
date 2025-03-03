// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {TokenDistributor} from "../src/LooksRare/TokenDistributor.sol";
import {TokenDistributor2} from "../src/LooksRare/TokenDistributor2.sol";
import {MockERC20} from "../src/LooksRare/MockERC20.sol";

contract TokenDistributorTest is Test {
    TokenDistributor public distributor;
    TokenDistributor2 public distributor2;
    MockERC20 public looksToken;
    address public user1 = makeAddr("user1");
    address public tokenSplitter = makeAddr("tokenSplitter");
    uint256 public startBlock;
    uint256 public periodLength = 1000;

    function setUp() public {
        looksToken = new MockERC20();
        startBlock = block.number + 10; // Start in the future

        uint256[] memory stakingRewards = new uint256[](20);
        uint256[] memory otherRewards = new uint256[](20);
        uint256[] memory periodLengths = new uint256[](20);
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < 20; i++) {
            uint256 reward = i * 0.001 ether;
            stakingRewards[i] = reward; // Increasing rewards
            otherRewards[i] = reward;
            periodLengths[i] = periodLength;
            totalRewards += 2 * reward * periodLength;
        }
        looksToken.mint(address(this), looksToken.SUPPLY_CAP() - totalRewards);
        distributor = new TokenDistributor(
            address(looksToken),
            tokenSplitter,
            startBlock,
            stakingRewards,
            otherRewards,
            periodLengths,
            20
        );

        distributor2 = new TokenDistributor2(
            address(looksToken),
            tokenSplitter,
            startBlock,
            stakingRewards,
            otherRewards,
            periodLengths,
            20
        );

        looksToken.approve(address(distributor), type(uint256).max);
        looksToken.approve(address(distributor2), type(uint256).max);
    }

    function testHarvestAndCompound1() public {
        uint256 depositAmount = 100e18;

        looksToken.mint(user1, depositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor), depositAmount);
        distributor.deposit(depositAmount);

        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);

            distributor.harvestAndCompound();
        }

        vm.roll(startBlock + 1000);

        vm.stopPrank();
    }
    function testHarvestAndCompound2() public {
        uint256 depositAmount = 100e18;

        looksToken.mint(user1, depositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor2), depositAmount);
        distributor2.deposit(depositAmount);
        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);

            distributor2.harvestAndCompound();
        }

        vm.roll(startBlock + 1000);

        vm.stopPrank();
    }

    function testDeposit1() public {
        uint256 totalDepositAmount = 10e18;

        looksToken.mint(user1, totalDepositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor), totalDepositAmount);

        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);
            distributor.deposit(totalDepositAmount / 100);
        }

        vm.roll(startBlock + 1000);

        vm.stopPrank();
    }

    function testDeposit2() public {
        uint256 totalDepositAmount = 10e18;

        looksToken.mint(user1, totalDepositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor2), totalDepositAmount);

        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);
            distributor2.deposit(totalDepositAmount / 100);
        }

        vm.roll(startBlock + 1000);

        vm.stopPrank();
    }

    function testWithdraw1() public {
        uint256 totalDepositAmount = 10e18;

        looksToken.mint(user1, totalDepositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor), totalDepositAmount);
        distributor.deposit(totalDepositAmount);
        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);
            distributor.withdraw(totalDepositAmount / 100);
        }

        vm.roll(startBlock + 1000);

        distributor.withdrawAll();
        vm.stopPrank();

        assertEq(distributor.totalAmountStaked(), 0);
    }

    function testWithdraw2() public {
        uint256 totalDepositAmount = 10e18;

        looksToken.mint(user1, totalDepositAmount);
        vm.startPrank(user1);
        looksToken.approve(address(distributor2), totalDepositAmount);
        distributor2.deposit(totalDepositAmount);
        for (uint256 i = 1; i <= 20; i++) {
            vm.roll(startBlock + i * periodLength + 10);
            distributor2.withdraw(totalDepositAmount / 100);
        }

        vm.roll(startBlock + 1000);

        distributor2.withdrawAll();
        vm.stopPrank();

        assertEq(distributor2.totalAmountStaked(), 0);
    }
}
