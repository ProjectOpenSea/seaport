// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    TransferHelperItemsWithRecipient
} from "../helpers/TransferHelperStructs.sol";

interface TransferHelperInterface {
    /**
     * @notice Transfer multiple items to a single recipient.
     *
     * @param items The items to transfer.
     * @param conduitKey  The key of the conduit performing the bulk transfer.
     */
    function bulkTransfer(
        TransferHelperItemsWithRecipient[] calldata items,
        bytes32 conduitKey
    ) external returns (bytes4);
}
