// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";

import "seaport-sol/../ArrayHelpers.sol";

import {
    Execution
} from "../../../../../contracts/lib/ConsiderationStructs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";
import { FuzzEngineLib } from "../FuzzEngineLib.sol";

import { ForgeEventsLib } from "./ForgeEventsLib.sol";

import { TransferEventsLib } from "./TransferEventsLib.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

bytes32 constant Topic0_ERC20_ERC721_Transfer = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
bytes32 constant Topic0_ERC1155_TransferSingle = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;

library ExpectedEventsUtil {
    using ArrayHelpers for MemoryPointer;
    using FuzzEngineLib for FuzzTestContext;
    using ForgeEventsLib for Vm.Log;
    using Casts for *;

    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));

    Vm private constant vm = Vm(VM_ADDRESS);

    function setExpectedEventHashes(
        FuzzTestContext memory context
    ) internal pure {
        Execution[] memory executions = ArrayHelpers
            .flatten
            .asExecutionsFlatten()(
                context.expectedExplicitExecutions,
                context.expectedImplicitExecutions
            );
        require(
            executions.length ==
                context.expectedExplicitExecutions.length +
                    context.expectedImplicitExecutions.length
        );
        /*         for (uint256 i; i < executions.length; i++) {
          Execution memory execution = executions[i];
          ReceivedItem memory item = execution.item;
          console2.log("Expecting item type: ", )
        } */
        context.expectedEventHashes = ArrayHelpers
            .filterMapWithArg
            .asExecutionsFilterMap()(
                executions,
                TransferEventsLib.getTransferEventHash,
                context
            );
    }

    function startRecordingLogs() internal {
        vm.recordLogs();
    }

    function checkExpectedEvents(FuzzTestContext memory context) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 logIndex;
        // MemoryPointer expectedEvents = toMemoryPointer(eventHashes);
        bytes32[] memory expectedEventHashes = context.expectedEventHashes;
        // For each expected event, verify that it matches the next log
        // in `logs` that has a topic0 matching one of the watched events.
        uint256 lastLogIndex = ArrayHelpers.reduceWithArg.asLogsReduce()(
            expectedEventHashes,
            checkNextEvent, // function called for each item in expectedEvents
            0, // initial value for the reduce call, index 0
            logs // 3rd argument given to checkNextEvent
        );
        // Verify that there are no other watched events in the array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(logs, isWatchedEvent, lastLogIndex);

        // assertEq(n)

        if (nextWatchedEventIndex != -1) {
            uint256 count = uint256(
                ArrayHelpers.countFrom.asLogsFindIndex()(
                    logs,
                    isWatchedEvent,
                    0
                )
            );

            console2.log(
                string.concat(
                  "\n\t\tmethod: ", context.actionName(),
                  "\n\t\texpected watched events: ",
                  Strings.toString(expectedEventHashes.length),
                  "\n\t\texplicit executions: ",
                  Strings.toString(context.expectedExplicitExecutions.length),
                  "\n\t\timplicit executions: ",
                  Strings.toString(context.expectedImplicitExecutions.length),
                  "\n"
                )
            );
            Vm.Log memory nextLog = logs[uint256(nextWatchedEventIndex)];
            nextLog.reEmit();

            revert("expected events failure -- too many watched events");
        }
    }

    /**
     * @dev This function defines which logs matter for the sake of the fuzz
     *      tests. This is called for every log emitted during a test run. If
     *      it returns true, `checkNextEvent` will assert that the log matches the
     *      next expected event recorded in the test context.
     */
    function isWatchedEvent(Vm.Log memory log) internal pure returns (bool) {
        bytes32 topic0 = log.getTopic0();
        return
            topic0 == Topic0_ERC20_ERC721_Transfer ||
            topic0 == Topic0_ERC20_ERC721_Transfer;
    }

    function checkNextEvent(
        uint256 lastLogIndex,
        uint256 expectedEventHash,
        Vm.Log[] memory logsArray
    ) internal returns (uint256 nextLogIndex) {
        // Get the index of the next watched event in the logs array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(logsArray, isWatchedEvent, lastLogIndex);
        // Revert if there are no remaining transfer events
        require(nextWatchedEventIndex != -1, "ExpectedEvents: event not found");
        // Verify that the transfer event matches the expected event
        uint256 i = uint256(nextWatchedEventIndex);
        Vm.Log memory log = logsArray[i];
        require(
            log.getForgeEventHash() == bytes32(expectedEventHash),
            "ExpectedEvents: event hash does not match"
        );
        // Increment the log index for the next iteration
        return i + 1;
    }
}

library Casts {
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

    function asLogsFindIndex(
        function(
            MemoryPointer,
            function(MemoryPointer) internal pure returns (bool),
            uint256
        ) internal pure returns (int256) fnIn
    )
        internal
        pure
        returns (
            function(
                Vm.Log[] memory,
                function(Vm.Log memory) internal pure returns (bool),
                uint256
            ) internal pure returns (int256) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }

    function asLogsReduce(
        function(
            MemoryPointer,
            function(uint256, uint256, MemoryPointer)
                internal
                returns (uint256),
            uint256,
            MemoryPointer
        ) internal returns (uint256) fnIn
    )
        internal
        pure
        returns (
            function(
                bytes32[] memory,
                function(uint256, uint256, Vm.Log[] memory)
                    internal
                    returns (uint256),
                uint256,
                Vm.Log[] memory
            ) internal returns (uint256) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }

    function asExecutionsFilterMap(
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
                    returns (bytes32),
                FuzzTestContext memory
            ) internal pure returns (bytes32[] memory) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }

    function toMemoryPointer(
        Execution[] memory arr
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := arr
        }
    }

    function toMemoryPointer(
        FuzzTestContext memory context
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := context
        }
    }

    function toMemoryPointer(
        Vm.Log[] memory arr
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := arr
        }
    }

    function toMemoryPointer(
        bytes32[] memory arr
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := arr
        }
    }
}
