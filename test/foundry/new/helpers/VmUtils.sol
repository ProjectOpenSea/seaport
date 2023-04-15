// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { logAssume } from "./Metrics.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

function assume(bool condition, string memory name) {
    if (!condition) {
        logAssume(name);
    }
    vm.assume(condition);
}
