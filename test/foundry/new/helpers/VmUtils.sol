// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { logAssume } from "./Metrics.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

/**
 * @dev A wrapper for Foundry vm.assume that logs rejected fuzz runs with a
 *      named reason. Use this instead of vm.assume in fuzz tests and give
 *      each assumption a unique name.
 */
function assume(bool condition, string memory name) {
    if (!condition) {
        logAssume(name);
    }
    vm.assume(condition);
}
