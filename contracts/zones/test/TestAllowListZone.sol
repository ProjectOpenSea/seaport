// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AllowList, BaseZone } from "../modules/AllowList.sol";
import { ServerSigned } from "../modules/ServerSigned.sol";
import {
    AdvancedOrder,
    CriteriaResolver
} from "../../lib/ConsiderationStructs.sol";
import { ZoneInterface } from "../../interfaces/ZoneInterface.sol";

contract TestAllowListZone is AllowList {
    constructor(address seaport) BaseZone(seaport) {}

    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address,
        bytes32
    ) external view returns (bytes4 validOrderMagicValue) {
        AllowList._validateOrder(orderHash, caller);

        return ZoneInterface.isValidOrder.selector;
    }

    // Called by Consideration whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata,
        CriteriaResolver[] calldata
    ) external view returns (bytes4 validOrderMagicValue) {
        (
            bytes[] memory fixedExtraDatas,
            bytes[] memory variableExtraDatas
        ) = _parseExtraData(order);
        AllowList._validateOrder(
            orderHash,
            caller,
            fixedExtraDatas,
            variableExtraDatas
        );

        return ZoneInterface.isValidOrderIncludingExtraData.selector;
    }
}
