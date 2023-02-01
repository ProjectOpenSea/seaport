// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ZoneParameters,
    Schema
} from "../../../../contracts/lib/ConsiderationStructs.sol";

import { ItemType } from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    ZoneInterface
} from "../../../../contracts/interfaces/ZoneInterface.sol";

contract PostFulfillmentStatefulTestZone is ZoneInterface {
    error IncorrectAmount(uint256 actual, uint256 expected);
    error IncorrectItemType(ItemType actual, ItemType expected);
    error IncorrectIdentifier(uint256 actual, uint256 expected);

    uint256 amountToCheck;

    constructor(uint256 amount) {
        amountToCheck = amount;
    }

    bool public called = false;

    /**
     * @dev Validates the order with the given `zoneParameters`.  Called by
     *      Consideration whenever any extraData is provided by the caller.
     *
     * @param zoneParameters The parameters for the order.
     *
     * @return validOrderMagicValue The validOrder magic value.
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external returns (bytes4 validOrderMagicValue) {
        // Check that the amount in the offer is correct.
        if (zoneParameters.offer[0].amount != amountToCheck) {
            revert IncorrectAmount(zoneParameters.offer[0].amount, 50);
        }

        // Check that the item type in the consideration is correct.
        if (zoneParameters.consideration[0].itemType != ItemType.ERC721) {
            revert IncorrectIdentifier(
                uint256(zoneParameters.consideration[0].itemType),
                uint256(ItemType.ERC721)
            );
        }

        // Check that the token ID in the consideration is correct.
        if (zoneParameters.consideration[0].identifier != 42) {
            revert IncorrectIdentifier(
                zoneParameters.consideration[0].identifier,
                42
            );
        }

        // Set the global called flag to true.
        called = true;

        // Return the validOrderMagicValue.
        return ZoneInterface.validateOrder.selector;
    }

    /**
     * @dev Returns the metadata for this zone.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("PostFulfillmentStatefulTestZone", schemas);
    }
}
