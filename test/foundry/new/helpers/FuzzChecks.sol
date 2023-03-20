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
}
