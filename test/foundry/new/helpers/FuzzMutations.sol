// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { OrderType } from "seaport-sol/SeaportEnums.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

contract MutationFilters {
    using AdvancedOrderLib for AdvancedOrder;

    // Determine if an order is unavailable, has been validated, has an offerer
    // with code, has an offerer equal to the caller, or is a contract order.
    function ineligibleForInvalidSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (!context.expectedAvailableOrders[orderIndex]) {
            return false;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return false;
        }

        if (order.parameters.offerer == context.caller) {
            return false;
        }

        if (order.parameters.offerer.code.length != 0) {
            return false;
        }

        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.orderHashes[orderIndex]
        );

        if (isValidated) {
            return false;
        }

        return true;
    }
}

contract FuzzMutations is Test, FuzzExecutor, MutationFilters {
    using OrderEligibilityLib for FuzzTestContext;

    function mutation_invalidSignature(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(ineligibleForInvalidSignature);

        AdvancedOrder memory order = context.selectEligibleOrder();

        // TODO: fuzz on size of invalid signature
        order.signature = "";

        exec(context);
    }
}

library OrderEligibilityLib {
    using LibPRNG for LibPRNG.PRNG;

    function setIneligibleOrders(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) condition
    ) internal view {
        for (uint256 i; i < context.orders.length; i++) {
            if (condition(context.orders[i], i, context)) {
                setIneligibleOrder(context, i);
            }
        }
    }

    function setIneligibleOrder(
        FuzzTestContext memory context,
        uint256 ineligibleOrderIndex
    ) internal pure {
        // Set the respective boolean for the ineligible order.
        context.ineligibleOrders[ineligibleOrderIndex] = true;
    }

    function getEligibleOrders(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder[] memory eligibleOrders) {
        eligibleOrders = new AdvancedOrder[](context.orders.length);

        uint256 totalEligibleOrders = 0;
        for (uint256 i = 0; i < context.ineligibleOrders.length; ++i) {
            // If the boolean is not set, the order is still eligible.
            if (!context.ineligibleOrders[i]) {
                eligibleOrders[totalEligibleOrders++] = context.orders[i];
            }
        }

        // Update the eligibleOrders array with the actual length.
        assembly {
            mstore(eligibleOrders, totalEligibleOrders)
        }
    }

    // TODO: may also want to return the order index for backing out to e.g.
    // orderIndex in fulfillments or criteria resolvers
    function selectEligibleOrder(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder memory eligibleOrder) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed ^ 0xff);

        AdvancedOrder[] memory eligibleOrders = getEligibleOrders(context);

        if (eligibleOrders.length == 0) {
            revert("OrderEligibilityLib: no eligible order found");
        }

        return eligibleOrders[prng.next() % eligibleOrders.length];
    }
}
