// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ArrayHelpers, MemoryPointer } from "seaport/helpers/ArrayHelpers.sol";

import { Execution, ItemType } from "seaport-sol/src/SeaportStructs.sol";
import { ExecutionLib } from "seaport-sol/src/lib/ExecutionLib.sol";

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
        require(
            context.expectations.allExpectedExecutions.length ==
                context.expectations.expectedImplicitPreExecutions.length +
                    context.expectations.expectedExplicitExecutions.length +
                    context.expectations.expectedImplicitPostExecutions.length,
            "LENGTHS OF EXECUTIONS DO NOT MATCH"
        );
        uint256 e;
        for (
            uint256 i;
            i < context.expectations.expectedImplicitPreExecutions.length;
            i++
        ) {
            Execution memory execution1 = context
                .expectations
                .expectedImplicitPreExecutions[i];
            Execution memory execution2 = context
                .expectations
                .allExpectedExecutions[e++];
            require(
                keccak256(abi.encode(execution1)) ==
                    keccak256(abi.encode(execution2)),
                "IMPLICIT PRE EXECUTIONS DO NOT MATCH"
            );
        }
        for (
            uint256 i;
            i < context.expectations.expectedExplicitExecutions.length;
            i++
        ) {
            Execution memory execution1 = context
                .expectations
                .expectedExplicitExecutions[i];
            Execution memory execution2 = context
                .expectations
                .allExpectedExecutions[e++];
            if (execution1.item.itemType == ItemType.NATIVE) {
                require(
                    execution2.offerer == address(context.seaport),
                    "SEAPORT NOT SET ON EXECUTION"
                );
                require(
                    execution1.conduitKey == execution2.conduitKey &&
                        keccak256(abi.encode(execution1.item)) ==
                        keccak256(abi.encode(execution2.item)),
                    "EXPLICIT EXECUTIONS DO NOT MATCH"
                );
            } else {
                require(
                    keccak256(abi.encode(execution1)) ==
                        keccak256(abi.encode(execution2)),
                    "EXPLICIT EXECUTIONS DO NOT MATCH"
                );
            }
        }
        for (
            uint256 i;
            i < context.expectations.expectedImplicitPostExecutions.length;
            i++
        ) {
            Execution memory execution1 = context
                .expectations
                .expectedImplicitPostExecutions[i];
            Execution memory execution2 = context
                .expectations
                .allExpectedExecutions[e++];
            require(
                keccak256(abi.encode(execution1)) ==
                    keccak256(abi.encode(execution2)),
                "IMPLICIT PRE EXECUTIONS DO NOT MATCH"
            );
        }
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

    function asExecutionsFlatten2(
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
