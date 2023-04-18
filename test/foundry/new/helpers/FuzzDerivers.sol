// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { assume } from "./VmUtils.sol";

import {
    AdvancedOrderLib,
    FulfillAvailableHelper,
    MatchComponent,
    MatchComponentType
} from "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    SpentItem
} from "seaport-sol/SeaportStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-sol/SeaportEnums.sol";

import { ItemType } from "seaport-sol/SeaportEnums.sol";

import { OrderStatusEnum } from "seaport-sol/SpaceEnums.sol";

import {
    AmountDeriverHelper
} from "seaport-sol/lib/fulfillment/AmountDeriverHelper.sol";

import { ExecutionHelper } from "seaport-sol/executions/ExecutionHelper.sol";

import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/fulfillments/lib/Structs.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { CriteriaResolverHelper } from "./CriteriaResolverHelper.sol";

/**
 *  @dev "Derivers" examine generated orders and calculate additional
 *       information based on the order state, like fulfillments and expected
 *       executions. Derivers run after generators, but before setup. Deriver
 *       functions should take a `FuzzTestContext` as input and modify it,
 *       adding any additional information that might be necessary for later
 *       steps. Derivers should not modify the order state itself, only the
 *       `FuzzTestContext`.
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

    function withDerivedCallValue(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        context.executionState.value = context.getNativeTokensToSupply();
        return context;
    }

    function withDerivedAvailableOrders(
        FuzzTestContext memory context
    ) internal returns (FuzzTestContext memory) {
        // TODO: handle skipped orders due to generateOrder reverts
        bool[] memory expectedAvailableOrders = new bool[](
            context.executionState.orders.length
        );

        uint256 totalAvailable = 0;
        for (uint256 i; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = context
                .executionState
                .orders[i]
                .parameters;
            OrderStatusEnum status = context
                .executionState
                .preExecOrderStatuses[i];

            // SANITY CHECKS; these should be removed once confidence
            // has been established in the soundness of the inputs or
            // if statuses are being modified downstream
            if (
                status == OrderStatusEnum.FULFILLED ||
                status == OrderStatusEnum.CANCELLED_EXPLICIT
            ) {
                bytes32 orderHash = context
                    .executionState
                    .orders[i]
                    .getTipNeutralizedOrderHash(context.seaport);

                (
                    ,
                    bool isCancelled,
                    uint256 totalFilled,
                    uint256 totalSize
                ) = context.seaport.getOrderStatus(orderHash);

                if (status == OrderStatusEnum.FULFILLED) {
                    // TEMP (TODO: fix how these are set)
                    require(
                        totalFilled != 0 && totalFilled == totalSize,
                        "FuzzDerivers: OrderStatus FULFILLED does not match order state"
                    );
                } else if (status == OrderStatusEnum.CANCELLED_EXPLICIT) {
                    // TEMP (TODO: fix how these are set)
                    require(
                        isCancelled,
                        "FuzzDerivers: OrderStatus CANCELLED_EXPLICIT does not match order state"
                    );
                }
            }

            // TEMP (TODO: handle upstream)
            assume(
                !(order.startTime == 0 && order.endTime == 0),
                "zero_start_end_time"
            );

            bool isAvailable = (block.timestamp < order.endTime && // not expired
                block.timestamp >= order.startTime && // started
                status != OrderStatusEnum.CANCELLED_EXPLICIT && // not cancelled
                status != OrderStatusEnum.FULFILLED && // not fully filled
                totalAvailable < context.executionState.maximumFulfilled);

            if (isAvailable) {
                ++totalAvailable;
            }

            expectedAvailableOrders[i] = isAvailable;
        }

        context.expectations.expectedAvailableOrders = expectedAvailableOrders;

        return context;
    }

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

    function withDerivedOrderDetails(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        OrderDetails[] memory orderDetails = context
            .executionState
            .orders
            .getOrderDetails(context.executionState.criteriaResolvers);

        context.executionState.orderDetails = orderDetails;

        return context;
    }

    /**
     * @dev Derive the `offerFulfillments` and `considerationFulfillments`
     *      arrays or the `fulfillments` array from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedFulfillments(
        FuzzTestContext memory context
    ) internal returns (FuzzTestContext memory) {
        // Determine the action.
        bytes4 action = context.action();

        // For the fulfill functions, derive the offerFullfillments and
        // considerationFulfillments arrays.
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            // Note: items do not need corresponding fulfillments for
            // unavailable orders, but generally will be provided as
            // availability is usually unknown at submission time.
            // Consider adding a fuzz condition to supply all or only
            // the necessary consideration fulfillment components.

            // TODO: Use `getAggregatedFulfillmentComponents` sometimes?
            (
                FulfillmentComponent[][] memory offerFulfillments,
                FulfillmentComponent[][] memory considerationFulfillments
            ) = context.testHelpers.getNaiveFulfillmentComponents(
                    context.executionState.orderDetails
                );

            context.executionState.offerFulfillments = offerFulfillments;
            context
                .executionState
                .considerationFulfillments = considerationFulfillments;

            // TODO: expectedImpliedNativeExecutions needs to be calculated
            // in cases where offer items are not included in fulfillments
        }

        // For the match functions, derive the fulfillments array.
        if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            (
                Fulfillment[] memory fulfillments,
                MatchComponent[] memory remainingOfferComponents,

            ) = context.testHelpers.getMatchedFulfillments(
                    context.executionState.orders,
                    context.executionState.criteriaResolvers
                );
            context.executionState.fulfillments = fulfillments;
            context
                .executionState
                .remainingOfferComponents = remainingOfferComponents
                .toFulfillmentComponents();

            uint256 expectedImpliedNativeExecutions = 0;
            for (uint256 i = 0; i < remainingOfferComponents.length; ++i) {
                MatchComponent memory component = remainingOfferComponents[i];
                OfferItem memory item = context.executionState.orders[uint256(component.orderIndex)].parameters.offer[uint256(component.itemIndex)];

                if (item.itemType == ItemType.NATIVE) {
                    expectedImpliedNativeExecutions += component.amount;
                }
            }

            context.expectations.expectedImpliedNativeExecutions = expectedImpliedNativeExecutions;
        }

        return context;
    }

    function getDerivedExecutions(
        FuzzTestContext memory context
    )
        internal
        returns (
            Execution[] memory implicitExecutions,
            Execution[] memory explicitExecutions,
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
            implicitExecutions = getStandardExecutions(context);
        } else if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            // For the fulfillBasic functions, derive the expected implicit
            // (basic) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            implicitExecutions = getBasicExecutions(context);
        } else if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            // For the fulfillAvailable functions, derive the expected implicit
            // and explicit executions.
            (
                explicitExecutions,
                implicitExecutions,
                nativeTokensReturned
            ) = getFulfillAvailableExecutions(context, context.executionState.value);

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
            (explicitExecutions, implicitExecutions, nativeTokensReturned) = getMatchExecutions(
                context
            );

            // TEMP (TODO: handle upstream)
            assume(
                explicitExecutions.length > 0,
                "no_explicit_executions_match"
            );

            if (explicitExecutions.length == 0) {
                revert("FuzzDerivers: no explicit executions derived - match");
            }
        }
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
            Execution[] memory implicitExecutions,
            Execution[] memory explicitExecutions,
            uint256 nativeTokensReturned
        ) = getDerivedExecutions(context);
        context.expectations.expectedImplicitExecutions = implicitExecutions;
        context.expectations.expectedExplicitExecutions = explicitExecutions;
        context.expectations.expectedNativeTokensReturned = nativeTokensReturned;

        return context;
    }

    function getStandardExecutions(
        FuzzTestContext memory context
    ) internal view returns (Execution[] memory implicitExecutions) {
        address caller = context.executionState.caller == address(0)
            ? address(this)
            : context.executionState.caller;
        address recipient = context.executionState.recipient == address(0)
            ? caller
            : context.executionState.recipient;

        return
            context
                .executionState
                .orders[0]
                .toOrderDetails(0, context.executionState.criteriaResolvers)
                .getStandardExecutions(
                    caller,
                    context.executionState.fulfillerConduitKey,
                    recipient,
                    context.executionState.value,
                    address(context.seaport)
                );
    }

    function getBasicExecutions(
        FuzzTestContext memory context
    ) internal view returns (Execution[] memory implicitExecutions) {
        address caller = context.executionState.caller == address(0)
            ? address(this)
            : context.executionState.caller;

        return
            context
                .executionState
                .orders[0]
                .toOrderDetails(0, context.executionState.criteriaResolvers)
                .getBasicExecutions(
                    caller,
                    context.executionState.fulfillerConduitKey,
                    context.executionState.value,
                    address(context.seaport)
                );
    }

    function getContractOrderSuppliedNativeTokens(
        FuzzTestContext memory context
    ) internal view returns (uint256 nativeTokens) {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderType orderType = (
                context.executionState.orders[i].parameters.orderType
            );
            if (orderType != OrderType.CONTRACT) {
                continue;
            }

            if (!context.expectations.expectedAvailableOrders[i]) {
                continue;
            }

            OrderDetails memory order = context.executionState.orderDetails[i];
            for (uint256 j = 0; j < order.offer.length; ++j) {
                SpentItem memory item = order.offer[j];
                if (item.itemType == ItemType.NATIVE) {
                    nativeTokens += item.amount;
                }
            }
        }
    }

    function getFulfillAvailableExecutions(
        FuzzTestContext memory context,
        uint256 nativeTokensSupplied
    )
        internal
        view
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions,
            uint256 nativeTokensReturned
        )
    {
        uint256 totalNativeTokensAvailable = (
            nativeTokensSupplied + getContractOrderSuppliedNativeTokens(
                context
            )
        );

        return
            context.toFulfillmentDetails().getFulfillAvailableExecutions(
                context.executionState.offerFulfillments,
                context.executionState.considerationFulfillments,
                totalNativeTokensAvailable,
                context.expectations.expectedAvailableOrders
            );
    }

    function getMatchExecutions(
        FuzzTestContext memory context
    )
        internal
        view
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions,
            uint256 nativeTokensReturned
        )
    {
        uint256 totalNativeTokensAvailable = (
            context.executionState.value + getContractOrderSuppliedNativeTokens(
                context
            )
        );

        return
            context.toFulfillmentDetails().getMatchExecutions(
                context.executionState.fulfillments,
                totalNativeTokensAvailable
            );
    }
}

library FulfillmentDetailsHelper {
    using AdvancedOrderLib for AdvancedOrder[];

    function toFulfillmentDetails(
        FuzzTestContext memory context
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
                fulfillerConduitKey: context.executionState.fulfillerConduitKey,
                seaport: address(context.seaport)
            });
    }
}
