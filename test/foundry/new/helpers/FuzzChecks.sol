// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { Test } from "forge-std/Test.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { State } from "./FuzzHelpers.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

abstract contract FuzzChecks is Test {
    using OrderParametersLib for OrderParameters;

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
