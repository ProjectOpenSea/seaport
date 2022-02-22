//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Used for minting test ERC721s in our tests
contract TestERC721 is ERC721("Test721", "TST721") {
  function mint(address to, uint256 tokenId) public returns (bool) {
    _mint(to, tokenId);
    return true;
  }
}
