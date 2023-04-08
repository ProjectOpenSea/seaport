// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

import { OrderParametersLib } from "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    Execution,
    OrderParameters,
    OrderType
} from "seaport-sol/SeaportStructs.sol";

import { OrderStatus as OrderStatusEnum } from "seaport-sol/SpaceEnums.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import {
    TestCalldataHashContractOfferer
} from "../../../../contracts/test/TestCalldataHashContractOfferer.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

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
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    address payable testZone;
    address payable contractOfferer;

    /**
     * @dev Check that the returned `fulfilled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderFulfilled(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.fulfilled,
            true,
            "check_orderFulfilled: not all orders were fulfilled"
        );
    }

    /**
     * @dev Check that the returned `validated` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderValidated(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.validated,
            true,
            "check_orderValidated: not all orders were validated"
        );
    }

    /**
     * @dev Check that the returned `cancelled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderCancelled(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.cancelled,
            true,
            "check_orderCancelled: not all orders were cancelled"
        );
    }

    /**
     * @dev Check that the returned `availableOrders` array length was the
     *      expected length and matches the expected array.
     *
     * @param context A Fuzz test context.
     */
    function check_allOrdersFilled(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.availableOrders.length,
            context.orders.length,
            "check_allOrdersFilled: returnValues.availableOrders.length != orders.length"
        );
        assertEq(
            context.returnValues.availableOrders.length,
            context.expectedAvailableOrders.length,
            "check_allOrdersFilled: returnValues.availableOrders.length != expectedAvailableOrders.length"
        );

        for (uint256 i; i < context.returnValues.availableOrders.length; i++) {
            assertEq(
                context.returnValues.availableOrders[i],
                context.expectedAvailableOrders[i],
                "check_allOrdersFilled: returnValues.availableOrders[i] != expectedAvailableOrders[i]"
            );
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
        // Iterate over the orders.
        for (uint256 i; i < context.orders.length; i++) {
            // If the order has a zone, check the calldata.
            if (context.orders[i].parameters.zone != address(0)) {
                testZone = payable(context.orders[i].parameters.zone);

                AdvancedOrder memory order = context.orders[i];

                // Each order has a calldata hash, indexed to orders, that is
                // expected to be returned by the zone.
                bytes32 expectedCalldataHash = context.expectedZoneCalldataHash[
                    i
                ];

                bytes32 orderHash = order.getTipNeutralizedOrderHash(
                    context.seaport
                );

                // Use the order hash to get the expected calldata hash from the
                // zone.
                bytes32 actualCalldataHash = HashValidationZoneOfferer(testZone)
                    .orderHashToValidateOrderDataHash(orderHash);

                // Check that the expected calldata hash matches the actual
                // calldata hash.
                assertEq(
                    actualCalldataHash,
                    expectedCalldataHash,
                    "check_validateOrderExpectedDataHash: actualCalldataHash != expectedCalldataHash"
                );
            }
        }
    }

    function check_contractOrderExpectedDataHashes(
        FuzzTestContext memory context
    ) public {
        bytes32[] memory orderHashes = context.orders.getOrderHashes(
            address(context.seaport)
        );
        bytes32[2][] memory expectedCalldataHashes = context
            .expectedContractOrderCalldataHashes;
        for (uint256 i; i < context.orders.length; i++) {
            AdvancedOrder memory order = context.orders[i];

            bytes32 orderHash = orderHashes[i];

            bytes32 expectedGenerateOrderCalldataHash = expectedCalldataHashes[
                i
            ][0];

            bytes32 expectedRatifyOrderCalldataHash = expectedCalldataHashes[i][
                1
            ];

            bytes32 actualGenerateOrderCalldataHash;
            bytes32 actualRatifyOrderCalldataHash;

            if (order.parameters.orderType == OrderType.CONTRACT) {
                contractOfferer = payable(order.parameters.offerer);

                // Decrease contractOffererNonce in the orderHash by 1 since it
                // has increased by 1 post-execution.
                bytes32 generateOrderOrderHash;

                assembly {
                    let mask := sub(0, 2) // 0xffff...fff0
                    generateOrderOrderHash := and(orderHash, mask)
                }

                actualGenerateOrderCalldataHash = TestCalldataHashContractOfferer(
                    contractOfferer
                ).orderHashToGenerateOrderDataHash(generateOrderOrderHash);

                actualRatifyOrderCalldataHash = TestCalldataHashContractOfferer(
                    contractOfferer
                ).orderHashToRatifyOrderDataHash(orderHash);
            } else {
                actualGenerateOrderCalldataHash = bytes32(0);
                actualRatifyOrderCalldataHash = bytes32(0);
            }

            assertEq(
                expectedGenerateOrderCalldataHash,
                actualGenerateOrderCalldataHash,
                "check_contractOrderExpectedDataHashes: actualGenerateOrderCalldataHash != expectedGenerateOrderCalldataHash"
            );
            assertEq(
                expectedRatifyOrderCalldataHash,
                actualRatifyOrderCalldataHash,
                "check_contractOrderExpectedDataHashes: actualRatifyOrderCalldataHash != expectedRatifyOrderCalldataHash"
            );
        }
    }

    /**
     * @dev Check that the returned `executions` array length is non-zero.
     *
     * @param context A Fuzz test context.
     */
    function check_executionsPresent(FuzzTestContext memory context) public {
        assertTrue(
            context.returnValues.executions.length > 0,
            "check_executionsPresent: returnValues.executions.length == 0"
        );
    }

    function check_executions(FuzzTestContext memory context) public {
        // TODO: fulfillAvailable cases return an extra expected execution

        assertEq(
            context.returnValues.executions.length,
            context.expectedExplicitExecutions.length,
            "check_executions: expectedExplicitExecutions.length != returnValues.executions.length"
        );

        for (
            uint256 i;
            (i < context.expectedExplicitExecutions.length &&
                i < context.returnValues.executions.length);
            i++
        ) {
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
        ExpectedEventsUtil.checkExpectedEvents(context);
    }

    function check_expectedBalances(
        FuzzTestContext memory context
    ) public view {
        context.testHelpers.balanceChecker().checkBalances();
    }

    /**
     * @dev Check that the order status is in expected state.
     *
     * @param context A Fuzz test context.
     */
    function check_orderStatusFullyFilled(
        FuzzTestContext memory context
    ) public {
        for (uint256 i; i < context.orders.length; i++) {
            AdvancedOrder memory order = context.orders[i];

            bytes32 orderHash = order.getTipNeutralizedOrderHash(
                context.seaport
            );

            (, , uint256 totalFilled, uint256 totalSize) = context
                .seaport
                .getOrderStatus(orderHash);

            if (context.preExecOrderStatuses[i] == OrderStatusEnum.FULFILLED) {
                assertEq(
                    totalFilled,
                    1,
                    "check_orderStatusFullyFilled: totalFilled != 1"
                );
                assertEq(
                    totalSize,
                    1,
                    "check_orderStatusFullyFilled: totalSize != 1"
                );
            } else if (context.expectedAvailableOrders[i]) {
                assertEq(totalFilled, order.numerator, "FuzzChecks: totalFilled != numerator");
                assertEq(totalSize, order.denominator, "FuzzChecks: totalSize != denominator");
                assertTrue(totalSize != 0, "FuzzChecks: totalSize != 0");
                assertTrue(totalFilled != 0, "FuzzChecks: totalFilled != 0");
            } else {
                assertTrue(
                    totalFilled == 0,
                    "check_orderStatusFullyFilled: totalFilled != 0"
                );
            }
        }
    }

    function check_ordersValidated(FuzzTestContext memory context) public {
        // Iterate over all orders and if the order was validated pre-execution,
        // check that calling `getOrderStatus` on the order hash returns `true`
        // for `isValid`.
        for (uint256 i; i < context.preExecOrderStatuses.length; i++) {
            // Only check orders that were validated pre-execution.
            if (context.preExecOrderStatuses[i] == OrderStatusEnum.VALIDATED) {
                AdvancedOrder memory order = context.orders[i];
                bytes32 orderHash = order.getTipNeutralizedOrderHash(
                    context.seaport
                );
                (bool isValid, , , ) = context.seaport.getOrderStatus(
                    orderHash
                );
                assertTrue(isValid, "check_ordersValidated: !isValid");
            }
        }
    }
}
