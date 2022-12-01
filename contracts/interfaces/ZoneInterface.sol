// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    AdvancedOrder,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem
} from "../lib/ConsiderationStructs.sol";

interface ZoneInterface {
    // Called by Consideration whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue);

    function validateOrder(
        bytes32 orderHash,
        address fulfiller,
        address offerer,
        OfferItem[] calldata offer,
        ConsiderationItem[] calldata consideration,
        bytes calldata extraData,
        bytes32[] calldata orderHashes,
        uint256 startTime,
        uint256 endTime,
        bytes32 zoneHash
    ) external returns (bytes4 validOrderMagicValue);
}
