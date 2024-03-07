// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Vm } from "forge-std/Vm.sol";

import {
    ArrayHelpers,
    MemoryPointer
} from "../../../../../contracts/helpers/ArrayHelpers.sol";

import { Execution } from "seaport-sol/src/SeaportStructs.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { FuzzEngineLib } from "../FuzzEngineLib.sol";

import { FuzzEngine } from "../FuzzEngine.sol";

import { ForgeEventsLib } from "./ForgeEventsLib.sol";

import { TransferEventsLib } from "./TransferEventsLib.sol";

import { OrderFulfilledEventsLib } from "./OrderFulfilledEventsLib.sol";

import { OrdersMatchedEventsLib } from "./OrdersMatchedEventsLib.sol";

import { dumpTransfers } from "../DebugUtil.sol";

bytes32 constant Topic0_ERC20_ERC721_Transfer = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
bytes32 constant Topic0_ERC1155_TransferSingle = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;

struct ReduceInput {
    Vm.Log[] logsArray;
    FuzzTestContext context;
}

struct Log {
    bytes32[] topics;
    bytes data;
    address emitter;
}

/**
 * @dev This library is used to check that the events emitted by tests match the
 *      expected events.
 */
library ExpectedEventsUtil {
    using ArrayHelpers for MemoryPointer;
    using Casts for *;
    using ForgeEventsLib for Vm.Log;
    using ForgeEventsLib for Vm.Log[];
    using FuzzEngineLib for FuzzTestContext;
    using OrderFulfilledEventsLib for FuzzTestContext;
    using OrdersMatchedEventsLib for FuzzTestContext;

    /**
     * @dev Set up the Vm.
     */

    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event OrderFulfilled(
        bytes32 orderHash,
        address indexed offerer,
        address indexed zone,
        address recipient,
        SpentItem[] offer,
        ReceivedItem[] consideration
    );

    event OrdersMatched(bytes32[] orderHashes);

    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        ERC721_WITH_CRITERIA,
        ERC1155_WITH_CRITERIA
    }

    struct SpentItem {
        ItemType itemType;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    struct ReceivedItem {
        ItemType itemType;
        address token;
        uint256 identifier;
        uint256 amount;
        address payable recipient;
    }

    /**
     * @dev Sets up the expected event hashes.
     *
     * @param context The test context
     */
    function setExpectedTransferEventHashes(
        FuzzTestContext memory context
    ) internal {
        Execution[] memory executions = context
            .expectations
            .allExpectedExecutions;
        require(
            executions.length ==
                context.expectations.expectedImplicitPreExecutions.length +
                    context.expectations.expectedExplicitExecutions.length +
                    context.expectations.expectedImplicitPostExecutions.length,
            "ExpectedEventsUtil: executions length mismatch"
        );

        Execution[] memory filteredExecutions = new Execution[](
            executions.length
        );

        uint256 filteredExecutionIndex = 0;

        for (uint256 i = 0; i < executions.length; ++i) {
            if (executions[i].item.amount > 0) {
                filteredExecutions[filteredExecutionIndex++] = executions[i];
            }
        }

        assembly {
            mstore(filteredExecutions, filteredExecutionIndex)
        }

        context.expectations.expectedTransferEventHashes = ArrayHelpers
            .filterMapWithArg
            .asExecutionsFilterMap()(
                filteredExecutions,
                TransferEventsLib.getTransferEventHash,
                context
            );

        vm.serializeBytes32(
            "root",
            "expectedTransferEventHashes",
            context.expectations.expectedTransferEventHashes
        );
    }

    function setExpectedSeaportEventHashes(
        FuzzTestContext memory context
    ) internal {
        bool isMatch = context.action() ==
            context.seaport.matchAdvancedOrders.selector ||
            context.action() == context.seaport.matchOrders.selector;

        uint256 totalExpectedEventHashes = isMatch ? 1 : 0;
        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
                ++totalExpectedEventHashes;
            }
        }

        context.expectations.expectedSeaportEventHashes = new bytes32[](
            totalExpectedEventHashes
        );

        totalExpectedEventHashes = 0;
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
                context.expectations.expectedSeaportEventHashes[
                    totalExpectedEventHashes++
                ] = context.getOrderFulfilledEventHash(i);
            }
        }

        if (isMatch) {
            context.expectations.expectedSeaportEventHashes[
                totalExpectedEventHashes
            ] = context.getOrdersMatchedEventHash();
        }

        vm.serializeBytes32(
            "root",
            "expectedSeaportEventHashes",
            context.expectations.expectedSeaportEventHashes
        );
    }

    /**
     * @dev Starts recording logs.
     */
    function startRecordingLogs() internal {
        vm.recordLogs();
    }

    /**
     * @dev Checks that the events emitted by the test match the expected
     *      events.
     *
     * @param context The test context
     */
    function checkExpectedTransferEvents(
        FuzzTestContext memory context
    ) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory callData = abi.encodeCall(FuzzEngine.setLogs, (logs));
        (bool ok, ) = address(this).call(callData);
        if (!ok) {
            revert("ExpectedEventsUtil: log registration failed");
        }

        // MemoryPointer expectedEvents = toMemoryPointer(eventHashes);
        bytes32[] memory expectedTransferEventHashes = context
            .expectations
            .expectedTransferEventHashes;

        // For each expected event, verify that it matches the next log
        // in `logs` that has a topic0 matching one of the watched events.
        uint256 lastLogIndex = ArrayHelpers.reduceWithArg.asLogsReduce()(
            expectedTransferEventHashes,
            checkNextTransferEvent, // function called for each item in expectedEvents
            0, // initial value for the reduce call, index 0
            ReduceInput(logs, context) // 3rd argument given to checkNextTransferEvent
        );

        // Verify that there are no other watched events in the array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(logs, isWatchedTransferEvent, lastLogIndex);

        if (nextWatchedEventIndex != -1) {
            dumpTransfers(context);
            revert(
                "ExpectedEvents: too many watched transfer events - info written to fuzz_debug.json"
            );
        }
    }

    function checkExpectedSeaportEvents(
        FuzzTestContext memory context
    ) internal {
        // TODO: set these upstream (this expects checkExpectedTransferEvents to run first)
        bytes memory callData = abi.encodeCall(FuzzEngine.getLogs, ());
        (, bytes memory returnData) = address(this).call(callData);
        Log[] memory rawLogs = abi.decode(returnData, (Log[]));

        Vm.Log[] memory logs = new Vm.Log[](rawLogs.length);

        for (uint256 i = 0; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            Log memory rawLog = rawLogs[i];

            log.topics = rawLog.topics;
            log.data = rawLog.data;
            log.emitter = rawLog.emitter;
        }

        // MemoryPointer expectedEvents = toMemoryPointer(eventHashes);
        bytes32[] memory expectedSeaportEventHashes = context
            .expectations
            .expectedSeaportEventHashes;

        // For each expected event, verify that it matches the next log
        // in `logs` that has a topic0 matching one of the watched events.
        uint256 lastLogIndex = ArrayHelpers.reduceWithArg.asLogsReduce()(
            expectedSeaportEventHashes,
            checkNextSeaportEvent, // function called for each item in expectedEvents
            0, // initial value for the reduce call, index 0
            ReduceInput(logs, context) // 3rd argument given to checkNextSeaportEvent
        );

        // Verify that there are no other watched events in the array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(logs, isWatchedSeaportEvent, lastLogIndex);

        if (nextWatchedEventIndex != -1) {
            revert("ExpectedEvents: too many watched seaport events");
        }
    }

    /**
     * @dev This function defines which logs matter for the sake of the fuzz
     *      tests. This is called for every log emitted during a test run. If
     *      it returns true, `checkNextEvent` will assert that the log matches
     *      the next expected event recorded in the test context.
     *
     * @param log The log to check
     *
     * @return True if the log is a watched event, false otherwise
     */
    function isWatchedTransferEvent(
        Vm.Log memory log
    ) internal pure returns (bool) {
        bytes32 topic0 = log.getTopic0();
        return
            topic0 == Topic0_ERC20_ERC721_Transfer ||
            topic0 == Topic0_ERC1155_TransferSingle;
    }

    function isWatchedSeaportEvent(
        Vm.Log memory log
    ) internal pure returns (bool) {
        bytes32 topic0 = log.getTopic0();
        return
            topic0 == OrderFulfilled.selector ||
            topic0 == OrdersMatched.selector;
    }

    /**
     * @dev Checks that the next log matches the next expected transfer event.
     *
     * @param lastLogIndex The index of the last log that was checked
     * @param expectedEventHash The expected event hash
     * @param input The input to the reduce function
     *
     * @return nextLogIndex The index of the next log to check
     */
    function checkNextTransferEvent(
        uint256 lastLogIndex,
        uint256 expectedEventHash,
        ReduceInput memory input
    ) internal returns (uint256 nextLogIndex) {
        // Get the index of the next watched event in the logs array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(
                input.logsArray,
                isWatchedTransferEvent,
                lastLogIndex
            );

        // Dump the events data and revert if there are no remaining transfer events
        if (nextWatchedEventIndex == -1) {
            vm.serializeUint("root", "failingIndex", lastLogIndex - 1);
            vm.serializeBytes32(
                "root",
                "expectedEventHash",
                bytes32(expectedEventHash)
            );
            dumpTransfers(input.context);
            revert(
                "ExpectedEvents: transfer event not found - info written to fuzz_debug.json"
            );
        }

        require(
            nextWatchedEventIndex != -1,
            "ExpectedEvents: transfer event not found"
        );

        // Verify that the transfer event matches the expected event
        uint256 i = uint256(nextWatchedEventIndex);
        Vm.Log memory log = input.logsArray[i];
        require(
            log.getForgeEventHash() == bytes32(expectedEventHash),
            "ExpectedEvents: transfer event hash does not match"
        );

        // Increment the log index for the next iteration
        return i + 1;
    }

    /**
     * @dev Checks that the next log matches the next expected event.
     *
     * @param lastLogIndex The index of the last log that was checked
     * @param expectedEventHash The expected event hash
     * @param input The input to the reduce function
     *
     * @return nextLogIndex The index of the next log to check
     */
    function checkNextSeaportEvent(
        uint256 lastLogIndex,
        uint256 expectedEventHash,
        ReduceInput memory input
    ) internal returns (uint256 nextLogIndex) {
        // Get the index of the next watched event in the logs array
        int256 nextWatchedEventIndex = ArrayHelpers
            .findIndexFrom
            .asLogsFindIndex()(
                input.logsArray,
                isWatchedSeaportEvent,
                lastLogIndex
            );

        // Dump the events data and revert if there are no remaining transfer events
        if (nextWatchedEventIndex == -1) {
            vm.serializeUint("root", "failingIndex", lastLogIndex - 1);
            vm.serializeBytes32(
                "root",
                "expectedEventHash",
                bytes32(expectedEventHash)
            );
            revert(
                "ExpectedEvents: seaport event not found - info written to fuzz_debug.json"
            );
        }

        require(
            nextWatchedEventIndex != -1,
            "ExpectedEvents: seaport event not found"
        );

        // Verify that the transfer event matches the expected event
        uint256 i = uint256(nextWatchedEventIndex);
        Vm.Log memory log = input.logsArray[i];
        require(
            log.getForgeEventHash() == bytes32(expectedEventHash),
            "ExpectedEvents: seaport event hash does not match"
        );

        // Increment the log index for the next iteration
        return i + 1;
    }
}

/**
 * @dev Low level helpers.
 */
library Casts {
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
                function(uint256, uint256, ReduceInput memory)
                    internal
                    returns (uint256),
                uint256,
                ReduceInput memory
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
