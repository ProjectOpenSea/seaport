// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { assume } from "./VmUtils.sol";

import {
    AdvancedOrderLib,
    MatchComponent,
    MatchComponentType
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import {
    OrderStatusEnum,
    UnavailableReason
} from "seaport-sol/src/SpaceEnums.sol";

import {
    ExecutionHelper
} from "seaport-sol/src/executions/ExecutionHelper.sol";

import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { CriteriaResolverHelper } from "./CriteriaResolverHelper.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

/**
 *  @dev "Derivers" examine generated orders and calculate additional
 *       information based on the order state, like fulfillments and expected
 *       executions. Derivers run after generators and amendments, but before
 *       setup. Deriver functions should take a `FuzzTestContext` as input and
 *       modify it, adding any additional information that might be necessary
 *       for later steps. Derivers should not modify the order state itself,
 *       only the `FuzzTestContext`.
 */
library FuzzDerivers {
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using FuzzHelpers for AdvancedOrder;
    using MatchComponentType for MatchComponent[];
    using ExecutionHelper for FulfillmentDetails;
    using ExecutionHelper for OrderDetails;
    using FulfillmentDetailsHelper for FuzzTestContext;
    using FulfillmentGeneratorLib for OrderDetails[];

    /**
     * @dev Calculate msg.value from native token amounts in the generated
     *      orders.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedCallValue(
        FuzzTestContext memory context
    ) internal returns (FuzzTestContext memory) {
        (uint256 value, uint256 minimum) = context.getNativeTokensToSupply();

        context.executionState.value = value;
        context.expectations.minimumValue = minimum;

        return context;
    }

    /**
     * @dev Calculate criteria resolvers for the generated orders.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedCriteriaResolvers(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        CriteriaResolverHelper criteriaResolverHelper = context
            .testHelpers
            .criteriaResolverHelper();

        CriteriaResolver[] memory criteriaResolvers = criteriaResolverHelper
            .deriveCriteriaResolvers(context.executionState.orders);

        context.executionState.criteriaResolvers = criteriaResolvers;

        return context;
    }

    /**
     * @dev Calculate OrderDetails for the generated orders.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedOrderDetails(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        UnavailableReason[] memory unavailableReasons = new UnavailableReason[](
            context.advancedOrdersSpace.orders.length
        );

        for (uint256 i; i < context.advancedOrdersSpace.orders.length; ++i) {
            unavailableReasons[i] = context
                .advancedOrdersSpace
                .orders[i]
                .unavailableReason;
        }

        bytes32[] memory orderHashes = context
            .executionState
            .orders
            .getOrderHashes(address(context.seaport));

        OrderDetails[] memory orderDetails = context
            .executionState
            .previewedOrders
            .getOrderDetails(
                context.executionState.criteriaResolvers,
                orderHashes,
                unavailableReasons
            );

        context.executionState.orderDetails = orderDetails;

        uint256 totalAvailable;

        // If it's not actually available, but that fact isn't reflected in the
        // unavailable reason in orderDetails, update orderDetails. This could
        // probably be removed at some point.
        for (uint256 i; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = context
                .executionState
                .orders[i]
                .parameters;
            OrderStatusEnum status = context
                .executionState
                .preExecOrderStatuses[i];

            // The only one of these that should get hit is the max fulfilled
            // branch. The rest are just for safety for now and should be
            // removed at some point.
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
                if (!(block.timestamp < order.endTime)) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason.EXPIRED;
                } else if (!(block.timestamp >= order.startTime)) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason.STARTS_IN_FUTURE;
                } else if (
                    status == OrderStatusEnum.CANCELLED_EXPLICIT ||
                    status == OrderStatusEnum.CANCELLED_COUNTER
                ) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason.CANCELLED;
                } else if (status == OrderStatusEnum.FULFILLED) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason
                        .ALREADY_FULFILLED;
                } else if (status == OrderStatusEnum.REVERT) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason
                        .GENERATE_ORDER_FAILURE;
                } else if (
                    !(totalAvailable < context.executionState.maximumFulfilled)
                ) {
                    context
                        .executionState
                        .orderDetails[i]
                        .unavailableReason = UnavailableReason
                        .MAX_FULFILLED_SATISFIED;
                } else {
                    totalAvailable += 1;
                }
            }
        }

        return context;
    }

    /**
     * @dev Derive the `offerFulfillments` and `considerationFulfillments`
     *      arrays or the `fulfillments` array from the `orders` array.
     *
     * @param context      A Fuzz test context.
     * @param orderDetails The orders after applying criteria resolvers, amounts
     *                     and contract rebates.
     */
    function getDerivedFulfillments(
        FuzzTestContext memory context,
        OrderDetails[] memory orderDetails
    )
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents
        )
    {
        // Note: items do not need corresponding fulfillments for unavailable
        // orders, but generally will be provided as availability is usually
        // unknown at submission time. Consider adding a fuzz condition to
        // supply all or only necessary consideration fulfillment components.
        (
            ,
            offerFulfillments,
            considerationFulfillments,
            fulfillments,
            remainingOfferComponents,

        ) = orderDetails.getFulfillments(
            context.advancedOrdersSpace.strategy,
            context.executionState.caller,
            context.executionState.recipient,
            context.fuzzParams.seed
        );
    }

    /**
     * @dev Derive the `offerFulfillments` and `considerationFulfillments`
     *      arrays or the `fulfillments` array from the `orders` array and set
     *      the values in context.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedFulfillments(
        FuzzTestContext memory context
    ) internal pure returns (FuzzTestContext memory) {
        // Derive the required fulfillment arrays.
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents
        ) = getDerivedFulfillments(
                context,
                context.executionState.orderDetails
            );

        // For the fulfillAvailable functions, set the offerFullfillments
        // and considerationFulfillments arrays.
        context.executionState.offerFulfillments = offerFulfillments;
        context
            .executionState
            .considerationFulfillments = considerationFulfillments;

        // For match, set fulfillment and remaining offer component arrays.
        context.executionState.fulfillments = fulfillments;
        context
            .executionState
            .remainingOfferComponents = remainingOfferComponents
            .toFulfillmentComponents();

        return context;
    }

    /**
     * @dev Derive implicit and explicit executions for the given orders.
     *
     * @param context A Fuzz test context.
     * @param nativeTokensSupplied quantity of native tokens supplied.
     */
    function getDerivedExecutions(
        FuzzTestContext memory context,
        uint256 nativeTokensSupplied
    )
        internal
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutionsPre,
            Execution[] memory implicitExecutionsPost,
            uint256 nativeTokensReturned
        )
    {
        // Get the action.
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillAdvancedOrder.selector
        ) {
            // For the fulfill functions, derive the expected implicit
            // (standard) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            (implicitExecutionsPost, nativeTokensReturned) = context
                .toFulfillmentDetails(nativeTokensSupplied)
                .getStandardExecutions();
        } else if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            // For the fulfillBasic functions, derive the expected implicit
            // (basic) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            (implicitExecutionsPost, nativeTokensReturned) = context
                .toFulfillmentDetails(nativeTokensSupplied)
                .getBasicExecutions();
        } else if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            // For the fulfillAvailable functions, derive the expected implicit
            // and explicit executions.
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = context
                .toFulfillmentDetails(nativeTokensSupplied)
                .getFulfillAvailableExecutions(
                    context.executionState.offerFulfillments,
                    context.executionState.considerationFulfillments,
                    context.executionState.orderDetails
                );

            // TEMP (TODO: handle upstream)
            assume(
                explicitExecutions.length > 0,
                "no_explicit_executions_fulfillAvailable"
            );

            if (explicitExecutions.length == 0) {
                revert(
                    "FuzzDerivers: no explicit execs derived - fulfillAvailable"
                );
            }
        } else if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            // For the match functions, derive the expected implicit and
            // explicit executions.
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = context
                .toFulfillmentDetails(nativeTokensSupplied)
                .getMatchExecutions(context.executionState.fulfillments);
        }
    }

    function getDerivedExecutionsFromDirectInputs(
        FuzzTestContext memory context,
        FulfillmentDetails memory details,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        Fulfillment[] memory fulfillments
    )
        internal
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutionsPre,
            Execution[] memory implicitExecutionsPost,
            uint256 nativeTokensReturned
        )
    {
        if (
            context.action() == context.seaport.fulfillOrder.selector ||
            context.action() == context.seaport.fulfillAdvancedOrder.selector
        ) {
            // For the fulfill functions, derive the expected implicit
            // (standard) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            (implicitExecutionsPost, nativeTokensReturned) = details
                .getStandardExecutions();
        } else if (
            context.action() == context.seaport.fulfillBasicOrder.selector ||
            context.action() ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            // For the fulfillBasic functions, derive the expected implicit
            // (basic) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            (implicitExecutionsPost, nativeTokensReturned) = details
                .getBasicExecutions();
        } else if (
            context.action() ==
            context.seaport.fulfillAvailableOrders.selector ||
            context.action() ==
            context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            // For the fulfillAvailable functions, derive the expected implicit
            // and explicit executions.
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = details.getFulfillAvailableExecutions(
                offerFulfillments,
                considerationFulfillments,
                context.executionState.orderDetails
            );

            // TEMP (TODO: handle upstream)
            assume(
                explicitExecutions.length > 0,
                "no_explicit_executions_fulfillAvailable_direct_in"
            );

            if (explicitExecutions.length == 0) {
                revert(
                    "FuzzDerivers: no explicit execs (direct) - fulfillAvailable"
                );
            }
        } else if (
            context.action() == context.seaport.matchOrders.selector ||
            context.action() == context.seaport.matchAdvancedOrders.selector
        ) {
            // For the match functions, derive the expected implicit and
            // explicit executions.
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = details.getMatchExecutions(fulfillments);

            // TEMP (TODO: handle upstream)
            assume(
                explicitExecutions.length > 0,
                "no_explicit_executions_match_direct_in"
            );

            if (explicitExecutions.length == 0) {
                revert("FuzzDerivers: no explicit executions (direct) - match");
            }
        }
    }

    function getExecutionsFromRegeneratedFulfillments(
        FuzzTestContext memory context,
        FulfillmentDetails memory details
    )
        internal
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutionsPre,
            Execution[] memory implicitExecutionsPost,
            uint256 nativeTokensReturned
        )
    {
        // Derive the required fulfillment arrays.
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,

        ) = getDerivedFulfillments(context, details.orders);

        return
            getDerivedExecutionsFromDirectInputs(
                context,
                details,
                offerFulfillments,
                considerationFulfillments,
                fulfillments
            );
    }

    /**
     * @dev Derive the `expectedImplicitExecutions` and
     *      `expectedExplicitExecutions` arrays from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedExecutions(
        FuzzTestContext memory context
    ) internal returns (FuzzTestContext memory) {
        (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutionsPre,
            Execution[] memory implicitExecutionsPost,
            uint256 nativeTokensReturned
        ) = getDerivedExecutions(context, context.executionState.value);
        context
            .expectations
            .expectedImplicitPreExecutions = implicitExecutionsPre;
        context
            .expectations
            .expectedImplicitPostExecutions = implicitExecutionsPost;
        context.expectations.expectedExplicitExecutions = explicitExecutions;
        context
            .expectations
            .expectedNativeTokensReturned = nativeTokensReturned;

        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            uint256 expectedImpliedNativeExecutions = 0;

            for (uint256 i = 0; i < implicitExecutionsPost.length; ++i) {
                ReceivedItem memory item = implicitExecutionsPost[i].item;
                if (item.itemType == ItemType.NATIVE) {
                    expectedImpliedNativeExecutions += item.amount;
                }
            }

            if (expectedImpliedNativeExecutions < nativeTokensReturned) {
                revert("FuzzDeriver: invalid expected implied native value");
            }

            context.expectations.expectedImpliedNativeExecutions =
                expectedImpliedNativeExecutions -
                nativeTokensReturned;
        }

        return context;
    }
}

library FulfillmentDetailsHelper {
    using AdvancedOrderLib for AdvancedOrder[];

    function toFulfillmentDetails(
        FuzzTestContext memory context,
        uint256 nativeTokensSupplied
    ) internal view returns (FulfillmentDetails memory fulfillmentDetails) {
        address caller = context.executionState.caller == address(0)
            ? address(this)
            : context.executionState.caller;
        address recipient = context.executionState.recipient == address(0)
            ? caller
            : context.executionState.recipient;

        return
            FulfillmentDetails({
                orders: context.executionState.orderDetails,
                recipient: payable(recipient),
                fulfiller: payable(caller),
                nativeTokensSupplied: nativeTokensSupplied,
                fulfillerConduitKey: context.executionState.fulfillerConduitKey,
                seaport: address(context.seaport)
            });
    }
}
