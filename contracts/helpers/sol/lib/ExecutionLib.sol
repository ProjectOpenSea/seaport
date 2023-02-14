// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Execution, ReceivedItem } from "../../../lib/ConsiderationStructs.sol";
import { ReceivedItemLib } from "./ReceivedItemLib.sol";
import { StructCopier } from "./StructCopier.sol";

library ExecutionLib {
    bytes32 private constant EXECUTION_MAP_POSITION =
        keccak256("seaport.ExecutionDefaults");
    bytes32 private constant EXECUTIONS_MAP_POSITION =
        keccak256("seaport.ExecutionsDefaults");

    using ReceivedItemLib for ReceivedItem;
    using ReceivedItemLib for ReceivedItem[];

    /**
     * @notice clears a default Execution from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => Execution) storage executionMap = _executionMap();
        Execution storage item = executionMap[defaultName];
        clear(item);
    }

    function clear(Execution storage execution) internal {
        // clear all fields
        execution.item = ReceivedItemLib.empty();
        execution.offerer = address(0);
        execution.conduitKey = bytes32(0);
    }

    function clear(Execution[] storage executions) internal {
        while (executions.length > 0) {
            clear(executions[executions.length - 1]);
            executions.pop();
        }
    }

    /**
     * @notice gets a default Execution from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (Execution memory item) {
        mapping(string => Execution) storage executionMap = _executionMap();
        item = executionMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (Execution[] memory items) {
        mapping(string => Execution[]) storage executionsMap = _executionsMap();
        items = executionsMap[defaultName];
    }

    /**
     * @notice saves an Execution as a named default
     * @param execution the Execution to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        Execution memory execution,
        string memory defaultName
    ) internal returns (Execution memory _execution) {
        mapping(string => Execution) storage executionMap = _executionMap();
        executionMap[defaultName] = execution;
        return execution;
    }

    function saveDefaultMany(
        Execution[] memory executions,
        string memory defaultName
    ) internal returns (Execution[] memory _executions) {
        mapping(string => Execution[]) storage executionsMap = _executionsMap();
        StructCopier.setExecutions(executionsMap[defaultName], executions);
        return executions;
    }

    /**
     * @notice makes a copy of an Execution in-memory
     * @param item the Execution to make a copy of in-memory
     */
    function copy(
        Execution memory item
    ) internal pure returns (Execution memory) {
        return
            Execution({
                item: item.item.copy(),
                offerer: item.offerer,
                conduitKey: item.conduitKey
            });
    }

    function copy(
        Execution[] memory item
    ) internal pure returns (Execution[] memory) {
        Execution[] memory copies = new Execution[](item.length);
        for (uint256 i = 0; i < item.length; i++) {
            copies[i] = copy(item[i]);
        }
        return copies;
    }

    function empty() internal pure returns (Execution memory) {
        return
            Execution({
                item: ReceivedItemLib.empty(),
                offerer: address(0),
                conduitKey: bytes32(0)
            });
    }

    /**
     * @notice gets the storage position of the default Execution map
     */
    function _executionMap()
        private
        pure
        returns (mapping(string => Execution) storage executionMap)
    {
        bytes32 position = EXECUTION_MAP_POSITION;
        assembly {
            executionMap.slot := position
        }
    }

    function _executionsMap()
        private
        pure
        returns (mapping(string => Execution[]) storage executionsMap)
    {
        bytes32 position = EXECUTIONS_MAP_POSITION;
        assembly {
            executionsMap.slot := position
        }
    }

    // methods for configuring a single of each of an Execution's fields, which modifies the Execution
    // in-place and
    // returns it

    function withItem(
        Execution memory execution,
        ReceivedItem memory item
    ) internal pure returns (Execution memory) {
        execution.item = item.copy();
        return execution;
    }

    function withOfferer(
        Execution memory execution,
        address offerer
    ) internal pure returns (Execution memory) {
        execution.offerer = offerer;
        return execution;
    }

    function withConduitKey(
        Execution memory execution,
        bytes32 conduitKey
    ) internal pure returns (Execution memory) {
        execution.conduitKey = conduitKey;
        return execution;
    }
}
