// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

contract FuzzMutations is Test, FuzzExecutor {
    function mutation_setNullOfferer(FuzzTestContext memory context) public {
        // Set null offerer on all orders
        for (uint256 i; i < context.orders.length; i++) {
            context.orders[i].parameters.offerer = address(0);
        }

        exec(context);
    }
}
