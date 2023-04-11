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
} from "seaport-sol/SeaportStructs.sol";

import {
    OrderDetails
} from "../../../../../contracts/helpers/sol/fulfillments/lib/Structs.sol";

import { OrderDetailsHelper } from "../FuzzGenerators.sol";

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics, getTopicsHash } from "./EventHashes.sol";

import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

import {
    OrderFulfilledEvent,
    EventSerializer,
    vm
} from "./EventSerializer.sol";

library OrderFulfilledEventsLib {
    using { toBytes32 } for address;
    using EventSerializer for *;
    using OrderDetailsHelper for AdvancedOrder[];
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
    //         context.orders.getOrderDetails(context.criteriaResolvers)
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
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bytes32 eventHash) {
        OrderParameters memory orderParams = context
            .orders[orderIndex]
            .parameters;

        OrderDetails memory details = (
            context.orders.getOrderDetails(context.criteriaResolvers)
        )[orderIndex];

        if (orderParams.isAvailable()) {
            return
                getEventHashWithTopics(
                    address(context.seaport), // emitter
                    OrderFulfilled.selector, // topic0
                    orderParams.offerer.toBytes32(), // topic1 - offerer
                    orderParams.zone.toBytes32(), // topic2 - zone
                    keccak256(
                        abi.encode(
                            context.orderHashes[orderIndex],
                            context.recipient,
                            details.offer,
                            details.consideration
                        )
                    ) // dataHash
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
