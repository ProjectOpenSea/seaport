//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;
import { BasicOrderParameters, OfferItem, ConsiderationItem, OrderParameters, OrderComponents, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver } from "../../../../contracts/lib/ConsiderationStructs.sol";

struct FulfillBasicOrderParameters {
    BasicOrderParameters parameters;
}

struct FulfillOrderParameters {
    Order order;
    bytes32 fulfillerConduitKey;
}

struct FulfillAdvancedOrderParameters {
    AdvancedOrder order;
    CriteriaResolver[] criteriaResolvers;
    bytes32 fulfillerConduitKey;
}

struct FulfillAvailableOrdersParameters {
    Order[] orders;
    FulfillmentComponent[][] orderFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    bytes32 fulfillerConduitKey;
    uint256 maximumFulfilled;
}

struct FulfillAvailableAdvancedOrdersParameters {
    AdvancedOrder[] advancedOrders;
    CriteriaResolver[] criteriaResolvers;
    FulfillmentComponent[][] orderFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    bytes32 fulfillerConduitKey;
    uint256 maximumFulfilled;
}

struct MatchOrdersParameters {
    Order[] orders;
    Fulfillment[] fulfillments;
}

struct MatchAdvancedOrdersParameters {
    AdvancedOrder[] advancedOrders;
    CriteriaResolver[] criteriaResolvers;
    Fulfillment[] fulfillments;
}

struct CancelParameters {
    OrderComponents[] orders;
}

struct ValidateParameters {
    Order[] orders;
}

struct ReentrantCallParameters {
    FulfillBasicOrderParameters fulfillBasicOrderParameters;
    FulfillOrderParameters fulfillOrderParameters;
    FulfillAdvancedOrderParameters fulfillAdvancedOrderParameters;
    FulfillAvailableOrdersParameters fulfillAvailableOrdersParameters;
    FulfillAvailableAdvancedOrdersParameters fulfillAvailableAdvancedOrdersParameters;
    MatchOrdersParameters matchOrdersParameters;
    MatchAdvancedOrdersParameters matchAdvancedOrdersParameters;
    CancelParameters cancelParameters;
    ValidateParameters validateParameters;
}
