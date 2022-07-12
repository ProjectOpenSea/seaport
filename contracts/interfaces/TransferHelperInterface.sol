// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    TransferHelperItem,
    TransferHelperItemWithRecipient
} from "../helpers/TransferHelperStructs.sol";

interface TransferHelperInterface {
    /**
     * @notice Transfer multiple items to a single recipient.
     *
     * @param items The items to transfer.
     * @param recipient  The address the items should be transferred to.
     * @param conduitKey  The key of the conduit performing the bulk transfer.
     */
    function bulkTransfer(
        TransferHelperItem[] calldata items,
        address recipient,
        bytes32 conduitKey
    ) external returns (bytes4);

    /**
     * @notice Transfer multiple items to multiple recipients.
     *
     * @param items The items to transfer.
     * @param conduitKey  The key of the conduit performing the bulk transfer.
     */
    function bulkTransferToMultipleRecipients(
        TransferHelperItemWithRecipient[] calldata items,
        bytes32 conduitKey
    ) external returns (bytes4);
}
