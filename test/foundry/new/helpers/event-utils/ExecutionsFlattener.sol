// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ArrayHelpers, MemoryPointer } from "seaport-sol/../ArrayHelpers.sol";

import {
    Execution
} from "../../../../../contracts/lib/ConsiderationStructs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

library ExecutionsFlattener {
    using ArrayHelpers for MemoryPointer;
    using ExecutionsFlattener for *;

    function flattenExecutions(FuzzTestContext memory context) internal pure {
        context.allExpectedExecutions = ArrayHelpers
            .flatten
            .asExecutionsFlatten()(
                context.expectedExplicitExecutions,
                context.expectedImplicitExecutions
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
