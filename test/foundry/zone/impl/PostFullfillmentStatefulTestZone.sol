// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    ZoneParameters
} from "seaport/lib/ConsiderationStructs.sol";
import { ItemType } from "seaport/lib/ConsiderationEnums.sol";
import { ZoneInterface } from "seaport/interfaces/ZoneInterface.sol";

contract PostFulfillmentStatefulTestZone is ZoneInterface {
    error IncorrectAmount(uint256 actual, uint256 expected);
    error IncorrectItemType(ItemType actual, ItemType expected);
    error IncorrectIdentifier(uint256 actual, uint256 expected);

    uint256 amountToCheck;

    constructor(uint256 amount) {
        amountToCheck = amount;
    }

    bool public called = false;

    // Called by Consideration whenever any extraData is provided by the caller.
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external returns (bytes4 validOrderMagicValue) {
        if (zoneParameters.offer[0].amount != amountToCheck) {
            revert IncorrectAmount(zoneParameters.offer[0].amount, 50);
        }
        if (zoneParameters.consideration[0].itemType != ItemType.ERC721) {
            revert IncorrectIdentifier(
                uint256(zoneParameters.consideration[0].itemType),
                uint256(ItemType.ERC721)
            );
        }
        if (zoneParameters.consideration[0].identifier != 42) {
            revert IncorrectIdentifier(
                zoneParameters.consideration[0].identifier,
                42
            );
        }

        called = true;
        return ZoneInterface.validateOrder.selector;
    }
}
