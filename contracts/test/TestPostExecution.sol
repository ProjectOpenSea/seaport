// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { ERC721Interface } from "../interfaces/AbridgedTokenInterfaces.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    ConsiderationItem
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

    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        priorOrderHashes;
        criteriaResolvers;

        ConsiderationItem memory considerationItem = (
            order.parameters.consideration[0]
        );

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

        if (currentOwner != address(uint160(considerationItem.endAmount))) {
            revert("Validity check performed prior to execution");
        }

        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }
}
