// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    ZoneParameters
} from "../../../../contracts/lib/ConsiderationStructs.sol";
import { ZoneInterface } from
    "../../../../contracts/interfaces/ZoneInterface.sol";

contract TestZone is ZoneInterface {
    // Called by Consideration whenever any extraData is provided by the caller.
    function validateOrder(ZoneParameters calldata)
        external
        pure
        returns (bytes4 validOrderMagicValue)
    {
        return ZoneInterface.validateOrder.selector;
    }
}
