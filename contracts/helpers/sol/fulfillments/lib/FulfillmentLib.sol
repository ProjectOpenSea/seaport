// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { LibSort } from "solady/src/utils/LibSort.sol";

import { MatchComponent } from "seaport-sol/SeaportSol.sol";

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

import { OrderDetails } from "./Structs.sol";

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
}

struct MatchDetails {
    DualFulfillmentItems[] items;
    DualFulfillmentMatchContext[] context;
    address recipient;
}

library FulfillmentGeneratorLib {
    using LibPRNG for LibPRNG.PRNG;
    using FulfillmentPrepLib for OrderDetails[];
    using FulfillmentPrepLib for FulfillmentPrepLib.ItemReference[];

    function getDefaultFulfillments(
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
        FulfillmentStrategy memory strategy = FulfillmentStrategy({
            aggregationStrategy: AggregationStrategy.MAXIMUM,
            fulfillAvailableStrategy: FulfillAvailableStrategy.KEEP_ALL,
            matchStrategy: MatchStrategy.MAX_INCLUSION
        });

        uint256 seed = 0;

        return getFulfillments(orderDetails, strategy, recipient, caller, seed);
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
        AggregationStrategy aggregationStrategy = strategy.aggregationStrategy;
        if (aggregationStrategy != AggregationStrategy.MAXIMUM) {
            revert("FulfillmentGeneratorLib: unsupported aggregation strategy");
        }

        FulfillAvailableStrategy fulfillAvailableStrategy = (
            strategy.fulfillAvailableStrategy
        );
        if (fulfillAvailableStrategy != FulfillAvailableStrategy.KEEP_ALL) {
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
        uint256 totalunmetConsiderationComponents
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
        bool eligibleForMatch = totalunmetConsiderationComponents == 0;

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

    function getMatchFulfillments(
        MatchDetails memory matchDetails,
        FulfillmentStrategy memory strategy,
        uint256 /* seed */
    )
        internal
        pure
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        )
    {
        AggregationStrategy aggregationStrategy = strategy.aggregationStrategy;
        MatchStrategy matchStrategy = strategy.matchStrategy;

        if (
            aggregationStrategy == AggregationStrategy.MAXIMUM &&
            matchStrategy == MatchStrategy.MAX_INCLUSION
        ) {
            (
                fulfillments,
                unspentOfferComponents,
                unmetConsiderationComponents
            ) = getMaxInclusionMatchFulfillments(matchDetails);
        } else {
            revert(
                "FulfillmentGeneratorLib: only MAXIMUM+MAX_INCLUSION supported"
            );
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
        uint256 totalUnspentOfferComponents = 0;
        uint256 totalUnmetConsiderationComponents = 0;

        for (uint256 i = 0; i < matchDetails.context.length; ++i) {
            DualFulfillmentMatchContext memory context = (
                matchDetails.context[i]
            );

            if (context.totalConsiderationAmount > context.totalOfferAmount) {
                ++totalUnmetConsiderationComponents;
            } else if (
                context.totalConsiderationAmount < context.totalOfferAmount
            ) {
                ++totalUnspentOfferComponents;
            }
        }

        unspentOfferComponents = (
            new MatchComponent[](totalUnspentOfferComponents)
        );

        unmetConsiderationComponents = (
            new MatchComponent[](totalUnmetConsiderationComponents)
        );

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
    }

    function getMaxInclusionMatchFulfillments(
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
        (
            unspentOfferComponents,
            unmetConsiderationComponents
        ) = getUncoveredComponents(matchDetails);

        // ...
    }

    function getFulfillAvailableFulfillments(
        FulfillAvailableDetails memory fulfillAvailableDetails,
        FulfillmentStrategy memory strategy,
        uint256 /* seed */
    )
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        )
    {
        AggregationStrategy aggregationStrategy = strategy.aggregationStrategy;
        FulfillAvailableStrategy fulfillAvailableStrategy = (
            strategy.fulfillAvailableStrategy
        );

        if (aggregationStrategy == AggregationStrategy.MAXIMUM) {
            offerFulfillments = getMaxFulfillmentComponents(
                fulfillAvailableDetails.items.offer
            );

            considerationFulfillments = getMaxFulfillmentComponents(
                fulfillAvailableDetails.items.consideration
            );
        } else {
            revert("FulfillmentGeneratorLib: only MAXIMUM supported for now");
        }

        if (fulfillAvailableStrategy != FulfillAvailableStrategy.KEEP_ALL) {
            revert("FulfillmentGeneratorLib: only KEEP_ALL supported for now");
        }
    }

    function getMaxFulfillmentComponents(
        FulfillmentItems[] memory fulfillmentItems
    ) internal pure returns (FulfillmentComponent[][] memory) {
        FulfillmentComponent[][] memory fulfillments = (
            new FulfillmentComponent[][](fulfillmentItems.length)
        );

        for (uint256 i = 0; i < fulfillmentItems.length; ++i) {
            FulfillmentItem[] memory items = fulfillmentItems[i].items;

            FulfillmentComponent[] memory fulfillment = (
                new FulfillmentComponent[](items.length)
            );

            for (uint256 j = 0; j < items.length; ++j) {
                FulfillmentItem memory item = items[j];

                fulfillment[j] = FulfillmentComponent({
                    orderIndex: item.orderIndex,
                    itemIndex: item.itemIndex
                });
            }

            fulfillments[i] = fulfillment;
        }

        return fulfillments;
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
        DualFulfillmentItems memory items = getDualFulfillmentItems(
            offerGroups,
            considerationGroups
        );

        return
            FulfillAvailableDetails({
                items: items,
                caller: caller,
                recipient: recipient
            });
    }

    function getMatchDetailsFromGroups(
        MatchableItemReferenceGroup[] memory matchableGroups,
        address recipient
    ) internal pure returns (MatchDetails memory) {
        DualFulfillmentItems[] memory items = new DualFulfillmentItems[](
            matchableGroups.length
        );

        for (uint256 i = 0; i < matchableGroups.length; ++i) {
            MatchableItemReferenceGroup memory matchableGroup = (
                matchableGroups[i]
            );

            items[i] = getDualFulfillmentItems(
                matchableGroup.offerGroups,
                matchableGroup.considerationGroups
            );
        }

        return
            MatchDetails({
                items: items,
                context: getFulfillmentMatchContext(items),
                recipient: recipient
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
    ) internal pure returns (DualFulfillmentItems memory) {
        DualFulfillmentItems memory items = DualFulfillmentItems({
            offer: new FulfillmentItems[](offerGroups.length),
            consideration: new FulfillmentItems[](considerationGroups.length)
        });

        for (uint256 i = 0; i < offerGroups.length; ++i) {
            items.offer[i] = getFulfillmentItems(offerGroups[i].references);
        }

        for (uint256 i = 0; i < considerationGroups.length; ++i) {
            items.consideration[i] = getFulfillmentItems(
                considerationGroups[i].references
            );
        }

        return items;
    }

    function getFulfillmentItems(
        ItemReference[] memory itemReferences
    ) internal pure returns (FulfillmentItems memory) {
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

        return fulfillmentItems;
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

        // update length of the hashCount array.
        assembly {
            mstore(hashCount, hashCountPointer)
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
