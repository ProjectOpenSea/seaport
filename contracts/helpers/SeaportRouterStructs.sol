// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    AdvancedOrder,
    CriteriaResolver,
    FulfillmentComponent
} from "../lib/ConsiderationStructs.sol";

/**
 * @dev Advanced order parameters for use through the
 *      FulfillAvailableAdvancedOrdersParams struct.
 */
struct AdvancedOrderParams {
    AdvancedOrder[] advancedOrders;
    CriteriaResolver[] criteriaResolvers;
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    uint256 value; // The amount of ether value to send with the set of orders.
}

/**
 * @dev Parameters for using fulfillAvailableAdvancedOrders
 *      through SeaportRouter.
 */
struct FulfillAvailableAdvancedOrdersParams {
    address[] seaportContracts;
    AdvancedOrderParams[] advancedOrderParams;
    bytes32 fulfillerConduitKey;
    address recipient;
    uint256 maximumFulfilled;
}
