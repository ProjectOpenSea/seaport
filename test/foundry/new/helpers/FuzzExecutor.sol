// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    AdvancedOrderLib,
    FulfillAvailableHelper,
    MatchFulfillmentHelper,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib
} from "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    Execution,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/SeaportStructs.sol";

import {
    FuzzTestContext,
    FuzzTestContextLib,
    FuzzParams
} from "./FuzzTestContextLib.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";

abstract contract FuzzExecutor is Test {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];
    using FuzzTestContextLib for FuzzTestContext;

    /**
     * @dev Call an available Seaport function based on the orders in the given
     *      FuzzTestContext. FuzzEngine will deduce which actions are available
     *      for the given orders and call a Seaport function at random using the
     *      context's fuzzParams.seed.
     *
     *      If a caller address is provided in the context, exec will prank the
     *      address before executing the selected action.
     *
     * @param context A Fuzz test context.
     */
    function exec(FuzzTestContext memory context, bool logCalls) public {
        // If the caller is not the zero address, prank the address.

        // Get the action to execute.  The action is derived from the fuzz seed,
        // so it will be the same for each run of the test throughout the entire
        // lifecycle of the test.
        bytes4 _action = context.action();
        uint256 value = context.getNativeTokensToSupply();

        // Execute the action.
        if (_action == context.seaport.fulfillOrder.selector) {
            logCall("fulfillOrder", logCalls);
            AdvancedOrder memory order = context.executionState.orders[0];

            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.fulfilled = context.seaport.fulfillOrder{
                value: value
            }(order.toOrder(), context.fulfillerConduitKey);
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            logCall("fulfillAdvancedOrder", logCalls);
            AdvancedOrder memory order = context.executionState.orders[0];

            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.fulfilled = context
                .seaport
                .fulfillAdvancedOrder{ value: value }(
                order,
                context.executionState.criteriaResolvers,
                context.fulfillerConduitKey,
                context.recipient
            );
        } else if (_action == context.seaport.fulfillBasicOrder.selector) {
            logCall("fulfillBasicOrder", logCalls);

            BasicOrderParameters memory basicOrderParameters = context
                .executionState
                .orders[0]
                .toBasicOrderParameters(
                    context.executionState.orders[0].getBasicOrderType()
                );

            basicOrderParameters.fulfillerConduitKey = context
                .fulfillerConduitKey;

            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.fulfilled = context.seaport.fulfillBasicOrder{
                value: value
            }(basicOrderParameters);
        } else if (
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            logCall("fulfillBasicOrder_efficient", logCalls);

            BasicOrderParameters memory basicOrderParameters = context
                .executionState
                .orders[0]
                .toBasicOrderParameters(
                    context.executionState.orders[0].getBasicOrderType()
                );

            basicOrderParameters.fulfillerConduitKey = context
                .fulfillerConduitKey;

            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.fulfilled = context
                .seaport
                .fulfillBasicOrder_efficient_6GL6yc{ value: value }(
                basicOrderParameters
            );
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            logCall("fulfillAvailableOrders", logCalls);
            if (context.caller != address(0)) vm.prank(context.caller);
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableOrders{ value: value }(
                    context.executionState.orders.toOrders(),
                    context.executionState.offerFulfillments,
                    context.executionState.considerationFulfillments,
                    context.fulfillerConduitKey,
                    context.executionState.maximumFulfilled
                );

            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (
            _action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            logCall("fulfillAvailableAdvancedOrders", logCalls);
            if (context.caller != address(0)) vm.prank(context.caller);
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableAdvancedOrders{ value: value }(
                    context.executionState.orders,
                    context.executionState.criteriaResolvers,
                    context.executionState.offerFulfillments,
                    context.executionState.considerationFulfillments,
                    context.fulfillerConduitKey,
                    context.recipient,
                    context.executionState.maximumFulfilled
                );

            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchOrders.selector) {
            logCall("matchOrders", logCalls);
            if (context.caller != address(0)) vm.prank(context.caller);
            Execution[] memory executions = context.seaport.matchOrders{
                value: value
            }(
                context.executionState.orders.toOrders(),
                context.executionState.fulfillments
            );

            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            logCall("matchAdvancedOrders", logCalls);
            if (context.caller != address(0)) vm.prank(context.caller);
            Execution[] memory executions = context.seaport.matchAdvancedOrders{
                value: value
            }(
                context.executionState.orders,
                context.executionState.criteriaResolvers,
                context.executionState.fulfillments,
                context.recipient
            );

            context.returnValues.executions = executions;
        } else if (_action == context.seaport.cancel.selector) {
            logCall("cancel", logCalls);
            AdvancedOrder[] memory orders = context.executionState.orders;
            OrderComponents[] memory orderComponents = new OrderComponents[](
                orders.length
            );

            for (uint256 i; i < orders.length; ++i) {
                AdvancedOrder memory order = orders[i];
                orderComponents[i] = order
                    .toOrder()
                    .parameters
                    .toOrderComponents(context.counter);
            }

            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.cancelled = context.seaport.cancel(
                orderComponents
            );
        } else if (_action == context.seaport.validate.selector) {
            logCall("validate", logCalls);
            if (context.caller != address(0)) vm.prank(context.caller);
            context.returnValues.validated = context.seaport.validate(
                context.executionState.orders.toOrders()
            );
        } else {
            revert("FuzzEngine: Action not implemented");
        }
    }

    function exec(FuzzTestContext memory context) public {
        exec(context, false);
    }

    function logCall(string memory callName, bool enabled) internal {
        if (enabled && vm.envOr("SEAPORT_COLLECT_FUZZ_METRICS", false)) {
            string memory metric = string.concat(callName, ":1|c");
            vm.writeLine("metrics.txt", metric);
        }
    }
}
