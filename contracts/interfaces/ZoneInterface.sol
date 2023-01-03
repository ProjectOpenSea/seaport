// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    AdvancedOrder,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

interface ZoneInterface {
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external returns (bytes4 validOrderMagicValue);
}
