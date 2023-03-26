// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "seaport-sol/../ArrayHelpers.sol";

import {
    Execution,
    ItemType,
    ReceivedItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";
import { getEventHashWithTopics } from "./EventHashes.sol";
import "forge-std/console2.sol";

struct EventData {
    address emitter;
    bytes32 topic0;
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
    bytes32 dataHash;
}

library TransferEventsLib {
    using { toBytes32 } for address;
    using TransferEventsLibCasts for *;

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

    event ExpectedERC20Transfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 valueOrIdentifier
    );

    event ExpectedERC721Transfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 valueOrIdentifier
    );

    event ExpectedERC1155Transfer(
        address token,
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    function getTransferEventHash(
        Execution memory execution,
        FuzzTestContext memory context
    ) internal returns (bytes32 eventHash) {
        ItemType itemType = execution.item.itemType;

        if (itemType == ItemType.ERC20) {
            ReceivedItem memory item = execution.item;
            emit ExpectedERC20Transfer(
                item.token,
                execution.offerer,
                address(item.recipient),
                item.amount
            );
            return getERC20TransferEventHash(execution);
        }

        if (itemType == ItemType.ERC721) {
            ReceivedItem memory item = execution.item;
            emit ExpectedERC721Transfer(
                item.token,
                execution.offerer,
                address(item.recipient),
                item.identifier
            );
            return getERC721TransferEventHash(execution);
        }
        if (itemType == ItemType.ERC1155) {
            ReceivedItem memory item = execution.item;
            address operator = _getConduit(execution.conduitKey, context);
            emit ExpectedERC1155Transfer(
                item.token,
                operator,
                execution.offerer,
                address(item.recipient),
                item.identifier,
                item.amount
            );
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
        if (conduitKey == bytes32(0)) {
            return address(context.seaport);
        }

        (address conduit, bool exists) = context.conduitController.getConduit(
            conduitKey
        );

        if (exists) {
            return conduit;
        }

        revert("TransferEventsLib: bad conduit key");
    }
}

function toBytes32(address a) pure returns (bytes32 b) {
    assembly {
        b := a
    }
}

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
