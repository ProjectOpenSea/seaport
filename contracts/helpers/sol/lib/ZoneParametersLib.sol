// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    ZoneParameters
} from "../../../lib/ConsiderationStructs.sol";

import {
    ConsiderationInterface
} from "../../../interfaces/ConsiderationInterface.sol";

import { GettersAndDerivers } from "../../../lib/GettersAndDerivers.sol";

import { AdvancedOrderLib } from "./AdvancedOrderLib.sol";

import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

import { OfferItemLib } from "./OfferItemLib.sol";

import { ReceivedItemLib } from "./ReceivedItemLib.sol";

import { OrderParametersLib } from "./OrderParametersLib.sol";

import { StructCopier } from "./StructCopier.sol";

library ZoneParametersLib {
    using AdvancedOrderLib for AdvancedOrder;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function getZoneParameters(
        AdvancedOrder[] memory advancedOrders,
        address fulfiller,
        uint256 counter,
        uint256 maximumFulfilled,
        ConsiderationInterface seaport
    ) internal view returns (ZoneParameters[] memory zoneParameters) {
        bytes32[] memory orderHashes = new bytes32[](advancedOrders.length);

        // Iterate over advanced orders to calculate orderHashes
        for (uint256 i = 0; i < advancedOrders.length; i++) {
            // Get orderParameters from advancedOrder
            OrderParameters memory orderParameters = advancedOrders[i]
                .parameters;

            // Get orderComponents from orderParameters
            OrderComponents memory orderComponents = OrderComponents({
                offerer: orderParameters.offerer,
                zone: orderParameters.zone,
                offer: orderParameters.offer,
                consideration: orderParameters.consideration,
                orderType: orderParameters.orderType,
                startTime: orderParameters.startTime,
                endTime: orderParameters.endTime,
                zoneHash: orderParameters.zoneHash,
                salt: orderParameters.salt,
                conduitKey: orderParameters.conduitKey,
                counter: counter
            });

            if (i >= maximumFulfilled) {
                // Set orderHash to 0 if order index exceeds maximumFulfilled
                orderHashes[i] = bytes32(0);
            } else {
                // Get orderHash from orderComponents
                bytes32 orderHash = seaport.getOrderHash(orderComponents);

                // Add orderHash to orderHashes
                orderHashes[i] = orderHash;
            }
        }

        zoneParameters = new ZoneParameters[](maximumFulfilled);

        // Iterate through advanced orders to create zoneParameters
        for (uint i = 0; i < advancedOrders.length; i++) {
            if (i >= maximumFulfilled) {
                continue;
            }
            // Get orderParameters from advancedOrder
            OrderParameters memory orderParameters = advancedOrders[i]
                .parameters;

            // Create spentItems array
            SpentItem[] memory spentItems = new SpentItem[](
                orderParameters.offer.length
            );

            // Convert offer to spentItems and add to spentItems array
            for (uint256 j = 0; j < orderParameters.offer.length; j++) {
                spentItems[j] = orderParameters.offer[j].toSpentItem();
            }

            // Create receivedItems array
            ReceivedItem[] memory receivedItems = new ReceivedItem[](
                orderParameters.consideration.length
            );

            // Convert consideration to receivedItems and add to receivedItems array
            for (uint256 k = 0; k < orderParameters.consideration.length; k++) {
                receivedItems[k] = orderParameters
                    .consideration[k]
                    .toReceivedItem();
            }

            // Create ZoneParameters and add to zoneParameters array
            zoneParameters[i] = ZoneParameters({
                orderHash: orderHashes[i],
                fulfiller: fulfiller,
                offerer: orderParameters.offerer,
                offer: spentItems,
                consideration: receivedItems,
                extraData: advancedOrders[i].extraData,
                orderHashes: orderHashes,
                startTime: orderParameters.startTime,
                endTime: orderParameters.endTime,
                zoneHash: orderParameters.zoneHash
            });
        }

        return zoneParameters;
    }
}
