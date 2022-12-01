// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    AdvancedOrder,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

interface ZoneInterface {
    // Called by Consideration whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue);

    function validateOrder(ZoneParameters calldata zoneParameters)
        external
        returns (bytes4 validOrderMagicValue);
}
