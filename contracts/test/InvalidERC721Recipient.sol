// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4);
}

contract InvalidERC721Recipient is IERC721Receiver {
    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return 0xabcd0000;
    }
}
