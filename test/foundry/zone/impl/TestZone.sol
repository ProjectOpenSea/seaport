// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver
} from "seaport/lib/ConsiderationStructs.sol";
import { ZoneInterface } from "seaport/interfaces/ZoneInterface.sol";

contract TestZone is ZoneInterface {
    // Called by Consideration whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue) {
        revert("hi");
        return 0x0e1d31dc;
    }

    // Called by Consideration whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view returns (bytes4 validOrderMagicValue) {
        AdvancedOrder memory _order = order;
        bytes32[] memory _priorOrderHashes = priorOrderHashes;
        CriteriaResolver[] memory _criteriaResolvers = criteriaResolvers;
        revert(hex"696969696969");
        return 0x0e1d31dc;
    }
}
