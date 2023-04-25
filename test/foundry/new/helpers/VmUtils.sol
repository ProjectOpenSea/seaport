// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { logAssume } from "./Metrics.sol";
import { console2 } from "forge-std/console2.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
bytes32 constant GLOBAL_FAILED_SLOT = bytes32("failed");

Vm constant vm = Vm(VM_ADDRESS);

function checkGlobalFailed() view returns (bool failed) {
    failed = vm.load(VM_ADDRESS, GLOBAL_FAILED_SLOT) != bytes32(0);
}

function setGlobalFailed() {
    vm.store(VM_ADDRESS, GLOBAL_FAILED_SLOT, bytes32(uint256(1)));
}

function unsetGlobalFailed() {
    vm.store(VM_ADDRESS, GLOBAL_FAILED_SLOT, bytes32(0));
}

function assume(bool condition, string memory name) {
    if (!condition) {
        logAssume(name);
    }
    vm.assume(condition);
}

function _log(string memory str) view {
    console2.log(str);
}

function pureLog(string memory str) pure {
    function(string memory) internal fn1 = _log;
    function(string memory) internal pure fn2;
    assembly {
        fn2 := fn1
    }
    fn2(str);
}

library AssertionHelper {
    event log(string);
    event log_named_uint(string key, uint val);
    event log_named_string(string key, string val);

    function assertEq(uint a, uint b, string memory err) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            emit log("Error: a == b not satisfied [uint]");
            emit log_named_uint("      Left", a);
            emit log_named_uint("     Right", b);
            setGlobalFailed();
        }
    }
}

function pureAssertEq(uint a, uint b, string memory str) pure {
    function(uint, uint, string memory) internal fn1 = AssertionHelper.assertEq;
    function(uint, uint, string memory) internal pure fn2;
    assembly {
        fn2 := fn1
    }
    fn2(a, b, str);
}

function pureAssertEq(address a, address b, string memory str) pure {
    function(uint, uint, string memory) internal fn1 = AssertionHelper.assertEq;
    function(address, address, string memory) internal pure fn2;
    assembly {
        fn2 := fn1
    }
    fn2(a, b, str);
}

function pureAssertEq(bool a, bool b, string memory str) pure {
    function(uint, uint, string memory) internal fn1 = AssertionHelper.assertEq;
    function(bool, bool, string memory) internal pure fn2;
    assembly {
        fn2 := fn1
    }
    fn2(a, b, str);
}
