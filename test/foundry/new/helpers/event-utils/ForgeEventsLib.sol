// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Vm } from "forge-std/Vm.sol";

import { MemoryPointer } from "seaport-types/src/helpers/PointerLibraries.sol";

import { getEventHash, getTopicsHash } from "./EventHashes.sol";

import {
    ERC20TransferEvent,
    ERC721TransferEvent,
    ERC1155TransferEvent,
    EventSerializer,
    vm
} from "./EventSerializer.sol";

bytes32 constant Topic0_ERC20_ERC721_Transfer = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
bytes32 constant Topic0_ERC1155_TransferSingle = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;

library ForgeEventsLib {
    using { ifTrue } for bytes32;
    using EventSerializer for *;

    /**
     * @dev Returns the hash of the event emitted by Forge.
     */
    function getForgeEventHash(
        Vm.Log memory log
    ) internal pure returns (bytes32) {
        bytes32 topicsHash = getForgeTopicsHash(log);
        bytes32 dataHash = getDataHash(log);
        return getEventHash(log.emitter, topicsHash, dataHash);
    }

    /**
     * @dev Returns the memory pointer for a given log.
     */
    function toMemoryPointer(
        Vm.Log memory log
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := log
        }
    }

    /**
     * @dev Returns the hash of the data on the event.
     */
    function getDataHash(Vm.Log memory log) internal pure returns (bytes32) {
        return keccak256(log.data);
        // MemoryPointer data = toMemoryPointer(log).pptr(32);
        // return data.offset(32).hash(data.readUint256());
    }

    /**
     * @dev Gets the first topic of the log.
     */
    function getTopic0(Vm.Log memory log) internal pure returns (bytes32) {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        return topics.offset(0x20).readBytes32().ifTrue(topicsCount > 0);
    }

    /**
     * @dev Emits a log again.
     */
    function reEmit(Vm.Log memory log) internal {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        (
            bytes32 topic0,
            ,
            bytes32 topic1,
            ,
            bytes32 topic2,
            ,
            bytes32 topic3,

        ) = getTopics(log);
        MemoryPointer data = toMemoryPointer(log).pptrOffset(32);
        assembly {
            switch topicsCount
            case 4 {
                log4(data, mload(data), topic0, topic1, topic2, topic3)
            }
            case 3 {
                log3(data, mload(data), topic0, topic1, topic2)
            }
            case 2 {
                log2(data, mload(data), topic0, topic1)
            }
            case 1 {
                log1(data, mload(data), topic0)
            }
            default {
                log0(data, mload(data))
            }
        }
    }

    /**
     * @dev Serializes a token transfer log for an ERC20, ERC721, or ERC1155.
     */
    function serializeTransferLog(
        Vm.Log memory log,
        string memory objectKey,
        string memory valueKey
    ) internal returns (string memory) {
        (
            bytes32 topic0,
            ,
            bytes32 topic1,
            ,
            bytes32 topic2,
            ,
            bytes32 topic3,
            bool hasTopic3
        ) = getTopics(log);
        if (topic0 == Topic0_ERC20_ERC721_Transfer) {
            if (hasTopic3) {
                return
                    ERC721TransferEvent(
                        "ERC721",
                        log.emitter,
                        address(uint160(uint256(topic1))),
                        address(uint160(uint256(topic2))),
                        uint256(topic3)
                    ).serializeERC721TransferEvent(objectKey, valueKey);
                // getForgeTopicsHash(log),
                // getDataHash(log),
                // getForgeEventHash(log)
            } else {
                ERC20TransferEvent memory eventData;
                eventData.kind = "ERC20";
                eventData.token = log.emitter;
                eventData.from = address(uint160(uint256(topic1)));
                eventData.to = address(uint160(uint256(topic2)));
                eventData.amount = log.data.length >= 32
                    ? abi.decode(log.data, (uint256))
                    : 0;
                if (log.data.length == 0) {
                    string memory obj = string.concat(objectKey, valueKey);
                    string memory finalJson = vm.serializeString(
                        obj,
                        "amount",
                        "No data provided in log for token amount"
                    );
                    vm.serializeString(objectKey, valueKey, finalJson);
                }
                return
                    eventData.serializeERC20TransferEvent(objectKey, valueKey);
            }
        } else if (topic0 == Topic0_ERC1155_TransferSingle) {
            ERC1155TransferEvent memory eventData;
            eventData.kind = "ERC1155";
            eventData.token = log.emitter;
            eventData.operator = address(uint160(uint256(topic1)));
            eventData.from = address(uint160(uint256(topic2)));
            eventData.to = address(uint160(uint256(topic3)));
            (eventData.identifier, eventData.amount) = abi.decode(
                log.data,
                (uint256, uint256)
            );
            // eventData.topicHash = getForgeTopicsHash(log);
            // eventData.dataHash = getDataHash(log);
            // eventData.eventHash = getForgeEventHash(log);

            return eventData.serializeERC1155TransferEvent(objectKey, valueKey);
        }

        revert("Invalid event log");
    }

    /**
     * @dev Serializes an array of token transfer logs.
     */
    function serializeTransferLogs(
        Vm.Log[] memory value,
        string memory objectKey,
        string memory valueKey
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            string memory _log = serializeTransferLog(
                value[i],
                obj,
                string.concat("event", vm.toString(i))
            );
            uint256 len;
            assembly {
                len := mload(_log)
            }
            if (length > 0) {
                out = _log;
            }
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    /**
     * @dev Gets the topics for a log.
     */
    function getTopics(
        Vm.Log memory log
    )
        internal
        pure
        returns (
            bytes32 topic0,
            bool hasTopic0,
            bytes32 topic1,
            bool hasTopic1,
            bytes32 topic2,
            bool hasTopic2,
            bytes32 topic3,
            bool hasTopic3
        )
    {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        hasTopic0 = topicsCount > 0;
        topic0 = topics.offset(0x20).readBytes32().ifTrue(hasTopic0);

        hasTopic1 = topicsCount > 1;
        topic1 = topics.offset(0x40).readBytes32().ifTrue(hasTopic1);

        hasTopic2 = topicsCount > 2;
        topic2 = topics.offset(0x60).readBytes32().ifTrue(hasTopic2);

        hasTopic3 = topicsCount > 3;
        topic3 = topics.offset(0x80).readBytes32().ifTrue(hasTopic3);
    }

    /**
     * @dev Gets the hash for a log's topics.
     */
    function getForgeTopicsHash(
        Vm.Log memory log
    ) internal pure returns (bytes32 topicHash) {
        // (
        //     bytes32 topic0,
        //     bool hasTopic0,
        //     bytes32 topic1,
        //     bool hasTopic1,
        //     bytes32 topic2,
        //     bool hasTopic2,
        //     bytes32 topic3,
        //     bool hasTopic3
        // ) = getTopics(log);
        return keccak256(abi.encodePacked(log.topics));
    }
}

/**
 * @dev Convenience helper.
 */
function ifTrue(bytes32 a, bool b) pure returns (bytes32 c) {
    assembly {
        c := mul(a, b)
    }
}
