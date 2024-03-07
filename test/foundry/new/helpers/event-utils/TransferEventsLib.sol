// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    MemoryPointer
} from "../../../../../contracts/helpers/ArrayHelpers.sol";

import {
    Execution,
    ItemType,
    ReceivedItem
} from "seaport-sol/src/SeaportStructs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics, getTopicsHash } from "./EventHashes.sol";

import {
    ERC20TransferEvent,
    ERC721TransferEvent,
    ERC1155TransferEvent,
    EventSerializer,
    vm
} from "./EventSerializer.sol";

library TransferEventsLib {
    using { toBytes32 } for address;
    using TransferEventsLibCasts for *;
    using EventSerializer for *;

    // ERC721 and ERC20 share the same topic0 for the Transfer event, but
    // for ERC721, the third parameter (identifier) is indexed.
    // The topic0 does not change based on which parameters are indexed.
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 valueOrIdentifier
    );

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    /**
     * @dev Serializes a token transfer log for an ERC20, ERC721, or ERC1155.
     *
     * @param execution The execution that corresponds to the transfer event.
     * @param objectKey The key to use for the object in the JSON.
     * @param valueKey  The key to use for the value in the JSON.
     * @param context   The context of the fuzz test.
     *
     * @return json The json for the event.
     */
    function serializeTransferLog(
        Execution memory execution,
        string memory objectKey,
        string memory valueKey,
        FuzzTestContext memory context
    ) internal returns (string memory json) {
        ItemType itemType = execution.item.itemType;

        if (itemType == ItemType.ERC20) {
            ReceivedItem memory item = execution.item;

            ERC20TransferEvent memory eventData = ERC20TransferEvent(
                "ERC20",
                item.token,
                execution.offerer,
                address(item.recipient),
                item.amount
            );
            return eventData.serializeERC20TransferEvent(objectKey, valueKey);
        }

        if (itemType == ItemType.ERC721) {
            ReceivedItem memory item = execution.item;

            return
                ERC721TransferEvent(
                    "ERC721",
                    item.token,
                    execution.offerer,
                    address(item.recipient),
                    item.identifier
                ).serializeERC721TransferEvent(objectKey, valueKey);
            // getTopicsHash(
            //     Transfer.selector, // topic0
            //     execution.offerer.toBytes32(), // topic1
            //     toBytes32(item.recipient), // topic2
            //     bytes32(item.identifier) // topic3
            // ),
            // keccak256(""),
            // getERC721TransferEventHash(execution)
        }
        if (itemType == ItemType.ERC1155) {
            ReceivedItem memory item = execution.item;
            address operator = _getConduit(execution.conduitKey, context);

            ERC1155TransferEvent memory eventData = ERC1155TransferEvent(
                "ERC1155",
                item.token,
                operator,
                execution.offerer,
                address(item.recipient),
                item.identifier,
                item.amount
            );
            //   getTopicsHash(
            //     TransferSingle.selector, // topic0
            //     _getConduit(execution.conduitKey, context).toBytes32(), // topic1 = operator
            //     execution.offerer.toBytes32(), // topic2 = from
            //     toBytes32(item.recipient) // topic3 = to
            // ),
            // keccak256(abi.encode(item.identifier, item.amount)), // dataHash
            // getERC1155TransferEventHash(execution, context) // event hash

            return eventData.serializeERC1155TransferEvent(objectKey, valueKey);
        }

        revert("Invalid event log");
    }

    /**
     * @dev Serializes an array of token transfer logs.
     */
    function serializeTransferLogs(
        Execution[] memory value,
        string memory objectKey,
        string memory valueKey,
        FuzzTestContext memory context
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            string memory _log = serializeTransferLog(
                value[i],
                obj,
                string.concat("event", vm.toString(i)),
                context
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

    function getTransferEventHash(
        Execution memory execution,
        FuzzTestContext memory context
    ) internal view returns (bytes32 eventHash) {
        ItemType itemType = execution.item.itemType;

        if (itemType == ItemType.ERC20) {
            // ReceivedItem memory item = execution.item;
            return getERC20TransferEventHash(execution);
        }

        if (itemType == ItemType.ERC721) {
            // ReceivedItem memory item = execution.item;
            return getERC721TransferEventHash(execution);
        }
        if (itemType == ItemType.ERC1155) {
            // ReceivedItem memory item = execution.item;
            //  address operator = _getConduit(execution.conduitKey, context);
            return getERC1155TransferEventHash(execution, context);
        }
    }

    function getERC20TransferEventHash(
        Execution memory execution
    ) internal pure returns (bytes32) {
        ReceivedItem memory item = execution.item;
        return
            getEventHashWithTopics(
                item.token, // emitter
                Transfer.selector, // topic0
                execution.offerer.toBytes32(), // topic1
                toBytes32(item.recipient), // topic2
                keccak256(abi.encode(item.amount)) // dataHash
            );
    }

    function getERC721TransferEventHash(
        Execution memory execution
    ) internal pure returns (bytes32) {
        ReceivedItem memory item = execution.item;
        return
            getEventHashWithTopics(
                item.token, // emitter
                Transfer.selector, // topic0
                execution.offerer.toBytes32(), // topic1
                toBytes32(item.recipient), // topic2
                bytes32(item.identifier), // topic3
                keccak256("") // dataHash
            );
    }

    function getERC1155TransferEventHash(
        Execution memory execution,
        FuzzTestContext memory context
    ) internal view returns (bytes32) {
        ReceivedItem memory item = execution.item;
        return
            getEventHashWithTopics(
                item.token, // emitter
                TransferSingle.selector, // topic0
                _getConduit(execution.conduitKey, context).toBytes32(), // topic1 = operator
                execution.offerer.toBytes32(), // topic2 = from
                toBytes32(item.recipient), // topic3 = to
                keccak256(abi.encode(item.identifier, item.amount)) // dataHash
            );
    }

    function _getConduit(
        bytes32 conduitKey,
        FuzzTestContext memory context
    ) internal view returns (address) {
        if (conduitKey == bytes32(0)) return address(context.seaport);
        (address conduit, bool exists) = context.conduitController.getConduit(
            conduitKey
        );
        if (exists) return conduit;
        revert("TransferEventsLib: bad conduit key");
    }
}

/**
 * @dev Low level helper to cast an address to a bytes32.
 */
function toBytes32(address a) pure returns (bytes32 b) {
    assembly {
        b := a
    }
}

/**
 * @dev Low level helper.
 */
library TransferEventsLibCasts {
    function cast(
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
                    view
                    returns (bytes32),
                FuzzTestContext memory
            ) internal pure returns (bytes32[] memory) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }
}
