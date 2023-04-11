// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { Vm } from "forge-std/Vm.sol";

import {
    AdvancedOrderLib,
    FulfillAvailableHelper,
    MatchComponent,
    MatchComponentType,
    MatchFulfillmentHelper
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

import { OrderDetails } from "seaport-sol/fulfillments/lib/Structs.sol";

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
abstract contract FuzzDerivers is
    FulfillAvailableHelper,
    MatchFulfillmentHelper,
    ExecutionHelper
{
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using FuzzHelpers for AdvancedOrder;
    using MatchComponentType for MatchComponent[];

    function deriveAvailableOrders(FuzzTestContext memory context) public view {
        // TODO: handle skipped orders due to generateOrder reverts
        bool[] memory expectedAvailableOrders = new bool[](
            context.orders.length
        );

        uint256 totalAvailable = 0;
        for (uint256 i; i < context.orders.length; ++i) {
            OrderParameters memory order = context.orders[i].parameters;
            OrderStatusEnum status = context.preExecOrderStatuses[i];

            // SANITY CHECKS; these should be removed once confidence
            // has been established in the soundness of the inputs or
            // if statuses are being modified downstream
            if (
                status == OrderStatusEnum.FULFILLED ||
                status == OrderStatusEnum.CANCELLED_EXPLICIT
            ) {
                bytes32 orderHash = context
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
                totalAvailable < context.maximumFulfilled);

            if (isAvailable) {
                ++totalAvailable;
            }

            expectedAvailableOrders[i] = isAvailable;
        }

        context.expectedAvailableOrders = expectedAvailableOrders;
    }

    function deriveCriteriaResolvers(
        FuzzTestContext memory context
    ) public view {
        CriteriaResolverHelper criteriaResolverHelper = context
            .testHelpers
            .criteriaResolverHelper();

        CriteriaResolver[] memory criteriaResolvers = criteriaResolverHelper
            .deriveCriteriaResolvers(context.orders);

        context.criteriaResolvers = criteriaResolvers;
    }

    /**
     * @dev Derive the `offerFulfillments` and `considerationFulfillments`
     *      arrays or the `fulfillments` array from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function deriveFulfillments(FuzzTestContext memory context) public {
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
            ) = getNaiveFulfillmentComponents(
                    context.orders.getOrderDetails(context.criteriaResolvers)
                );

            context.offerFulfillments = offerFulfillments;
            context.considerationFulfillments = considerationFulfillments;
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
                    context.orders,
                    context.criteriaResolvers
                );
            context.fulfillments = fulfillments;
            context.remainingOfferComponents = remainingOfferComponents
                .toFulfillmentComponents();
        }
    }

    /**
     * @dev Derive the `expectedImplicitExecutions` and
     *      `expectedExplicitExecutions` arrays from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function deriveExecutions(FuzzTestContext memory context) public view {
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
        context.expectedImplicitExecutions = implicitExecutions;
        context.expectedExplicitExecutions = explicitExecutions;
    }

    function toFulfillmentDetails(
        FuzzTestContext memory context
    ) public view returns (FulfillmentDetails memory fulfillmentDetails) {
        address caller = context.caller == address(0)
            ? address(this)
            : context.caller;
        address recipient = context.recipient == address(0)
            ? caller
            : context.recipient;

        OrderDetails[] memory details = context.orders.getOrderDetails(
            context.criteriaResolvers
        );

        return
            FulfillmentDetails({
                orders: details,
                recipient: payable(recipient),
                fulfiller: payable(caller),
                fulfillerConduitKey: context.fulfillerConduitKey,
                seaport: address(context.seaport)
            });
    }

    function getStandardExecutions(
        FuzzTestContext memory context
    ) public view returns (Execution[] memory implicitExecutions) {
        address caller = context.caller == address(0)
            ? address(this)
            : context.caller;
        address recipient = context.recipient == address(0)
            ? caller
            : context.recipient;

        return
            getStandardExecutions(
                context.orders[0].toOrderDetails(0, context.criteriaResolvers),
                caller,
                context.fulfillerConduitKey,
                recipient,
                context.getNativeTokensToSupply(),
                address(context.seaport)
            );
    }

    function getBasicExecutions(
        FuzzTestContext memory context
    ) public view returns (Execution[] memory implicitExecutions) {
        address caller = context.caller == address(0)
            ? address(this)
            : context.caller;

        return
            getBasicExecutions(
                context.orders[0].toOrderDetails(0, context.criteriaResolvers),
                caller,
                context.fulfillerConduitKey,
                context.getNativeTokensToSupply(),
                address(context.seaport)
            );
    }

    function getFulfillAvailableExecutions(
        FuzzTestContext memory context
    )
        public
        view
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        return
            getFulfillAvailableExecutions(
                toFulfillmentDetails(context),
                context.offerFulfillments,
                context.considerationFulfillments,
                context.getNativeTokensToSupply(),
                context.expectedAvailableOrders
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
            getMatchExecutions(
                toFulfillmentDetails(context),
                context.fulfillments,
                context.getNativeTokensToSupply()
            );
    }
}
