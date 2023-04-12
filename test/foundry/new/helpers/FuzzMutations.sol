// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { OrderEligibilityLib } from "./FuzzMutationHelpers.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { OrderType } from "seaport-sol/SeaportEnums.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

library MutationFilters {
    using AdvancedOrderLib for AdvancedOrder;

    // Determine if an order is unavailable, has been validated, has an offerer
    // with code, has an offerer equal to the caller, or is a contract order.
    function ineligibleForInvalidSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (!context.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        if (order.parameters.offerer == context.caller) {
            return true;
        }

        if (order.parameters.offerer.code.length != 0) {
            return true;
        }

        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.orderHashes[orderIndex]
        );

        if (isValidated) {
            return true;
        }

        return false;
    }
}

contract FuzzMutations is Test, FuzzExecutor {
    using OrderEligibilityLib for FuzzTestContext;

    function mutation_invalidSignature(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(
            MutationFilters.ineligibleForInvalidSignature
        );

        AdvancedOrder memory order = context.selectEligibleOrder();

        // TODO: fuzz on size of invalid signature
        order.signature = "";

        exec(context);
    }
}
