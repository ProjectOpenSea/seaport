// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ArrayHelpers, MemoryPointer } from "seaport-sol/../ArrayHelpers.sol";

import { Execution, ItemType } from "seaport-sol/SeaportStructs.sol";
import { ExecutionLib } from "seaport-sol/lib/ExecutionLib.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

library ExecutionsFlattener {
    using ArrayHelpers for MemoryPointer;
    using ExecutionsFlattener for *;
    using ExecutionLib for Execution;

    function flattenExecutions(FuzzTestContext memory context) internal pure {
        context.expectations.allExpectedExecutions = ArrayHelpers
            .flattenThree
            .asExecutionsFlatten()(
                context.expectations.expectedImplicitPreExecutions,
                ArrayHelpers.mapWithArg.asMap()(
                    context.expectations.expectedExplicitExecutions,
                    fixExplicitExecution,
                    context
                ),
                context.expectations.expectedImplicitPostExecutions
            );
    }

    function fixExplicitExecution(
        Execution memory execution,
        FuzzTestContext memory context
    ) internal pure returns (Execution memory) {
        if (execution.item.itemType == ItemType.NATIVE) {
            return execution.copy().withOfferer(address(context.seaport));
        }
        return execution;
    }

    function asMapCallback(
        function(Execution memory, FuzzTestContext memory)
            internal
            pure
            returns (Execution memory) fnIn
    )
        internal
        pure
        returns (
            function(MemoryPointer, MemoryPointer)
                internal
                pure
                returns (MemoryPointer) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }

    function asMap(
        function(
            MemoryPointer,
            function(MemoryPointer, MemoryPointer)
                internal
                pure
                returns (MemoryPointer),
            MemoryPointer
        ) internal pure returns (MemoryPointer) fnIn
    )
        internal
        pure
        returns (
            function(
                Execution[] memory,
                function(Execution memory, FuzzTestContext memory)
                    internal
                    pure
                    returns (Execution memory),

                FuzzTestContext memory
            ) internal pure returns (Execution[] memory) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }

    function asExecutionsFlatten(
        function(MemoryPointer, MemoryPointer, MemoryPointer)
            internal
            view
            returns (MemoryPointer) fnIn
    )
        internal
        pure
        returns (
            function(Execution[] memory, Execution[] memory, Execution[] memory)
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
