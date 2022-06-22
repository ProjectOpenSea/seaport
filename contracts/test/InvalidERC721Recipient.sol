// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

interface ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4);
}

contract InvalidERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xabcd0000;
    }
}
