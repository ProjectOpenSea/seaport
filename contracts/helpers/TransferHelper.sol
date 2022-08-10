// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IERC721Receiver } from "../interfaces/IERC721Receiver.sol";

import "./TransferHelperStructs.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import {
    ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";

import { Conduit } from "../conduit/Conduit.sol";

import { ConduitTransfer } from "../conduit/lib/ConduitStructs.sol";

import {
    TransferHelperInterface
} from "../interfaces/TransferHelperInterface.sol";

import { TransferHelperErrors } from "../interfaces/TransferHelperErrors.sol";

/**
 * @title TransferHelper
 * @author stephankmin, stuckinaboot, ryanio
 * @notice TransferHelper is a utility contract for transferring
 *         ERC20/ERC721/ERC1155 items in bulk to specific recipients.
 */
contract TransferHelper is TransferHelperInterface, TransferHelperErrors {
    // Allow for interaction with the conduit controller.
    ConduitControllerInterface internal immutable _CONDUIT_CONTROLLER;

    // Set conduit creation code and runtime code hashes as immutable arguments.
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;
    bytes32 internal immutable _CONDUIT_RUNTIME_CODE_HASH;

    /**
     * @dev Set the supplied conduit controller and retrieve its
     *      conduit creation code hash.
     *
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController) {
        // Get the conduit creation code and runtime code hashes from the
        // supplied conduit controller and set them as an immutable.
        ConduitControllerInterface controller = ConduitControllerInterface(
            conduitController
        );
        (_CONDUIT_CREATION_CODE_HASH, _CONDUIT_RUNTIME_CODE_HASH) = controller
            .getConduitCodeHashes();

        // Set the supplied conduit controller as an immutable.
        _CONDUIT_CONTROLLER = controller;
    }

    /**
     * @notice Transfer multiple ERC20/ERC721/ERC1155 items to
     *         specified recipients.
     *
     * @param items      The items to transfer to an intended recipient.
     * @param conduitKey An optional conduit key referring to a conduit through
     *                   which the bulk transfer should occur.
     *
     * @return magicValue A value indicating that the transfers were successful.
     */
    function bulkTransfer(
        TransferHelperItemsWithRecipient[] calldata items,
        bytes32 conduitKey
    ) external override returns (bytes4 magicValue) {
        // Ensure that a conduit key has been supplied.
        if (conduitKey == bytes32(0)) {
            revert InvalidConduit(conduitKey, address(0));
        }

        // Use conduit derived from supplied conduit key to perform transfers.
        _performTransfersWithConduit(items, conduitKey);

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.bulkTransfer.selector;
    }

    /**
     * @notice Perform multiple transfers to specified recipients via the
     *         conduit derived from the provided conduit key.
     *
     * @param transfers  The items to transfer.
     * @param conduitKey The conduit key referring to the conduit through
     *                   which the bulk transfer should occur.
     */
    function _performTransfersWithConduit(
        TransferHelperItemsWithRecipient[] calldata transfers,
        bytes32 conduitKey
    ) internal {
        // Retrieve total number of transfers and place on stack.
        uint256 numTransfers = transfers.length;

        // Derive the conduit address from the deployer, conduit key
        // and creation code hash.
        address conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(_CONDUIT_CONTROLLER),
                            conduitKey,
                            _CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );

        // Declare a variable to store the sum of all items across transfers.
        uint256 sumOfItemsAcrossAllTransfers;

        // Skip overflow checks: all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each transfer.
            for (uint256 i = 0; i < numTransfers; ++i) {
                // Retrieve the transfer in question.
                TransferHelperItemsWithRecipient calldata transfer = transfers[
                    i
                ];

                // Increment totalItems by the number of items in the transfer.
                sumOfItemsAcrossAllTransfers += transfer.items.length;
            }
        }

        // Declare a new array in memory with length totalItems to populate with
        // each conduit transfer.
        ConduitTransfer[] memory conduitTransfers = new ConduitTransfer[](
            sumOfItemsAcrossAllTransfers
        );

        // Declare an index for storing ConduitTransfers in conduitTransfers.
        uint256 itemIndex;

        // Skip overflow checks: all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each transfer.
            for (uint256 i = 0; i < numTransfers; ++i) {
                // Retrieve the transfer in question.
                TransferHelperItemsWithRecipient calldata transfer = transfers[
                    i
                ];

                // Retrieve the items of the transfer in question.
                TransferHelperItem[] calldata transferItems = transfer.items;

                // Ensure recipient is not the zero address.
                _checkRecipientIsNotZeroAddress(transfer.recipient);

                // Create a boolean indicating whether validateERC721Receiver
                // is true and recipient is a contract.
                bool callERC721Receiver = transfer.validateERC721Receiver &&
                    transfer.recipient.code.length != 0;

                // Retrieve the total number of items in the transfer and
                // place on stack.
                uint256 numItemsInTransfer = transferItems.length;

                // Iterate over each item in the transfer to create a
                // corresponding ConduitTransfer.
                for (uint256 j = 0; j < numItemsInTransfer; ++j) {
                    // Retrieve the item from the transfer.
                    TransferHelperItem calldata item = transferItems[j];

                    if (item.itemType == ConduitItemType.ERC20) {
                        // Ensure that the identifier of an ERC20 token is 0.
                        if (item.identifier != 0) {
                            revert InvalidERC20Identifier();
                        }
                    }

                    // If the item is an ERC721 token and
                    // callERC721Receiver is true...
                    if (item.itemType == ConduitItemType.ERC721) {
                        if (callERC721Receiver) {
                            // Check if the recipient implements
                            // onERC721Received for the given tokenId.
                            _checkERC721Receiver(
                                conduit,
                                transfer.recipient,
                                item.identifier
                            );
                        }
                    }

                    // Create a ConduitTransfer corresponding to each
                    // TransferHelperItem.
                    conduitTransfers[itemIndex] = ConduitTransfer(
                        item.itemType,
                        item.token,
                        msg.sender,
                        transfer.recipient,
                        item.identifier,
                        item.amount
                    );

                    // Increment the index for storing ConduitTransfers.
                    ++itemIndex;
                }
            }
        }

        // Attempt the external call to transfer tokens via the derived conduit.
        try ConduitInterface(conduit).execute(conduitTransfers) returns (
            bytes4 conduitMagicValue
        ) {
            // Check if the value returned from the external call matches
            // the conduit `execute` selector.
            if (conduitMagicValue != ConduitInterface.execute.selector) {
                // If the external call fails, revert with the conduit key
                // and conduit address.
                revert InvalidConduit(conduitKey, conduit);
            }
        } catch Error(string memory reason) {
            // Catch reverts with a provided reason string and
            // revert with the reason, conduit key and conduit address.
            revert ConduitErrorRevertString(reason, conduitKey, conduit);
        } catch (bytes memory data) {
            // Conduits will throw a custom error when attempting to transfer
            // native token item types or an ERC721 item amount other than 1.
            // Bubble up these custom errors when encountered. Note that the
            // conduit itself will bubble up revert reasons from transfers as
            // well, meaning that these errors are not necessarily indicative of
            // an issue with the item type or amount in cases where the same
            // custom error signature is encountered during a conduit transfer.

            // Set initial value of first four bytes of revert data to the mask.
            bytes4 customErrorSelector = bytes4(0xffffffff);

            // Utilize assembly to read first four bytes (if present) directly.
            assembly {
                // Combine original mask with first four bytes of revert data.
                customErrorSelector := and(
                    mload(add(data, 0x20)), // Data begins after length offset.
                    customErrorSelector
                )
            }

            // Pass through the custom error in question if the revert data is
            // the correct length and matches an expected custom error selector.
            if (
                data.length == 4 &&
                (customErrorSelector == InvalidItemType.selector ||
                    customErrorSelector == InvalidERC721TransferAmount.selector)
            ) {
                // "Bubble up" the revert reason.
                assembly {
                    revert(add(data, 0x20), 0x04)
                }
            }

            // Catch all other reverts from the external call to the conduit and
            // include the conduit's raw revert reason as a data argument to a
            // new custom error.
            revert ConduitErrorRevertBytes(data, conduitKey, conduit);
        }
    }

    /**
     * @notice An internal function to check if a recipient address implements
     *         onERC721Received for a given tokenId. Note that this check does
     *         not adhere to the safe transfer specification and is only meant
     *         to provide an additional layer of assurance that the recipient
     *         can receive the tokens — any hooks or post-transfer checks will
     *         fail and the caller will be the transfer helper rather than the
     *         ERC721 contract.
     *
     * @param conduit   The conduit to provide as the operator when calling
     *                  onERC721Received.
     * @param recipient The ERC721 recipient on which to call onERC721Received.
     * @param tokenId   The ERC721 tokenId of the token being transferred.
     */
    function _checkERC721Receiver(
        address conduit,
        address recipient,
        uint256 tokenId
    ) internal {
        // Check if recipient can receive ERC721 tokens.
        try
            IERC721Receiver(recipient).onERC721Received(
                conduit,
                msg.sender,
                tokenId,
                ""
            )
        returns (bytes4 selector) {
            // Check if onERC721Received selector is valid.
            if (selector != IERC721Receiver.onERC721Received.selector) {
                // Revert if recipient cannot accept
                // ERC721 tokens.
                revert InvalidERC721Recipient(recipient);
            }
        } catch (bytes memory data) {
            // "Bubble up" recipient's revert reason.
            revert ERC721ReceiverErrorRevertBytes(
                data,
                recipient,
                msg.sender,
                tokenId
            );
        } catch Error(string memory reason) {
            // "Bubble up" recipient's revert reason.
            revert ERC721ReceiverErrorRevertString(
                reason,
                recipient,
                msg.sender,
                tokenId
            );
        }
    }

    /**
     * @notice An internal function that reverts if the passed-in recipient
     *         is the zero address.
     *
     * @param recipient The recipient on which to perform the check.
     */
    function _checkRecipientIsNotZeroAddress(address recipient) internal pure {
        // Revert if the recipient is the zero address.
        if (recipient == address(0x0)) {
            revert RecipientCannotBeZeroAddress();
        }
    }
}
