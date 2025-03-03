// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ILooksRareToken} from "./ILooksRareToken.sol";

contract MockERC20 is ERC20, ILooksRareToken {
    uint256 private supply_cap = 1000 ether;
    constructor() ERC20("MockERC20", "ME20") {}

    function mint(
        address account,
        uint256 amount
    ) external override returns (bool) {
        if (amount + totalSupply() > supply_cap) {
            return false;
        }
        _mint(account, amount);
        return true;
    }
    function SUPPLY_CAP() external view override returns (uint256) {
        return supply_cap;
    }
}
