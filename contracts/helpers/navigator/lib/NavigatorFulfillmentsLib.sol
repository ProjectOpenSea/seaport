// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Fulfillment } from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

import {
    FulfillmentComponent,
    MatchComponent,
    OrderDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

library NavigatorFulfillmentsLib {
    using FulfillmentGeneratorLib for OrderDetails[];

    /**
     * @dev Calculate fulfillments and match components for the provided orders
     *      and add them to the NavigatorResponse.
     */
    function withFulfillments(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        (
            ,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        ) = context.response.orderDetails.getFulfillments(
                context.request.fulfillmentStrategy,
                context.request.recipient,
                context.request.caller,
                context.request.seed
            );

        context.response.offerFulfillments = offerFulfillments;
        context.response.considerationFulfillments = considerationFulfillments;
        context.response.fulfillments = fulfillments;
        context.response.unspentOfferComponents = unspentOfferComponents;
        context
            .response
            .unmetConsiderationComponents = unmetConsiderationComponents;
        return context;
    }
}
