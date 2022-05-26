// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { TransferHelperItem } from "../helper/TransferHelperStructs.sol";

interface TransferHelperInterface {
    /**
     * @notice Transfer multiple items to a single recipient.
     *
     * @param items The items to transfer.
     * @param recipient  The address the items should be transferred to.
     * @param conduitKey  The key of the conduit through which the bulk transfer should occur.
     */
    function bulkTransfer(
        TransferHelperItem[] calldata items,
        address recipient,
        bytes32 conduitKey
    ) external returns (bytes4);
}
