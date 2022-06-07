// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

contract ERC1155BatchRecipient {
    error UnexpectedBatchData();

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes memory data
    ) external pure returns (bytes4) {
        if (data.length != 0) {
            revert UnexpectedBatchData();
        }
        return ERC1155BatchRecipient.onERC1155BatchReceived.selector;
    }
}
