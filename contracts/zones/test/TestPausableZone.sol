// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Pausable, BaseZone } from "../modules/Pausable.sol";
import {
    AdvancedOrder,
    CriteriaResolver
} from "../../lib/ConsiderationStructs.sol";
import { ZoneInterface } from "../../interfaces/ZoneInterface.sol";

contract TestPausableZone is Pausable {
    constructor(address seaport) BaseZone(seaport) {}

    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address,
        bytes32
    ) external view returns (bytes4 validOrderMagicValue) {
        Pausable._validateOrder(orderHash, caller);

        return ZoneInterface.isValidOrder.selector;
    }

    // Called by Consideration whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata,
        bytes32[] calldata,
        CriteriaResolver[] calldata
    ) external view returns (bytes4 validOrderMagicValue) {
        Pausable._validateOrder(
            orderHash,
            caller,
            new bytes[](0),
            new bytes[](0)
        );

        return ZoneInterface.isValidOrderIncludingExtraData.selector;
    }
}
