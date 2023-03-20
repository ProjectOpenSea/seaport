// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { TestContext } from "./TestContextLib.sol";
import { Test } from "forge-std/Test.sol";

abstract contract FuzzChecks is Test {
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
}
