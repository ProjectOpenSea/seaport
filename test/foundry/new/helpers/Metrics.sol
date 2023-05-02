// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { vm } from "./VmUtils.sol";

function logCall(string memory name) {
    logCall(name, true);
}

/**
 * @dev Log a call to "call-metrics.txt"
 */
function logCall(string memory name, bool enabled) {
    logCounter("call", name, enabled);
}

/**
 * @dev Log a mutation to "mutation-metrics.txt"
 */
function logMutation(string memory name) {
    logCounter("mutation", name, true);
}

/**
 * @dev Log a vm.assume to "assume-metrics.txt"
 */
function logAssume(string memory name) {
    logCounter("assume", name, true);
}

/**
 * @dev Log a counter to a metrics file if the SEAPORT_COLLECT_FUZZ_METRICS env
 *      var is set. Named metrics are written as statsd counters, e.g.
 *      "metric:1|c". To write to a new file, it must be allowlisted under
 *      `fs_permissions` in `foundry.toml`.
 *
 * @param file     name of the metrics file to write to. "-metrics.txt" will be
 *                 appended to the name.
 * @param metric   name of the metric to increment.
 * @param enabled  flag to enable/disable metrics collection
 */
function logCounter(string memory file, string memory metric, bool enabled) {
    if (enabled && vm.envOr("SEAPORT_COLLECT_FUZZ_METRICS", false)) {
        string memory counter = string.concat(metric, ":1|c");
        vm.writeLine(string.concat(file, "-metrics.txt"), counter);
    }
}
