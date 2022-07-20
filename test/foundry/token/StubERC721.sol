// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StubERC721 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        emit Transfer(from, to, tokenId);
    }
}
