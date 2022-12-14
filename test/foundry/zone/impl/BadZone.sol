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
        } else if (zoneParameters.consideration[0].identifier == 2) {
            assembly {
                return(0, 0)
            }
        } else {
            // return garbage
            bytes32 h1 = keccak256(abi.encode(zoneParameters.offer));
            bytes32 h2 = keccak256(abi.encode(zoneParameters.consideration));
            assembly {
                mstore(0x00, h1)
                mstore(0x20, h2)
                return(0, 0x100)
            }
        }
    }
}
