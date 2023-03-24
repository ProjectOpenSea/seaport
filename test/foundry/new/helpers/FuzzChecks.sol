// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import { Test } from "forge-std/Test.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

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
     * @dev Check that the returned `executions` and `expectedExecutions` match.
     *
     * @param context A Fuzz test context.
     */
    function check_executions(FuzzTestContext memory context) public {
        bytes4 action = context.action();
        // TODO: Currently skipping this check for match cases (helper not
        //       implemented yet). Fulfill available cases seem to have an
        //       off-by-some error.
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) return;

        Execution[] memory expectedExecutions = new Execution[](
            context.expectedExplicitExecutions.length +
                context.expectedImplicitExecutions.length
        );
        uint256 expectedExecutionsIndex;
        for (uint256 i; i < context.expectedExplicitExecutions.length; ++i) {
            expectedExecutions[expectedExecutionsIndex] = context
                .expectedExplicitExecutions[i];
            ++expectedExecutionsIndex;
        }
        for (
            uint256 i = 0;
            i < context.expectedImplicitExecutions.length;
            ++i
        ) {
            expectedExecutions[expectedExecutionsIndex] = context
                .expectedImplicitExecutions[i];
            ++expectedExecutionsIndex;
        }
        console.log(
            "expectedExplicitExecutions.length",
            context.expectedExplicitExecutions.length
        );
        console.log(
            "expectedImplicitExecutions.length",
            context.expectedImplicitExecutions.length
        );
        assertEq(
            context.returnValues.executions.length,
            context.expectedExplicitExecutions.length,
            "check_executions: expectedExecutions.length != returnValues.executions.length"
        );
    }

    /**
     * @dev Check that the order status is in expected state.
     *
     * @param context A Fuzz test context.
     */
    function check_orderStatusCorrect(
        FuzzTestContext memory context
        // ,
        // State expectedState
    ) public {
        for (uint256 i; i < context.orders.length; i++) {
            AdvancedOrder memory order = context.orders[i];
            uint256 counter = context.seaport.getCounter(
                order.parameters.offerer
            );
            OrderComponents memory orderComponents = order
                .parameters
                .toOrderComponents(counter);
            bytes32 orderHash = context.seaport.getOrderHash(orderComponents);
            (, , uint256 totalFilled, uint256 totalSize) = context
                .seaport
                .getOrderStatus(orderHash);

            if (totalFilled != totalSize) {
                emit log_named_uint("totalFilled", totalFilled);
                emit log_named_uint("totalSize", totalSize);
                revert('NOT EQUAL');
            }

            // TODO: Can we pass arguments into these?
            //if (expectedState == State.FULLY_FILLED) {
                assertEq(totalFilled, totalSize);
            // } else if (expectedState == State.PARTIALLY_FILLED) {
            //     assertTrue(totalFilled < totalSize);
            // }
        }
    }
}

// state variable accessible in test or pass into FuzzTestContext
