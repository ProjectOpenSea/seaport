// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { logAssume } from "./Metrics.sol";
import { console2 } from "forge-std/console2.sol";

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
