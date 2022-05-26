// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./TransferHelperStructs.sol";
import { TokenTransferrer } from "../lib/TokenTransferrer.sol";
import { ConduitInterface } from "../interfaces/ConduitInterface.sol";
import { ConduitControllerInterface } from "../interfaces/ConduitControllerInterface.sol";
import { ConduitTransfer } from "../conduit/lib/ConduitStructs.sol";

/**
 * @title TransferHelper
 * @author stuckinaboot, stephankmin
 * @notice TransferHelper is a trivial ETH/ERC20/ERC721/ERC1155 marketplace
 */
contract TransferHelper is TokenTransferrer {
    // Allow for interaction with the conduit controller.
    ConduitControllerInterface internal immutable _CONDUIT_CONTROLLER;

    // Cache the conduit creation code hash used by the conduit controller.
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;

    constructor(address conduitController) {
        // Set the supplied conduit controller.
        _CONDUIT_CONTROLLER = ConduitControllerInterface(conduitController);

        // Retrieve the conduit creation code hash from the supplied controller.
        (_CONDUIT_CREATION_CODE_HASH, ) = (
            _CONDUIT_CONTROLLER.getConduitCodeHashes()
        );
    }

    function bulkTransfer(
        TransferHelperItem[] calldata items,
        address recipient,
        bytes32 conduitKey
    ) public returns (bytes4) {
        // if no conduit, call TokenTransferrer
        if (conduitKey == bytes32(0)) {
            for (uint256 i; i < items.length; i++) {
                TransferHelperItem calldata item = items[i];
                if (item.itemType == ConduitItemType.NATIVE) {
                    continue;
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
                    // do we have to check for ERC721 and ERC1155 with criteria?
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
        // if conduit, derive conduit address from key
        else {
            (address conduit, ) = _CONDUIT_CONTROLLER.getConduit(conduitKey);
            ConduitTransfer[] memory conduitTransfers = new ConduitTransfer[](
                items.length
            );
            // modify TransferHelperItems to ConduitTranfsers
            for (uint256 i; i < items.length; i++) {
                TransferHelperItem calldata item = items[i];
                conduitTransfers[i] = ConduitTransfer(
                    item.itemType,
                    item.token,
                    msg.sender,
                    recipient,
                    item.tokenIdentifier,
                    item.amount
                );
            }
            ConduitInterface(conduit).execute(conduitTransfers);
        }

        return this.bulkTransfer.selector;
    }
}
