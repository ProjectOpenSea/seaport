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
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    Execution,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import {
    FuzzTestContext,
    FuzzTestContextLib,
    FuzzParams
} from "./FuzzTestContextLib.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";

import { logCall } from "./Metrics.sol";
import { dumpExecutions } from "./DebugUtil.sol";

/**
 * @notice Abstract FuzzEngine helper contract responsible for executing the
 *         selected Seaport action.
 */
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
     *      context's `fuzzParams.seed`.
     *
     *      1. Log the call to a call metrics file.
     *      2. If a caller address is set in the context, prank the address.
     *      3. Call the selected Seaport function, passing any additional data
     *         necessary from the test context.
     *      4. Store the return value of the call in the context.
     *
     * @param context A Fuzz test context.
     */
    function exec(FuzzTestContext memory context, bool logCalls) public {
        // // Activate this to help with debugging
        // dumpExecutions(context);

        // Get the action to execute.  The action is derived from the fuzz seed,
        // so it will be the same for each run of the test throughout the entire
        // lifecycle of the test.
        bytes4 _action = context.action();

        // Execute the action.
        if (_action == context.seaport.fulfillOrder.selector) {
            logCall("fulfillOrder", logCalls);
            AdvancedOrder memory order = context.executionState.orders[0];

            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            context.returnValues.fulfilled = context.seaport.fulfillOrder{
                value: context.executionState.value
            }(order.toOrder(), context.executionState.fulfillerConduitKey);
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            logCall("fulfillAdvancedOrder", logCalls);
            AdvancedOrder memory order = context.executionState.orders[0];

            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            context.returnValues.fulfilled = context
                .seaport
                .fulfillAdvancedOrder{ value: context.executionState.value }(
                order,
                context.executionState.criteriaResolvers,
                context.executionState.fulfillerConduitKey,
                context.executionState.recipient
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
                .executionState
                .fulfillerConduitKey;

            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            context.returnValues.fulfilled = context.seaport.fulfillBasicOrder{
                value: context.executionState.value
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
                .executionState
                .fulfillerConduitKey;

            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            context.returnValues.fulfilled = context
                .seaport
                .fulfillBasicOrder_efficient_6GL6yc{
                value: context.executionState.value
            }(basicOrderParameters);
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            logCall("fulfillAvailableOrders", logCalls);
            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableOrders{
                    value: context.executionState.value
                }(
                    context.executionState.orders.toOrders(),
                    context.executionState.offerFulfillments,
                    context.executionState.considerationFulfillments,
                    context.executionState.fulfillerConduitKey,
                    context.executionState.maximumFulfilled
                );

            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (
            _action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            logCall("fulfillAvailableAdvancedOrders", logCalls);
            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableAdvancedOrders{
                    value: context.executionState.value
                }(
                    context.executionState.orders,
                    context.executionState.criteriaResolvers,
                    context.executionState.offerFulfillments,
                    context.executionState.considerationFulfillments,
                    context.executionState.fulfillerConduitKey,
                    context.executionState.recipient,
                    context.executionState.maximumFulfilled
                );

            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchOrders.selector) {
            logCall("matchOrders", logCalls);
            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            Execution[] memory executions = context.seaport.matchOrders{
                value: context.executionState.value
            }(
                context.executionState.orders.toOrders(),
                context.executionState.fulfillments
            );

            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            logCall("matchAdvancedOrders", logCalls);
            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            Execution[] memory executions = context.seaport.matchAdvancedOrders{
                value: context.executionState.value
            }(
                context.executionState.orders,
                context.executionState.criteriaResolvers,
                context.executionState.fulfillments,
                context.executionState.recipient
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
                    .toOrderComponents(context.executionState.counter);
            }

            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
            context.returnValues.cancelled = context.seaport.cancel(
                orderComponents
            );
        } else if (_action == context.seaport.validate.selector) {
            logCall("validate", logCalls);
            if (context.executionState.caller != address(0)) {
                vm.prank(context.executionState.caller);
            }
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
}
