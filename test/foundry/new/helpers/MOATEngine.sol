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
import { BaseOrderTest } from "../BaseOrderTest.sol";

import "forge-std/console.sol";

struct FuzzParams {
    uint256 seed;
}

struct TestContext {
    MOATOrder[] orders;
    SeaportInterface seaport;
    address caller;
    FuzzParams fuzzParams;
    bytes4[] checks;
}

library MOATEngineLib {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
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
}

contract MOATEngine is BaseOrderTest {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;
    using MOATHelpers for MOATOrder;
    using MOATHelpers for MOATOrder[];
    using MOATEngineLib for TestContext;

    function exec(TestContext memory context) internal {
        vm.startPrank(context.caller);
        bytes4 _action = context.action();
        if (_action == context.seaport.fulfillOrder.selector) {
            MOATOrder memory moatOrder = context.orders[0];
            AdvancedOrder memory order = moatOrder.order;
            MOATOrderContext memory orderContext = moatOrder.context;

            context.seaport.fulfillOrder(
                order.toOrder().withSignature(orderContext.signature),
                orderContext.fulfillerConduitKey
            );
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            MOATOrder memory moatOrder = context.orders[0];
            AdvancedOrder memory order = moatOrder.order;
            MOATOrderContext memory orderContext = moatOrder.context;

            context.seaport.fulfillAdvancedOrder(
                order.withSignature(orderContext.signature),
                orderContext.criteriaResolvers,
                orderContext.fulfillerConduitKey,
                orderContext.recipient
            );
        } else if (_action == context.seaport.cancel.selector) {
            MOATOrder[] memory moatOrders = context.orders;
            OrderComponents[] memory orderComponents = new OrderComponents[](
                moatOrders.length
            );

            for (uint256 i; i < moatOrders.length; ++i) {
                MOATOrder memory moatOrder = context.orders[i];
                orderComponents[i] = moatOrder
                    .order
                    .toOrder()
                    .parameters
                    .toOrderComponents(moatOrder.context.counter);
            }

            context.seaport.cancel(orderComponents);
        } else if (_action == context.seaport.validate.selector) {
            MOATOrder[] memory moatOrders = context.orders;
            Order[] memory orders = new Order[](moatOrders.length);

            for (uint256 i; i < moatOrders.length; ++i) {
                orders[i] = context.orders[i].order.toOrder();
            }

            context.seaport.validate(orders);
        } else {
            revert("MOATEngine: Action not implemented");
        }
        vm.stopPrank();
    }

    function check(TestContext memory context, bytes4 selector) internal {
        (bool success, bytes memory result) = address(this).delegatecall(
            abi.encodeWithSelector(selector, context)
        );
        if (!success) {
            if (result.length == 0) revert();
            assembly {
                revert(add(0x20, result), mload(result))
            }
        }
    }

    function checkAll(TestContext memory context) internal {
        for (uint256 i; i < context.checks.length; ++i) {
            bytes4 selector = context.checks[i];
            check(context, selector);
        }
    }
}
