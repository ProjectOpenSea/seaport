//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

contract TestTransferValidationZoneOfferer is
    ContractOffererInterface,
    ZoneInterface
{
    error InvalidBalance();
    error InvalidOwner();

    constructor() {}

    /**
     * @dev Validates that the parties have received the correct items.
     *
     * @param zoneParameters The zone parameters, including the SpentItem and
     *                       ReceivedItem arrays.
     *
     * @return validOrderMagicValue The magic value to indicate things are OK.
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external view override returns (bytes4 validOrderMagicValue) {
        // Validate the order.
        // Currently assumes that the balances of all tokens of addresses are
        // zero at the start of the transaction.

        // Check if all consideration items have been received.
        _assertValidReceivedItems(zoneParameters.consideration);

        // Check if all offer items have been spent.
        _assertValidSpentItems(zoneParameters.fulfiller, zoneParameters.offer);

        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items.
     */
    function generateOrder(
        address,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata c
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        return previewOrder(address(this), address(this), a, b, c);
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata
    )
        public
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        return (a, _convertSpentToReceived(b));
    }

    /**
     * @dev Ratifies that the parties have received the correct items.
     *
     * @param minimumReceived The minimum items that the caller was willing to
     *                        receive.
     * @param maximumSpent    The maximum items that the caller was willing to
     *                        spend.
     * @param context         The context of the order.
     * @ param orderHashes     The order hashes, unused here.
     * @ param contractNonce   The contract nonce, unused here.
     *
     * @return ratifyOrderMagicValue The magic value to indicate things are OK.
     */
    function ratifyOrder(
        SpentItem[] calldata minimumReceived /* offer */,
        ReceivedItem[] calldata maximumSpent /* consideration */,
        bytes calldata context /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external view override returns (bytes4 /* ratifyOrderMagicValue */) {
        // Ratify the order.

        // Ensure that the offerer or recipient has received all consideration
        // items.
        _assertValidReceivedItems(maximumSpent);

        // Get the fulfiller address from the context.
        address fulfiller = address(bytes20(context[0:20]));

        // Ensure that the fulfiller has received all offer items.
        _assertValidSpentItems(fulfiller, minimumReceived);

        return this.ratifyOrder.selector;
    }

    function getSeaportMetadata()
        external
        pure
        override(ContractOffererInterface, ZoneInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        // Return the metadata.
        name = "TestTransferValidationZoneOfferer";
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);
    }

    function _convertSpentToReceived(
        SpentItem[] calldata spentItems
    ) internal view returns (ReceivedItem[] memory) {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            spentItems.length
        );
        for (uint256 i = 0; i < spentItems.length; ++i) {
            receivedItems[i] = _convertSpentToReceived(spentItems[i]);
        }
        return receivedItems;
    }

    function _convertSpentToReceived(
        SpentItem calldata spentItem
    ) internal view returns (ReceivedItem memory) {
        return
            ReceivedItem({
                itemType: spentItem.itemType,
                token: spentItem.token,
                identifier: spentItem.identifier,
                amount: spentItem.amount,
                recipient: payable(address(this))
            });
    }

    function _assertValidReceivedItems(
        ReceivedItem[] calldata receivedItems
    ) internal view {
        address recipient;
        ItemType itemType;
        ReceivedItem memory receivedItem;
        // Check if all consideration items have been received.
        for (uint256 i = 0; i < receivedItems.length; i++) {
            // Check if the consideration item has been received.
            receivedItem = receivedItems[i];
            // Get the recipient of the consideration item.
            recipient = receivedItem.recipient;

            // Get item type.
            itemType = receivedItem.itemType;

            // Check balance/ownerOf depending on item type.
            if (itemType == ItemType.NATIVE) {
                // NATIVE Token
                _assertNativeTokenTransfer(receivedItem.amount, recipient);
            } else if (itemType == ItemType.ERC20) {
                // ERC20 Token
                _assertERC20Transfer(
                    receivedItem.amount,
                    receivedItem.token,
                    recipient
                );
            } else if (itemType == ItemType.ERC721) {
                // ERC721 Token
                _assertERC721Transfer(
                    receivedItem.identifier,
                    receivedItem.token,
                    recipient
                );
            } else if (itemType == ItemType.ERC1155) {
                // ERC1155 Token
                _assertERC1155Transfer(
                    receivedItem.amount,
                    receivedItem.identifier,
                    receivedItem.token,
                    recipient
                );
            }
        }
    }

    function _assertValidSpentItems(
        address fulfiller,
        SpentItem[] calldata spentItems
    ) internal view {
        SpentItem memory spentItem;
        ItemType itemType;

        // Check if all offer items have been spent.
        for (uint256 i = 0; i < spentItems.length; i++) {
            // Check if the offer item has been spent.
            spentItem = spentItems[i];
            // Get item type.
            itemType = spentItem.itemType;

            // Check balance/ownerOf depending on item type.
            if (itemType == ItemType.NATIVE) {
                // NATIVE Token
                _assertNativeTokenTransfer(spentItem.amount, fulfiller);
            } else if (itemType == ItemType.ERC20) {
                // ERC20 Token
                _assertERC20Transfer(
                    spentItem.amount,
                    spentItem.token,
                    fulfiller
                );
            } else if (itemType == ItemType.ERC721) {
                // ERC721 Token
                _assertERC721Transfer(
                    spentItem.identifier,
                    spentItem.token,
                    fulfiller
                );
            } else if (itemType == ItemType.ERC1155) {
                // ERC1155 Token
                _assertERC1155Transfer(
                    spentItem.amount,
                    spentItem.identifier,
                    spentItem.token,
                    fulfiller
                );
            }
        }
    }

    function _assertNativeTokenTransfer(
        uint256 amount,
        address recipient
    ) internal view {
        if (amount > address(recipient).balance) {
            revert InvalidBalance();
        }
    }

    function _assertERC20Transfer(
        uint256 amount,
        address token,
        address recipient
    ) internal view {
        if (amount > ERC20Interface(token).balanceOf(recipient)) {
            revert InvalidBalance();
        }
    }

    function _assertERC721Transfer(
        uint256 identifier,
        address token,
        address recipient
    ) internal view {
        if (recipient != ERC721Interface(token).ownerOf(identifier)) {
            revert InvalidOwner();
        }
    }

    function _assertERC1155Transfer(
        uint256 amount,
        uint256 identifier,
        address token,
        address recipient
    ) internal view {
        if (amount > ERC1155Interface(token).balanceOf(recipient, identifier)) {
            revert InvalidBalance();
        }
    }
}
