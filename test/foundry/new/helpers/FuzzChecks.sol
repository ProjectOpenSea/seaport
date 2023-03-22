// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { TestContext } from "./TestContextLib.sol";
import { Test } from "forge-std/Test.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";
import {
    TestCalldataHashContractOfferer
} from "../../../../contracts/test/TestCalldataHashContractOfferer.sol";
import {
    TestTransferValidationZoneOfferer
} from "../../../../contracts/test/TestTransferValidationZoneOfferer.sol";
import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

abstract contract FuzzChecks is Test {
    using OrderParametersLib for OrderParameters;
    using FuzzHelpers for AdvancedOrder[];

    address payable testZone;
    address payable contractOfferer;

    function check_orderFulfilled(TestContext memory context) public {
        assertEq(context.returnValues.fulfilled, true);
    }

    function check_orderValidated(TestContext memory context) public {
        assertEq(context.returnValues.validated, true);
    }

    function check_orderCancelled(TestContext memory context) public {
        assertEq(context.returnValues.cancelled, true);
    }

    function check_allOrdersFilled(TestContext memory context) public {
        assertEq(
            context.returnValues.availableOrders.length,
            context.initialOrders.length
        );
        for (uint256 i; i < context.returnValues.availableOrders.length; i++) {
            assertTrue(context.returnValues.availableOrders[i]);
        }
    }

    function check_validateOrderExpectedDataHash(
        TestContext memory context
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

                bytes32 actualCalldataHash = TestTransferValidationZoneOfferer(
                    testZone
                ).orderHashToValidateOrderDataHash(orderHash);

                assertEq(actualCalldataHash, expectedCalldataHash);
            }
        }
    }

    function check_contractOrderExpectedDataHashes(
        TestContext memory context
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
                bytes32 mask = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0;

                assembly {
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
                actualGenerateOrderCalldataHash
            );
            assertEq(
                expectedRatifyOrderCalldataHash,
                actualRatifyOrderCalldataHash
            );
        }
    }

    function check_executionsPresent(TestContext memory context) public {
        assertTrue(context.returnValues.executions.length > 0);
    }
}

// state variable accessible in test or pass into TestContext
