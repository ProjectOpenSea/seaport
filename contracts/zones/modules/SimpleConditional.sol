// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { BaseZone } from "../BaseZone.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ZoneModuleInterface } from "../interfaces/ZoneModuleInterface.sol";
import { AdvancedOrder } from "../../lib/ConsiderationStructs.sol";

abstract contract SimpleConditional is BaseZone {
    error ConditionNotMet();

    enum ConditionalType {
        Min,
        Max
    }

    ConditionalType internal conditionalType;

    function validateConditionalOrder(uint256 amount, bytes32[] memory orders)
        internal
        view
        returns (bool)
    {
        uint256 counter = 0;

        for (uint256 i = 0; i < orders.length; i++) {
            (, , uint256 fulfilled, uint256 size) = SEAPORT.getOrderStatus(
                orders[i]
            );
            assembly {
                counter := add(counter, and(eq(fulfilled, size), gt(size, 0)))
            }
        }

        return
            conditionalType == ConditionalType.Min
                ? counter >= amount
                : counter <= amount;
    }
}

abstract contract SimpleConditionalMin is SimpleConditional {
    uint256 private immutable _EXTRA_DATA_INDEX = _FIXED_EXTRA_DATA_LENGTH++;

    constructor() {
        conditionalType = ConditionalType.Min;
    }

    function _validateOrder(bytes32, address) internal view virtual override {
        // Reverts on basic validation call since required data is not available
        revert ExtraDataRequired();
    }

    function _validateOrder(
        bytes32,
        address,
        bytes[] memory fixedExtraData,
        bytes[] memory
    ) internal view virtual override {
        (uint256 amount, bytes32[] memory orders) = abi.decode(
            fixedExtraData[_EXTRA_DATA_INDEX],
            (uint256, bytes32[])
        );

        if (!validateConditionalOrder(amount, orders)) {
            revert ConditionNotMet();
        }
    }
}

abstract contract SimpleConditionalMax is SimpleConditional {
    uint256 private immutable _EXTRA_DATA_INDEX = _FIXED_EXTRA_DATA_LENGTH++;

    constructor() {
        conditionalType = ConditionalType.Max;
    }

    function _validateOrder(bytes32, address) internal view virtual override {
        // Reverts on basic validation call since required data is not available
        revert ExtraDataRequired();
    }

    function _validateOrder(
        bytes32,
        address,
        bytes[] memory fixedExtraData,
        bytes[] memory
    ) internal view virtual override {
        (uint256 amount, bytes32[] memory orders) = abi.decode(
            fixedExtraData[_EXTRA_DATA_INDEX],
            (uint256, bytes32[])
        );

        if (!validateConditionalOrder(amount, orders)) {
            revert ConditionNotMet();
        }
    }
}
