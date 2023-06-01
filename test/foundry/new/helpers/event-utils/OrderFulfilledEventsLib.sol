// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    MemoryPointer
} from "../../../../../contracts/helpers/ArrayHelpers.sol";

import {
    AdvancedOrder,
    Execution,
    ItemType,
    OrderParameters,
    SpentItem,
    ReceivedItem
} from "seaport-sol/src/SeaportStructs.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics, getTopicsHash } from "./EventHashes.sol";

import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";

import { OrderParametersLib } from "seaport-sol/src/lib/OrderParametersLib.sol";

import {
    OrderFulfilledEvent,
    EventSerializer,
    vm
} from "./EventSerializer.sol";

library OrderFulfilledEventsLib {
    using { toBytes32 } for address;
    using EventSerializer for *;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderParametersLib for OrderParameters;

    event OrderFulfilled(
        bytes32 orderHash,
        address indexed offerer,
        address indexed zone,
        address recipient,
        SpentItem[] offer,
        ReceivedItem[] consideration
    );

    // check if order is available - expected available orders
    // look up actions, if match
    // create new lib for order fulfilled/match
    // DON"T TOUCH anything related to transfer events
    // function serializeOrderFulfilledLog(
    //     string memory objectKey,
    //     string memory valueKey,
    //     FuzzTestContext memory context
    // ) internal returns (string memory) {
    //     OrderDetails[] memory orderDetails = (
    //         context.executionState.orders.getOrderDetails(context.executionState.criteriaResolvers)
    //     );

    //     for (uint256 i; i < orderDetails.length; i++) {
    //         OrderDetails memory detail = orderDetails[i];

    //         OrderFulfilledEvent memory eventData = OrderFulfilledEvent({
    //             orderHash: getOrderFulfilledEventHash(context),
    //             offerer: detail.offerer,
    //             zone: detail.zone,
    //             recipient: detail.recipient,
    //             offer: detail.offer,
    //             consideration: detail.consideration
    //         });

    //         return eventData.serializeOrderFulfilledEvent(objectKey, valueKey);
    //     }
    // }

    function getOrderFulfilledEventHash(
        FuzzTestContext memory context,
        uint256 orderIndex
    ) internal pure returns (bytes32 eventHash) {
        OrderParameters memory orderParams = context
            .executionState
            .orders[orderIndex]
            .parameters;

        OrderDetails memory details = (
            context.executionState.orderDetails[orderIndex]
        );

        return
            getEventHashWithTopics(
                address(context.seaport), // emitter
                OrderFulfilled.selector, // topic0
                orderParams.offerer.toBytes32(), // topic1 - offerer
                orderParams.zone.toBytes32(), // topic2 - zone
                keccak256(
                    abi.encode(
                        details.orderHash,
                        context.executionState.recipient == address(0)
                            ? context.executionState.caller
                            : context.executionState.recipient,
                        details.offer,
                        details.consideration
                    )
                ) // dataHash
            );
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
