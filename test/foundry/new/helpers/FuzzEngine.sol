// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";

import "seaport-sol/SeaportSol.sol";

import { BaseOrderTest } from "../BaseOrderTest.sol";

import {
    FuzzGeneratorContext,
    FuzzGeneratorContextLib
} from "./FuzzGeneratorContextLib.sol";

import {
    FuzzTestContext,
    FuzzTestContextLib,
    FuzzParams
} from "./FuzzTestContextLib.sol";

import {
    AdvancedOrdersSpace,
    AdvancedOrdersSpaceGenerator,
    TestStateGenerator
} from "./FuzzGenerators.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzDerivers } from "./FuzzDerivers.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzSetup } from "./FuzzSetup.sol";

import { dumpExecutions } from "./DebugUtil.sol";

/**
 * @notice Base test contract for FuzzEngine. Fuzz tests should inherit this.
 *         Includes the setup and helper functions from BaseOrderTest.
 */
contract FuzzEngine is BaseOrderTest, FuzzDerivers, FuzzSetup, FuzzChecks {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzTestContextLib for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    /**
     * @dev Generate a randomized `FuzzTestContext` from fuzz parameters and run a
     *      `FuzzEngine` test. Calls the following test lifecycle functions in
     *      order:
     *
     *      1. generate: Generate a new `FuzzTestContext` from fuzz parameters
     *      2. runDerivers: Run deriver functions for the test.
     *      3. runSetup: Run setup functions for the test.
     *      3. exec: Select and call a Seaport function.
     *      4. checkAll: Call all registered checks.
     *
     * @param fuzzParams A FuzzParams struct containing fuzzed values.
     */
    function run(FuzzParams memory fuzzParams) internal {
        FuzzTestContext memory context = generate(fuzzParams);
        runDerivers(context);
        runSetup(context);
        exec(context);
        checkAll(context);
    }

    /**
     * @dev Run a `FuzzEngine` test with the provided FuzzTestContext. Calls the
     *      following test lifecycle functions in order:
     *
     *      1. runDerivers: Run deriver functions for the test.
     *      1. runSetup: Run setup functions for the test.
     *      2. exec: Select and call a Seaport function.
     *      3. checkAll: Call all registered checks.
     *
     * @param context A Fuzz test context.
     */
    function run(FuzzTestContext memory context) internal {
        runDerivers(context);
        runSetup(context);
        exec(context);
        checkAll(context);
    }

    /**
     * @dev Generate a randomized `FuzzTestContext` from fuzz parameters.
     *
     * @param fuzzParams A FuzzParams struct containing fuzzed values.
     */
    function generate(
        FuzzParams memory fuzzParams
    ) internal returns (FuzzTestContext memory) {
        ConsiderationInterface seaport_ = getSeaport();
        ConduitControllerInterface conduitController_ = getConduitController();
        
        // Set up a default context.
        FuzzGeneratorContext memory generatorContext = FuzzGeneratorContextLib
            .from({
                vm: vm,
                seaport: seaport_,
                conduitController: conduitController_,
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s
            });

        // Generate a random order space.
        AdvancedOrdersSpace memory space = TestStateGenerator.generate(
            fuzzParams.totalOrders,
            fuzzParams.maxOfferItems,
            fuzzParams.maxConsiderationItems,
            generatorContext
        );

        // Generate orders from the space.
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            generatorContext
        );

        return
            FuzzTestContextLib
                .from({
                    orders: orders,
                    seaport: seaport_,
                    caller: address(this)
                })
                .withConduitController(conduitController_)
                .withFuzzParams(fuzzParams);
    }

    /**
     * @dev Perform any "deriver" steps necessary before calling `runSetup`.
     *
     *      1. deriveFulfillments: calculate fulfillments and add them to the
     *         test context.
     *      2. deriveMaximumFulfilled: calculate maximumFulfilled and add it to
     *         the test context.
     *      4. TODO: deriveUnavailable.
     *      3. deriveExecutions: calculate expected implicit/explicit executions
     *         and add them to the test context.
     *
     * @param context A Fuzz test context.
     */
    function runDerivers(FuzzTestContext memory context) internal {
        deriveFulfillments(context);
        deriveMaximumFulfilled(context);
        // TODO: deriveUnavailable(context);
        deriveExecutions(context);
    }

    /**
     * @dev Perform any setup steps necessary before calling `exec`.
     *
     *      1. setUpZoneParameters: calculate expected zone hashes and set up
     *         zone related checks for restricted orders.
     *      2. setUpOfferItems: Create and approve offer items for each order.
     *      3. setUpConsiderationItems: Create and approve consideration items
     *         for each order.
     *
     * @param context A Fuzz test context.
     */
    function runSetup(FuzzTestContext memory context) internal {
        // TODO: Scan all orders, look for unavailable orders
        // 1. order has been cancelled
        // 2. order has expired
        // 3. order has not yet started
        // 4. order is already filled
        // 5. order is a contract order and the call to the offerer reverts
        // 6. maximumFullfilled is less than total orders provided and
        //    enough other orders are available
        setUpZoneParameters(context);
        setUpOfferItems(context);
        setUpConsiderationItems(context);
        setupExpectedEventsAndBalances(context);
    }

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
    function exec(FuzzTestContext memory context) internal {
        // If the caller is not the zero address, prank the address.
        if (context.caller != address(0)) vm.startPrank(context.caller);

        // Get the action to execute.
        bytes4 _action = context.action();

        // Execute the action.
        if (_action == context.seaport.fulfillOrder.selector) {
            logCall("fulfillOrder");
            AdvancedOrder memory order = context.orders[0];

            context.returnValues.fulfilled = context.seaport.fulfillOrder{
                value: context.getNativeTokensToSupply()
            }(order.toOrder(), context.fulfillerConduitKey);
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            logCall("fulfillAdvancedOrder");
            AdvancedOrder memory order = context.orders[0];

            context.returnValues.fulfilled = context
                .seaport
                .fulfillAdvancedOrder{
                value: context.getNativeTokensToSupply()
            }(
                order,
                context.criteriaResolvers,
                context.fulfillerConduitKey,
                context.recipient
            );
        } else if (_action == context.seaport.fulfillBasicOrder.selector) {
            logCall("fulfillBasicOrder");

            BasicOrderParameters memory basicOrderParameters = context
                .orders[0]
                .toBasicOrderParameters(context.orders[0].getBasicOrderType());

            basicOrderParameters.fulfillerConduitKey = context
                .fulfillerConduitKey;

            context.returnValues.fulfilled = context.seaport.fulfillBasicOrder{
                value: context.getNativeTokensToSupply()
            }(basicOrderParameters);
        } else if (
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            logCall("fulfillBasicOrder_efficient");

            BasicOrderParameters memory basicOrderParameters = context
                .orders[0]
                .toBasicOrderParameters(context.orders[0].getBasicOrderType());

            basicOrderParameters.fulfillerConduitKey = context
                .fulfillerConduitKey;

            context.returnValues.fulfilled = context
                .seaport
                .fulfillBasicOrder_efficient_6GL6yc{
                value: context.getNativeTokensToSupply()
            }(basicOrderParameters);
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            logCall("fulfillAvailableOrders");
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableOrders{
                    value: context.getNativeTokensToSupply()
                }(
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
            logCall("fulfillAvailableAdvancedOrders");
            (
                bool[] memory availableOrders,
                Execution[] memory executions
            ) = context.seaport.fulfillAvailableAdvancedOrders{
                    value: context.getNativeTokensToSupply()
                }(
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
            logCall("matchOrders");
            Execution[] memory executions = context.seaport.matchOrders{
                value: context.getNativeTokensToSupply()
            }(context.orders.toOrders(), context.fulfillments);

            context.returnValues.executions = executions;
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            logCall("matchAdvancedOrders");
            Execution[] memory executions = context.seaport.matchAdvancedOrders{
                value: context.getNativeTokensToSupply()
            }(
                context.orders,
                context.criteriaResolvers,
                context.fulfillments,
                context.recipient
            );

            context.returnValues.executions = executions;
        } else if (_action == context.seaport.cancel.selector) {
            logCall("cancel");
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
            logCall("validate");
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
     *      FuzzTestContext as their only argument. Checks have access to the
     *      post-execution FuzzTestContext and can use it to make test assertions.
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
    function check(FuzzTestContext memory context, bytes4 selector) internal {
        (bool success, bytes memory result) = address(this).delegatecall(
            abi.encodeWithSelector(selector, context)
        );

        if (!success) {
            dumpExecutions(context);
            if (result.length == 0) revert();
            assembly {
                revert(add(0x20, result), mload(result))
            }
        }
    }

    /**
     * @dev Perform all checks registered in the context.checks array.
     *
     *      We can add checks to the FuzzTestContext at any point in the context
     *      lifecycle, to be called after `exec` in the test lifecycle.
     *
     * @param context A Fuzz test context.
     */
    function checkAll(FuzzTestContext memory context) internal {
        for (uint256 i; i < context.checks.length; ++i) {
            bytes4 selector = context.checks[i];
            check(context, selector);
        }
    }

    function logCall(string memory callName) internal {
        if (vm.envOr("SEAPORT_COLLECT_FUZZ_METRICS", false)) {
            string memory metric = string.concat(callName, ":1|c");
            vm.writeLine("metrics.txt", metric);
        }
    }
}
