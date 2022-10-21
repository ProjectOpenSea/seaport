// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ServerSigned, BaseZone } from "../modules/ServerSigned.sol";
import {
    AdvancedOrder,
    CriteriaResolver
} from "../../lib/ConsiderationStructs.sol";
import { ZoneInterface } from "../../interfaces/ZoneInterface.sol";
import { SimpleConditionalMax } from "../modules/SimpleConditional.sol";

contract TestSimpleConditionalMax is SimpleConditionalMax {
    constructor(address seaport) BaseZone(seaport) {}

    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address,
        bytes32
    ) external view returns (bytes4 validOrderMagicValue) {
        SimpleConditionalMax._validateOrder(orderHash, caller);

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
        SimpleConditionalMax._validateOrder(
            orderHash,
            caller,
            fixedExtraDatas,
            variableExtraDatas
        );

        return ZoneInterface.isValidOrderIncludingExtraData.selector;
    }
}
