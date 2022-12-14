// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    ZoneParameters
} from "../../../../contracts/lib/ConsiderationStructs.sol";
import {
    ZoneInterface
} from "../../../../contracts/interfaces/ZoneInterface.sol";

contract BadZone is ZoneInterface {
    function validateOrder(ZoneParameters calldata zoneParameters)
        external
        pure
        returns (bytes4 validOrderMagicValue)
    {
        if (zoneParameters.consideration[0].identifier == 1) {
            return ZoneInterface.validateOrder.selector;
        } else {
            assembly {
                return(0, 0)
            }
        }
    }
}
