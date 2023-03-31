// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    ZoneParameters,
    CriteriaResolver
} from "../../../lib/ConsiderationStructs.sol";

import { SeaportInterface } from "../../../interfaces/SeaportInterface.sol";

import { GettersAndDerivers } from "../../../lib/GettersAndDerivers.sol";

import { AdvancedOrderLib } from "./AdvancedOrderLib.sol";

import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

import { OfferItemLib } from "./OfferItemLib.sol";

import { ReceivedItemLib } from "./ReceivedItemLib.sol";

import { OrderParametersLib } from "./OrderParametersLib.sol";

import { StructCopier } from "./StructCopier.sol";

import { AmountDeriverHelper } from "./fulfillment/AmountDeriverHelper.sol";
import { OrderDetails } from "../fulfillments/lib/Structs.sol";

library ZoneParametersLib {
    using AdvancedOrderLib for AdvancedOrder;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function getZoneParameters(
        AdvancedOrder memory advancedOrder,
        address fulfiller,
        uint256 counter,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (ZoneParameters memory zoneParameters) {
        SeaportInterface seaportInterface = SeaportInterface(seaport);
        // Get orderParameters from advancedOrder
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Get orderHash
        bytes32 orderHash = getTipNeutralizedOrderHash(
            advancedOrder,
            seaportInterface
        );

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

        // Store orderHash in orderHashes array to pass into zoneParameters
        bytes32[] memory orderHashes = new bytes32[](1);
        orderHashes[0] = orderHash;

        // Create ZoneParameters and add to zoneParameters array
        zoneParameters = ZoneParameters({
            orderHash: orderHash,
            fulfiller: fulfiller,
            offerer: orderParameters.offerer,
            offer: spentItems,
            consideration: receivedItems,
            extraData: advancedOrder.extraData,
            orderHashes: orderHashes,
            startTime: orderParameters.startTime,
            endTime: orderParameters.endTime,
            zoneHash: orderParameters.zoneHash
        });
    }

    function getZoneParameters(
        AdvancedOrder[] memory advancedOrders,
        address fulfiller,
        uint256 maximumFulfilled,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal returns (ZoneParameters[] memory zoneParameters) {
        // TODO: use testHelpers pattern to use single amount deriver helper
        OrderDetails[] memory orderDetails = (new AmountDeriverHelper())
            .toOrderDetails(advancedOrders, criteriaResolvers);

        bytes32[] memory orderHashes = new bytes32[](advancedOrders.length);

        // Iterate over advanced orders to calculate orderHashes
        for (uint256 i = 0; i < advancedOrders.length; i++) {
            if (i >= maximumFulfilled) {
                // Set orderHash to 0 if order index exceeds maximumFulfilled
                orderHashes[i] = bytes32(0);
            } else {
                // Add orderHash to orderHashes
                orderHashes[i] = getTipNeutralizedOrderHash(
                    advancedOrders[i],
                    SeaportInterface(seaport)
                );
            }
        }

        zoneParameters = new ZoneParameters[](maximumFulfilled);

        // Iterate through advanced orders to create zoneParameters
        for (uint i = 0; i < advancedOrders.length; i++) {
            if (i >= maximumFulfilled) {
                break;
            }

            // Create ZoneParameters and add to zoneParameters array
            zoneParameters[i] = _createZoneParameters(
                orderHashes[i],
                orderDetails[i],
                advancedOrders[i],
                fulfiller,
                orderHashes
            );
        }

        return zoneParameters;
    }

    function _createZoneParameters(
        bytes32 orderHash,
        OrderDetails memory orderDetails,
        AdvancedOrder memory advancedOrder,
        address fulfiller,
        bytes32[] memory orderHashes
    ) internal returns (ZoneParameters memory) {
        return ZoneParameters({
            orderHash: orderHash,
            fulfiller: fulfiller,
            offerer: advancedOrder.parameters.offerer,
            offer: orderDetails.offer,
            consideration: orderDetails.consideration,
            extraData: advancedOrder.extraData,
            orderHashes: orderHashes,
            startTime: advancedOrder.parameters.startTime,
            endTime: advancedOrder.parameters.endTime,
            zoneHash: advancedOrder.parameters.zoneHash
        });
    }

    function getTipNeutralizedOrderHash(
        AdvancedOrder memory order,
        SeaportInterface seaport
    ) internal view returns (bytes32 orderHash) {
        OrderParameters memory orderParameters = order.parameters;

        // Get orderComponents from orderParameters.
        OrderComponents memory components = OrderComponents({
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
            counter: seaport.getCounter(orderParameters.offerer)
        });

        // Get the length of the consideration array (which might have
        // additional consideration items set as tips).
        uint256 lengthWithTips = components.consideration.length;

        // Get the length of the consideration array without tips, which is
        // stored in the totalOriginalConsiderationItems field.
        uint256 lengthSansTips = (
            orderParameters.totalOriginalConsiderationItems
        );

        // Get a reference to the consideration array.
        ConsiderationItem[] memory considerationSansTips = (
            components.consideration
        );

        // Set proper length of the considerationSansTips array.
        assembly {
            mstore(considerationSansTips, lengthSansTips)
        }

        // Get the orderHash using the tweaked OrderComponents.
        orderHash = seaport.getOrderHash(components);

        // Restore the length of the considerationSansTips array.
        assembly {
            mstore(considerationSansTips, lengthWithTips)
        }
    }
}