// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IERC721Receiver } from "../interfaces/IERC721Receiver.sol";

import "./TransferHelperStructs.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    TokenTransferrerErrors
} from "../interfaces/TokenTransferrerErrors.sol";

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
contract TransferHelper is
    TransferHelperInterface,
    TransferHelperErrors,
    TokenTransferrer
{
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
        // If no conduitKey is given, use TokenTransferrer to perform transfers.
        if (conduitKey == bytes32(0)) {
            _performTransfersWithoutConduit(items);
        } else {
            // Otherwise, a conduitKey was provided.
            _performTransfersWithConduit(items, conduitKey);
        }

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.bulkTransfer.selector;
    }

    /**
     * @notice Perform multiple transfers to individually-specified recipients
     *         via TokenTransferrer.
     *
     * @param transfers The transfers to perform.
     */
    function _performTransfersWithoutConduit(
        TransferHelperItemsWithRecipient[] calldata transfers
    ) internal {
        // Retrieve total number of transfers and place on stack.
        uint256 totalTransfers = transfers.length;

        // Skip overflow checks: all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each transfer.
            for (uint256 i = 0; i < totalTransfers; ++i) {
                // Retrieve the transfer in question.
                TransferHelperItemsWithRecipient calldata transfer = transfers[
                    i
                ];
                TransferHelperItem[] calldata transferItems = transfer.items;
                address recipient = transfer.recipient;

                // Ensure tokens aren't transferred to the zero address.
                if (recipient == address(0x0)) {
                    revert RecipientCannotBeZeroAddress();
                }

                // Create a boolean indicating whether recipient is
                // a contract.
                bool callERC721Receiver = transfer.validateERC721Receiver &&
                    recipient.code.length != 0;

                // Retrieve total number of transfers and place on stack.
                uint256 totalItemTransfers = transferItems.length;

                for (uint256 j = 0; j < totalItemTransfers; ++j) {
                    TransferHelperItem calldata item = transferItems[j];

                    // Perform a transfer based on the transfer's item type.
                    if (item.itemType == ConduitItemType.ERC20) {
                        // Ensure that the identifier for an ERC20 token is 0.
                        if (item.identifier != 0) {
                            revert InvalidERC20Identifier();
                        }

                        // Transfer ERC20 token.
                        _performERC20Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.amount
                        );
                    } else if (item.itemType == ConduitItemType.ERC721) {
                        // If recipient is a contract, ensure it can receive
                        // ERC721 tokens.
                        if (callERC721Receiver) {
                            // Check if recipient can receive ERC721 tokens.
                            try
                                IERC721Receiver(recipient).onERC721Received(
                                    address(this),
                                    msg.sender,
                                    item.identifier,
                                    ""
                                )
                            returns (bytes4 selector) {
                                // Check if onERC721Received selector is valid.
                                if (
                                    selector !=
                                    IERC721Receiver.onERC721Received.selector
                                ) {
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
                                    item.identifier
                                );
                            } catch Error(string memory reason) {
                                // "Bubble up" recipient's revert reason.
                                revert ERC721ReceiverErrorRevertString(
                                    reason,
                                    recipient,
                                    msg.sender,
                                    item.identifier
                                );
                            }
                        }
                        // Ensure that the amount for an ERC721 transfer is 1.
                        if (item.amount != 1) {
                            revert InvalidERC721TransferAmount();
                        }

                        // Transfer ERC721 token.
                        _performERC721Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.identifier
                        );
                    } else if (item.itemType == ConduitItemType.ERC1155) {
                        // Transfer ERC1155 token.
                        _performERC1155Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.identifier,
                            item.amount
                        );
                    } else {
                        // Revert if the item being transferred is a native token.
                        revert InvalidItemType();
                    }
                }
            }
        }
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
        uint256 totalTransfers = transfers.length;

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
        uint256 totalItems;

        // Skip overflow checks: all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each transfer.
            for (uint256 i = 0; i < totalTransfers; ++i) {
                // Increment totalItems by the number of items in the transfer.
                totalItems += transfers[i].items.length;
            }
        }

        // Declare a new array in memory with length totalItems to populate with
        // each conduit transfer.
        ConduitTransfer[] memory conduitTransfers = new ConduitTransfer[](
            totalItems
        );

        // Skip overflow checks: all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each transfer.
            for (uint256 i = 0; i < totalTransfers; ++i) {
                // Retrieve the transfer in question.
                TransferHelperItemsWithRecipient calldata transfer = transfers[
                    i
                ];
                TransferHelperItem[] calldata transferItems = transfer.items;
                address recipient = transfer.recipient;

                // Ensure tokens aren't transferred to the zero address.
                if (recipient == address(0x0)) {
                    revert RecipientCannotBeZeroAddress();
                }

                // Retrieve total number of transfers and place on stack.
                uint256 totalItemTransfers = transferItems.length;

                for (uint256 j = 0; j < totalItemTransfers; ++j) {
                    TransferHelperItem calldata item = transferItems[j];
                    // Create a ConduitTransfer corresponding to each
                    // TransferHelperItem.
                    conduitTransfers[j] = ConduitTransfer(
                        item.itemType,
                        item.token,
                        msg.sender,
                        recipient,
                        item.identifier,
                        item.amount
                    );
                }
            }
        }

        // Attempt the external call to transfer tokens via the derived conduit.
        try ConduitInterface(conduit).execute(conduitTransfers) returns (
            bytes4 conduitMagicValue
        ) {
            // Check if the value returned from the external call matches
            // the conduit `execute` selector.
            if (
                conduitMagicValue != ConduitInterface(conduit).execute.selector
            ) {
                // If the external call fails, revert with the conduit key
                // and conduit address.
                revert InvalidConduit(conduitKey, conduit);
            }
        } catch (bytes memory data) {
            // Catch reverts from the external call to the conduit and
            // "bubble up" the conduit's revert reason.
            revert ConduitErrorRevertBytes(data, conduitKey, conduit);
        } catch Error(string memory reason) {
            // Catch reverts with a provided reason string and
            // revert with the reason, conduit key and conduit address.
            revert ConduitErrorRevertString(reason, conduitKey, conduit);
        }
    }
}
