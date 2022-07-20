// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StubERC1155 {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) public {
        emit TransferSingle(msg.sender, from, to, tokenId, amount);
    }
}
