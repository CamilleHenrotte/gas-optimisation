// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;
/// @dev Minimal IERC721 interface used in Staking721.
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "nft") {}
    function mint(address account, uint256 tokenId) external {
        _mint(account, tokenId);
    }
}
