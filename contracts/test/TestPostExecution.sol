// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { ERC721Interface } from "../interfaces/AbridgedTokenInterfaces.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    ConsiderationItem,
    OfferItem,
    ConsiderationItem,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

contract TestPostExecution is ZoneInterface {
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external pure override returns (bytes4) {
        orderHash;
        caller;
        offerer;
        zoneHash;

        revert("Basic validity check not allowed");
    }

    function validateOrder(ZoneParameters calldata zoneParameters)
        external
        view
        override
        returns (bytes4 validOrderMagicValue)
    {
        ConsiderationItem memory considerationItem =
            zoneParameters.consideration[0];

        address currentOwner = ERC721Interface(considerationItem.token).ownerOf(
            considerationItem.identifierOrCriteria
        );

        if (considerationItem.itemType != ItemType.ERC721) {
            revert("Validity check performed with unsupported item type");
        }

        // Note that endAmount has been repurposed as recipient; this interface
        // still needs to be modified to return spent / received items.
        if (considerationItem.startAmount != 1) {
            // Note that this is currently failing in the matchOrder case.
            revert("Returned item amount incorrectly modified");
        }

        if (currentOwner != considerationItem.recipient) {
            revert("Validity check performed prior to execution");
        }

        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }
}
