// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {MockERC20} from "src/TraderJoe/MockERC20.sol";
import {TokenVesting} from "src/TraderJoe/TokenVesting.sol";
import {TokenVesting2} from "src/TraderJoe/TokenVesting2.sol";
import {Test, console} from "forge-std/Test.sol";

contract TestSynthetix is Test {
    MockERC20 public token;
    TokenVesting public tokenVesting;
    TokenVesting2 public tokenVesting2;
    address public beneficiary = makeAddr("beneficiary");
    uint256 start = block.timestamp;
    uint256 cliffDuration = 2 days;
    uint256 duration = 10 days;
    bool revocable = true;
    uint256 amount = 1000 ether;

    function setUp() public {
        token = new MockERC20();
        tokenVesting = new TokenVesting(
            beneficiary,
            start,
            cliffDuration,
            duration,
            revocable
        );
        tokenVesting2 = new TokenVesting2(
            beneficiary,
            start,
            cliffDuration,
            duration,
            revocable
        );
        token.mint(address(tokenVesting), amount);
        token.mint(address(tokenVesting2), amount);
    }
    function testScenario1() public {
        vm.warp(block.timestamp + 3 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 300 ether);
        assert(token.balanceOf(address(tokenVesting)) == 700 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 400 ether);
        assert(token.balanceOf(address(tokenVesting)) == 600 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 500 ether);
        assert(token.balanceOf(address(tokenVesting)) == 500 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 600 ether);
        assert(token.balanceOf(address(tokenVesting)) == 400 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 700 ether);
        assert(token.balanceOf(address(tokenVesting)) == 300 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 800 ether);
        assert(token.balanceOf(address(tokenVesting)) == 200 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 900 ether);
        assert(token.balanceOf(address(tokenVesting)) == 100 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting.release(token);
        assert(token.balanceOf(beneficiary) == 1000 ether);
        assert(token.balanceOf(address(tokenVesting)) == 0 ether);
    }
    function testScenario2() public {
        tokenVesting2.setTokenInfo(address(token), uint128(amount));

        vm.warp(block.timestamp + 3 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 300 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 700 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 400 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 600 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 500 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 500 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 600 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 400 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 700 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 300 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 800 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 200 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 900 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 100 ether);

        vm.warp(block.timestamp + 1 days);
        tokenVesting2.release(token);
        assert(token.balanceOf(beneficiary) == 1000 ether);
        assert(token.balanceOf(address(tokenVesting2)) == 0 ether);
    }
}
