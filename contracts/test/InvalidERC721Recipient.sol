// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

contract InvalidERC721Recipient {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xabcd0000;
    }
}
