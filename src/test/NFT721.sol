// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@solmate/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC721 {
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function mintTo(address recipient, uint256 tokenId)
        public
        payable
        returns (uint256)
    {
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return Strings.toString(id);
    }
}
