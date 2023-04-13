// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { Vm } from "forge-std/Vm.sol";

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
    OrderParameters
} from "seaport-sol/SeaportStructs.sol";

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
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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
    ) internal view returns (FuzzTestContext memory) {
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
            vm.assume(!(order.startTime == 0 && order.endTime == 0));

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
        }

        return context;
    }

    /**
     * @dev Derive the `expectedImplicitExecutions` and
     *      `expectedExplicitExecutions` arrays from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function withDerivedExecutions(
        FuzzTestContext memory context
    ) internal view returns (FuzzTestContext memory) {
        // Get the action.
        bytes4 action = context.action();

        // Set up the expected executions arrays.
        Execution[] memory implicitExecutions;
        Execution[] memory explicitExecutions;

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
                implicitExecutions
            ) = getFulfillAvailableExecutions(context);

            // TEMP (TODO: handle upstream)
            vm.assume(explicitExecutions.length > 0);

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
            (explicitExecutions, implicitExecutions) = getMatchExecutions(
                context
            );

            // TEMP (TODO: handle upstream)
            vm.assume(explicitExecutions.length > 0);

            if (explicitExecutions.length == 0) {
                revert("FuzzDerivers: no explicit executions derived - match");
            }
        }
        context.expectations.expectedImplicitExecutions = implicitExecutions;
        context.expectations.expectedExplicitExecutions = explicitExecutions;

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

    function getFulfillAvailableExecutions(
        FuzzTestContext memory context
    )
        internal
        view
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        return
            context.toFulfillmentDetails().getFulfillAvailableExecutions(
                context.executionState.offerFulfillments,
                context.executionState.considerationFulfillments,
                context.executionState.value,
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
            Execution[] memory implicitExecutions
        )
    {
        return
            context.toFulfillmentDetails().getMatchExecutions(
                context.executionState.fulfillments,
                context.executionState.value
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
