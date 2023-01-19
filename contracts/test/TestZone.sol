// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem,
    ZoneParameters,
    Schema
} from "../lib/ConsiderationStructs.sol";

contract TestZone is ZoneInterface {
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external pure override returns (bytes4 validOrderMagicValue) {
        if (zoneParameters.extraData.length == 0) {
            if (zoneParameters.zoneHash == bytes32(uint256(1))) {
                revert("Revert on zone hash 1");
            } else if (zoneParameters.zoneHash == bytes32(uint256(2))) {
                assembly {
                    revert(0, 0)
                }
            }
        } else if (zoneParameters.extraData.length == 4) {
            revert("Revert on extraData length 4");
        } else if (zoneParameters.extraData.length == 5) {
            assembly {
                revert(0, 0)
            }
        }

        validOrderMagicValue = zoneParameters.zoneHash != bytes32(uint256(3))
            ? ZoneInterface.validateOrder.selector
            : bytes4(0xffffffff);
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

        return ("TestZone", schemas);
    }
}
