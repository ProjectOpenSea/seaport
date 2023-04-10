// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { dumpExecutions } from "./DebugUtil.sol";

import {
    AdvancedOrderLib,
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

import { SeaportInterface } from "seaport-sol/SeaportInterface.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/ConduitControllerInterface.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/ConduitControllerInterface.sol";

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

import { FuzzAmendments } from "./FuzzAmendments.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzDerivers } from "./FuzzDerivers.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers, Structure } from "./FuzzHelpers.sol";

import { CheckHelpers, FuzzSetup } from "./FuzzSetup.sol";

/**
 * @notice Base test contract for FuzzEngine. Fuzz tests should inherit this.
 *         Includes the setup and helper functions from BaseOrderTest.
 *
 *         The BaseOrderTest used in this fuzz engine is not the same as the
 *         BaseOrderTest contract used in the legacy tests.  The relative path
 *         for the relevant version is `test/foundry/new/BaseOrderTest.sol`.
 *
 *         Running test_fuzz_validOrders in FuzzMain triggers the following
 *         lifecycle. First, a pseudorandom `FuzzTestContext` is generated from
 *         the FuzzParams. The important bits of his phase are order and action
 *         generation. Then, the fuzz derivers are run to derive values
 *         such as fulfillments and executions from the orders. Next, the
 *         setup phase is run to set up the necessary conditions for a test to
 *         pass, including minting the necessary tokens and setting up the
 *         necessary approvals. The setup phase also lays out the expectations
 *         for the post-execution state of the test. Then, during the execution
 *         phase, some Seaport function gets called according the the action
 *         determined by the seed in the FuzzParams. Finally, the checks phase
 *         runs all registered checks to ensure that the post-execution state
 *         matches the expectations set up in the setup phase.
 *
 *         The `generate` function in this file calls out to the `generate`
 *         functions in `TestStateGenerator` (responsible for setting up the
 *         order components) and `AdvancedOrdersSpaceGenerator` (responsible for
 *         setting up the orders and actions). The generation phase relies on a
 *         `FuzzGeneratorContext` internally, but it returns a `FuzzTestContext`
 *         struct, which is used throughout the rest of the lifecycle.
 *
 *         The `runDerivers` function in this file serves as a central location
 *         to slot in calls to functions that deterministically derive values
 *         from the state that was created in the generation phase.
 *
 *         The `amendOrderState` function in this file serves as a central
 *         location to slot in calls to functions that amend the state of the
 *         orders.  For example, calling `validate` on an order.
 *
 *         The `runSetup` function should hold everything that mutates state,
 *         such as minting and approving tokens.  It also contains the logic
 *         for setting up the expectations for the post-execution state of the
 *         test. Logic for handling unavailable orders and balance checking
 *         will also live here.
 *
 *          The `runCheckRegistration` function should hold everything that
 *          registers checks but does not belong naturally elsewhere.  Checks
 *          can be registered throughout the lifecycle, but unless there's a
 *          natural reason to place them inline elsewhere in the lifecycle, they
 *          should go in a helper in `runCheckRegistration`.
 *
 *         The `exec` function is lean and only 1) sets up a prank if the caller
 *         is not the test contract, 2) logs the action, 3) calls the Seaport
 *         function, and adds the values returned by the function call to the
 *         context for later use in checks.
 *
 *         The `checkAll` function runs all of the checks that were registered
 *         throughout the test lifecycle. To add a new check, add a function
 *         to `FuzzChecks` and then register it with `registerCheck`.
 *
 */
contract FuzzEngine is
    BaseOrderTest,
    FuzzAmendments,
    FuzzChecks,
    FuzzDerivers,
    FuzzSetup
{
    // Use the various builder libraries.  These allow for creating structs in a
    // more readable way.
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];
    using FuzzTestContextLib for FuzzTestContext;

    uint256 constant JAN_1_2023_UTC = 1672531200;

    /**
     * @dev Generate a randomized `FuzzTestContext` from fuzz parameters and run
     *      a `FuzzEngine` test.
     *
     * @param fuzzParams A FuzzParams struct containing fuzzed values.
     */
    function run(FuzzParams memory fuzzParams) internal {
        FuzzTestContext memory context = generate(fuzzParams);
        run(context);
    }

    /**
     * @dev Run a `FuzzEngine` test with the provided FuzzTestContext. Calls the
     *      following test lifecycle functions in order:
     *
     *      1. amendOrderState: Amend the order state.
     *      2. runDerivers: Run deriver functions for the test.
     *      3. runSetup: Run setup functions for the test.
     *      4. runCheckRegistration: Register checks for the test.
     *      5. exec: Select and call a Seaport function.
     *      6. checkAll: Call all registered checks.
     *
     * @param context A Fuzz test context.
     */
    function run(FuzzTestContext memory context) internal {
        amendOrderState(context);
        runDerivers(context);
        runSetup(context);
        runCheckRegistration(context);
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
        vm.warp(JAN_1_2023_UTC);
        // Set either the optimized version or the reference version of Seaport,
        // depending on the active profile.
        SeaportInterface seaport_ = getSeaport();
        // Get the conduit controller, which allows dpeloying and managing
        // conduits.  Conduits are used to transfer tokens between accounts.
        ConduitControllerInterface conduitController_ = getConduitController();

        // Set up a default FuzzGeneratorContext.  Note that this is only used
        // for the generation pphase.  The `FuzzTestContext` is used throughout
        // the rest of the lifecycle.
        FuzzGeneratorContext memory generatorContext = FuzzGeneratorContextLib
            .from({
                vm: vm,
                seaport: seaport_,
                conduitController: conduitController_,
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s
            });

        // Generate a pseudorandom order space. The `AdvancedOrdersSpace` is
        // made up of an `OrderComponentsSpace` array and an `isMatchable` bool.
        // Each `OrderComponentsSpace` is a struct with fields that are enums
        // (or arrays of enums) from `SpaceEnums.sol`. In other words, the
        // `AdvancedOrdersSpace` is a container for a set of constrained
        // possibilities.
        AdvancedOrdersSpace memory space = TestStateGenerator.generate(
            fuzzParams.totalOrders,
            fuzzParams.maxOfferItems,
            fuzzParams.maxConsiderationItems,
            generatorContext
        );

        // Generate orders from the space. These are the actual orders that will
        // be used in the test.
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            generatorContext
        );

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport_ })
            .withConduitController(conduitController_)
            .withFuzzParams(fuzzParams)
            .withMaximumFulfilled(space.maximumFulfilled)
            .withPreExecOrderStatuses(space);

        // Generate and add a top-level fulfiller conduit key to the context.
        // This is on a separate line to avoid stack too deep.
        context = context
            .withCaller(
                AdvancedOrdersSpaceGenerator.generateCaller(
                    space,
                    generatorContext
                )
            )
            .withFulfillerConduitKey(
                AdvancedOrdersSpaceGenerator.generateFulfillerConduitKey(
                    space,
                    generatorContext
                )
            );

        // If it's an advanced order, generate and add a top-level recipient.
        if (
            orders.getStructure(address(context.seaport)) == Structure.ADVANCED
        ) {
            context = context.withRecipient(
                AdvancedOrdersSpaceGenerator.generateRecipient(
                    space,
                    generatorContext
                )
            );
        }

        return context;
    }

    /**
     * @dev Perform any "deriver" steps necessary before calling `runSetup`.
     *
     *      1. deriveAvailableOrders: calculate which orders are available and
     *         add them to the test context.
     *      2. deriveCriteriaResolvers: calculate criteria resolvers and add
     *         them to the test context.
     *      3. deriveFulfillments: calculate fulfillments and add them to the
     *         test context.
     *      4. deriveExecutions: calculate expected implicit/explicit executions
     *         and add them to the test context.
     *
     * @param context A Fuzz test context.
     */
    function runDerivers(FuzzTestContext memory context) internal {
        deriveAvailableOrders(context);
        deriveCriteriaResolvers(context);
        deriveFulfillments(context);
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
        // 1. order has been cancelled
        // 2. order has expired
        // 3. order has not yet started
        // 4. order is already filled
        // 5. order is a contract order and the call to the offerer reverts
        // 6. maximumFullfilled is less than total orders provided and
        //    enough other orders are available
        setUpZoneParameters(context);
        setUpCallerApprovals(context);
        setUpOfferItems(context);
        setUpConsiderationItems(context);
    }

    /**
     * @dev Amend the order state.
     *
     * @param context A Fuzz test context.
     */
    function amendOrderState(FuzzTestContext memory context) internal {
        conformOnChainStatusToExpected(context);
    }

    /**
     * @dev Register checks for the test.
     *
     * @param context A Fuzz test context.
     */
    function runCheckRegistration(FuzzTestContext memory context) internal {
        registerExpectedEventsAndBalances(context);
        registerCommonChecks(context);
        registerFunctionSpecificChecks(context);
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

        // Get the action to execute.  The action is derived from the fuzz seed,
        // so it will be the same for each run of the test throughout the entire
        // lifecycle of the test.
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
     *      post-execution FuzzTestContext and can use it to make test
     *      assertions.
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
