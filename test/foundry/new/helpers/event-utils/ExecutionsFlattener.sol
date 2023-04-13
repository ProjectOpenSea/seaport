// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ArrayHelpers, MemoryPointer } from "seaport-sol/../ArrayHelpers.sol";

import { Execution } from "seaport-sol/SeaportStructs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

library ExecutionsFlattener {
    using ArrayHelpers for MemoryPointer;
    using ExecutionsFlattener for *;

    function flattenExecutions(FuzzTestContext memory context) internal pure {
        context.expectations.allExpectedExecutions = ArrayHelpers
            .flatten
            .asExecutionsFlatten()(
                context.expectations.expectedExplicitExecutions,
                context.expectations.expectedImplicitExecutions
            );
    }

    function asExecutionsFlatten(
        function(MemoryPointer, MemoryPointer)
            internal
            view
            returns (MemoryPointer) fnIn
    )
        internal
        pure
        returns (
            function(Execution[] memory, Execution[] memory)
                internal
                pure
                returns (Execution[] memory) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }
}
