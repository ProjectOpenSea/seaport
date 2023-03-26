// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { Test } from "forge-std/Test.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

/**
 * @dev Check functions are the post-execution assertions we want to validate.
 *      Checks should be public functions that accept a FuzzTestContext as their
 *      only argument. Checks have access to the post-execution FuzzTestContext
 *      and can use it to make test assertions. The check phase happens last,
 *      immediately after execution.
 */
abstract contract FuzzChecks is Test {
    using OrderParametersLib for OrderParameters;
    using FuzzEngineLib for FuzzTestContext;

    address payable testZone;

    /**
     * @dev Check that the returned `fulfilled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderFulfilled(FuzzTestContext memory context) public {
        assertEq(context.returnValues.fulfilled, true);
    }

    /**
     * @dev Check that the returned `validated` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderValidated(FuzzTestContext memory context) public {
        assertEq(context.returnValues.validated, true);
    }

    /**
     * @dev Check that the returned `cancelled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderCancelled(FuzzTestContext memory context) public {
        assertEq(context.returnValues.cancelled, true);
    }

    /**
     * @dev Check that the returned `availableOrders` array length was the
     *      expected length. and that all values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_allOrdersFilled(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.availableOrders.length,
            context.initialOrders.length
        );
        for (uint256 i; i < context.returnValues.availableOrders.length; i++) {
            assertTrue(context.returnValues.availableOrders[i]);
        }
    }

    /**
     * @dev Check that the zone is getting the right calldata.
     *
     * @param context A Fuzz test context.
     */
    function check_validateOrderExpectedDataHash(
        FuzzTestContext memory context
    ) public {
        for (uint256 i; i < context.orders.length; i++) {
            if (context.orders[i].parameters.zone != address(0)) {
                testZone = payable(context.orders[i].parameters.zone);

                AdvancedOrder memory order = context.orders[i];

                bytes32 expectedCalldataHash = context.expectedZoneCalldataHash[
                    i
                ];

                uint256 counter = context.seaport.getCounter(
                    order.parameters.offerer
                );

                OrderComponents memory orderComponents = order
                    .parameters
                    .toOrderComponents(counter);

                bytes32 orderHash = context.seaport.getOrderHash(
                    orderComponents
                );

                bytes32 actualCalldataHash = HashValidationZoneOfferer(testZone)
                    .orderHashToValidateOrderDataHash(orderHash);

                assertEq(actualCalldataHash, expectedCalldataHash);
            }
        }
    }

    /**
     * @dev Check that the returned `executions` array length is non-zero.
     *
     * @param context A Fuzz test context.
     */
    function check_executionsPresent(FuzzTestContext memory context) public {
        assertTrue(context.returnValues.executions.length > 0);
    }

    function check_executions(FuzzTestContext memory context) public {
        // TODO: fulfillAvailable cases return an extra expected execution
        bytes4 action = context.action();

        assertEq(
            context.returnValues.executions.length,
            context.expectedExplicitExecutions.length,
            "check_executions: expectedExplicitExecutions.length != returnValues.executions.length"
        );
        for (uint256 i; i < context.expectedExplicitExecutions.length; i++) {
            Execution memory actual = context.returnValues.executions[i];
            Execution memory expected = context.expectedExplicitExecutions[i];
            assertEq(
                uint256(actual.item.itemType),
                uint256(expected.item.itemType),
                "check_executions: itemType"
            );
            assertEq(
                actual.item.token,
                expected.item.token,
                "check_executions: token"
            );
            assertEq(
                actual.item.identifier,
                expected.item.identifier,
                "check_executions: identifier"
            );
            assertEq(
                actual.item.amount,
                expected.item.amount,
                "check_executions: amount"
            );
            assertEq(
                address(actual.item.recipient),
                address(expected.item.recipient),
                "check_executions: recipient"
            );
            assertEq(
                actual.conduitKey,
                expected.conduitKey,
                "check_executions: conduitKey"
            );
            assertEq(
                actual.offerer,
                expected.offerer,
                "check_executions: offerer"
            );
        }
    }

    function check_expectedEventsEmitted(
        FuzzTestContext memory context
    ) public {
        bytes4 action = context.action();

        ExpectedEventsUtil.checkExpectedEvents(context);
    }
}

// state variable accessible in test or pass into FuzzTestContext
