// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { TransferHelperItem } from "../helpers/TransferHelperStructs.sol";

interface TransferHelperInterface {
    /**
     * @dev Revert with an error when attempting to execute transfers with a
     *      NATIVE itemType.
     */
    error InvalidItemType();

    /**
     * @dev Revert with an error when attempting to execute an ERC721 transfer
            to an invalid recipient.
     */
    error InvalidERC721Recipient();

    /**
     * @dev Revert with an error when an ERC20 token has an invalid identifier.
     */
    error InvalidERC20Identifier();

    /**
     * @dev Revert with an error when a call to a conduit returns an invalid
     *      magic value.
     */
    error InvalidMagicValue();

    /**
     * @dev Revert with an error when a call to a conduit reverts with a
     *      reason string.
     */
    error ConduitErrorString(string reason);

    /**
     * @dev Revert with an error when a call to a conduit reverts with a
     *      panic error.
     */
    error ConduitErrorPanic(uint256 errorCode);

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
}
