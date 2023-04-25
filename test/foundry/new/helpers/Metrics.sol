// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { vm } from "./VmUtils.sol";
import { LibString } from "solady/src/utils/LibString.sol";

using LibString for uint256;
using LibString for string;

function logCall(string memory name) {
    logCall(name, true);
}

function logCall(string memory name, bool enabled) {
    logCounter("call", name, enabled);
}

function logScuff(
    bool pass,
    string memory functionName,
    string memory kind,
    bytes memory returnData,
    bool enabled
) {
    logCounter("scuff-result", pass ? "pass" : "revert", enabled);
    logCounter("scuff-method", functionName, enabled);
    logCounter("scuff-kind", kind, enabled);
    string[] memory segments = kind.split("_");
    if (segments.length >= 2) {
        string memory field = segments[segments.length - 2];
        logCounter("scuff-field", field, enabled);
    }
    if (!pass) {
        uint256 errorSelector;
        if (returnData.length >= 4) {
            assembly {
                errorSelector := and(mload(add(returnData, 0x04)), 0xffffffff)
            }
        }
        logCounter("scuff-error", errorSelector.toHexString(), enabled);
    }
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
