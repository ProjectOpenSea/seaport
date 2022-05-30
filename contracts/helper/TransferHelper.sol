// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

// prettier-ignore
import "./TransferHelperStructs.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { ConduitControllerInterface } from "../interfaces/ConduitControllerInterface.sol";

import { ConduitTransfer } from "../conduit/lib/ConduitStructs.sol";

import { TransferHelperInterface } from "../interfaces/TransferHelperInterface.sol";

/**
 * @title TransferHelper
 * @author stuckinaboot, stephankmin
 * @notice TransferHelper is a utility contract for transferring ERC20/ERC721/ERC1155 items in bulk to a specific recipient
 */
contract TransferHelper is TransferHelperInterface, TokenTransferrer {
    // Allow for interaction with the conduit controller.
    ConduitControllerInterface internal immutable _CONDUIT_CONTROLLER;

    // Cache the conduit creation code hash used by the conduit controller.
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;

    /**
     * @dev Set the supplied conduit controller and retrieve its conduit creation code hash.
     *
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController) {
        // Set the supplied conduit controller.
        _CONDUIT_CONTROLLER = ConduitControllerInterface(conduitController);

        // Retrieve the conduit creation code hash from the supplied controller.
        (_CONDUIT_CREATION_CODE_HASH, ) = (
            _CONDUIT_CONTROLLER.getConduitCodeHashes()
        );
    }

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
    ) external returns (bytes4 magicValue) {
        // Retrieve total number of transfers and place on stack.
        uint256 numTransfers = items.length;

        // If no conduitKey is given, call TokenTransferrer to perform transfers.
        if (conduitKey == bytes32(0)) {
            // Skip overflow checks as all for loops are indexed starting at zero.
            unchecked {
                // Iterate over each transfer.
                for (uint256 i = 0; i < numTransfers; ++i) {
                    // Retrieve the transfer in question.
                    TransferHelperItem calldata item = items[i];

                    // Perform a transfer based on the transfer's item type.
                    // Ensure that the item being transferred is not a native token.
                    if (item.itemType == ConduitItemType.NATIVE) {
                        revert InvalidItemType();
                    } else if (item.itemType == ConduitItemType.ERC20) {
                        _performERC20Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.amount
                        );
                    } else if (item.itemType == ConduitItemType.ERC721) {
                        _performERC721Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.tokenIdentifier
                        );
                    } else {
                        _performERC1155Transfer(
                            item.token,
                            msg.sender,
                            recipient,
                            item.tokenIdentifier,
                            item.amount
                        );
                    }
                }
            }
        }
        // If a conduitKey is given, derive the conduit address from the conduitKey and call the conduit to perform transfers.
        else {
            (address conduit, ) = _CONDUIT_CONTROLLER.getConduit(conduitKey);
            ConduitTransfer[] memory conduitTransfers = new ConduitTransfer[](
                numTransfers
            );

            // Skip overflow checks as all for loops are indexed starting at zero.
            unchecked {
                // Iterate over each transfer.
                for (uint256 i = 0; i < numTransfers; ++i) {
                    // Retrieve the transfer in question.
                    TransferHelperItem calldata item = items[i];

                    // Create a ConduitTransfer corresponding to each TransferHelperItem.
                    conduitTransfers[i] = ConduitTransfer(
                        item.itemType,
                        item.token,
                        msg.sender,
                        recipient,
                        item.tokenIdentifier,
                        item.amount
                    );
                }
            }

            // Call the conduit and execute bulk transfers.
            ConduitInterface(conduit).execute(conduitTransfers);
        }

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.bulkTransfer.selector;
    }
}
