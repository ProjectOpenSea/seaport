// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";
import { ExecutionHelper } from "seaport-sol/executions/ExecutionHelper.sol";
import { ItemType } from "seaport-sol/SeaportEnums.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";
import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import {
    AmountDeriverHelper
} from "../../../../contracts/helpers/sol/lib/fulfillment/AmountDeriverHelper.sol";
import {
    CriteriaMetadata,
    CriteriaResolverHelper
} from "./CriteriaResolverHelper.sol";
import {
    OrderStatus as OrderStatusEnum
} from "../../../../contracts/helpers/sol/SpaceEnums.sol";

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
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using MatchComponentType for MatchComponent[];

    function deriveAvailableOrders(
        FuzzTestContext memory context
    ) public view {
        // TODO: handle skipped orders due to generateOrder reverts
        // TODO: handle maximumFulfilled < orders.length
        bool[] memory expectedAvailableOrders = new bool[](
            context.orders.length
        );

        for (uint256 i; i < context.orders.length; ++i) {
            OrderParameters memory order = context.orders[i].parameters;
            OrderStatusEnum status = context.preExecOrderStatuses[i];

            expectedAvailableOrders[i] = (
                block.timestamp < order.endTime && // not expired
                block.timestamp >= order.startTime && // started
                status != OrderStatusEnum.CANCELLED_EXPLICIT && // not cancelled
                status != OrderStatusEnum.FULFILLED // not fully filled
            );
        }

        context.expectedAvailableOrders = expectedAvailableOrders;
    }

    function deriveCriteriaResolvers(
        FuzzTestContext memory context
    ) public view {
        CriteriaResolverHelper criteriaResolverHelper = context
            .testHelpers
            .criteriaResolverHelper();

        uint256 totalCriteriaItems;

        for (uint256 i; i < context.orders.length; i++) {
            // Note: criteria resolvers do not need to be provided for
            // unavailable orders, but generally will be provided as
            // availability is usually unknown at submission time.
            // Consider adding a fuzz condition to supply all or only
            // the necessary resolvers.
            AdvancedOrder memory order = context.orders[i];

            for (uint256 j; j < order.parameters.offer.length; j++) {
                OfferItem memory offerItem = order.parameters.offer[j];
                if (
                    offerItem.itemType == ItemType.ERC721_WITH_CRITERIA ||
                    offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    totalCriteriaItems++;
                }
            }

            for (uint256 j; j < order.parameters.consideration.length; j++) {
                ConsiderationItem memory considerationItem = order
                    .parameters
                    .consideration[j];
                if (
                    considerationItem.itemType ==
                    ItemType.ERC721_WITH_CRITERIA ||
                    considerationItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    totalCriteriaItems++;
                }
            }
        }

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            totalCriteriaItems
        );

        totalCriteriaItems = 0;

        for (uint256 i; i < context.orders.length; i++) {
            AdvancedOrder memory order = context.orders[i];

            for (uint256 j; j < order.parameters.offer.length; j++) {
                OfferItem memory offerItem = order.parameters.offer[j];
                if (
                    offerItem.itemType == ItemType.ERC721_WITH_CRITERIA ||
                    offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    CriteriaMetadata memory criteriaMetadata = (
                        criteriaResolverHelper
                            .resolvableIdentifierForGivenCriteria(
                                offerItem.identifierOrCriteria
                            )
                    );
                    criteriaResolvers[totalCriteriaItems] = CriteriaResolver({
                        orderIndex: i,
                        index: j,
                        side: Side.OFFER,
                        identifier: criteriaMetadata.resolvedIdentifier,
                        criteriaProof: criteriaMetadata.proof
                    });
                    // TODO: choose one at random for wildcards
                    totalCriteriaItems++;
                }
            }

            for (uint256 j; j < order.parameters.consideration.length; j++) {
                ConsiderationItem memory considerationItem = order
                    .parameters
                    .consideration[j];
                if (
                    considerationItem.itemType ==
                    ItemType.ERC721_WITH_CRITERIA ||
                    considerationItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    CriteriaMetadata
                        memory criteriaMetadata = criteriaResolverHelper
                            .resolvableIdentifierForGivenCriteria(
                                considerationItem.identifierOrCriteria
                            );
                    criteriaResolvers[totalCriteriaItems] = CriteriaResolver({
                        orderIndex: i,
                        index: j,
                        side: Side.CONSIDERATION,
                        identifier: criteriaMetadata.resolvedIdentifier,
                        criteriaProof: criteriaMetadata.proof
                    });
                    // TODO: choose one at random for wildcards
                    totalCriteriaItems++;
                }
            }
        }

        context.criteriaResolvers = criteriaResolvers;

        // TODO: read from test context
        // TODO: handle wildcard
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
                    toOrderDetails(context.orders, context.criteriaResolvers)
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
     * @dev Derive the `maximumFulfilled` value from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function deriveMaximumFulfilled(
        FuzzTestContext memory context
    ) public pure {
        // TODO: Start fuzzing this.
        context.maximumFulfilled = context.orders.length;
    }

    /**
     * @dev Derive the `expectedImplicitExecutions` and
     *      `expectedExplicitExecutions` arrays from the `orders` array.
     *
     * @param context A Fuzz test context.
     */
    function deriveExecutions(FuzzTestContext memory context) public {
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

            if (explicitExecutions.length == 0) {
                revert(
                    "FuzzDerivers: no explicit executions derived on fulfillAvailable"
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

            if (explicitExecutions.length == 0) {
                revert("FuzzDerivers: no explicit executions derived on match");
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

        OrderDetails[] memory details = toOrderDetails(
            context.orders,
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
                toOrderDetails(context.orders[0], 0, context.criteriaResolvers),
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
                toOrderDetails(context.orders[0], 0, context.criteriaResolvers),
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
