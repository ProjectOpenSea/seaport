// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

abstract contract FuzzDerivers is
    FulfillAvailableHelper,
    MatchFulfillmentHelper
{
    using AdvancedOrderLib for AdvancedOrder[];

    function deriveFulfillments(FuzzTestContext memory context) public {
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = getNaiveFulfillmentComponents(context.orders.toOrders());

        context.offerFulfillments = offerFulfillments;
        context.considerationFulfillments = considerationFulfillments;

        (Fulfillment[] memory fulfillments, , ) = context
            .testHelpers
            .getMatchedFulfillments(context.orders);
        context.fulfillments = fulfillments;
    }

    function deriveMaximumFulfilled(
        FuzzTestContext memory context
    ) public pure {
        context.maximumFulfilled = context.orders.length;
    }
}
