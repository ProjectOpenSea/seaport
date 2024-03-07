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
    OrderParametersLib,
    OfferItem,
    ConsiderationItem,
    ItemType,
    OrderType
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    Execution,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import { BaseOrderTest } from "../BaseOrderTest.sol";
import { SeaportValidatorTest } from "../SeaportValidatorTest.sol";
import { SeaportNavigatorTest } from "../SeaportNavigatorTest.sol";

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

import { MutationEligibilityLib } from "./FuzzMutationHelpers.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers, Structure } from "./FuzzHelpers.sol";

import { CheckHelpers, FuzzSetup } from "./FuzzSetup.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

import { logMutation } from "./Metrics.sol";

import {
    ErrorsAndWarnings,
    ValidationConfiguration
} from "../../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    IssueStringHelpers
} from "../../../../contracts/helpers/order-validator/lib/SeaportValidatorTypes.sol";

import {
    NavigatorRequest
} from "../../../../contracts/helpers/navigator/lib/SeaportNavigatorTypes.sol";

import {
    NavigatorAdvancedOrderLib
} from "../../../../contracts/helpers/navigator/lib/NavigatorAdvancedOrderLib.sol";

import {
    FulfillmentStrategy,
    AggregationStrategy,
    FulfillAvailableStrategy,
    MatchStrategy
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

/**
 * @notice Base test contract for FuzzEngine. Fuzz tests should inherit this.
 *         Includes the setup and helper functions from BaseOrderTest.
 *
 *         The BaseOrderTest used in this fuzz engine is not the same as the
 *         BaseOrderTest contract used in the legacy tests.  The relative path
 *         for the relevant version is `test/foundry/new/BaseOrderTest.sol`.
 *
 *         Running test_fuzz_generateOrders in FuzzMain triggers the following
 *         lifecycle:
 *
 *         1. Generation - `generate`
 *         First, the engine generates a  pseudorandom `FuzzTestContext` from
 *         the randomized `FuzzParams`. See `FuzzGenerators.sol` for the helper
 *         libraries used to construct orders from the Seaport state space.
 *
 *         The `generate` function in this file calls out to the `generate`
 *         functions in `TestStateGenerator` (responsible for setting up the
 *         order components) and `AdvancedOrdersSpaceGenerator` (responsible for
 *         setting up the orders and actions). The generation phase relies on a
 *         `FuzzGeneratorContext` internally, but it returns a `FuzzTestContext`
 *         struct, which is used throughout the rest of the lifecycle.
 *
 *         2. Amendment - `amendOrderState`
 *         Next, the engine runs "amendments," which mutate the state of the
 *         orders. See `FuzzAmendments.sol` for the amendment helper library.
 *
 *         The `amendOrderState` function in this file serves as a central
 *         location to slot in calls to functions that amend the state of the
 *         orders.  For example, calling `validate` on an order.
 *
 *         3. Derivation - `runDerivers`
 *         Next up are "derivers," functions that calculate additional values
 *         like fulfillments and executions from the generated orders. See
 *         `FuzzDerivers.sol` for the deriver helper library. Derivers don't
 *         mutate order state, but do add new values to the `FuzzTestContext`.
 *
 *         The `runDerivers` function in this file serves as a central location
 *         to slot in calls to functions that deterministically derive values
 *         from the state that was created in the generation phase.
 *
 *         4. Setup - `runSetup`
 *         This phase sets up any necessary conditions for a test to pass,
 *         including minting test tokens and setting up the required approvals.
 *         The setup phase also detects and registers relevant expectations
 *         to verify after executing the selected Seaport action.
 *
 *         The `runSetup` function should hold everything that mutates test
 *         environment state, such as minting and approving tokens.  It also
 *         contains the logic for setting up the expectations for the
 *         post-execution state of the test. Logic for handling unavailable
 *         orders and balance checking should also live here. Setup phase
 *         helpers are in `FuzzSetup.sol`.
 *
 *         5. Check Registration - `runCheckRegistration`
 *         The `runCheckRegistration` function should hold everything that
 *         registers checks but does not belong naturally elsewhere.  Checks
 *         can be registered throughout the lifecycle, but unless there's a
 *         natural reason to place them inline elsewhere in the lifecycle, they
 *         should go in a helper in `runCheckRegistration`.
 *
 *         6. Execution - `execFailure` and `execSuccess`
 *         The execution phase runs the selected Seaport action and saves the
 *         returned values to the `FuzzTestContext`. See `FuzzExecutor.sol` for
 *         the executor helper contract.
 *
 *         Execution has two phases: `execFailure` and `execSuccess`. For each
 *         generated order, we test both a failure and success case. To test the
 *         failure case, the engine selects and applies a random mutation to the
 *         order and verifies that it reverts with an expected error. We then
 *         proceed to the success case, where we execute a successful call to
 *         Seaport and save return values to the test context.
 *
 *         7. Checks - `checkAll`
 *         Finally, the checks phase runs all registered checks to ensure that
 *         the post-execution state matches all expectations registered during
 *          the setup phase.
 *
 *         The `checkAll` function runs all of the checks that were registered
 *         throughout the test lifecycle. This is where the engine makes actual
 *         assertions about the effects of a specific test, based on the post
 *         execution state. The engine registers different checks during test
 *         setup depending on the order state, like verifying token transfers,
 *         and account balances, expected events, and expected calldata for
 *         contract orders. To add a new check, add a function to `FuzzChecks`
 *         and then register it with `registerCheck`.
 *
 *
 */
contract FuzzEngine is
    BaseOrderTest,
    SeaportValidatorTest,
    SeaportNavigatorTest,
    FuzzAmendments,
    FuzzSetup,
    FuzzChecks,
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

    using IssueStringHelpers for uint16;
    using IssueStringHelpers for uint16[];

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

    function setUp()
        public
        virtual
        override(BaseOrderTest, SeaportValidatorTest)
    {
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
     *      5. execFailure: Mutate orders and call a function expecting failure.
     *      6. execSuccess: Call a Seaport function expecting success.
     *      7. checkAll: Call all registered checks.
     *
     * @param context A Fuzz test context.
     */
    function run(FuzzTestContext memory context) internal {
        amendOrderState(context);
        runDerivers(context);
        runSetup(context);
        runCheckRegistration(context);
        validate(context);
        runNavigator(context);
        execFailure(context);
        execSuccess(context);
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
            fuzzParams.seedInput,
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
            .withSeaportValidator(validator)
            .withSeaportNavigator(navigator)
            .withFuzzParams(fuzzParams)
            .withMaximumFulfilled(space.maximumFulfilled)
            .withPreExecOrderStatuses(space);

        // This is on a separate line to avoid stack too deep.
        context = context
            .withCounter(generatorContext.counter)
            .withContractOffererNonce(generatorContext.contractOffererNonce)
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
     * @dev Amend the order state.
     *
     * @param context A Fuzz test context.
     */
    function amendOrderState(FuzzTestContext memory context) internal {
        setPartialFills(context);
        conformOnChainStatusToExpected(context);
        // Redundant for now, because the counter and nonce are set in the
        // generation phase.
        setCounter(context);
        setContractOffererNonce(context);
        prepareRebates(context);
    }

    /**
     * @dev Perform any "deriver" steps necessary before calling `runSetup`.
     *      Each `withDerived` function calculates a value from the generated
     *      orders and adds it to the test context.
     *
     *      1. withDerivedCriteriaResolvers: calculate criteria resolvers
     *      2. withDerivedOrderDetails: calculate order details
     *      3. withDetectedRemainders: detect and calculate remainders
     *      4. withDerivedFulfillments: calculate expected fulfillments
     *      5. withDerivedCallValue: calculate expected call value
     *      6. withDerivedExecutions: expected implicit/explicit executions
     *      7. withDerivedOrderDetails: calculate order details
     *
     * @param context A Fuzz test context.
     */
    function runDerivers(FuzzTestContext memory context) internal {
        context = context
            .withDerivedCriteriaResolvers()
            .withDerivedOrderDetails()
            .withDetectedRemainders()
            .withDerivedFulfillments()
            .withDerivedCallValue()
            .withDerivedExecutions()
            .withDerivedOrderDetails();
    }

    /**
     * @dev Perform any setup steps necessary before execution
     *
     *      1. setUpZoneParameters: calculate expected zone hashes and set up
     *         zone related checks for restricted orders.
     *      2. setUpContractOfferers: configure test contract offerers.
     *      3. setUpOfferItems: Create and approve offer items for each order.
     *      4. setUpConsiderationItems: Create and approve consideration items
     *         for each order.
     *
     * @param context A Fuzz test context.
     */
    function runSetup(FuzzTestContext memory context) internal {
        setUpZoneParameters(context);
        setUpContractOfferers(context);
        setUpOfferItems(context);
        setUpConsiderationItems(context);
    }

    /**
     * @dev Register additional checks for the test.
     *
     *      1. registerExpectedEventsAndBalances: checks for expected token
     *         transfer events and account balance changes.
     *      2. registerCommonChecks: register common checks applied to all test
     *         cases: expected Seaport events and post-exec order status.
     *      4. registerFunctionSpecificChecks: register additional function
     *         specific checks based on the selected action.
     *
     * @param context A Fuzz test context.
     */
    function runCheckRegistration(FuzzTestContext memory context) internal {
        registerExpectedEventsAndBalances(context);
        registerCommonChecks(context);
        registerFunctionSpecificChecks(context);
    }

    /**
     * @dev Mutate an order, call Seaport, and verify the failure.
     *      `execFailure` is a generative test of its own: the engine selects
     *      a mutation, applies it to the order, calls Seaport, and verifies
     *      that the call reverts as expected.
     *
     *      Mutations, helpers, and expected errors  are defined in
     *      `FuzzMutations.sol`.
     *
     * @param context A Fuzz test context.
     */
    function execFailure(FuzzTestContext memory context) internal {
        (
            string memory name,
            bytes4 mutationSelector,
            bytes memory expectedRevertReason,
            MutationState memory mutationState
        ) = context.selectMutation();

        logMutation(name);

        bytes memory callData = abi.encodeWithSelector(
            mutationSelector,
            context,
            mutationState
        );
        (bool success, bytes memory data) = address(mutations).call(callData);

        assertFalse(
            success,
            string.concat("Mutation ", name, " did not revert")
        );

        if (
            data.length == 4 &&
            abi.decode(abi.encodePacked(data, uint224(0)), (bytes4)) ==
            MutationEligibilityLib.NoEligibleIndexFound.selector
        ) {
            assertTrue(
                false,
                string.concat(
                    "No eligible element index found to apply failure '",
                    name,
                    "'"
                )
            );
        }

        // NOTE: some reverts in the reference contracts do not revert with
        // the same revert reason as the optimized. Consider a more granular
        // approach than this one.
        string memory profile = vm.envOr("MOAT_PROFILE", string("optimized"));
        if (!stringEq(profile, "reference")) {
            assertEq(
                data,
                expectedRevertReason,
                string.concat(
                    "Mutation ",
                    name,
                    " did not revert with the expected reason"
                )
            );
        }
    }

    /**
     * @dev Validate the generated orders using SeaportValidator and save the
     *      validation errors to the test context.
     *
     * @param context A Fuzz test context.
     */
    function validate(FuzzTestContext memory context) internal {
        if (vm.envOr("SEAPORT_FUZZ_VALIDATOR", false)) {
            for (uint256 i; i < context.executionState.orders.length; ++i) {
                Order memory order = context.executionState.orders[i].toOrder();
                context.executionState.validationErrors[i] = context
                    .seaportValidator
                    .isValidOrderWithConfiguration(
                        ValidationConfiguration({
                            seaport: address(context.seaport),
                            primaryFeeRecipient: address(0),
                            primaryFeeBips: 0,
                            checkCreatorFee: false,
                            skipStrictValidation: true,
                            shortOrderDuration: 30 minutes,
                            distantOrderExpiration: 26 weeks
                        }),
                        order
                    );
            }
        }
    }

    /**
     * @dev Call SeaportNavigator.run with generated order.
     *
     * @param context A Fuzz test context.
     */
    function runNavigator(FuzzTestContext memory context) internal {
        if (vm.envOr("SEAPORT_FUZZ_NAVIGATOR", false)) {
            // Skip contract orders, which are not supported by the helper.
            bool isContractOrder;
            for (uint256 i; i < context.executionState.orders.length; i++) {
                if (
                    context.executionState.orders[i].parameters.orderType ==
                    OrderType.CONTRACT
                ) {
                    isContractOrder = true;
                    break;
                }
            }

            if (!isContractOrder) {
                FulfillmentStrategy
                    memory fulfillmentStrategy = FulfillmentStrategy({
                        aggregationStrategy: AggregationStrategy.RANDOM,
                        fulfillAvailableStrategy: FulfillAvailableStrategy
                            .DROP_RANDOM_OFFER,
                        matchStrategy: MatchStrategy.MAX_INCLUSION
                    });
                context.seaportNavigator.prepare(
                    NavigatorRequest({
                        seaport: context.seaport,
                        validator: context.seaportValidator,
                        orders: NavigatorAdvancedOrderLib.fromAdvancedOrders(
                            context.executionState.orders
                        ),
                        caller: context.executionState.caller,
                        nativeTokensSupplied: context.executionState.value,
                        fulfillerConduitKey: context
                            .executionState
                            .fulfillerConduitKey,
                        recipient: context.executionState.recipient,
                        maximumFulfilled: context
                            .executionState
                            .maximumFulfilled,
                        seed: context.fuzzParams.seed,
                        fulfillmentStrategy: fulfillmentStrategy,
                        criteriaResolvers: context
                            .executionState
                            .criteriaResolvers,
                        preferMatch: true
                    })
                );
            }
        }
    }

    /**
     * @dev Call a Seaport function with the generated order, expecting success.
     *
     * @param context A Fuzz test context.
     */
    function execSuccess(FuzzTestContext memory context) internal {
        ExpectedEventsUtil.startRecordingLogs();
        exec(context, true);
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
     *      Shared check functions are defined in `FuzzChecks.sol`.
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
     * @param context A Fuzz test context.
     */
    function checkAll(FuzzTestContext memory context) internal {
        for (uint256 i; i < context.checks.length; ++i) {
            bytes4 selector = context.checks[i];
            check(context, selector);
        }
    }
}
