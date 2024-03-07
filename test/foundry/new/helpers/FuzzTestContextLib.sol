// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { StdCheats } from "forge-std/StdCheats.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    AdvancedOrderLib,
    BasicOrderParametersLib,
    MatchComponent
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType, Side } from "seaport-sol/src/SeaportEnums.sol";

import {
    BroadOrderType,
    OrderStatusEnum,
    SignatureMethod,
    UnavailableReason
} from "seaport-sol/src/SpaceEnums.sol";

import { AdvancedOrdersSpace } from "seaport-sol/src/StructSpace.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    AmountDeriverHelper
} from "seaport-sol/src/lib/fulfillment/AmountDeriverHelper.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { Result } from "./FuzzHelpers.sol";

import { ExpectedBalances } from "./ExpectedBalances.sol";

import { CriteriaResolverHelper } from "./CriteriaResolverHelper.sol";

import {
    FuzzGeneratorContext,
    FuzzGeneratorContextLib
} from "./FuzzGeneratorContextLib.sol";

import { TestStateGenerator } from "./FuzzGenerators.sol";

import { Failure } from "./FuzzMutationSelectorLib.sol";

import { FractionResults } from "./FractionUtil.sol";

import {
    ErrorsAndWarnings,
    SeaportValidatorInterface
} from "../../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    SeaportNavigatorInterface
} from "../../../../contracts/helpers/navigator/SeaportNavigator.sol";

interface TestHelpers {
    function balanceChecker() external view returns (ExpectedBalances);

    function amountDeriverHelper() external view returns (AmountDeriverHelper);

    function criteriaResolverHelper()
        external
        view
        returns (CriteriaResolverHelper);

    function makeAccountWrapper(
        string memory name
    ) external view returns (StdCheats.Account memory);

    function getNaiveFulfillmentComponents(
        OrderDetails[] memory orderDetails
    )
        external
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        );

    function getMatchedFulfillments(
        AdvancedOrder[] memory orders,
        CriteriaResolver[] memory resolvers
    )
        external
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents,
            MatchComponent[] memory remainingConsiderationComponents
        );

    function getMatchedFulfillments(
        OrderDetails[] memory orders
    )
        external
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents,
            MatchComponent[] memory remainingConsiderationComponents
        );

    function allocateTokensAndApprovals(address _to, uint128 _amount) external;
}

struct FuzzParams {
    uint256 seed;
    uint256 totalOrders;
    uint256 maxOfferItems;
    uint256 maxConsiderationItems;
    bytes seedInput;
}

struct ReturnValues {
    bool fulfilled;
    bool cancelled;
    bool validated;
    bool[] availableOrders;
    Execution[] executions;
}

/**
 * @dev Context data related to post-execution expectations.
 */
struct Expectations {
    /**
     * @dev Expected zone calldata hashes.
     */
    bytes32[] expectedZoneAuthorizeCalldataHashes;
    bytes32[] expectedZoneValidateCalldataHashes;
    /**
     * @dev Expected contract order calldata hashes. Index 0 of the outer array
     *      corresponds to the generateOrder hash, while index 1 corresponds to
     *      the ratifyOrder hash.
     */
    bytes32[2][] expectedContractOrderCalldataHashes;
    /**
     * @dev Expected Result state for each order. Indexes correspond to the
     *      indexes of the orders in the orders array.
     */
    Result[] expectedResults;
    /**
     * @dev Expected executions.  Implicit means it doesn't correspond directly
     *      with a fulfillment that was passed in.
     */
    Execution[] expectedImplicitPreExecutions;
    Execution[] expectedImplicitPostExecutions;
    Execution[] expectedExplicitExecutions;
    Execution[] allExpectedExecutions;
    // /**
    //  * @dev Whether an order is available and will be fulfilled. Indexes
    //  *      correspond to order indexes in the orders array.
    //  */
    // bool[] expectedAvailableOrders;
    /**
     * @dev Expected event hashes. Encompasses all events that match watched
     *      topic0s.
     */
    bytes32[] expectedTransferEventHashes;
    /**
     * @dev Expected event hashes. Encompasses all events that match watched
     *      topic0s.
     */
    bytes32[] expectedSeaportEventHashes;
    bool[] ineligibleOrders;
    bool[] ineligibleFailures;
    /**
     * @dev Number of expected implicit native executions.
     */
    uint256 expectedImpliedNativeExecutions;
    /**
     * @dev Amount of native tokens we expect to be returned to the caller.
     */
    uint256 expectedNativeTokensReturned;
    /**
     * @dev Minimum msg.value that must be provided by caller.
     */
    uint256 minimumValue;
    FractionResults[] expectedFillFractions;
}

/**
 * @dev Context data related to test execution
 */
struct ExecutionState {
    /**
     * @dev A caller address. If this is nonzero, the FuzzEngine will prank this
     *      address before calling exec.
     */
    address caller;
    uint256 contractOffererNonce;
    /**
     * @dev A recipient address to be passed into fulfillAdvancedOrder,
     *      fulfillAvailableAdvancedOrders, or matchAdvancedOrders. Speciying a
     *      recipient on the fulfill functions will set that address as the
     *      recipient for all received items.  Specifying a recipient on the
     *      match function will set that address as the recipient for all
     *      unspent offer item amounts.
     */
    address recipient;
    /**
     * @dev A counter that can be incremented to cancel all orders made with
     *      the same counter value.
     */
    uint256 counter;
    /**
     * @dev Indicates what conduit, if any, to check for token approvals. A zero
     *      value means no conduit, look to seaport itself.
     */
    bytes32 fulfillerConduitKey;
    /**
     * @dev A struct containing basic order parameters that are used in the
     *      fulfillBasic functions.
     */
    BasicOrderParameters basicOrderParameters;
    /**
     * @dev An array of AdvancedOrders
     */
    AdvancedOrder[] orders;
    OrderDetails[] orderDetails;
    /**
     * @dev A copy of the original orders array. Modify this when calling
     *      previewOrder on contract orders and use it to derive order
     *      details (which is used to derive fulfillments and executions).
     */
    AdvancedOrder[] previewedOrders;
    /**
     * @dev An array of CriteriaResolvers. These allow specification of an
     *      order, offer or consideration, an identifier, and a proof.  They
     *      enable trait offer and collection offers, etc.
     */
    CriteriaResolver[] criteriaResolvers;
    /**
     * @dev An array of Fulfillments. These are used in the match functions to
     *      point offers and considerations to one another.
     */
    Fulfillment[] fulfillments;
    /**
     * @dev offer components not explicitly supplied in match fulfillments.
     */
    FulfillmentComponent[] remainingOfferComponents;
    bool hasRemainders;
    /**
     * @dev An array of FulfillmentComponents. These are used in the
     *      fulfillAvailable functions to set up aggregations.
     */
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    /**
     * @dev The maximum number of fulfillments to attempt in the
     *      fulfillAvailable functions.
     */
    uint256 maximumFulfilled;
    /**
     * @dev Status of each order before execution.
     */
    OrderStatusEnum[] preExecOrderStatuses;
    uint256 value;
    /**
     * @dev ErrorsAndWarnings returned from SeaportValidator.
     */
    ErrorsAndWarnings[] validationErrors;
}

/**
 * @dev Context data related to failure mutations.
 */
struct MutationState {
    /**
     * @dev Copy of the order selected for mutation.
     */
    AdvancedOrder selectedOrder;
    /**
     * @dev Index of the selected order in the orders array.
     */
    uint256 selectedOrderIndex;
    bytes32 selectedOrderHash;
    Side side;
    CriteriaResolver selectedCriteriaResolver;
    uint256 selectedCriteriaResolverIndex;
    address selectedArbitraryAddress;
}

struct FuzzTestContext {
    /**
     * @dev Cached selector of the chosen Seaport action.
     */
    bytes4 _action;
    /**
     * @dev Whether a Seaport action has been selected. This boolean is used as
     *      a workaround to detect when the cached action is set, since the
     *      empty selector is a valid Seaport action (fulfill basic efficient).
     */
    bool actionSelected;
    /**
     * @dev A Seaport interface, either the reference or optimized version.
     */
    SeaportInterface seaport;
    /**
     * @dev A ConduitController interface.
     */
    ConduitControllerInterface conduitController;
    /**
     * @dev A SeaportValidator interface.
     */
    SeaportValidatorInterface seaportValidator;
    /**
     * @dev A SeaportNavigator interface.
     */
    SeaportNavigatorInterface seaportNavigator;
    /**
     * @dev A TestHelpers interface. These helper functions are used to generate
     *      accounts and fulfillments.
     */
    TestHelpers testHelpers;
    /**
     * @dev A struct containing fuzzed params generated by the Foundry fuzzer.
     */
    FuzzParams fuzzParams;
    /**
     * @dev A struct containing the state for the execution phase.
     */
    ExecutionState executionState;
    /**
     * @dev Return values from the last call to exec. Superset of return values
     *      from all Seaport functions.
     */
    ReturnValues returnValues;
    /**
     * @dev Actual events emitted.
     */
    Vm.Log[] actualEvents;
    /**
     * @dev A struct containing expectations for the test. These are used to
     *      make assertions about the resulting test state.
     */
    Expectations expectations;
    /**
     * @dev An array of function selectors for "checks". The FuzzEngine will
     *      call these functions after calling exec to make assertions about
     *      the resulting test state.
     */
    bytes4[] checks;
    /**
     * @dev A struct containing the context for the FuzzGenerator. This is used
     *      upstream to generate the order state and is included here for use
     *      and reference throughout the rest of the lifecycle.
     */
    FuzzGeneratorContext generatorContext;
    /**
     * @dev The AdvancedOrdersSpace used to generate the orders. A nested struct
     *      of enums defining the selected permutation of orders.
     */
    AdvancedOrdersSpace advancedOrdersSpace;
}

/**
 * @notice Builder library for FuzzTestContext.
 */
library FuzzTestContextLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using BasicOrderParametersLib for BasicOrderParameters;
    using FuzzTestContextLib for FuzzTestContext;
    using LibPRNG for LibPRNG.PRNG;
    using FuzzGeneratorContextLib for FuzzGeneratorContext;

    /**
     * @dev Create an empty FuzzTestContext.
     *
     * @custom:return emptyContext the empty FuzzTestContext
     */
    function empty() internal returns (FuzzTestContext memory) {
        AdvancedOrder[] memory orders;
        CriteriaResolver[] memory resolvers;
        Fulfillment[] memory fulfillments;
        FulfillmentComponent[] memory components;
        FulfillmentComponent[][] memory componentsArray;
        Result[] memory results;
        bool[] memory available;
        Execution[] memory executions;
        Vm.Log[] memory actualEvents;
        Expectations memory expectations;

        {
            bytes32[] memory authorizeHashes;
            bytes32[] memory validateHashes;
            bytes32[] memory expectedTransferEventHashes;
            bytes32[] memory expectedSeaportEventHashes;

            expectations = Expectations({
                expectedZoneAuthorizeCalldataHashes: authorizeHashes,
                expectedZoneValidateCalldataHashes: validateHashes,
                expectedContractOrderCalldataHashes: new bytes32[2][](0),
                expectedImplicitPreExecutions: new Execution[](0),
                expectedImplicitPostExecutions: new Execution[](0),
                expectedExplicitExecutions: new Execution[](0),
                allExpectedExecutions: new Execution[](0),
                expectedResults: results,
                // expectedAvailableOrders: new bool[](0),
                expectedTransferEventHashes: expectedTransferEventHashes,
                expectedSeaportEventHashes: expectedSeaportEventHashes,
                ineligibleOrders: new bool[](orders.length),
                ineligibleFailures: new bool[](uint256(Failure.length)),
                expectedImpliedNativeExecutions: 0,
                expectedNativeTokensReturned: 0,
                minimumValue: 0,
                expectedFillFractions: new FractionResults[](orders.length)
            });
        }

        return
            FuzzTestContext({
                _action: bytes4(0),
                actionSelected: false,
                seaport: SeaportInterface(address(0)),
                conduitController: ConduitControllerInterface(address(0)),
                seaportValidator: SeaportValidatorInterface(address(0)),
                seaportNavigator: SeaportNavigatorInterface(address(0)),
                fuzzParams: FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0,
                    seedInput: ""
                }),
                checks: new bytes4[](0),
                returnValues: ReturnValues({
                    fulfilled: false,
                    cancelled: false,
                    validated: false,
                    availableOrders: available,
                    executions: executions
                }),
                expectations: expectations,
                executionState: ExecutionState({
                    caller: address(0),
                    contractOffererNonce: 0,
                    recipient: address(0),
                    counter: 0,
                    fulfillerConduitKey: bytes32(0),
                    basicOrderParameters: BasicOrderParametersLib.empty(),
                    preExecOrderStatuses: new OrderStatusEnum[](0),
                    previewedOrders: orders,
                    orders: orders,
                    orderDetails: new OrderDetails[](0),
                    criteriaResolvers: resolvers,
                    fulfillments: fulfillments,
                    remainingOfferComponents: components,
                    hasRemainders: false,
                    offerFulfillments: componentsArray,
                    considerationFulfillments: componentsArray,
                    maximumFulfilled: 0,
                    value: 0,
                    validationErrors: new ErrorsAndWarnings[](orders.length)
                }),
                actualEvents: actualEvents,
                testHelpers: TestHelpers(address(this)),
                generatorContext: FuzzGeneratorContextLib.empty(),
                advancedOrdersSpace: TestStateGenerator.empty()
            });
    }

    /**
     * @dev Create a FuzzTestContext from the given partial arguments.
     *
     * @param orders the AdvancedOrder[] to set
     * @param seaport the SeaportInterface to set
     * @param caller the caller address to set
     * @custom:return _context the FuzzTestContext
     */
    function from(
        AdvancedOrder[] memory orders,
        SeaportInterface seaport,
        address caller
    ) internal returns (FuzzTestContext memory) {
        return
            empty()
                .withOrders(orders)
                .withSeaport(seaport)
                .withOrderHashes()
                .withCaller(caller)
                .withPreviewedOrders(orders.copy())
                .withProvisionedIneligbleOrdersArray();
    }

    /**
     * @dev Create a FuzzTestContext from the given partial arguments.
     *
     * @param orders the AdvancedOrder[] to set
     * @param seaport the SeaportInterface to set
     * @custom:return _context the FuzzTestContext
     */
    function from(
        AdvancedOrder[] memory orders,
        SeaportInterface seaport
    ) internal returns (FuzzTestContext memory) {
        return
            empty()
                .withOrders(orders)
                .withSeaport(seaport)
                .withOrderHashes()
                .withPreviewedOrders(orders.copy())
                .withProvisionedIneligbleOrdersArray();
    }

    /**
     * @dev Sets the orders on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the orders of
     * @param orders the AdvancedOrder[] to set
     *
     * @return _context the FuzzTestContext with the orders set
     */
    function withOrders(
        FuzzTestContext memory context,
        AdvancedOrder[] memory orders
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.orders = orders.copy();

        // Bootstrap with all available to ease direct testing.
        if (context.executionState.orderDetails.length == 0) {
            context.executionState.orderDetails = new OrderDetails[](
                orders.length
            );
            context.executionState.validationErrors = new ErrorsAndWarnings[](
                orders.length
            );
            for (uint256 i = 0; i < orders.length; ++i) {
                context
                    .executionState
                    .orderDetails[i]
                    .unavailableReason = UnavailableReason.AVAILABLE;
            }
        }

        context.expectations.expectedFillFractions = (
            new FractionResults[](orders.length)
        );

        return context;
    }

    // NOTE: expects context.executionState.orders and context.seaport to
    //       already be set.
    function withOrderHashes(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        bytes32[] memory orderHashes = context
            .executionState
            .orders
            .getOrderHashes(address(context.seaport));

        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            context.executionState.orderDetails[i].orderHash = orderHashes[i];
        }

        return context;
    }

    function withPreviewedOrders(
        FuzzTestContext memory context,
        AdvancedOrder[] memory orders
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.previewedOrders = orders.copy();
        return context;
    }

    function withProvisionedIneligbleOrdersArray(
        FuzzTestContext memory context
    ) internal pure returns (FuzzTestContext memory) {
        context.expectations.ineligibleOrders = new bool[](
            context.executionState.orders.length
        );
        return context;
    }

    /**
     * @dev Sets the SeaportInterface on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the SeaportInterface of
     * @param seaport the SeaportInterface to set
     *
     * @return _context the FuzzTestContext with the SeaportInterface set
     */
    function withSeaport(
        FuzzTestContext memory context,
        SeaportInterface seaport
    ) internal pure returns (FuzzTestContext memory) {
        context.seaport = seaport;
        return context;
    }

    /**
     * @dev Sets the ConduitControllerInterface on a FuzzTestContext
     *
     * @param context           the FuzzTestContext to set the
     *                          ConduitControllerInterface of
     * @param conduitController the ConduitControllerInterface to set
     *
     * @return _context the FuzzTestContext with the ConduitControllerInterface
     *                  set
     */
    function withConduitController(
        FuzzTestContext memory context,
        ConduitControllerInterface conduitController
    ) internal pure returns (FuzzTestContext memory) {
        context.conduitController = conduitController;
        return context;
    }

    /**
     * @dev Sets the SeaportValidatorInterface on a FuzzTestContext
     *
     * @param context           the FuzzTestContext to set the
     *                          SeaportValidatorInterface of
     * @param seaportValidator  the SeaportValidatorInterface to set
     *
     * @return _context the FuzzTestContext with the SeaportValidatorInterface
     *                  set
     */
    function withSeaportValidator(
        FuzzTestContext memory context,
        SeaportValidatorInterface seaportValidator
    ) internal pure returns (FuzzTestContext memory) {
        context.seaportValidator = seaportValidator;
        return context;
    }

    /**
     * @dev Sets the SeaportNavigatorInterface on a FuzzTestContext
     *
     * @param context             the FuzzTestContext to set the
     *                            SeaportNavigatorInterface of
     * @param seaportNavigator  the SeaportNavigatorInterface to set
     *
     * @return _context the FuzzTestContext with the SeaportNavigatorInterface
     *                  set
     */
    function withSeaportNavigator(
        FuzzTestContext memory context,
        SeaportNavigatorInterface seaportNavigator
    ) internal pure returns (FuzzTestContext memory) {
        context.seaportNavigator = seaportNavigator;
        return context;
    }

    /**
     * @dev Sets the caller on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the caller of
     * @param caller the caller address to set
     *
     * @return _context the FuzzTestContext with the caller set
     */
    function withCaller(
        FuzzTestContext memory context,
        address caller
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.caller = caller;
        return context;
    }

    /**
     * @dev Sets the fuzzParams on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the fuzzParams of
     * @param fuzzParams the fuzzParams struct to set
     *
     * @return _context the FuzzTestContext with the fuzzParams set
     */
    function withFuzzParams(
        FuzzTestContext memory context,
        FuzzParams memory fuzzParams
    ) internal pure returns (FuzzTestContext memory) {
        context.fuzzParams = _copyFuzzParams(fuzzParams);
        return context;
    }

    /**
     * @dev Sets the checks on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the checks of
     * @param checks the checks array to set
     *
     * @return _context the FuzzTestContext with the checks set
     */
    function withChecks(
        FuzzTestContext memory context,
        bytes4[] memory checks
    ) internal pure returns (FuzzTestContext memory) {
        context.checks = _copyBytes4(checks);
        return context;
    }

    /**
     * @dev Sets the counter on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the counter of
     * @param counter the counter value to set
     *
     * @return _context the FuzzTestContext with the counter set
     */
    function withCounter(
        FuzzTestContext memory context,
        uint256 counter
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.counter = counter;
        return context;
    }

    /**
     * @dev Sets the counter on a FuzzTestContext
     *
     * @param context              the FuzzTestContext to set the counter of
     * @param contractOffererNonce the cocontractOffererNonceunter value to set
     *
     * @return _context the FuzzTestContext with the counter set
     */
    function withContractOffererNonce(
        FuzzTestContext memory context,
        uint256 contractOffererNonce
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.contractOffererNonce = contractOffererNonce;
        return context;
    }

    function withGeneratorContext(
        FuzzTestContext memory context,
        FuzzGeneratorContext memory generatorContext
    ) internal pure returns (FuzzTestContext memory) {
        context.generatorContext = generatorContext;
        return context;
    }

    function withSpace(
        FuzzTestContext memory context,
        AdvancedOrdersSpace memory space
    ) internal pure returns (FuzzTestContext memory) {
        context.advancedOrdersSpace = space;
        return context;
    }

    /**
     * @dev Sets the fulfillerConduitKey on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the fulfillerConduitKey of
     * @param fulfillerConduitKey the fulfillerConduitKey value to set
     *
     * @return _context the FuzzTestContext with the fulfillerConduitKey set
     */
    function withFulfillerConduitKey(
        FuzzTestContext memory context,
        bytes32 fulfillerConduitKey
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.fulfillerConduitKey = fulfillerConduitKey;
        return context;
    }

    /**
     * @dev Sets the criteriaResolvers on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the criteriaResolvers of
     * @param criteriaResolvers the criteriaResolvers array to set
     *
     * @return _context the FuzzTestContext with the criteriaResolvers set
     */
    function withCriteriaResolvers(
        FuzzTestContext memory context,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.criteriaResolvers = _copyCriteriaResolvers(
            criteriaResolvers
        );
        return context;
    }

    /**
     * @dev Sets the recipient on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the recipient of
     * @param recipient the recipient value to set
     *
     * @return _context the FuzzTestContext with the recipient set
     */
    function withRecipient(
        FuzzTestContext memory context,
        address recipient
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.recipient = recipient;
        return context;
    }

    /**
     * @dev Sets the fulfillments on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the fulfillments of
     * @param fulfillments the offerFulfillments value to set
     *
     * @return _context the FuzzTestContext with the fulfillments set
     */
    function withFulfillments(
        FuzzTestContext memory context,
        Fulfillment[] memory fulfillments
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.fulfillments = fulfillments;
        return context;
    }

    /**
     * @dev Sets the offerFulfillments on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the offerFulfillments of
     * @param offerFulfillments the offerFulfillments value to set
     *
     * @return _context the FuzzTestContext with the offerFulfillments set
     */
    function withOfferFulfillments(
        FuzzTestContext memory context,
        FulfillmentComponent[][] memory offerFulfillments
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.offerFulfillments = _copyFulfillmentComponents(
            offerFulfillments
        );
        return context;
    }

    /**
     * @dev Sets the considerationFulfillments on a FuzzTestContext
     *
     * @param context                   the FuzzTestContext to set the
     *                                  considerationFulfillments of
     * @param considerationFulfillments the considerationFulfillments value to
     *                                  set
     *
     * @return _context the FuzzTestContext with the considerationFulfillments
     *                  set
     */
    function withConsiderationFulfillments(
        FuzzTestContext memory context,
        FulfillmentComponent[][] memory considerationFulfillments
    ) internal pure returns (FuzzTestContext memory) {
        context
            .executionState
            .considerationFulfillments = _copyFulfillmentComponents(
            considerationFulfillments
        );
        return context;
    }

    /**
     * @dev Sets the maximumFulfilled on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the maximumFulfilled of
     * @param maximumFulfilled the maximumFulfilled value to set
     *
     * @return _context the FuzzTestContext with maximumFulfilled set
     */
    function withMaximumFulfilled(
        FuzzTestContext memory context,
        uint256 maximumFulfilled
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.maximumFulfilled = maximumFulfilled;
        return context;
    }

    /**
     * @dev Sets the basicOrderParameters on a FuzzTestContext
     *
     * @param context the FuzzTestContext to set the fulfillments of
     * @param basicOrderParameters the offerFulfillments value to set
     *
     * @return _context the FuzzTestContext with the fulfillments set
     */
    function withBasicOrderParameters(
        FuzzTestContext memory context,
        BasicOrderParameters memory basicOrderParameters
    ) internal pure returns (FuzzTestContext memory) {
        context.executionState.basicOrderParameters = basicOrderParameters;
        return context;
    }

    /**
     * @dev Sets a pseudorandom OrderStatus for each order on a FuzzTestContext.
     *      The preExecOrderStatuses are indexed to orders.
     *
     *
     * @param context the FuzzTestContext to set the preExecOrderStatuses of
     *
     * @return _context the FuzzTestContext with the preExecOrderStatuses set
     */
    function withPreExecOrderStatuses(
        FuzzTestContext memory context,
        AdvancedOrdersSpace memory space
    ) internal pure returns (FuzzTestContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed);

        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](
            context.executionState.orders.length
        );

        for (uint256 i = 0; i < context.executionState.orders.length; i++) {
            if (space.orders[i].orderType == BroadOrderType.CONTRACT) {
                if (
                    space.orders[i].unavailableReason ==
                    UnavailableReason.GENERATE_ORDER_FAILURE
                ) {
                    context.executionState.preExecOrderStatuses[
                        i
                    ] = OrderStatusEnum.REVERT;
                } else {
                    context.executionState.preExecOrderStatuses[
                        i
                    ] = OrderStatusEnum.AVAILABLE;
                }
            } else if (
                space.orders[i].unavailableReason == UnavailableReason.CANCELLED
            ) {
                // TODO: support cases where order is both cancelled and has
                // been partially fulfilled.
                context.executionState.preExecOrderStatuses[i] = OrderStatusEnum
                    .CANCELLED_EXPLICIT;
            } else if (
                space.orders[i].unavailableReason ==
                UnavailableReason.ALREADY_FULFILLED
            ) {
                context.executionState.preExecOrderStatuses[i] = OrderStatusEnum
                    .FULFILLED;
            } else if (
                space.orders[i].signatureMethod == SignatureMethod.VALIDATE
            ) {
                // NOTE: this assumes that the order has not been partially
                // filled (partially filled orders are de-facto validated).
                context.executionState.preExecOrderStatuses[i] = OrderStatusEnum
                    .VALIDATED;
            } else {
                if (
                    space.orders[i].unavailableReason ==
                    UnavailableReason.GENERATE_ORDER_FAILURE
                ) {
                    revert(
                        "FuzzTestContextLib: bad location for generate order failure"
                    );
                }

                OrderType orderType = (
                    context.executionState.orders[i].parameters.orderType
                );

                // TODO: figure out a way to do this for orders with 721 items
                OrderParameters memory orderParams = (
                    context.executionState.orders[i].parameters
                );

                bool has721 = false;
                for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                    if (
                        orderParams.offer[j].itemType == ItemType.ERC721 ||
                        orderParams.offer[j].itemType ==
                        ItemType.ERC721_WITH_CRITERIA
                    ) {
                        has721 = true;
                        break;
                    }
                }

                if (!has721) {
                    for (
                        uint256 j = 0;
                        j < orderParams.consideration.length;
                        ++j
                    ) {
                        if (
                            orderParams.consideration[j].itemType ==
                            ItemType.ERC721 ||
                            orderParams.consideration[j].itemType ==
                            ItemType.ERC721_WITH_CRITERIA
                        ) {
                            has721 = true;
                            break;
                        }
                    }
                }

                uint256 upperBound = (!has721 &&
                    (orderType == OrderType.PARTIAL_OPEN ||
                        orderType == OrderType.PARTIAL_RESTRICTED))
                    ? 2
                    : 1;

                context.executionState.preExecOrderStatuses[
                    i
                ] = OrderStatusEnum(uint8(bound(prng.next(), 0, upperBound)));
            }
        }

        return context;
    }

    function _copyBytes4(
        bytes4[] memory selectors
    ) private pure returns (bytes4[] memory) {
        bytes4[] memory copy = new bytes4[](selectors.length);
        for (uint256 i = 0; i < selectors.length; i++) {
            copy[i] = selectors[i];
        }
        return copy;
    }

    function _copyFulfillmentComponents(
        FulfillmentComponent[][] memory fulfillmentComponents
    ) private pure returns (FulfillmentComponent[][] memory) {
        FulfillmentComponent[][]
            memory outerCopy = new FulfillmentComponent[][](
                fulfillmentComponents.length
            );
        for (uint256 i = 0; i < fulfillmentComponents.length; i++) {
            FulfillmentComponent[]
                memory innerCopy = new FulfillmentComponent[](
                    fulfillmentComponents[i].length
                );
            for (uint256 j = 0; j < fulfillmentComponents[i].length; j++) {
                innerCopy[j] = fulfillmentComponents[i][j];
            }
            outerCopy[i] = innerCopy;
        }
        return outerCopy;
    }

    function _copyCriteriaResolvers(
        CriteriaResolver[] memory criteriaResolvers
    ) private pure returns (CriteriaResolver[] memory) {
        CriteriaResolver[] memory copy = new CriteriaResolver[](
            criteriaResolvers.length
        );
        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            copy[i] = criteriaResolvers[i];
        }
        return copy;
    }

    function _copyFuzzParams(
        FuzzParams memory params
    ) private pure returns (FuzzParams memory) {
        return
            FuzzParams({
                seed: params.seed,
                totalOrders: params.totalOrders,
                maxOfferItems: params.maxOfferItems,
                maxConsiderationItems: params.maxConsiderationItems,
                seedInput: bytes.concat(params.seedInput)
            });
    }
}

// @dev Implementation cribbed from forge-std bound
function bound(
    uint256 x,
    uint256 min,
    uint256 max
) pure returns (uint256 result) {
    require(min <= max, "Max is less than min.");
    // If x is between min and max, return x directly. This is to ensure that
    // dictionary values do not get shifted if the min is nonzero.
    if (x >= min && x <= max) return x;

    uint256 size = max - min + 1;

    // If the value is 0, 1, 2, 3, warp that to min, min+1, min+2, min+3.
    // Similarly for the UINT256_MAX side. This helps ensure coverage of the
    // min/max values.
    if (x <= 3 && size > x) return min + x;
    if (x >= type(uint256).max - 3 && size > type(uint256).max - x) {
        return max - (type(uint256).max - x);
    }

    // Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
    if (x > max) {
        uint256 diff = x - max;
        uint256 rem = diff % size;
        if (rem == 0) return max;
        result = min + rem - 1;
    } else if (x < min) {
        uint256 diff = min - x;
        uint256 rem = diff % size;
        if (rem == 0) return min;
        result = max - rem + 1;
    }
}
