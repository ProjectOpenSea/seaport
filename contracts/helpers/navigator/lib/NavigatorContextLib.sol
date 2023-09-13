// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    MatchComponent
} from "seaport-sol/src/lib/types/MatchComponentType.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    NavigatorContext,
    NavigatorRequest,
    NavigatorResponse
} from "./SeaportNavigatorTypes.sol";

import { ErrorsAndWarnings } from "../../order-validator/SeaportValidator.sol";

library NavigatorContextLib {
    /**
     * @dev Creates a new NavigatorContext from a NavigatorRequest, which just
     *      means slotting the request into the context's request field and
     *      ignoring the response field.
     */
    function from(
        NavigatorRequest memory request
    ) internal pure returns (NavigatorContext memory context) {
        context.request = request;
    }

    /**
     * @dev Adds an empty response to the context.
     */
    function withEmptyResponse(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        context.response = NavigatorResponse({
            orders: new AdvancedOrder[](0),
            criteriaResolvers: new CriteriaResolver[](0),
            suggestedActionName: "",
            suggestedCallData: hex"",
            validationErrors: new ErrorsAndWarnings[](0),
            orderDetails: new OrderDetails[](0),
            offerFulfillments: new FulfillmentComponent[][](0),
            considerationFulfillments: new FulfillmentComponent[][](0),
            fulfillments: new Fulfillment[](0),
            unspentOfferComponents: new MatchComponent[](0),
            unmetConsiderationComponents: new MatchComponent[](0),
            explicitExecutions: new Execution[](0),
            implicitExecutions: new Execution[](0),
            implicitExecutionsPre: new Execution[](0),
            implicitExecutionsPost: new Execution[](0),
            nativeTokensReturned: 0
        });
        return context;
    }
}
