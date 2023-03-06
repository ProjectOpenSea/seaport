//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "seaport-sol/SeaportStructs.sol";
import { ItemType } from "seaport-sol/SeaportEnums.sol";

import {
    ContractOffererInterface
} from "seaport-core/interfaces/ContractOffererInterface.sol";

import { ZoneInterface } from "seaport-core/interfaces/ZoneInterface.sol";

contract ValidationOffererZone is ContractOffererInterface, ZoneInterface {
    error IncorrectSpentAmount(address fulfiller, bytes32 got, uint256 want);

    uint256 expectedMaxSpentAmount;

    constructor(uint256 expectedMax) {
        expectedMaxSpentAmount = expectedMax;
    }

    receive() external payable {}

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
        validate(zoneParameters.fulfiller, zoneParameters.offer);

        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = this.validateOrder.selector;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent items,
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

    function ratifyOrder(
        SpentItem[] calldata spentItems /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external view override returns (bytes4 /* ratifyOrderMagicValue */) {
        validate(address(0), spentItems);
        return ValidationOffererZone.ratifyOrder.selector;
    }

    function validate(
        address fulfiller,
        SpentItem[] calldata offer
    ) internal view {
        if (offer[0].amount > expectedMaxSpentAmount) {
            revert IncorrectSpentAmount(
                fulfiller,
                bytes32(offer[0].amount),
                expectedMaxSpentAmount
            );
        }
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
}
