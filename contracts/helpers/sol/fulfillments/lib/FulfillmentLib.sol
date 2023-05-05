// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { LibSort } from "solady/src/utils/LibSort.sol";

import {
    FulfillmentComponent,
    Fulfillment,
    Order,
    AdvancedOrder,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    CriteriaResolver
} from "../../SeaportStructs.sol";

import { ItemType, Side } from "../../SeaportEnums.sol";

import { MatchComponent, OrderDetails } from "./Structs.sol";

enum FulfillmentEligibility {
    NONE,
    FULFILL_AVAILABLE,
    MATCH,
    BOTH
}

enum AggregationStrategy {
    MINIMUM, // Aggregate as few items as possible
    MAXIMUM, // Aggregate as many items as possible
    RANDOM // Randomize aggregation quantity
    // NOTE: for match cases, there may be more sophisticated optimal strategies
}

enum FulfillAvailableStrategy {
    KEEP_ALL, // Persist default aggregation strategy
    DROP_SINGLE_OFFER, // Exclude aggregations for single offer items
    DROP_ALL_OFFER, // Exclude offer aggregations (keep one if no consideration)
    DROP_RANDOM_OFFER, // Exclude random offer aggregations
    DROP_SINGLE_KEEP_FILTERED, // Exclude single unless it would be filtered
    DROP_ALL_KEEP_FILTERED, // Exclude all unfilterable offer aggregations
    DROP_RANDOM_KEEP_FILTERED // Exclude random, unfilterable offer aggregations
}

enum MatchStrategy {
    MAX_FILTERS, // prioritize locating filterable executions
    MIN_FILTERS, // prioritize avoiding filterable executions where possible
    MAX_INCLUSION, // try not to leave any unspent offer items
    MIN_INCLUSION, // leave as many unspent offer items as possible
    MIN_INCLUSION_MAX_FILTERS, // leave unspent items if not filterable
    MAX_EXECUTIONS, // use as many fulfillments as possible given aggregations
    MIN_EXECUTIONS, // use as few fulfillments as possible given aggregations
    MIN_EXECUTIONS_MAX_FILTERS // minimize fulfillments and prioritize filters
    // NOTE: more sophisticated match strategies require modifying aggregations
}

enum ItemCategory {
    NATIVE,
    ERC721,
    OTHER
}

struct FulfillmentStrategy {
    AggregationStrategy aggregationStrategy;
    FulfillAvailableStrategy fulfillAvailableStrategy;
    MatchStrategy matchStrategy;
}

struct FulfillmentItem {
    uint256 orderIndex;
    uint256 itemIndex;
    uint256 amount;
    address account;
}

struct FulfillmentItems {
    ItemCategory itemCategory;
    uint256 totalAmount;
    FulfillmentItem[] items;
}

struct DualFulfillmentItems {
    FulfillmentItems[] offer;
    FulfillmentItems[] consideration;
}

struct DualFulfillmentMatchContext {
    ItemCategory itemCategory;
    uint256 totalOfferAmount;
    uint256 totalConsiderationAmount;
}

struct FulfillAvailableDetails {
    DualFulfillmentItems items;
    address caller;
    address recipient;
    uint256 totalItems;
}

struct MatchDetails {
    DualFulfillmentItems[] items;
    DualFulfillmentMatchContext[] context;
    address recipient;
    uint256 totalItems;
}

library FulfillmentGeneratorLib {
    using LibPRNG for LibPRNG.PRNG;
    using FulfillmentPrepLib for OrderDetails[];
    using FulfillmentPrepLib for FulfillmentPrepLib.ItemReference[];

    function getDefaultFulfillmentStrategy()
        internal
        pure
        returns (FulfillmentStrategy memory)
    {
        return
            FulfillmentStrategy({
                aggregationStrategy: AggregationStrategy.MAXIMUM,
                fulfillAvailableStrategy: FulfillAvailableStrategy.KEEP_ALL,
                matchStrategy: MatchStrategy.MAX_INCLUSION
            });
    }

    // This uses the "default" set of strategies and applies no randomization.
    function getFulfillments(
        OrderDetails[] memory orderDetails,
        address recipient,
        address caller
    )
        internal
        pure
        returns (
            FulfillmentEligibility eligibility,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        uint256 seed = 0;

        return
            getFulfillments(
                orderDetails,
                getDefaultFulfillmentStrategy(),
                recipient,
                caller,
                seed
            );
    }

    function getFulfillments(
        OrderDetails[] memory orderDetails,
        FulfillmentStrategy memory strategy,
        address recipient,
        address caller,
        uint256 seed
    )
        internal
        pure
        returns (
            FulfillmentEligibility eligibility,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        FulfillmentPrepLib.ItemReference[] memory itemReferences = orderDetails
            .getItemReferences(seed);

        FulfillAvailableDetails memory fulfillAvailableDetails = itemReferences
            .getFulfillAvailableDetailsFromReferences(recipient, caller);

        MatchDetails memory matchDetails = itemReferences
            .getMatchDetailsFromReferences(recipient);

        return
            getFulfillmentsFromDetails(
                fulfillAvailableDetails,
                matchDetails,
                strategy,
                seed
            );
    }

    function getFulfillmentsFromDetails(
        FulfillAvailableDetails memory fulfillAvailableDetails,
        MatchDetails memory matchDetails,
        FulfillmentStrategy memory strategy,
        uint256 seed
    )
        internal
        pure
        returns (
            FulfillmentEligibility eligibility,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        assertSupportedStrategy(strategy);

        (
            fulfillments,
            unspentOfferComponents,
            unmetConsiderationComponents
        ) = getMatchFulfillments(matchDetails, strategy, seed);

        eligibility = determineEligibility(
            fulfillAvailableDetails,
            unmetConsiderationComponents.length
        );

        if (
            eligibility == FulfillmentEligibility.FULFILL_AVAILABLE ||
            eligibility == FulfillmentEligibility.BOTH
        ) {
            (
                offerFulfillments,
                considerationFulfillments
            ) = getFulfillAvailableFulfillments(
                fulfillAvailableDetails,
                strategy,
                seed
            );
        }
    }

    function assertSupportedStrategy(
        FulfillmentStrategy memory strategy
    ) internal pure {
        // TODO: add more strategies here as support is added for them.
        if (uint256(strategy.fulfillAvailableStrategy) > 3) {
            revert(
                "FulfillmentGeneratorLib: unsupported fulfillAvailable strategy"
            );
        }

        MatchStrategy matchStrategy = strategy.matchStrategy;
        if (matchStrategy != MatchStrategy.MAX_INCLUSION) {
            revert("FulfillmentGeneratorLib: unsupported match strategy");
        }
    }

    function determineEligibility(
        FulfillAvailableDetails memory fulfillAvailableDetails,
        uint256 totalUnmetConsiderationComponents
    ) internal pure returns (FulfillmentEligibility) {
        // FulfillAvailable: cannot be used if native offer items are present on
        // non-contract orders or if ERC721 items with amounts != 1 are present.
        // There must also be at least one unfiltered explicit execution. Note
        // that it is also *very* tricky to use FulfillAvailable in cases where
        // ERC721 items are present on both the offer side & consideration side.
        bool eligibleForFulfillAvailable = determineFulfillAvailableEligibility(
            fulfillAvailableDetails
        );

        // Match: cannot be used if there is no way to meet each consideration
        // item. In these cases, remaining offer components should be returned.
        bool eligibleForMatch = totalUnmetConsiderationComponents == 0;

        if (eligibleForFulfillAvailable) {
            return
                eligibleForMatch
                    ? FulfillmentEligibility.BOTH
                    : FulfillmentEligibility.FULFILL_AVAILABLE;
        }

        return
            eligibleForMatch
                ? FulfillmentEligibility.MATCH
                : FulfillmentEligibility.NONE;
    }

    // This uses the "default" set of strategies, applies no randomization, and
    // does not give a recipient & will not properly detect filtered executions.
    function getMatchedFulfillments(
        OrderDetails[] memory orderDetails
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        return
            getMatchFulfillments(
                orderDetails.getItemReferences(0).getMatchDetailsFromReferences(
                    address(0)
                )
            );
    }

    // This does not give a recipient & so will not detect filtered executions.
    function getMatchedFulfillments(
        OrderDetails[] memory orderDetails,
        FulfillmentStrategy memory strategy,
        uint256 seed
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        return
            getMatchFulfillments(
                orderDetails.getItemReferences(0).getMatchDetailsFromReferences(
                    address(0)
                ),
                strategy,
                seed
            );
    }

    function getMatchDetails(
        OrderDetails[] memory orderDetails,
        FulfillmentStrategy memory strategy,
        address recipient,
        uint256 seed
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        return
            getMatchFulfillments(
                orderDetails
                    .getItemReferences(seed)
                    .getMatchDetailsFromReferences(recipient),
                strategy,
                seed
            );
    }

    // This uses the "default" set of strategies and applies no randomization.
    function getMatchFulfillments(
        MatchDetails memory matchDetails
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        uint256 seed = 0;

        return
            getMatchFulfillments(
                matchDetails,
                getDefaultFulfillmentStrategy(),
                seed
            );
    }

    function getMatchFulfillments(
        MatchDetails memory matchDetails,
        FulfillmentStrategy memory strategy,
        uint256 seed
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        MatchStrategy matchStrategy = strategy.matchStrategy;

        if (matchStrategy == MatchStrategy.MAX_INCLUSION) {
            (
                fulfillments,
                unspentOfferComponents,
                unmetConsiderationComponents
            ) = getMatchFulfillmentsUsingConsumeMethod(
                matchDetails,
                getMaxInclusionConsumeMethod(strategy.aggregationStrategy),
                seed
            );
        } else {
            revert("FulfillmentGeneratorLib: unsupported match strategy");
        }
    }

    function getMaxInclusionConsumeMethod(
        AggregationStrategy aggregationStrategy
    )
        internal
        pure
        returns (
            function(FulfillmentItems memory, FulfillmentItems memory, uint256)
                internal
                pure
                returns (Fulfillment memory)
        )
    {
        if (aggregationStrategy == AggregationStrategy.MAXIMUM) {
            return consumeMaximumItemsAndGetFulfillment;
        } else if (aggregationStrategy == AggregationStrategy.MINIMUM) {
            return consumeMinimumItemsAndGetFulfillment;
        } else if (aggregationStrategy == AggregationStrategy.RANDOM) {
            return consumeRandomItemsAndGetFulfillment;
        } else {
            revert(
                "FulfillmentGeneratorLib: unknown match aggregation strategy"
            );
        }
    }

    function getTotalUncoveredComponents(
        DualFulfillmentMatchContext[] memory contexts
    )
        internal
        pure
        returns (
            uint256 totalUnspentOfferComponents,
            uint256 totalUnmetConsiderationComponents
        )
    {
        for (uint256 i = 0; i < contexts.length; ++i) {
            DualFulfillmentMatchContext memory context = contexts[i];

            if (context.totalConsiderationAmount > context.totalOfferAmount) {
                ++totalUnmetConsiderationComponents;
            } else if (
                context.totalConsiderationAmount < context.totalOfferAmount
            ) {
                ++totalUnspentOfferComponents;
            }
        }
    }

    function getUncoveredComponents(
        MatchDetails memory matchDetails
    )
        internal
        pure
        returns (
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        (
            uint256 totalUnspentOfferComponents,
            uint256 totalUnmetConsiderationComponents
        ) = getTotalUncoveredComponents(matchDetails.context);

        unspentOfferComponents = (
            new MatchComponent[](totalUnspentOfferComponents)
        );

        unmetConsiderationComponents = (
            new MatchComponent[](totalUnmetConsiderationComponents)
        );

        if (
            totalUnspentOfferComponents + totalUnmetConsiderationComponents == 0
        ) {
            return (unspentOfferComponents, unmetConsiderationComponents);
        }

        totalUnspentOfferComponents = 0;
        totalUnmetConsiderationComponents = 0;

        for (uint256 i = 0; i < matchDetails.items.length; ++i) {
            DualFulfillmentMatchContext memory context = (
                matchDetails.context[i]
            );

            FulfillmentItems[] memory offer = matchDetails.items[i].offer;

            FulfillmentItems[] memory consideration = (
                matchDetails.items[i].consideration
            );

            if (context.totalConsiderationAmount > context.totalOfferAmount) {
                uint256 amount = (context.totalConsiderationAmount -
                    context.totalOfferAmount);

                if (consideration.length == 0) {
                    revert(
                        "FulfillmentGeneratorLib: empty consideration array"
                    );
                }

                if (consideration[0].items.length == 0) {
                    revert(
                        "FulfillmentGeneratorLib: empty consideration items"
                    );
                }

                FulfillmentItem memory item = consideration[0].items[0];

                if (
                    item.orderIndex > type(uint8).max ||
                    item.itemIndex > type(uint8).max
                ) {
                    revert(
                        "FulfillmentGeneratorLib: OOR consideration item index"
                    );
                }

                unmetConsiderationComponents[
                    totalUnmetConsiderationComponents++
                ] = MatchComponent({
                    amount: amount,
                    orderIndex: uint8(item.orderIndex),
                    itemIndex: uint8(item.itemIndex)
                });
            } else if (
                context.totalConsiderationAmount < context.totalOfferAmount
            ) {
                uint256 amount = (context.totalOfferAmount -
                    context.totalConsiderationAmount);

                if (offer.length == 0) {
                    revert("FulfillmentGeneratorLib: empty offer array");
                }

                if (offer[0].items.length == 0) {
                    revert("FulfillmentGeneratorLib: empty offer items");
                }

                FulfillmentItem memory item = offer[0].items[0];

                if (
                    item.orderIndex > type(uint8).max ||
                    item.itemIndex > type(uint8).max
                ) {
                    revert("FulfillmentGeneratorLib: OOR offer item index");
                }

                unspentOfferComponents[
                    totalUnspentOfferComponents++
                ] = MatchComponent({
                    amount: amount,
                    orderIndex: uint8(item.orderIndex),
                    itemIndex: uint8(item.itemIndex)
                });
            }
        }

        // Sanity checks
        if (unspentOfferComponents.length != totalUnspentOfferComponents) {
            revert(
                "FulfillmentGeneratorLib: unspent match item assignment error"
            );
        }

        if (
            unmetConsiderationComponents.length !=
            totalUnmetConsiderationComponents
        ) {
            revert(
                "FulfillmentGeneratorLib: unmet match item assignment error"
            );
        }

        for (uint256 i = 0; i < unspentOfferComponents.length; ++i) {
            if (unspentOfferComponents[i].amount == 0) {
                revert("FulfillmentGeneratorLib: unspent match amount of zero");
            }
        }

        for (uint256 i = 0; i < unmetConsiderationComponents.length; ++i) {
            if (unmetConsiderationComponents[i].amount == 0) {
                revert("FulfillmentGeneratorLib: unmet match amount of zero");
            }
        }
    }

    function getMatchFulfillmentsUsingConsumeMethod(
        MatchDetails memory matchDetails,
        function(FulfillmentItems memory, FulfillmentItems memory, uint256)
            internal
            pure
            returns (Fulfillment memory) consumeMethod,
        uint256 seed
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        if (matchDetails.totalItems == 0) {
            return (
                fulfillments,
                unspentOfferComponents,
                unmetConsiderationComponents
            );
        }

        (
            unspentOfferComponents,
            unmetConsiderationComponents
        ) = getUncoveredComponents(matchDetails);

        // Allocate based on max possible fulfillments; reduce after assignment.
        fulfillments = new Fulfillment[](matchDetails.totalItems - 1);
        uint256 currentFulfillment = 0;

        // The outer loop processes each matchable group.
        for (uint256 i = 0; i < matchDetails.items.length; ++i) {
            // This is actually a "while" loop, but bound it as a sanity check.
            bool allProcessed = false;
            for (uint256 j = 0; j < matchDetails.totalItems; ++j) {
                Fulfillment memory fulfillment = consumeItems(
                    matchDetails.items[i],
                    consumeMethod,
                    seed
                );

                // Exit the inner loop if no fulfillment was located.
                if (fulfillment.offerComponents.length == 0) {
                    allProcessed = true;
                    break;
                }

                // append the located fulfillment and continue searching.
                fulfillments[currentFulfillment++] = fulfillment;
            }
            if (!allProcessed) {
                revert("FulfillmentGeneratorLib: did not complete processing");
            }
        }

        // Resize the fulfillments array based on number of elements assigned.
        assembly {
            mstore(fulfillments, currentFulfillment)
        }
    }

    // NOTE: this does not currently minimize the number of fulfillments.
    function consumeItems(
        DualFulfillmentItems memory matchItems,
        function(FulfillmentItems memory, FulfillmentItems memory, uint256)
            internal
            pure
            returns (Fulfillment memory) consumeMethod,
        uint256 seed
    ) internal pure returns (Fulfillment memory) {
        // Search for something that can be offered.
        for (uint256 i = 0; i < matchItems.offer.length; ++i) {
            FulfillmentItems memory offerItems = matchItems.offer[i];
            if (offerItems.totalAmount != 0) {
                // Search for something it can be matched against.
                for (uint256 j = 0; j < matchItems.consideration.length; ++j) {
                    FulfillmentItems memory considerationItems = (
                        matchItems.consideration[j]
                    );

                    if (considerationItems.totalAmount != 0) {
                        return
                            consumeMethod(offerItems, considerationItems, seed);
                    }
                }
            }
        }

        // If none were found, return an empty fulfillment.
        return emptyFulfillment();
    }

    function consumeMinimumItemsAndGetFulfillment(
        FulfillmentItems memory offerItems,
        FulfillmentItems memory considerationItems,
        uint256 /* seed */
    ) internal pure returns (Fulfillment memory) {
        if (
            offerItems.totalAmount == 0 || considerationItems.totalAmount == 0
        ) {
            revert("FulfillmentGeneratorLib: missing item amounts to consume");
        }

        // Allocate fulfillment component arrays with a single element.
        FulfillmentComponent[] memory offerComponents = (
            new FulfillmentComponent[](1)
        );
        FulfillmentComponent[] memory considerationComponents = (
            new FulfillmentComponent[](1)
        );

        FulfillmentItem memory offerItem;
        for (uint256 i = 0; i < offerItems.items.length; ++i) {
            offerItem = offerItems.items[i];

            if (offerItem.amount != 0) {
                break;
            }
        }

        FulfillmentItem memory considerationItem;
        for (uint256 i = 0; i < considerationItems.items.length; ++i) {
            considerationItem = considerationItems.items[i];

            if (considerationItem.amount != 0) {
                break;
            }
        }

        offerComponents[0] = getFulfillmentComponent(offerItem);
        considerationComponents[0] = getFulfillmentComponent(considerationItem);

        if (offerItem.amount < considerationItem.amount) {
            offerItems.totalAmount -= offerItem.amount;
            considerationItems.totalAmount -= offerItem.amount;
            considerationItem.amount -= offerItem.amount;
            offerItem.amount = 0;
        } else {
            offerItems.totalAmount -= considerationItem.amount;
            considerationItems.totalAmount -= considerationItem.amount;
            offerItem.amount -= considerationItem.amount;
            considerationItem.amount = 0;
        }

        return
            Fulfillment({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents
            });
    }

    function consumeMaximumItemsAndGetFulfillment(
        FulfillmentItems memory offerItems,
        FulfillmentItems memory considerationItems,
        uint256 /* seed */
    ) internal pure returns (Fulfillment memory) {
        if (
            offerItems.totalAmount == 0 || considerationItems.totalAmount == 0
        ) {
            revert("FulfillmentGeneratorLib: missing item amounts to consume");
        }

        // Allocate fulfillment component arrays using total items; reduce
        // length after based on the total number of elements assigned to each.
        FulfillmentComponent[] memory offerComponents = (
            new FulfillmentComponent[](offerItems.items.length)
        );
        FulfillmentComponent[] memory considerationComponents = (
            new FulfillmentComponent[](considerationItems.items.length)
        );

        uint256 assignmentIndex = 0;

        uint256 amountToConsume = offerItems.totalAmount >
            considerationItems.totalAmount
            ? considerationItems.totalAmount
            : offerItems.totalAmount;

        uint256 amountToCredit = amountToConsume;

        bool firstConsumedItemLocated = false;
        uint256 firstConsumedItemIndex;

        for (uint256 i = 0; i < offerItems.items.length; ++i) {
            FulfillmentItem memory item = offerItems.items[i];
            if (item.amount != 0) {
                if (!firstConsumedItemLocated) {
                    firstConsumedItemLocated = true;
                    firstConsumedItemIndex = i;
                }

                offerComponents[assignmentIndex++] = getFulfillmentComponent(
                    item
                );

                if (item.amount >= amountToConsume) {
                    uint256 amountToAddBack = item.amount - amountToConsume;

                    item.amount = 0;

                    offerItems.items[firstConsumedItemIndex].amount += (
                        amountToAddBack
                    );

                    offerItems.totalAmount -= amountToConsume;

                    amountToConsume = 0;
                    break;
                } else {
                    amountToConsume -= item.amount;
                    offerItems.totalAmount -= item.amount;

                    item.amount = 0;
                }
            }
        }

        // Sanity check
        if (amountToConsume != 0) {
            revert("FulfillmentGeneratorLib: did not consume expected amount");
        }

        // Reduce offerComponents length based on number of elements assigned.
        assembly {
            mstore(offerComponents, assignmentIndex)
        }

        firstConsumedItemLocated = false;
        assignmentIndex = 0;

        for (uint256 i = 0; i < considerationItems.items.length; ++i) {
            FulfillmentItem memory item = considerationItems.items[i];
            if (item.amount != 0) {
                if (!firstConsumedItemLocated) {
                    firstConsumedItemLocated = true;
                    firstConsumedItemIndex = i;
                }

                considerationComponents[assignmentIndex++] = (
                    getFulfillmentComponent(item)
                );

                if (item.amount >= amountToCredit) {
                    uint256 amountToAddBack = item.amount - amountToCredit;

                    item.amount = 0;

                    considerationItems.items[firstConsumedItemIndex].amount += (
                        amountToAddBack
                    );

                    considerationItems.totalAmount -= amountToCredit;

                    amountToCredit = 0;
                    break;
                } else {
                    amountToCredit -= item.amount;
                    considerationItems.totalAmount -= item.amount;

                    item.amount = 0;
                }
            }
        }

        // Sanity check
        if (amountToCredit != 0) {
            revert("FulfillmentGeneratorLib: did not credit expected amount");
        }

        // Reduce considerationComponents length based on # elements assigned.
        assembly {
            mstore(considerationComponents, assignmentIndex)
        }

        // Sanity check
        if (
            offerComponents.length == 0 || considerationComponents.length == 0
        ) {
            revert("FulfillmentGeneratorLib: empty match component generated");
        }

        return
            Fulfillment({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents
            });
    }

    function consumeRandomItemsAndGetFulfillment(
        FulfillmentItems memory offerItems,
        FulfillmentItems memory considerationItems,
        uint256 seed
    ) internal pure returns (Fulfillment memory) {
        if (
            offerItems.totalAmount == 0 || considerationItems.totalAmount == 0
        ) {
            revert("FulfillmentGeneratorLib: missing item amounts to consume");
        }

        // Allocate fulfillment component arrays using total items; reduce
        // length after based on the total number of elements assigned to each.
        FulfillmentComponent[] memory offerComponents = (
            new FulfillmentComponent[](offerItems.items.length)
        );

        FulfillmentComponent[] memory considerationComponents = (
            new FulfillmentComponent[](considerationItems.items.length)
        );

        uint256[] memory consumableOfferIndices = new uint256[](
            offerItems.items.length
        );
        uint256[] memory consumableConsiderationIndices = new uint256[](
            considerationItems.items.length
        );

        {
            uint256 assignmentIndex = 0;

            for (uint256 i = 0; i < offerItems.items.length; ++i) {
                FulfillmentItem memory item = offerItems.items[i];
                if (item.amount != 0) {
                    consumableOfferIndices[assignmentIndex++] = i;
                }
            }

            assembly {
                mstore(consumableOfferIndices, assignmentIndex)
            }

            assignmentIndex = 0;

            for (uint256 i = 0; i < considerationItems.items.length; ++i) {
                FulfillmentItem memory item = considerationItems.items[i];
                if (item.amount != 0) {
                    consumableConsiderationIndices[assignmentIndex++] = i;
                }
            }

            assembly {
                mstore(consumableConsiderationIndices, assignmentIndex)
            }

            // Sanity check
            if (
                consumableOfferIndices.length == 0 ||
                consumableConsiderationIndices.length == 0
            ) {
                revert(
                    "FulfillmentGeneratorLib: did not find consumable items"
                );
            }

            LibPRNG.PRNG memory prng;
            prng.seed(seed ^ 0xdd);

            prng.shuffle(consumableOfferIndices);
            prng.shuffle(consumableConsiderationIndices);

            assignmentIndex = prng.uniform(consumableOfferIndices.length) + 1;
            assembly {
                mstore(offerComponents, assignmentIndex)
                mstore(consumableOfferIndices, assignmentIndex)
            }

            assignmentIndex =
                prng.uniform(consumableConsiderationIndices.length) +
                1;
            assembly {
                mstore(considerationComponents, assignmentIndex)
                mstore(consumableConsiderationIndices, assignmentIndex)
            }
        }

        uint256 totalOfferAmount = 0;
        uint256 totalConsiderationAmount = 0;

        for (uint256 i = 0; i < consumableOfferIndices.length; ++i) {
            FulfillmentItem memory item = offerItems.items[
                consumableOfferIndices[i]
            ];

            offerComponents[i] = getFulfillmentComponent(item);

            totalOfferAmount += item.amount;
            item.amount = 0;
        }

        for (uint256 i = 0; i < consumableConsiderationIndices.length; ++i) {
            FulfillmentItem memory item = considerationItems.items[
                consumableConsiderationIndices[i]
            ];

            considerationComponents[i] = getFulfillmentComponent(item);

            totalConsiderationAmount += item.amount;
            item.amount = 0;
        }

        if (totalOfferAmount > totalConsiderationAmount) {
            uint256 remainingAmount = (totalOfferAmount -
                totalConsiderationAmount);

            // add back excess to first offer item
            offerItems.items[consumableOfferIndices[0]].amount += (
                remainingAmount
            );

            offerItems.totalAmount -= totalConsiderationAmount;
            considerationItems.totalAmount -= totalConsiderationAmount;
        } else {
            uint256 remainingAmount = (totalConsiderationAmount -
                totalOfferAmount);

            // add back excess to first consideration item
            considerationItems
                .items[consumableConsiderationIndices[0]]
                .amount += remainingAmount;

            offerItems.totalAmount -= totalOfferAmount;
            considerationItems.totalAmount -= totalOfferAmount;
        }

        return
            Fulfillment({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents
            });
    }

    function emptyFulfillment() internal pure returns (Fulfillment memory) {
        FulfillmentComponent[] memory components;
        return
            Fulfillment({
                offerComponents: components,
                considerationComponents: components
            });
    }

    function getFulfillAvailableFulfillments(
        FulfillAvailableDetails memory fulfillAvailableDetails,
        FulfillmentStrategy memory strategy,
        uint256 seed
    )
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        )
    {
        (
            offerFulfillments,
            considerationFulfillments
        ) = getFulfillmentComponentsUsingMethod(
            fulfillAvailableDetails,
            getFulfillmentMethod(strategy.aggregationStrategy),
            seed
        );

        FulfillAvailableStrategy dropStrategy = (
            strategy.fulfillAvailableStrategy
        );

        if (dropStrategy == FulfillAvailableStrategy.KEEP_ALL) {
            return (offerFulfillments, considerationFulfillments);
        }

        if (dropStrategy == FulfillAvailableStrategy.DROP_SINGLE_OFFER) {
            return (dropSingle(offerFulfillments), considerationFulfillments);
        }

        if (dropStrategy == FulfillAvailableStrategy.DROP_ALL_OFFER) {
            return (new FulfillmentComponent[][](0), considerationFulfillments);
        }

        if (dropStrategy == FulfillAvailableStrategy.DROP_RANDOM_OFFER) {
            return (
                dropRandom(offerFulfillments, seed),
                considerationFulfillments
            );
        }

        if (dropStrategy == FulfillAvailableStrategy.DROP_SINGLE_KEEP_FILTERED) {
            revert(
                "FulfillmentGeneratorLib: DROP_SINGLE_KEEP_FILTERED unsupported"
            );
        }

        if (dropStrategy == FulfillAvailableStrategy.DROP_ALL_KEEP_FILTERED) {
            revert(
                "FulfillmentGeneratorLib: DROP_ALL_KEEP_FILTERED unsupported"
            );
        }

        if (
            dropStrategy == FulfillAvailableStrategy.DROP_RANDOM_KEEP_FILTERED
        ) {
            revert(
                "FulfillmentGeneratorLib: DROP_RANDOM_KEEP_FILTERED unsupported"
            );
        }

        revert("FulfillmentGeneratorLib: unknown fulfillAvailable strategy");
    }

    function dropSingle(
        FulfillmentComponent[][] memory offerFulfillments
    ) internal pure returns (FulfillmentComponent[][] memory) {
        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](offerFulfillments.length)
        );

        uint256 assignmentIndex = 0;

        for (uint256 i = 0; i < offerFulfillments.length; ++i) {
            FulfillmentComponent[] memory components = offerFulfillments[i];
            if (components.length > 1) {
                fulfillments[assignmentIndex++] = components;
            }
        }

        assembly {
            mstore(fulfillments, assignmentIndex)
        }

        return fulfillments;
    }

    function dropRandom(
        FulfillmentComponent[][] memory offerFulfillments,
        uint256 seed
    ) internal pure returns (FulfillmentComponent[][] memory) {
        LibPRNG.PRNG memory prng;
        prng.seed(seed ^ 0xbb);

        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](offerFulfillments.length)
        );

        uint256 assignmentIndex = 0;

        for (uint256 i = 0; i < offerFulfillments.length; ++i) {
            FulfillmentComponent[] memory components = offerFulfillments[i];
            if (prng.uniform(2) == 0) {
                fulfillments[assignmentIndex++] = components;
            }
        }

        assembly {
            mstore(fulfillments, assignmentIndex)
        }

        return fulfillments;
    }

    function getFulfillmentMethod(
        AggregationStrategy aggregationStrategy
    )
        internal
        pure
        returns (
            function(FulfillmentItems[] memory, uint256)
                internal
                pure
                returns (FulfillmentComponent[][] memory)
        )
    {
        if (aggregationStrategy == AggregationStrategy.MAXIMUM) {
            return getMaxFulfillmentComponents;
        } else if (aggregationStrategy == AggregationStrategy.MINIMUM) {
            return getMinFulfillmentComponents;
        } else if (aggregationStrategy == AggregationStrategy.RANDOM) {
            return getRandomFulfillmentComponents;
        } else {
            revert("FulfillmentGeneratorLib: unknown aggregation strategy");
        }
    }

    function getFulfillmentComponentsUsingMethod(
        FulfillAvailableDetails memory fulfillAvailableDetails,
        function(FulfillmentItems[] memory, uint256)
            internal
            pure
            returns (FulfillmentComponent[][] memory) fulfillmentMethod,
        uint256 seed
    )
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        )
    {
        offerFulfillments = fulfillmentMethod(
            fulfillAvailableDetails.items.offer,
            seed
        );

        considerationFulfillments = fulfillmentMethod(
            fulfillAvailableDetails.items.consideration,
            seed
        );
    }

    function getMaxFulfillmentComponents(
        FulfillmentItems[] memory fulfillmentItems,
        uint256 /* seed */
    ) internal pure returns (FulfillmentComponent[][] memory) {
        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](fulfillmentItems.length)
        );

        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            fulfillments[i] = getFulfillmentComponents(
                fulfillmentItems[i].items
            );
        }

        return fulfillments;
    }

    function getRandomFulfillmentComponents(
        FulfillmentItems[] memory fulfillmentItems,
        uint256 seed
    ) internal pure returns (FulfillmentComponent[][] memory) {
        uint256 fulfillmentCount = 0;

        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            fulfillmentCount += fulfillmentItems[i].items.length;
        }

        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](fulfillmentCount)
        );

        LibPRNG.PRNG memory prng;
        prng.seed(seed ^ 0xcc);

        fulfillmentCount = 0;
        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            FulfillmentItem[] memory items = fulfillmentItems[i].items;

            for (uint256 j = 0; j < items.length; ++j) {
                FulfillmentComponent[] memory fulfillment = (
                    consumeRandomFulfillmentItems(items, prng)
                );

                if (fulfillment.length == 0) {
                    break;
                }

                fulfillments[fulfillmentCount++] = fulfillment;
            }
        }

        assembly {
            mstore(fulfillments, fulfillmentCount)
        }

        uint256[] memory componentIndices = new uint256[](fulfillments.length);
        for (uint256 i = 0; i < fulfillments.length; ++i) {
            componentIndices[i] = i;
        }

        prng.shuffle(componentIndices);

        FulfillmentComponent[][] memory shuffledFulfillments = (
            new FulfillmentComponent[][](fulfillments.length)
        );

        for (uint256 i = 0; i < fulfillments.length; ++i) {
            shuffledFulfillments[i] = fulfillments[componentIndices[i]];
        }

        return shuffledFulfillments;
    }

    function consumeRandomFulfillmentItems(
        FulfillmentItem[] memory items,
        LibPRNG.PRNG memory prng
    ) internal pure returns (FulfillmentComponent[] memory) {
        uint256[] memory consumableItemIndices = new uint256[](items.length);
        uint256 assignmentIndex = 0;
        for (uint256 i = 0; i < items.length; ++i) {
            if (items[i].amount != 0) {
                consumableItemIndices[assignmentIndex++] = i;
            }
        }

        if (assignmentIndex == 0) {
            return new FulfillmentComponent[](0);
        }

        assembly {
            mstore(consumableItemIndices, assignmentIndex)
        }

        prng.shuffle(consumableItemIndices);

        assignmentIndex = prng.uniform(assignmentIndex) + 1;

        assembly {
            mstore(consumableItemIndices, assignmentIndex)
        }

        FulfillmentComponent[] memory fulfillment = new FulfillmentComponent[](
            consumableItemIndices.length
        );

        for (uint256 i = 0; i < consumableItemIndices.length; ++i) {
            FulfillmentItem memory item = items[consumableItemIndices[i]];

            fulfillment[i] = getFulfillmentComponent(item);

            item.amount = 0;
        }

        return fulfillment;
    }

    function getMinFulfillmentComponents(
        FulfillmentItems[] memory fulfillmentItems,
        uint256 /* seed */
    ) internal pure returns (FulfillmentComponent[][] memory) {
        uint256 fulfillmentCount = 0;

        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            fulfillmentCount += fulfillmentItems[i].items.length;
        }

        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](fulfillmentCount)
        );

        fulfillmentCount = 0;
        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            FulfillmentItem[] memory items = fulfillmentItems[i].items;

            for (uint256 j = 0; j < items.length; ++j) {
                FulfillmentComponent[] memory fulfillment = (
                    new FulfillmentComponent[](1)
                );
                fulfillment[0] = getFulfillmentComponent(items[j]);
                fulfillments[fulfillmentCount++] = fulfillment;
            }
        }

        return fulfillments;
    }

    function getFulfillmentComponents(
        FulfillmentItem[] memory items
    ) internal pure returns (FulfillmentComponent[] memory) {
        FulfillmentComponent[] memory fulfillment = new FulfillmentComponent[](
            items.length
        );

        for (uint256 i = 0; i < items.length; ++i) {
            fulfillment[i] = getFulfillmentComponent(items[i]);
        }

        return fulfillment;
    }

    function getFulfillmentComponent(
        FulfillmentItem memory item
    ) internal pure returns (FulfillmentComponent memory) {
        return
            FulfillmentComponent({
                orderIndex: item.orderIndex,
                itemIndex: item.itemIndex
            });
    }

    function determineFulfillAvailableEligibility(
        FulfillAvailableDetails memory fulfillAvailableDetails
    ) internal pure returns (bool) {
        bool atLeastOneExecution = false;

        FulfillmentItems[] memory offer = fulfillAvailableDetails.items.offer;
        for (uint256 i = 0; i < offer.length; ++i) {
            FulfillmentItems memory fulfillmentItems = offer[i];
            if (
                fulfillmentItems.itemCategory == ItemCategory.NATIVE ||
                (fulfillmentItems.itemCategory == ItemCategory.ERC721 &&
                    fulfillmentItems.totalAmount != 1)
            ) {
                return false;
            }

            // TODO: Ensure that the same ERC721 item doesn't appear on both the
            // offer side and the consideration side if the recipient does not
            // equal the caller.

            if (!atLeastOneExecution) {
                for (uint256 j = 0; j < fulfillmentItems.items.length; ++j) {
                    FulfillmentItem memory item = fulfillmentItems.items[j];
                    if (item.account != fulfillAvailableDetails.recipient) {
                        atLeastOneExecution = true;
                        break;
                    }
                }
            }
        }

        FulfillmentItems[] memory consideration = (
            fulfillAvailableDetails.items.consideration
        );
        for (uint256 i = 0; i < consideration.length; ++i) {
            FulfillmentItems memory fulfillmentItems = consideration[i];
            if (
                fulfillmentItems.itemCategory == ItemCategory.ERC721 &&
                fulfillmentItems.totalAmount != 1
            ) {
                return false;
            }

            if (!atLeastOneExecution) {
                for (uint256 j = 0; j < fulfillmentItems.items.length; ++j) {
                    FulfillmentItem memory item = fulfillmentItems.items[j];
                    if (item.account != fulfillAvailableDetails.caller) {
                        atLeastOneExecution = true;
                        break;
                    }
                }
            }
        }

        return true;
    }
}

library FulfillmentPrepLib {
    using LibPRNG for LibPRNG.PRNG;
    using LibSort for uint256[];

    struct ItemReference {
        uint256 orderIndex;
        uint256 itemIndex;
        Side side;
        bytes32 dataHash; // itemType ++ token ++ identifier
        bytes32 fullHash; // dataHash ++ [offerer ++ conduitKey || recipient]
        uint256 amount;
        ItemCategory itemCategory;
        address account;
    }

    struct HashCount {
        bytes32 hash;
        uint256 count;
    }

    struct ItemReferenceGroup {
        bytes32 fullHash;
        ItemReference[] references;
        uint256 assigned;
    }

    struct MatchableItemReferenceGroup {
        bytes32 dataHash;
        ItemReferenceGroup[] offerGroups;
        ItemReferenceGroup[] considerationGroups;
        uint256 offerAssigned;
        uint256 considerationAssigned;
    }

    function getFulfillAvailableDetails(
        OrderDetails[] memory orderDetails,
        address recipient,
        address caller,
        uint256 seed
    ) internal pure returns (FulfillAvailableDetails memory) {
        return
            getFulfillAvailableDetailsFromReferences(
                getItemReferences(orderDetails, seed),
                recipient,
                caller
            );
    }

    function getFulfillAvailableDetailsFromReferences(
        ItemReference[] memory itemReferences,
        address recipient,
        address caller
    ) internal pure returns (FulfillAvailableDetails memory) {
        (
            ItemReferenceGroup[] memory offerGroups,
            ItemReferenceGroup[] memory considerationGroups
        ) = splitBySide(bundleByAggregatable(itemReferences));

        return
            getFulfillAvailableDetailsFromGroups(
                offerGroups,
                considerationGroups,
                recipient,
                caller
            );
    }

    function getMatchDetails(
        OrderDetails[] memory orderDetails,
        address recipient,
        uint256 seed
    ) internal pure returns (MatchDetails memory) {
        return
            getMatchDetailsFromReferences(
                getItemReferences(orderDetails, seed),
                recipient
            );
    }

    function getMatchDetailsFromReferences(
        ItemReference[] memory itemReferences,
        address recipient
    ) internal pure returns (MatchDetails memory) {
        return
            getMatchDetailsFromGroups(
                bundleByMatchable(
                    itemReferences,
                    bundleByAggregatable(itemReferences)
                ),
                recipient
            );
    }

    function getItemReferences(
        OrderDetails[] memory orderDetails,
        uint256 seed
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory itemReferences = new ItemReference[](
            getTotalItems(orderDetails)
        );

        uint256 itemReferenceIndex = 0;

        for (
            uint256 orderIndex = 0;
            orderIndex < orderDetails.length;
            ++orderIndex
        ) {
            OrderDetails memory order = orderDetails[orderIndex];
            for (
                uint256 itemIndex = 0;
                itemIndex < order.offer.length;
                ++itemIndex
            ) {
                itemReferences[itemReferenceIndex++] = getItemReference(
                    orderIndex,
                    itemIndex,
                    order.offerer,
                    order.conduitKey,
                    order.offer[itemIndex]
                );
            }
            for (
                uint256 itemIndex = 0;
                itemIndex < order.consideration.length;
                ++itemIndex
            ) {
                itemReferences[itemReferenceIndex++] = getItemReference(
                    orderIndex,
                    itemIndex,
                    order.consideration[itemIndex]
                );
            }
        }

        if (seed == 0) {
            return itemReferences;
        }

        return shuffleItemReferences(itemReferences, seed);
    }

    function bundleByAggregatable(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory groups = allocateItemReferenceGroup(
            getUniqueFullHashes(itemReferences)
        );

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            ItemReference memory itemReference = itemReferences[i];
            for (uint256 j = 0; j < groups.length; ++j) {
                ItemReferenceGroup memory group = groups[j];
                if (group.fullHash == itemReference.fullHash) {
                    group.references[group.assigned++] = itemReference;
                    break;
                }
            }
        }

        // Sanity check: ensure at least one reference item on each group
        for (uint256 i = 0; i < groups.length; ++i) {
            if (groups[i].references.length == 0) {
                revert("FulfillmentPrepLib: missing item reference in group");
            }
        }

        return groups;
    }

    function splitBySide(
        ItemReferenceGroup[] memory groups
    )
        internal
        pure
        returns (ItemReferenceGroup[] memory, ItemReferenceGroup[] memory)
    {
        // NOTE: lengths are overallocated; reduce after assignment.
        ItemReferenceGroup[] memory offerGroups = (
            new ItemReferenceGroup[](groups.length)
        );
        ItemReferenceGroup[] memory considerationGroups = (
            new ItemReferenceGroup[](groups.length)
        );
        uint256 offerItems = 0;
        uint256 considerationItems = 0;

        for (uint256 i = 0; i < groups.length; ++i) {
            ItemReferenceGroup memory group = groups[i];

            if (group.references.length == 0) {
                revert("FulfillmentPrepLib: no items in group");
            }

            Side side = group.references[0].side;

            if (side == Side.OFFER) {
                offerGroups[offerItems++] = copy(group);
            } else if (side == Side.CONSIDERATION) {
                considerationGroups[considerationItems++] = copy(group);
            } else {
                revert("FulfillmentPrepLib: invalid side located (split)");
            }
        }

        // Reduce group lengths based on number of elements assigned.
        assembly {
            mstore(offerGroups, offerItems)
            mstore(considerationGroups, considerationItems)
        }

        return (offerGroups, considerationGroups);
    }

    function getFulfillAvailableDetailsFromGroups(
        ItemReferenceGroup[] memory offerGroups,
        ItemReferenceGroup[] memory considerationGroups,
        address recipient,
        address caller
    ) internal pure returns (FulfillAvailableDetails memory) {
        (
            DualFulfillmentItems memory items,
            uint256 totalItems
        ) = getDualFulfillmentItems(offerGroups, considerationGroups);

        return
            FulfillAvailableDetails({
                items: items,
                caller: caller,
                recipient: recipient,
                totalItems: totalItems
            });
    }

    function getMatchDetailsFromGroups(
        MatchableItemReferenceGroup[] memory matchableGroups,
        address recipient
    ) internal pure returns (MatchDetails memory) {
        DualFulfillmentItems[] memory items = new DualFulfillmentItems[](
            matchableGroups.length
        );

        uint256 totalItems = 0;
        uint256 itemsInGroup = 0;

        for (uint256 i = 0; i < matchableGroups.length; ++i) {
            MatchableItemReferenceGroup memory matchableGroup = (
                matchableGroups[i]
            );

            (items[i], itemsInGroup) = getDualFulfillmentItems(
                matchableGroup.offerGroups,
                matchableGroup.considerationGroups
            );

            totalItems += itemsInGroup;
        }

        return
            MatchDetails({
                items: items,
                context: getFulfillmentMatchContext(items),
                recipient: recipient,
                totalItems: totalItems
            });
    }

    function getFulfillmentMatchContext(
        DualFulfillmentItems[] memory matchItems
    ) internal pure returns (DualFulfillmentMatchContext[] memory) {
        DualFulfillmentMatchContext[] memory context = (
            new DualFulfillmentMatchContext[](matchItems.length)
        );

        for (uint256 i = 0; i < matchItems.length; ++i) {
            bool itemCategorySet = false;
            ItemCategory itemCategory;
            uint256 totalOfferAmount = 0;
            uint256 totalConsiderationAmount = 0;

            FulfillmentItems[] memory offer = matchItems[i].offer;
            for (uint256 j = 0; j < offer.length; ++j) {
                FulfillmentItems memory items = offer[j];

                if (!itemCategorySet) {
                    itemCategory = items.itemCategory;
                } else if (itemCategory != items.itemCategory) {
                    revert(
                        "FulfillmentGeneratorLib: mismatched item categories"
                    );
                }

                totalOfferAmount += items.totalAmount;
            }

            FulfillmentItems[] memory consideration = (
                matchItems[i].consideration
            );
            for (uint256 j = 0; j < consideration.length; ++j) {
                FulfillmentItems memory items = consideration[j];

                if (!itemCategorySet) {
                    itemCategory = items.itemCategory;
                } else if (itemCategory != items.itemCategory) {
                    revert(
                        "FulfillmentGeneratorLib: mismatched item categories"
                    );
                }

                totalConsiderationAmount += items.totalAmount;
            }

            context[i] = DualFulfillmentMatchContext({
                itemCategory: itemCategory,
                totalOfferAmount: totalOfferAmount,
                totalConsiderationAmount: totalConsiderationAmount
            });
        }

        return context;
    }

    function getDualFulfillmentItems(
        ItemReferenceGroup[] memory offerGroups,
        ItemReferenceGroup[] memory considerationGroups
    ) internal pure returns (DualFulfillmentItems memory, uint256 totalItems) {
        DualFulfillmentItems memory items = DualFulfillmentItems({
            offer: new FulfillmentItems[](offerGroups.length),
            consideration: new FulfillmentItems[](considerationGroups.length)
        });

        uint256 currentItems;

        for (uint256 i = 0; i < offerGroups.length; ++i) {
            // XYZ
            (items.offer[i], currentItems) = getFulfillmentItems(
                offerGroups[i].references
            );

            totalItems += currentItems;
        }

        for (uint256 i = 0; i < considerationGroups.length; ++i) {
            (items.consideration[i], currentItems) = getFulfillmentItems(
                considerationGroups[i].references
            );

            totalItems += currentItems;
        }

        return (items, totalItems);
    }

    function getFulfillmentItems(
        ItemReference[] memory itemReferences
    ) internal pure returns (FulfillmentItems memory, uint256 totalItems) {
        // Sanity check: ensure there's at least one reference
        if (itemReferences.length == 0) {
            revert("FulfillmentPrepLib: empty item references supplied");
        }

        ItemReference memory firstReference = itemReferences[0];
        FulfillmentItems memory fulfillmentItems = FulfillmentItems({
            itemCategory: firstReference.itemCategory,
            totalAmount: 0,
            items: new FulfillmentItem[](itemReferences.length)
        });

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            ItemReference memory itemReference = itemReferences[i];
            uint256 amount = itemReference.amount;
            fulfillmentItems.totalAmount += amount;
            fulfillmentItems.items[i] = FulfillmentItem({
                orderIndex: itemReference.orderIndex,
                itemIndex: itemReference.itemIndex,
                amount: amount,
                account: itemReference.account
            });
        }

        totalItems = itemReferences.length;

        return (fulfillmentItems, totalItems);
    }

    function bundleByMatchable(
        ItemReference[] memory itemReferences,
        ItemReferenceGroup[] memory groups
    ) internal pure returns (MatchableItemReferenceGroup[] memory) {
        MatchableItemReferenceGroup[] memory matchableGroups = (
            allocateMatchableItemReferenceGroup(
                getUniqueDataHashes(itemReferences)
            )
        );

        for (uint256 i = 0; i < groups.length; ++i) {
            ItemReferenceGroup memory group = groups[i];

            if (group.references.length == 0) {
                revert(
                    "FulfillmentPrepLib: empty item reference group supplied"
                );
            }

            ItemReference memory firstReference = group.references[0];
            for (uint256 j = 0; j < matchableGroups.length; ++j) {
                MatchableItemReferenceGroup memory matchableGroup = (
                    matchableGroups[j]
                );

                if (matchableGroup.dataHash == firstReference.dataHash) {
                    if (firstReference.side == Side.OFFER) {
                        matchableGroup.offerGroups[
                            matchableGroup.offerAssigned++
                        ] = copy(group);
                    } else if (firstReference.side == Side.CONSIDERATION) {
                        matchableGroup.considerationGroups[
                            matchableGroup.considerationAssigned++
                        ] = copy(group);
                    } else {
                        revert(
                            "FulfillmentPrepLib: invalid side located (match)"
                        );
                    }

                    break;
                }
            }
        }

        // Reduce reference group array lengths based on assigned elements.
        for (uint256 i = 0; i < matchableGroups.length; ++i) {
            MatchableItemReferenceGroup memory group = matchableGroups[i];
            uint256 offerAssigned = group.offerAssigned;
            uint256 considerationAssigned = group.considerationAssigned;
            ItemReferenceGroup[] memory offerGroups = (group.offerGroups);
            ItemReferenceGroup[] memory considerationGroups = (
                group.considerationGroups
            );

            assembly {
                mstore(offerGroups, offerAssigned)
                mstore(considerationGroups, considerationAssigned)
            }
        }

        return matchableGroups;
    }

    function allocateItemReferenceGroup(
        HashCount[] memory hashCount
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory group = new ItemReferenceGroup[](
            hashCount.length
        );

        for (uint256 i = 0; i < hashCount.length; ++i) {
            group[i] = ItemReferenceGroup({
                fullHash: hashCount[i].hash,
                references: new ItemReference[](hashCount[i].count),
                assigned: 0
            });
        }

        return group;
    }

    function allocateMatchableItemReferenceGroup(
        HashCount[] memory hashCount
    ) internal pure returns (MatchableItemReferenceGroup[] memory) {
        MatchableItemReferenceGroup[] memory group = (
            new MatchableItemReferenceGroup[](hashCount.length)
        );

        for (uint256 i = 0; i < hashCount.length; ++i) {
            // NOTE: reference group lengths are overallocated and will need to
            // be reduced once their respective elements have been assigned.
            uint256 count = hashCount[i].count;
            group[i] = MatchableItemReferenceGroup({
                dataHash: hashCount[i].hash,
                offerGroups: new ItemReferenceGroup[](count),
                considerationGroups: new ItemReferenceGroup[](count),
                offerAssigned: 0,
                considerationAssigned: 0
            });
        }

        return group;
    }

    function getUniqueFullHashes(
        ItemReference[] memory itemReferences
    ) internal pure returns (HashCount[] memory) {
        uint256[] memory fullHashes = new uint256[](itemReferences.length);

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            fullHashes[i] = uint256(itemReferences[i].fullHash);
        }

        return getHashCount(fullHashes);
    }

    function getUniqueDataHashes(
        ItemReference[] memory itemReferences
    ) internal pure returns (HashCount[] memory) {
        uint256[] memory dataHashes = new uint256[](itemReferences.length);

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            dataHashes[i] = uint256(itemReferences[i].dataHash);
        }

        return getHashCount(dataHashes);
    }

    function getHashCount(
        uint256[] memory hashes
    ) internal pure returns (HashCount[] memory) {
        if (hashes.length == 0) {
            return new HashCount[](0);
        }

        hashes.sort();

        HashCount[] memory hashCount = new HashCount[](hashes.length);
        hashCount[0] = HashCount({ hash: bytes32(hashes[0]), count: 1 });

        uint256 hashCountPointer = 0;
        for (uint256 i = 1; i < hashes.length; ++i) {
            bytes32 element = bytes32(hashes[i]);

            if (element != hashCount[hashCountPointer].hash) {
                hashCount[++hashCountPointer] = HashCount({
                    hash: element,
                    count: 1
                });
            } else {
                ++hashCount[hashCountPointer].count;
            }
        }

        // update length of the hashCount array based on the hash count pointer.
        assembly {
            mstore(hashCount, add(hashCountPointer, 1))
        }

        return hashCount;
    }

    function getTotalItems(
        OrderDetails[] memory orderDetails
    ) internal pure returns (uint256) {
        uint256 totalItems = 0;

        for (uint256 i = 0; i < orderDetails.length; ++i) {
            totalItems += getTotalItems(orderDetails[i]);
        }

        return totalItems;
    }

    function getTotalItems(
        OrderDetails memory order
    ) internal pure returns (uint256) {
        return (order.offer.length + order.consideration.length);
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        address offerer,
        bytes32 conduitKey,
        SpentItem memory item
    ) internal pure returns (ItemReference memory) {
        return
            getItemReference(
                orderIndex,
                itemIndex,
                Side.OFFER,
                item.itemType,
                item.token,
                item.identifier,
                offerer,
                conduitKey,
                item.amount
            );
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        ReceivedItem memory item
    ) internal pure returns (ItemReference memory) {
        return
            getItemReference(
                orderIndex,
                itemIndex,
                Side.CONSIDERATION,
                item.itemType,
                item.token,
                item.identifier,
                item.recipient,
                bytes32(0),
                item.amount
            );
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        Side side,
        ItemType itemType,
        address token,
        uint256 identifier,
        address account,
        bytes32 conduitKey,
        uint256 amount
    ) internal pure returns (ItemReference memory) {
        bytes32 dataHash = keccak256(
            abi.encodePacked(itemType, token, identifier)
        );

        bytes32 fullHash;
        if (side == Side.OFFER) {
            fullHash = keccak256(
                abi.encodePacked(dataHash, account, conduitKey)
            );
        } else if (side == Side.CONSIDERATION) {
            fullHash = keccak256(abi.encodePacked(dataHash, account));
        } else {
            revert("FulfillmentPrepLib: invalid side located (get reference)");
        }

        ItemCategory itemCategory;
        if (itemType == ItemType.NATIVE) {
            itemCategory = ItemCategory.NATIVE;
        } else if (itemType == ItemType.ERC721) {
            itemCategory = ItemCategory.ERC721;
        } else if (itemType == ItemType.ERC20 || itemType == ItemType.ERC1155) {
            itemCategory = ItemCategory.OTHER;
        } else {
            revert("FulfillmentPrepLib: invalid item type located");
        }

        return
            ItemReference({
                orderIndex: orderIndex,
                itemIndex: itemIndex,
                side: side,
                dataHash: dataHash,
                fullHash: fullHash,
                amount: amount,
                itemCategory: itemCategory,
                account: account
            });
    }

    function shuffleItemReferences(
        ItemReference[] memory itemReferences,
        uint256 seed
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory shuffledItemReferences = new ItemReference[](
            itemReferences.length
        );

        uint256[] memory indices = new uint256[](itemReferences.length);
        for (uint256 i = 0; i < indices.length; ++i) {
            indices[i] = i;
        }

        LibPRNG.PRNG memory prng;
        prng.seed(seed ^ 0xee);
        prng.shuffle(indices);

        for (uint256 i = 0; i < indices.length; ++i) {
            shuffledItemReferences[i] = copy(itemReferences[indices[i]]);
        }

        return shuffledItemReferences;
    }

    function copy(
        ItemReference memory itemReference
    ) internal pure returns (ItemReference memory) {
        return
            ItemReference({
                orderIndex: itemReference.orderIndex,
                itemIndex: itemReference.itemIndex,
                side: itemReference.side,
                dataHash: itemReference.dataHash,
                fullHash: itemReference.fullHash,
                amount: itemReference.amount,
                itemCategory: itemReference.itemCategory,
                account: itemReference.account
            });
    }

    function copy(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory copiedReferences = new ItemReference[](
            itemReferences.length
        );

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            copiedReferences[i] = copy(itemReferences[i]);
        }

        return copiedReferences;
    }

    function copy(
        ItemReferenceGroup memory group
    ) internal pure returns (ItemReferenceGroup memory) {
        return
            ItemReferenceGroup({
                fullHash: group.fullHash,
                references: copy(group.references),
                assigned: group.assigned
            });
    }
}
