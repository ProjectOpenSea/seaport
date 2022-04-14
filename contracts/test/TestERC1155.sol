//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Used for minting test ERC1155s in our tests
contract TestERC1155 is ERC1155("Test1155") {
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) public returns (bool) {
        _mint(to, tokenId, amount, "");
        return true;
    }
}
