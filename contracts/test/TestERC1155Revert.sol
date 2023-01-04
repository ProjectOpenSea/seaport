// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract TestERC1155Revert {
    function safeTransferFrom(
        address /* from */,
        address /* to */,
        uint256 /* id */,
        uint256 /* amount */,
        bytes memory /* data */
    ) public pure {
        revert("Some ERC1155 revert message");
    }

    function safeBatchTransferFrom(
        address /* from */,
        address /* to */,
        uint256[] memory /* ids */,
        uint256[] memory /* values */,
        bytes memory /* data */
    ) public pure {
        revert("Some ERC1155 revert message for batch transfers");
    }
}

