// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    TransferHelperItem,
    TransferHelperItemWithRecipient
} from "../helpers/TransferHelperStructs.sol";

interface TransferHelperInterface {
    /**
     * @dev Revert with an error when attempting to execute transfers with a
     *      NATIVE itemType.
     */
    error InvalidItemType();

    /**
     * @dev Revert with an error when attempting to execute an ERC721 transfer
     *      to an invalid recipient.
     */
    error InvalidERC721Recipient(address recipient);

    /**
     * @dev Revert with an error when a call to a ERC721 receiver reverts with
     *      bytes data.
     */
    error ERC721ReceiverErrorRevertBytes(
        bytes reason,
        address receiver,
        address sender,
        uint256 identifier
    );

    /**
     * @dev Revert with an error when a call to a ERC721 receiver reverts with
     *      string reason.
     */
    error ERC721ReceiverErrorRevertString(
        string reason,
        address receiver,
        address sender,
        uint256 identifier
    );

    /**
     * @dev Revert with an error when an ERC20 token has an invalid identifier.
     */
    error InvalidERC20Identifier();

    /**
     * @dev Revert with an error if the recipient is the zero address.
     */
    error RecipientCannotBeZero();

    /**
     * @dev Revert with an error when attempting to fill an order referencing an
     *      invalid conduit (i.e. one that has not been deployed).
     */
    error InvalidConduit(bytes32 conduitKey, address conduit);

    /**
     * @dev Revert with an error when a call to a conduit reverts with a
     *      reason string.
     */
    error ConduitErrorRevertString(
        string reason,
        bytes32 conduitKey,
        address conduit
    );

    /**
     * @dev Revert with an error when a call to a conduit reverts with bytes
     *      data.
     */
    error ConduitErrorRevertBytes(
        bytes reason,
        bytes32 conduitKey,
        address conduit
    );

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
