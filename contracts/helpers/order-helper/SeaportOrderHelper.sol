// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrderLib,
    OrderLib,
    SeaportInterface,
    CriteriaResolver,
    OrderDetails,
    AdvancedOrder,
    Order,
    FulfillmentComponent,
    Fulfillment,
    MatchComponent
} from "seaport-sol/SeaportSol.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/fulfillments/lib/FulfillmentLib.sol";

import {
    SeaportValidatorInterface,
    ErrorsAndWarnings
} from "../order-validator/SeaportValidator.sol";

struct Response {
    ErrorsAndWarnings[] validationErrors;
    OrderDetails[] orderDetails;
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    Fulfillment[] fulfillments;
    MatchComponent[] unspentOfferComponents;
    MatchComponent[] unmetConsiderationComponents;
}

contract SeaportOrderHelper {
    using AdvancedOrderLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;
    using OrderLib for Order;
    using OrderLib for Order[];
    using FulfillmentGeneratorLib for OrderDetails[];

    SeaportInterface public immutable seaport;
    SeaportValidatorInterface public immutable validator;

    constructor(
        SeaportInterface _seaport,
        SeaportValidatorInterface _validator
    ) {
        seaport = _seaport;
        validator = _validator;
    }

    function run(
        AdvancedOrder[] memory orders,
        address recipient,
        address caller
    ) external returns (Response memory) {
        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
            orders.length
        );
        for (uint256 i; i < orders.length; i++) {
            errors[i] = validator.isValidOrder(
                orders[i].toOrder(),
                address(seaport)
            );
        }
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        bytes32[] memory orderHashes = orders.getOrderHashes(address(seaport));
        OrderDetails[] memory orderDetails = orders.getOrderDetails(
            criteriaResolvers,
            orderHashes
        );
        (
            ,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        ) = orderDetails.getFulfillments(recipient, caller);

        return
            Response({
                validationErrors: errors,
                orderDetails: orderDetails,
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                fulfillments: fulfillments,
                unspentOfferComponents: unspentOfferComponents,
                unmetConsiderationComponents: unmetConsiderationComponents
            });
    }
}
