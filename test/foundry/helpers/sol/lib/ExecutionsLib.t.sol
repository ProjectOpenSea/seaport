// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    ExecutionLib
} from "../../../../../contracts/helpers/sol/lib/ExecutionLib.sol";
import {
    Execution,
    ReceivedItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    ReceivedItemLib
} from "../../../../../contracts/helpers/sol/lib/ReceivedItemLib.sol";

contract ExecutionLibTest is BaseTest {
    using ExecutionLib for Execution;

    struct ReceivedItemBlob {
        uint8 itemType;
        address token;
        uint256 identifier;
        uint256 amount;
        address payable recipient;
    }

    function testRetrieveDefault(
        ReceivedItemBlob memory blob,
        address offerer,
        bytes32 conduitKey
    ) public {
        ReceivedItem memory receivedItem = ReceivedItem({
            itemType: toItemType(blob.itemType),
            token: blob.token,
            identifier: blob.identifier,
            amount: blob.amount,
            recipient: blob.recipient
        });
        Execution memory execution = Execution({
            item: receivedItem,
            offerer: offerer,
            conduitKey: conduitKey
        });
        ExecutionLib.saveDefault(execution, "default");
        Execution memory defaultExecution = ExecutionLib.fromDefault("default");
        assertEq(execution, defaultExecution);
    }

    function testRetrieveNonexistentDefault() public {
        vm.expectRevert("Empty Execution selected.");
        ExecutionLib.fromDefault("nonexistent");

        vm.expectRevert("Empty Execution array selected.");
        ExecutionLib.fromDefaultMany("nonexistent");
    }

    function _fromBlob(
        ReceivedItemBlob memory blob
    ) internal view returns (ReceivedItem memory) {
        return
            ReceivedItem({
                itemType: toItemType(blob.itemType),
                token: blob.token,
                identifier: blob.identifier,
                amount: blob.amount,
                recipient: blob.recipient
            });
    }

    function testComposeEmpty(
        ReceivedItemBlob memory blob,
        address offerer,
        bytes32 conduitKey
    ) public {
        ReceivedItem memory receivedItem = _fromBlob(blob);
        Execution memory execution = ExecutionLib
            .empty()
            .withItem(receivedItem)
            .withOfferer(offerer)
            .withConduitKey(conduitKey);
        assertEq(
            execution,
            Execution({
                item: receivedItem,
                offerer: offerer,
                conduitKey: conduitKey
            })
        );
    }

    function testCopy() public {
        Execution memory execution = Execution({
            item: ReceivedItem({
                itemType: ItemType(1),
                token: address(1),
                identifier: 1,
                amount: 1,
                recipient: payable(address(1234))
            }),
            offerer: address(1),
            conduitKey: bytes32(uint256(1))
        });
        Execution memory copy = execution.copy();
        assertEq(execution, copy);
        execution.offerer = address(2);
        assertEq(copy.offerer, address(1));
    }

    function testRetrieveDefaultMany(
        ReceivedItemBlob[3] memory blob,
        address[3] memory offerer,
        bytes32[3] memory conduitKey
    ) public {
        Execution[] memory executions = new Execution[](3);
        for (uint256 i = 0; i < 3; i++) {
            ReceivedItem memory item = _fromBlob(blob[i]);
            executions[i] = Execution({
                item: item,
                offerer: offerer[i],
                conduitKey: conduitKey[i]
            });
        }
        ExecutionLib.saveDefaultMany(executions, "default");
        Execution[] memory defaultExecutions = ExecutionLib.fromDefaultMany(
            "default"
        );
        for (uint256 i = 0; i < 3; i++) {
            assertEq(executions[i], defaultExecutions[i]);
        }
    }
}
