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
                    // Check if criteria is wildcard
                    if (offerItem.identifierOrCriteria == 0) {
                        // Derive the item hash using the order index,
                        // item index, and side
                        uint256 itemHash = keccak256(
                            abi.encodePacked(
                                i, // orderIndex
                                j, // itemIndex
                                Side.OFFER // side
                            )
                        );

                        // Look up the identifier to use for wildcards on the
                        // criteria resolver helper using the item hash
                        uint256 wildcardIdentifier = criteriaResolverHelper
                            .wildcardIdentifierForGivenCriteria(itemHash);

                        // Store the criteria resolver
                        criteriaResolvers[
                            totalCriteriaItems
                        ] = CriteriaResolver({
                            orderIndex: i,
                            index: j,
                            side: Side.OFFER,
                            identifier: wildcardIdentifier,
                            criteriaProof: []
                        });

                        // Handle non-wildcard criteria
                    } else {
                        // Look up criteria metadata for the given criteria
                        CriteriaMetadata memory criteriaMetadata = (
                            criteriaResolverHelper
                                .resolvableIdentifierForGivenCriteria(
                                    offerItem.identifierOrCriteria
                                )
                        );

                        // Store the criteria resolver
                        criteriaResolvers[
                            totalCriteriaItems
                        ] = CriteriaResolver({
                            orderIndex: i,
                            index: j,
                            side: Side.OFFER,
                            identifier: criteriaMetadata.resolvedIdentifier,
                            criteriaProof: criteriaMetadata.proof
                        });
                    }
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
                    // Check if criteria is wildcard
                    if (considerationItem.identifierOrCriteria == 0) {
                        // Derive the item hash using the order index,
                        // item index, and side
                        uint256 itemHash = keccak256(
                            abi.encodePacked(
                                i, // order index
                                j, // item index
                                Side.CONSIDERATION // side
                            )
                        );

                        // Look up the identifier to use for wildcards on the
                        // criteria resolver helper using the item hash
                        uint256 wildcardIdentifier = criteriaResolverHelper
                            .wildcardIdentifierForGivenCriteria(itemHash);

                        // Store the criteria resolver
                        criteriaResolvers[
                            totalCriteriaItems
                        ] = CriteriaResolver({
                            orderIndex: i,
                            index: j,
                            side: Side.CONSIDERATION,
                            identifier: wildcardIdentifier,
                            criteriaProof: []
                        });

                        // Handle non-wildcard criteria
                    } else {
                        // Look up criteria metadata for the given criteria
                        CriteriaMetadata
                            memory criteriaMetadata = criteriaResolverHelper
                                .resolvableIdentifierForGivenCriteria(
                                    considerationItem.identifierOrCriteria
                                );

                        // Store the criteria resolver
                        criteriaResolvers[
                            totalCriteriaItems
                        ] = CriteriaResolver({
                            orderIndex: i,
                            index: j,
                            side: Side.CONSIDERATION,
                            identifier: criteriaMetadata.resolvedIdentifier,
                            criteriaProof: criteriaMetadata.proof
                        });
                    }
                    totalCriteriaItems++;
                }
            }
        }

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
                context.getNativeTokensToSupply()
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
