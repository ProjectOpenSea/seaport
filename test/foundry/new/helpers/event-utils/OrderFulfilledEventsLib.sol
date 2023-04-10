// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    MemoryPointer
} from "../../../../../contracts/helpers/ArrayHelpers.sol";

import {
    Execution,
    ItemType,
    SpentItem,
    ReceivedItem
} from "seaport-sol/SeaportStructs.sol";

import {
    OrderDetails
} from "../../../../../contracts/helpers/sol/fulfillments/lib/Structs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics, getTopicsHash } from "./EventHashes.sol";

import {
    ERC20TransferEvent,
    ERC721TransferEvent,
    ERC1155TransferEvent,
    EventSerializer,
    vm
} from "./EventSerializer.sol";

library OrderFulfilledEventsLib {
    using { toBytes32 } for address;
    using EventSerializer for *;

    event OrderFulfilled(
        bytes32 orderHash,
        address indexed offerer,
        address indexed zone,
        address recipient,
        SpentItem[] offer,
        ReceivedItem[] consideration
    );

    function serializeOrderFulfilledLog(
        string memory objectKey,
        string memory valueKey,
        FuzzTestContext memory context
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        serialize
    }

    function getOrderFulfilledEventHash(
        FuzzTestContext memory context
    ) internal view returns (bytes32 eventHash) {
        OrderDetails[] memory orderDetails = context.orderDetails;

        for (uint256 i; i < orderDetails.length; i++) {
            OrderDetails memory detail = orderDetails[i];

            return
                getEventHashWithTopics(
                    context.seaport,
                    OrderFulfilled.selector, // topic0
                    detail.offerer.toBytes32(), // topic1 - offerer
                    detail.zone.toBytes32() // topic2 - zone
                );
        }
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
