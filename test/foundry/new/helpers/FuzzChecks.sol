// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { TestContext } from "./TestContextLib.sol";
import { Test } from "forge-std/Test.sol";
import {
    TestTransferValidationZoneOfferer
} from "../../../../contracts/test/TestTransferValidationZoneOfferer.sol";
import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

abstract contract FuzzChecks is Test {
    using OrderParametersLib for OrderParameters;

    address payable testZone;

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
}

// state variable accessible in test or pass into TestContext
