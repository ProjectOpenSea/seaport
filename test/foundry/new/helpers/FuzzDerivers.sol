// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";
import { ExecutionHelper } from "seaport-sol/executions/ExecutionHelper.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";

/**
 *  @dev "Derivers" examine generated orders and calculate additional
 *       information based on the order state, like fulfillments and expected
 *       executions. Derivers run after generators, but before setup. Deriver
 *       functions should take a `FuzzTestContext` as input and modify it,
 *       adding any additional information that might be necessary for later
 *       steps. Derivers should not modify the order state itself, only the
 *       `FuzzTestContext`.
 */
abstract contract FuzzDerivers is
    FulfillAvailableHelper,
    MatchFulfillmentHelper,
    ExecutionHelper
{
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using MatchComponentType for MatchComponent[];

    function deriveFulfillments(FuzzTestContext memory context) public {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                FulfillmentComponent[][] memory offerFulfillments,
                FulfillmentComponent[][] memory considerationFulfillments
            ) = getNaiveFulfillmentComponents(context.orders.toOrders());

            context.offerFulfillments = offerFulfillments;
            context.considerationFulfillments = considerationFulfillments;
        }

        if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            (
                Fulfillment[] memory fulfillments,
                MatchComponent[] memory remainingOfferComponents,

            ) = context.testHelpers.getMatchedFulfillments(context.orders);
            context.fulfillments = fulfillments;
            context.remainingOfferComponents = remainingOfferComponents
                .toFulfillmentComponents();
        }
    }

    function deriveMaximumFulfilled(
        FuzzTestContext memory context
    ) public pure {
        context.maximumFulfilled = context.orders.length;
    }

    function deriveExecutions(FuzzTestContext memory context) public {
        bytes4 action = context.action();
        Execution[] memory implicitExecutions;
        Execution[] memory explicitExecutions;
        if (
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillAdvancedOrder.selector
        ) {
            implicitExecutions = getStandardExecutions(
                toOrderDetails(context.orders[0].parameters),
                context.caller,
                context.fulfillerConduitKey,
                context.recipient,
                0 // TODO: Native tokens?
            );
        } else if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            implicitExecutions = getBasicExecutions(
                toOrderDetails(context.orders[0].parameters),
                context.caller,
                context.fulfillerConduitKey,
                0 // TODO: Native tokens?
            );
        } else if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutions
            ) = getFulfillAvailableExecutions(
                toFulfillmentDetails(context.orders, context.recipient),
                context.offerFulfillments,
                context.considerationFulfillments,
                0 // TODO: Native tokens?
            );
        } else if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            FulfillmentComponent[] memory remainingOfferComponents;
            (explicitExecutions, implicitExecutions) = getMatchExecutions(
                toFulfillmentDetails(context.orders, context.recipient),
                context.fulfillments,
                remainingOfferComponents
            );
        }
        context.expectedImplicitExecutions = implicitExecutions;
        context.expectedExplicitExecutions = explicitExecutions;
    }
}
