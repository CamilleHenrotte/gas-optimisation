// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "ME20") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
