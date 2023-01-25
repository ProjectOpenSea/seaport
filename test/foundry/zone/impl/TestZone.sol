// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    ZoneParameters,
    Schema
} from "../../../../contracts/lib/ConsiderationStructs.sol";
import {
    ZoneInterface
} from "../../../../contracts/interfaces/ZoneInterface.sol";

contract TestZone is ZoneInterface {
    // Called by Consideration whenever any extraData is provided by the caller.
    function validateOrder(
        ZoneParameters calldata
    ) external pure returns (bytes4 validOrderMagicValue) {
        return ZoneInterface.validateOrder.selector;
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
