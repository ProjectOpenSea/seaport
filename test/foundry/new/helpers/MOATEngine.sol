// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import {
    MOATOrder,
    MOATOrderContext,
    MOATHelpers,
    Structure,
    Family
} from "./MOATHelpers.sol";

import "forge-std/console.sol";

struct FuzzParams {
    uint256 seed;
}

struct TestContext {
    MOATOrder[] orders;
    SeaportInterface seaport;
    FuzzParams fuzzParams;
}

library MOATEngine {
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;
    using MOATHelpers for MOATOrder;
    using MOATHelpers for MOATOrder[];

    function action(TestContext memory context) internal pure returns (bytes4) {
        bytes4[] memory _actions = actions(context);
        return _actions[context.fuzzParams.seed % _actions.length];
    }

    function actions(
        TestContext memory context
    ) internal pure returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        if (family == Family.SINGLE) {
            MOATOrder memory order = context.orders[0];
            Structure structure = order.getStructure();
            if (structure == Structure.STANDARD) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }
        }

        if (family == Family.COMBINED) {
            bytes4[] memory selectors = new bytes4[](6);
            selectors[0] = context.seaport.fulfillAvailableOrders.selector;
            selectors[1] = context
                .seaport
                .fulfillAvailableAdvancedOrders
                .selector;
            selectors[2] = context.seaport.matchOrders.selector;
            selectors[3] = context.seaport.matchAdvancedOrders.selector;
            selectors[4] = context.seaport.cancel.selector;
            selectors[5] = context.seaport.validate.selector;
            return selectors;
        }
        revert("MOATEngine: Actions not found");
    }

    function exec(TestContext memory context) internal {
        bytes4 action = action(context);
        if (action == context.seaport.fulfillOrder.selector) {
            MOATOrder memory moatOrder = context.orders[0];
            AdvancedOrder memory order = moatOrder.order;
            MOATOrderContext memory orderContext = moatOrder.context;

            context.seaport.fulfillOrder(
                order.toOrder().withSignature(orderContext.signature),
                orderContext.fulfillerConduitKey
            );
        } else if (action == context.seaport.fulfillAdvancedOrder.selector) {
            MOATOrder memory moatOrder = context.orders[0];
            AdvancedOrder memory order = moatOrder.order;
            MOATOrderContext memory orderContext = moatOrder.context;

            context.seaport.fulfillAdvancedOrder(
                order.withSignature(orderContext.signature),
                orderContext.criteriaResolvers,
                orderContext.fulfillerConduitKey,
                orderContext.recipient
            );
        } else if (action == context.seaport.validate.selector) {
            MOATOrder[] memory moatOrders = context.orders;
            Order[] memory orders = new Order[](context.orders.length);

            for (uint256 i; i < context.orders.length; ++i) {
                orders[i] = context.orders[i].order.toOrder();
            }

            context.seaport.validate(orders);
        } else {
            revert("MOATEngine: Action not implemented");
        }
    }
}
