// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";
import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";
import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";
import { NavigatorContext } from "./SeaportNavigatorTypes.sol";
import { OrderAvailabilityLib } from "./OrderAvailabilityLib.sol";

library NavigatorDetailsLib {
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderAvailabilityLib for AdvancedOrder[];

    /**
     * @dev Calculate OrderDetails for each order and add them to the NavigatorResponse.
     */
    function withDetails(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        UnavailableReason[] memory unavailableReasons = context
            .response
            .orders
            .unavailableReasons(
                context.request.maximumFulfilled,
                context.request.seaport
            );
        bytes32[] memory orderHashes = context.response.orders.getOrderHashes(
            address(context.request.seaport)
        );
        context.response.orderDetails = context.response.orders.getOrderDetails(
            context.response.criteriaResolvers,
            orderHashes,
            unavailableReasons
        );
        return context;
    }
}
