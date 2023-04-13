// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { dumpExecutions } from "./DebugUtil.sol";

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
    FuzzParams,
    MutationState
} from "./FuzzTestContextLib.sol";

import {
    AdvancedOrdersSpace,
    AdvancedOrdersSpaceGenerator,
    TestStateGenerator
} from "./FuzzGenerators.sol";

import { FuzzAmendments } from "./FuzzAmendments.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzDerivers } from "./FuzzDerivers.sol";

import { FuzzExecutor } from "./FuzzExecutor.sol";

import { FuzzMutations } from "./FuzzMutations.sol";

import { FuzzMutationSelectorLib } from "./FuzzMutationSelectorLib.sol";

import { OrderEligibilityLib } from "./FuzzMutationHelpers.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers, Structure } from "./FuzzHelpers.sol";

import { CheckHelpers, FuzzSetup } from "./FuzzSetup.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

import "forge-std/console.sol";

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
    FuzzSetup,
    FuzzExecutor,
    FulfillAvailableHelper,
    MatchFulfillmentHelper
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
    using FuzzDerivers for FuzzTestContext;
    using FuzzMutationSelectorLib for FuzzTestContext;

    Vm.Log[] internal _logs;
    FuzzMutations internal mutations;

    function setLogs(Vm.Log[] memory logs) external {
        delete _logs;
        for (uint256 i = 0; i < logs.length; ++i) {
            _logs.push(logs[i]);
        }
    }

    function getLogs() external view returns (Vm.Log[] memory logs) {
        logs = new Vm.Log[](_logs.length);
        for (uint256 i = 0; i < _logs.length; ++i) {
            logs[i] = _logs[i];
        }
    }

    function setUp() public virtual override {
        super.setUp();
        mutations = new FuzzMutations();
    }

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
        execFailure(context);
        execSuccess(context);
        checkAll(context);
    }

    function execSuccess(FuzzTestContext memory context) internal {
        ExpectedEventsUtil.startRecordingLogs();
        exec(context, true);
    }

    /**
     * @dev Generate a randomized `FuzzTestContext` from fuzz parameters.
     *
     * @param fuzzParams A FuzzParams struct containing fuzzed values.
     */
    function generate(
        FuzzParams memory fuzzParams
    ) internal returns (FuzzTestContext memory) {
        // JAN_1_2023_UTC
        vm.warp(1672531200);

        // Get the conduit controller, which allows dpeloying and managing
        // conduits.  Conduits are used to transfer tokens between accounts.
        ConduitControllerInterface conduitController_ = getConduitController();

        // Set up a default FuzzGeneratorContext.  Note that this is only used
        // for the generation pphase.  The `FuzzTestContext` is used throughout
        // the rest of the lifecycle.
        FuzzGeneratorContext memory generatorContext = FuzzGeneratorContextLib
            .from({
                vm: vm,
                seaport: getSeaport(),
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

        generatorContext.caller = AdvancedOrdersSpaceGenerator.generateCaller(
            space,
            generatorContext
        );

        // Generate orders from the space. These are the actual orders that will
        // be used in the test.
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            generatorContext
        );

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: getSeaport() })
            .withConduitController(conduitController_)
            .withFuzzParams(fuzzParams)
            .withMaximumFulfilled(space.maximumFulfilled)
            .withPreExecOrderStatuses(space)
            .withCounter(generatorContext.counter)
            .withContractOffererNonce(generatorContext.contractOffererNonce);

        // Generate and add a top-level fulfiller conduit key to the context.
        // This is on a separate line to avoid stack too deep.
        context = context
            .withCaller(generatorContext.caller)
            .withFulfillerConduitKey(
                AdvancedOrdersSpaceGenerator.generateFulfillerConduitKey(
                    space,
                    generatorContext
                )
            )
            .withGeneratorContext(generatorContext)
            .withSpace(space);

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
     *      4. deriveOrderDetails: calculate order details and add them to the
     *         test context.
     *      5. deriveExecutions: calculate expected implicit/explicit executions
     *         and add them to the test context.
     *
     * @param context A Fuzz test context.
     */
    function runDerivers(FuzzTestContext memory context) internal {
        context = context
            .withDerivedAvailableOrders()
            .withDerivedCriteriaResolvers()
            .withDetectedRemainders()
            .withDerivedOrderDetails()
            .withDerivedFulfillments()
            .withDerivedCallValue()
            .withDerivedExecutions()
            .withDerivedOrderDetails();
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
        // Redundant for now, because the counter and nonce are set in the
        // generation phase.
        setCounter(context);
        setContractOffererNonce(context);
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

    function execFailure(FuzzTestContext memory context) internal {
        (
            string memory name,
            bytes4 mutationSelector,
            bytes memory expectedRevertReason,
            MutationState memory mutationState
        ) = context.selectMutation();

        context.mutationState = mutationState;

        console.log("topmost orderIndex", context.mutationState.selectedOrderIndex);
        console.logBytes(abi.encodePacked(mutationSelector));

        logMutation(name);

        // TODO: here for debugging
        if (address(mutations).code.length == 0) {
            revert("WTF");
        }

        bytes memory callData = abi.encodeWithSelector(mutationSelector, context);
        (bool success, bytes memory data) = address(mutations).call(callData);

        assertFalse(
            success,
            string.concat("Mutation ", name, " did not revert")
        );

        if (
            data.length == 4 &&
            abi.decode(abi.encodePacked(data, uint224(0)), (bytes4)) ==
            OrderEligibilityLib.NoEligibleOrderFound.selector
        ) {
            assertTrue(
                false,
                string.concat(
                    "No eligible order found to apply failure '",
                    name,
                    "'"
                )
            );
        }

        assertEq(
            data,
            expectedRevertReason,
            string.concat(
                "Mutation ",
                name,
                " did not revert with the expected reason"
            )
        );

        if (keccak256(data) != keccak256(expectedRevertReason)) {
            revert("TEMP EXPECTED REVERT BREAKPOINT");
        }
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

    function logMutation(string memory mutationName) internal {
        if (vm.envOr("SEAPORT_COLLECT_FUZZ_METRICS", false)) {
            string memory metric = string.concat(mutationName, ":1|c");
            vm.writeLine("mutation-metrics.txt", metric);
        }
    }
}
