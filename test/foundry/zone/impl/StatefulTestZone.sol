// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    Schema,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

contract StatefulTestZone is ERC165, ZoneInterface {
    error IncorrectAmount(uint256 actual, uint256 expected);
    error IncorrectItemType(ItemType actual, ItemType expected);
    error IncorrectIdentifier(uint256 actual, uint256 expected);

    uint256 amountToCheck;

    constructor(uint256 amount) {
        amountToCheck = amount;
    }

    bool public authorizeCalled = false;
    bool public validateCalled = false;

    function authorizeOrder(
        ZoneParameters calldata zoneParameters
    ) public returns (bytes4) {
        _checkZoneParameters(zoneParameters);

        // Set the global called flag to true.
        authorizeCalled = true;

        // Return the authorizeOrder magic value.
        return this.authorizeOrder.selector;
    }

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
        _checkZoneParameters(zoneParameters);

        // Set the global called flag to true.
        validateCalled = true;

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

        return ("StatefulTestZone", schemas);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165, ZoneInterface) returns (bool) {
        return
            interfaceId == type(ZoneInterface).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _checkZoneParameters(
        ZoneParameters calldata zoneParameters
    ) internal view {
        // Check that the amount in the offer is correct.
        if (zoneParameters.offer[0].amount != amountToCheck) {
            revert IncorrectAmount(
                zoneParameters.offer[0].amount,
                amountToCheck
            );
        }

        // Check that the item type in the consideration is correct.
        if (zoneParameters.consideration[0].itemType != ItemType.ERC721) {
            revert IncorrectItemType(
                zoneParameters.consideration[0].itemType,
                ItemType.ERC721
            );
        }

        // Check that the token ID in the consideration is correct.
        if (zoneParameters.consideration[0].identifier != 42) {
            revert IncorrectIdentifier(
                zoneParameters.consideration[0].identifier,
                42
            );
        }
    }
}
