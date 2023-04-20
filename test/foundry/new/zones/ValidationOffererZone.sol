//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ItemType } from "seaport-sol/SeaportEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem,
    ZoneParameters
} from "seaport-sol/SeaportStructs.sol";

import {
    ContractOffererInterface
} from "seaport-core/interfaces/ContractOffererInterface.sol";

import { ZoneInterface } from "seaport-core/interfaces/ZoneInterface.sol";

contract ValidationOffererZone is ContractOffererInterface, ZoneInterface {
    error IncorrectSpentAmount(address fulfiller, bytes32 got, uint256 want);

    /**
     * HashCalldataContractOfferer
HashValidationZoneOfferer

should be able to poke it and say "go to this [offer]item and increase the amount
or insert this item as an extra item
or go to consideratino item and reduce a mount
remove consideration
or insert this item as an extra item
     */

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
        if (failureReason == FailureReason.Zone_reverts) {
            revert("Zone reverts");
        } else if (failureReason == FailureReason.Zone_InvalidMagicValue) {
            return bytes4(0x12345678);
        }

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
        (offer, consideration) = previewOrder(
            address(this),
            address(this),
            a,
            b,
            c
        );
        FailureReason reason = failureReason;
        if (reason == FailureReason.ContractOfferer_generateReverts) {
            revert("generateOrder reverts");
        } else if (
            reason == FailureReason.ContractOfferer_InsufficientMinimumReceived
        ) {
            require(
                offer.length > 0,
                "Insufficient minimum received items to truncate for failure case"
            );
            assembly {
                // truncate offer length by 1
                mstore(offer, sub(mload(offer), 1))
            }
            return (offer, consideration);
        } else if (
            reason == FailureReason.ContractOfferer_IncorrectMinimumReceived
        ) {
            return (returnedOffer, consideration);
        } else if (reason == FailureReason.ContractOfferer_ExcessMaximumSpent) {
            ReceivedItem[] memory newConsideration = new ReceivedItem[](
                consideration.length + 1
            );
            for (uint256 i = 0; i < consideration.length; i++) {
                newConsideration[i] = consideration[i];
            }
            newConsideration[consideration.length] = ReceivedItem({
                token: address(0),
                amount: 1,
                itemType: ItemType.ERC20,
                identifier: 0,
                recipient: payable(address(this))
            });
            return (offer, newConsideration);
        } else if (
            reason == FailureReason.ContractOfferer_IncorrectMaximumSpent
        ) {
            return (offer, returnedConsideration);
        }
        return (offer, consideration);
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
        if (failureReason == FailureReason.ContractOfferer_ratifyReverts) {
            revert("ContractOfferer ratifyOrder reverts");
        } else if (
            failureReason == FailureReason.ContractOfferer_InvalidMagicValue
        ) {
            return bytes4(0x12345678);
        }
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
        name = "HashValidationZoneOfferer";
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);
    }
}
