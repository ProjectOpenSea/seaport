// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

function logCall(string memory name) {
    logCall(name, true);
}

function logCall(string memory name, bool enabled) {
    logCounter("call", name, enabled);
}

function logMutation(string memory name) {
    logCounter("mutation", name, true);
}

function logAssume(string memory name) {
    logCounter("assume", name, true);
}

function logCounter(string memory file, string memory metric, bool enabled) {
    if (enabled && vm.envOr("SEAPORT_COLLECT_FUZZ_METRICS", false)) {
        string memory counter = string.concat(metric, ":1|c");
        vm.writeLine(string.concat(file, "-metrics.txt"), counter);
    }
}
