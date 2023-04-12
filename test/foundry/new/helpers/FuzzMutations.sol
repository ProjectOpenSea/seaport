// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

contract FuzzMutations is Test, FuzzExecutor {
    function mutation_invalidSignature(
        FuzzTestContext memory context
    ) external {
        // Find the first available order that also has a non-validated order status
        // and the offerer is not a contract.
        for (uint256 i; i < context.orders.length; i++) {
            context.orders[i].parameters.offerer = address(0);
            context.orders[i].signature = bytes("");
        }

        exec(context);
    }
}
