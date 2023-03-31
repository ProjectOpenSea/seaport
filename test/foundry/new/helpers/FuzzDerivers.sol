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

    function deriveCriteriaResolvers(
        FuzzTestContext memory context
    ) public view {
        CriteriaResolverHelper criteriaResolverHelper = context
            .testHelpers
            .criteriaResolverHelper();

        uint256 totalCriteriaItems;

        for (uint256 i; i < context.orders.length; i++) {
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

        // Get the parties.
        address caller = context.caller == address(0)
            ? address(this)
            : context.caller;
        address recipient = context.recipient == address(0)
            ? caller
            : context.recipient;

        if (
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillAdvancedOrder.selector
        ) {
            // For the fulfill functions, derive the expected implicit
            // (standard) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            implicitExecutions = getStandardExecutions(
                toOrderDetails(context.orders[0], 0, context.criteriaResolvers),
                caller,
                context.fulfillerConduitKey,
                recipient,
                context.getNativeTokensToSupply(),
                address(context.seaport)
            );
        } else if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            // For the fulfillBasic functions, derive the expected implicit
            // (basic) executions. There are no explicit executions here
            // because the caller doesn't pass in fulfillments for these
            // functions.
            implicitExecutions = getBasicExecutions(
                toOrderDetails(context.orders[0], 0, context.criteriaResolvers),
                caller,
                context.fulfillerConduitKey,
                context.getNativeTokensToSupply(),
                address(context.seaport)
            );
        } else if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            // For the fulfillAvailable functions, derive the expected implicit
            // and explicit executions.
            (
                explicitExecutions,
                implicitExecutions
            ) = getFulfillAvailableExecutions(
                toFulfillmentDetails(
                    context.orders,
                    recipient,
                    caller,
                    context.fulfillerConduitKey,
                    context.criteriaResolvers,
                    address(context.seaport)
                ),
                context.offerFulfillments,
                context.considerationFulfillments,
                context.getNativeTokensToSupply()
            );
        } else if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            // For the match functions, derive the expected implicit and
            // explicit executions.
            (explicitExecutions, implicitExecutions) = getMatchExecutions(
                toFulfillmentDetails(
                    context.orders,
                    recipient,
                    caller,
                    context.fulfillerConduitKey,
                    context.criteriaResolvers,
                    address(context.seaport)
                ),
                context.fulfillments,
                context.getNativeTokensToSupply()
            );
        }
        context.expectedImplicitExecutions = implicitExecutions;
        context.expectedExplicitExecutions = explicitExecutions;
    }
}
