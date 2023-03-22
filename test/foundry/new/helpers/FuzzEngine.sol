// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    FuzzHelpers,
    Structure,
    Family
} from "./FuzzHelpers.sol";
import { TestContext, FuzzParams, TestContextLib } from "./TestContextLib.sol";
import { BaseOrderTest } from "../BaseOrderTest.sol";
import { FuzzChecks } from "./FuzzChecks.sol";
import { FuzzSetup } from "./FuzzSetup.sol";

/**
 * @notice Stateless helpers for FuzzEngine.
 */
library FuzzEngineLib {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    /**
     * @dev Select an available "action," i.e. "which Seaport function to call,"
     *      based on the orders in a given TestContext. Selects a random action
     *      using the context's fuzzParams.seed when multiple actions are
     *      available for the given order config.
     *
     * @param context A Fuzz test context.
     * @return bytes4 selector of a SeaportInterface function.
     */
    function action(TestContext memory context) internal view returns (bytes4) {
        bytes4[] memory _actions = actions(context);
        return _actions[context.fuzzParams.seed % _actions.length];
    }

    /**
     * @dev Get an array of all possible "actions," i.e. "which Seaport
     *      functions can we call," based on the orders in a given TestContext.
     *
     * @param context A Fuzz test context.
     * @return bytes4[] of SeaportInterface function selectors.
     */
    function actions(
        TestContext memory context
    ) internal view returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        if (family == Family.SINGLE) {
            AdvancedOrder memory order = context.orders[0];
            Structure structure = order.getStructure(address(context.seaport));

            if (structure == Structure.BASIC) {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillBasicOrder.selector;
                selectors[3] = context
                    .seaport
                    .fulfillBasicOrder_efficient_6GL6yc
                    .selector;
                return selectors;
            }

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
        revert("FuzzEngine: Actions not found");
    }
}

/**
 * @notice Base test contract for FuzzEngine. Fuzz tests should inherit this.
 *         Includes the setup and helper functions from BaseOrderTest.
 */
contract FuzzEngine is FuzzSetup, FuzzChecks, BaseOrderTest {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];
    using FuzzEngineLib for TestContext;

    /**
     * @dev Run a `FuzzEngine` test with the given TestContext. Calls the
     *      following test lifecycle functions in order:
     *
     *      1. exec: Select and call a Seaport function.
     *      2. checkAll: Call all registered checks.
     *
     * @param context A Fuzz test context.
     */
    function run(TestContext memory context) internal {
        beforeEach(context);
        exec(context);
        checkAll(context);
    }

    /**
     * @dev Perform any setup steps necessary before calling `exec`.
     *
     * @param context A Fuzz test context.
     */
    function beforeEach(TestContext memory context) internal {
        setUpOfferItems(context);
        setUpConsiderationItems(context);
    }

    /**
     * @dev Call an available Seaport function based on the orders in the given
     *      TestContext. FuzzEngine will deduce which actions are available
     *      for the given orders and call a Seaport function at random using the
     *      context's fuzzParams.seed.
     *
     *      If a caller address is provided in the context, exec will prank the
     *      address before executing the selected action.
     *
     *      Note: not all Seaport actions are implemented here yet.
     *
     * @param context A Fuzz test context.
     */
    function exec(TestContext memory context) internal {
        if (context.caller != address(0)) vm.startPrank(context.caller);
        bytes4 _action = context.action();
        if (_action == context.seaport.fulfillOrder.selector) {
            AdvancedOrder memory order = context.orders[0];

            context.returnValues.fulfilled = context.seaport.fulfillOrder(
                order.toOrder(),
                context.fulfillerConduitKey
            );
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            AdvancedOrder memory order = context.orders[0];

            context.returnValues.fulfilled = context
                .seaport
                .fulfillAdvancedOrder(
                    order,
                    context.criteriaResolvers,
                    context.fulfillerConduitKey,
                    context.recipient
                );
        } else if (_action == context.seaport.fulfillBasicOrder.selector) {
            context.returnValues.fulfilled = context.seaport.fulfillBasicOrder(
                context.basicOrderParameters
            );
        } else if (
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            context.returnValues.fulfilled = context
                .seaport
                .fulfillBasicOrder_efficient_6GL6yc(
                    context.basicOrderParameters
                );
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableOrders(
                    context.orders.toOrders(),
                    context.offerFulfillments,
                    context.considerationFulfillments,
                    context.fulfillerConduitKey,
                    context.maximumFulfilled
                );
            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (
            _action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableAdvancedOrders(
                    context.orders,
                    context.criteriaResolvers,
                    context.offerFulfillments,
                    context.considerationFulfillments,
                    context.fulfillerConduitKey,
                    context.recipient,
                    context.maximumFulfilled
                );
            context.returnValues.availableOrders = availableOrders;
            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchOrders.selector) {
            Execution[] memory executions = context.seaport.matchOrders(
                context.orders.toOrders(),
                context.fulfillments
            );
            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            Execution[] memory executions = context.seaport.matchAdvancedOrders(
                context.orders,
                context.criteriaResolvers,
                context.fulfillments,
                context.recipient
            );
            context.returnValues.executions = executions;
        } else if (_action == context.seaport.cancel.selector) {
            AdvancedOrder[] memory orders = context.orders;
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

            context.returnValues.cancelled = context.seaport.cancel(
                orderComponents
            );
        } else if (_action == context.seaport.validate.selector) {
            context.returnValues.validated = context.seaport.validate(
                context.orders.toOrders()
            );
        } else {
            revert("FuzzEngine: Action not implemented");
        }
        if (context.caller != address(0)) vm.stopPrank();
    }

    /**
     * @dev Perform a "check," i.e. a post-execution assertion we want to
     *      validate. Checks should be public functions that accept a
     *      TestContext as their only argument. Checks have access to the
     *      post-execution TestContext and can use it to make test assertions.
     *
     *      Since we delegatecall ourself, checks must be public functions on
     *      this contract. It's a good idea to prefix them with "check_" as a
     *      naming convention, although it doesn't actually matter.
     *
     *      The idea here is that we can add checks for different scenarios to
     *      the FuzzEngine by adding them via abstract contracts.
     *
     * @param context A Fuzz test context.
     * @param selector bytes4 selector of the check function to call.
     */
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

    /**
     * @dev Perform all checks registered in the context.checks array.
     *
     *      We can add checks to the TestContext at any point in the context
     *      lifecycle, to be called after exec in the test lifecycle.
     *
     *      This is not set up yet, but the idea here is that we can add checks
     *      at order generation time, based on the characteristics of the orders
     *      we generate.
     *
     * @param context A Fuzz test context.
     */
    function checkAll(TestContext memory context) internal {
        for (uint256 i; i < context.checks.length; ++i) {
            bytes4 selector = context.checks[i];
            check(context, selector);
        }
    }
}
