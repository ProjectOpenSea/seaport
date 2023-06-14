// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    Execution,
    SpentItem,
    ReceivedItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    FulfillmentDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    ExecutionHelper
} from "seaport-sol/src/executions/ExecutionHelper.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

library NavigatorExecutionsLib {
    using ExecutionHelper for FulfillmentDetails;

    /**
     * @dev Internal error: Could not select a fulfillment method for the provided
     *      orders.
     */
    error UnknownAction();

    /**
     * @dev Calculate executions for the provided orders and add them to the
     *      NavigatorResponse.
     */
    function withExecutions(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        bytes memory callData = context.response.suggestedCallData;
        bytes4 _suggestedAction = bytes4(callData);
        FulfillmentDetails memory fulfillmentDetails = FulfillmentDetails({
            orders: context.response.orderDetails,
            recipient: payable(context.request.recipient),
            fulfiller: payable(context.request.caller),
            nativeTokensSupplied: context.request.nativeTokensSupplied,
            fulfillerConduitKey: context.request.fulfillerConduitKey,
            seaport: address(context.request.seaport)
        });

        Execution[] memory explicitExecutions;
        Execution[] memory implicitExecutions;
        Execution[] memory implicitExecutionsPre;
        Execution[] memory implicitExecutionsPost;
        uint256 nativeTokensReturned;

        if (
            _suggestedAction ==
            ConsiderationInterface.fulfillAvailableOrders.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getFulfillAvailableExecutions(
                context.response.offerFulfillments,
                context.response.considerationFulfillments,
                context.response.orderDetails
            );
        } else if (
            _suggestedAction == ConsiderationInterface.matchOrders.selector ||
            _suggestedAction ==
            ConsiderationInterface.matchAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getMatchExecutions(
                context.response.fulfillments
            );
        } else if (
            _suggestedAction == ConsiderationInterface.fulfillOrder.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillAdvancedOrder.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getStandardExecutions();
        } else if (
            _suggestedAction ==
            ConsiderationInterface.fulfillBasicOrder.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getBasicExecutions();
        } else {
            revert UnknownAction();
        }
        context.response.explicitExecutions = explicitExecutions;
        context.response.implicitExecutions = implicitExecutions;
        context.response.implicitExecutionsPre = implicitExecutionsPre;
        context.response.implicitExecutionsPost = implicitExecutionsPost;
        context.response.nativeTokensReturned = nativeTokensReturned;
        return context;
    }
}
