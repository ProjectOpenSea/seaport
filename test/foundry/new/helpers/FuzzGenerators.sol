// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import "seaport-sol/SeaportSol.sol";

import { EIP712MerkleTree } from "../../utils/EIP712MerkleTree.sol";

import { ItemType, Side } from "seaport-sol/SeaportEnums.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/StructSpace.sol";

import { CriteriaMetadata } from "./CriteriaResolverHelper.sol";

import {
    Amount,
    BasicOrderCategory,
    BroadOrderType,
    ConduitChoice,
    Criteria,
    EOASignature,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    Tips,
    TokenIndex,
    UnavailableReason,
    Zone,
    ZoneHash
} from "seaport-sol/SpaceEnums.sol";

import {
    FuzzGeneratorContext,
    TestConduit
} from "./FuzzGeneratorContextLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

/**
 *  @dev Generators are responsible for creating guided, random order data for
 *       FuzzEngine tests. Generation happens in two phases: first, we create an
 *       AdvancedOrdersSpace, a nested struct of state enums that represent the
 *       test state itself. Then we walk this generated state struct and build
 *       up an actual array of AdvancedOrders that we can give to Seaport. Each
 *       state enum has its own "generator" library, responsible either for
 *       returning a value or modifying an order according to the selected
 *       state. Generators have access to a PRNG in their context, which they
 *       can use to generate random values.
 */
library TestStateGenerator {
    using PRNGHelpers for FuzzGeneratorContext;
    using MatchComponentType for MatchComponent;

    function generate(
        uint256 totalOrders,
        uint256 maxOfferItemsPerOrder,
        uint256 maxConsiderationItemsPerOrder,
        FuzzGeneratorContext memory context
    ) internal pure returns (AdvancedOrdersSpace memory) {
        context.prng.state = uint256(keccak256(msg.data));

        {
            uint256 basicToggle = context.randRange(0, 10);
            if (basicToggle == 0) {
                context.basicOrderCategory = BasicOrderCategory.LISTING;
            } else if (basicToggle == 1) {
                context.basicOrderCategory = BasicOrderCategory.BID;
            } else {
                context.basicOrderCategory = BasicOrderCategory.NONE;
            }
        }

        bool isMatchable = false;

        uint256 maximumFulfilled = totalOrders;

        if (context.basicOrderCategory != BasicOrderCategory.NONE) {
            totalOrders = 1;
            maxOfferItemsPerOrder = 1;
            if (maxConsiderationItemsPerOrder == 0) {
                maxConsiderationItemsPerOrder = 1;
            }
            maximumFulfilled = 1;
        } else {
            isMatchable = context.randRange(0, 4) == 0 ? true : false;
            if (!isMatchable) {
                maximumFulfilled = context.randRange(1, totalOrders);
            }
        }

        if (maxOfferItemsPerOrder == 0 && maxConsiderationItemsPerOrder == 0) {
            maxOfferItemsPerOrder = context.randRange(0, 1);
            maxConsiderationItemsPerOrder = 1 - maxOfferItemsPerOrder;
        }

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            totalOrders
        );

        bool someAvailable = false;

        for (uint256 i; i < totalOrders; ++i) {
            UnavailableReason reason = (
                context.randRange(0, 1) == 0
                    ? UnavailableReason.AVAILABLE
                    : UnavailableReason(context.randEnum(1, 4))
            );

            if (reason == UnavailableReason.AVAILABLE) {
                someAvailable = true;
            }

            components[i] = OrderComponentsSpace({
                // TODO: Restricted range to 1 and 2 to avoid test contract.
                //       Range should be 0-2.
                offerer: Offerer(context.randEnum(1, 2)),
                // TODO: Ignoring fail for now. Should be 0-2.
                zone: Zone(context.randEnum(0, 1)),
                offer: generateOffer(maxOfferItemsPerOrder, context),
                consideration: generateConsideration(
                    maxConsiderationItemsPerOrder,
                    context,
                    false
                ),
                orderType: BroadOrderType(context.randEnum(0, 2)),
                // TODO: Restricted range to 1 and 2 to avoid unavailable.
                //       Range should be 0-4.
                time: Time(context.randEnum(1, 2)),
                zoneHash: ZoneHash(context.randEnum(0, 2)),
                // TODO: Add more signature methods (restricted to EOA for now)
                signatureMethod: SignatureMethod(0),
                eoaSignatureType: EOASignature(context.randEnum(0, 3)),
                conduit: ConduitChoice(context.randEnum(0, 2)),
                tips: Tips(context.randEnum(0, 1)),
                // TODO: Add more unavailable order reasons (1-5).
                unavailableReason: reason
            });
        }

        if (!someAvailable) {
            components[context.randRange(0, totalOrders - 1)]
                .unavailableReason = UnavailableReason.AVAILABLE;
        }

        return
            AdvancedOrdersSpace({
                orders: components,
                isMatchable: isMatchable,
                maximumFulfilled: maximumFulfilled
            });
    }

    function generateOffer(
        uint256 maxOfferItemsPerOrder,
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItemSpace[] memory) {
        if (context.basicOrderCategory == BasicOrderCategory.NONE) {
            uint256 len = context.randRange(0, maxOfferItemsPerOrder);

            OfferItemSpace[] memory offer = new OfferItemSpace[](len);
            for (uint256 i; i < len; ++i) {
                offer[i] = OfferItemSpace({
                    itemType: ItemType(context.randEnum(0, 5)),
                    tokenIndex: TokenIndex(context.randEnum(0, 1)),
                    // TODO: support wildcard criteria, should be 0-1
                    criteria: Criteria(context.randEnum(0, 0)),
                    // TODO: Fixed amounts only, should be 0-2
                    amount: Amount(context.randEnum(0, 0))
                });
            }

            return offer;
        } else {
            OfferItemSpace[] memory offer = new OfferItemSpace[](1);
            offer[0] = OfferItemSpace({
                itemType: ItemType(
                    context.basicOrderCategory == BasicOrderCategory.LISTING
                        ? context.randEnum(2, 3)
                        : 1
                ),
                tokenIndex: TokenIndex(context.randEnum(0, 2)),
                criteria: Criteria(0),
                // TODO: Fixed amounts only, should be 0-2
                amount: Amount(context.randEnum(0, 0))
            });

            context.basicOfferSpace = offer[0];

            return offer;
        }
    }

    function generateConsideration(
        uint256 maxConsiderationItemsPerOrder,
        FuzzGeneratorContext memory context,
        bool atLeastOne
    ) internal pure returns (ConsiderationItemSpace[] memory) {
        bool isBasic = context.basicOrderCategory != BasicOrderCategory.NONE;

        uint256 len = context.randRange(
            (isBasic || atLeastOne) ? 1 : 0,
            ((isBasic || atLeastOne) && maxConsiderationItemsPerOrder == 0)
                ? 1
                : maxConsiderationItemsPerOrder
        );

        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](len);

        if (!isBasic) {
            for (uint256 i; i < len; ++i) {
                consideration[i] = ConsiderationItemSpace({
                    itemType: ItemType(context.randEnum(0, 5)),
                    tokenIndex: TokenIndex(context.randEnum(0, 2)),
                    // TODO: support wildcard criteria, should be 0-1
                    criteria: Criteria(context.randEnum(0, 0)),
                    // TODO: Fixed amounts only, should be 0-2
                    amount: Amount(context.randEnum(0, 0)),
                    recipient: Recipient(context.randEnum(0, 4))
                });
            }
        } else {
            consideration[0] = ConsiderationItemSpace({
                itemType: ItemType(
                    context.basicOrderCategory == BasicOrderCategory.BID
                        ? context.randEnum(2, 3)
                        : context.randEnum(0, 1)
                ),
                tokenIndex: TokenIndex(context.randEnum(0, 2)),
                criteria: Criteria(0),
                // TODO: Fixed amounts only, should be 0-2
                amount: Amount(context.randEnum(0, 0)),
                recipient: Recipient(0) // Always offerer
            });

            for (uint256 i = 1; i < len; ++i) {
                consideration[i] = ConsiderationItemSpace({
                    itemType: context.basicOfferSpace.itemType,
                    tokenIndex: context.basicOfferSpace.tokenIndex,
                    criteria: Criteria(0),
                    // TODO: Fixed amounts only, should be 0-2
                    // TODO: sum(amounts) must be less than offer amount
                    amount: Amount(context.randEnum(0, 0)),
                    recipient: Recipient(context.randEnum(0, 4))
                });
            }
        }
        return consideration;
    }
}

library AdvancedOrdersSpaceGenerator {
    using AdvancedOrderLib for AdvancedOrder;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace;
    using FuzzInscribers for AdvancedOrder;
    using MatchComponentType for MatchComponent;
    using OrderComponentsSpaceGenerator for OrderComponentsSpace;
    using PRNGHelpers for FuzzGeneratorContext;
    using SignatureGenerator for AdvancedOrder;
    using TimeGenerator for OrderParameters;
    using OfferItemSpaceGenerator for OfferItemSpace;

    function generate(
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal returns (AdvancedOrder[] memory) {
        uint256 len = bound(space.orders.length, 0, 10);
        AdvancedOrder[] memory orders = new AdvancedOrder[](len);

        // Build orders.
        _buildOrders(orders, space, context);

        // Ensure that orders are not entirely empty of items.
        _handleInsertIfAllEmpty(orders, context);
        _handleInsertIfAllFilterable(orders, context, space);

        // Handle match case.
        if (space.isMatchable) {
            _ensureAllAvailable(space);
            _handleInsertIfAllConsiderationEmpty(orders, context);
            _handleInsertIfAllMatchFilterable(orders, context);
            _squareUpRemainders(orders, context);
            space.maximumFulfilled = orders.length;
        } else {
            if (len > 1) {
                _adjustUnavailable(orders, space, context);
            } else {
                _ensureAllAvailable(space);
            }
            _ensureDirectSupport(orders, space, context);
        }

        // Sign orders and add the hashes to the context.
        _signOrders(space, orders, context);

        return orders;
    }

    function _ensureDirectSupport(
        AdvancedOrder[] memory orders,
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal {
        // Ensure no native offer items on non-contract order types
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderParameters memory order = orders[i].parameters;
            if (order.orderType == OrderType.CONTRACT) {
                continue;
            }

            for (uint256 j = 0; j < order.offer.length; ++j) {
                OfferItem memory item = order.offer[j];
                if (item.itemType == ItemType.NATIVE) {
                    // Generate a new offer and make sure it has no native items
                    item = space.orders[i].offer[j].generate(context, true);
                }
            }
        }
    }

    function _ensureAllAvailable(
        AdvancedOrdersSpace memory space
    ) internal pure {
        for (uint256 i = 0; i < space.orders.length; ++i) {
            space.orders[i].unavailableReason = UnavailableReason.AVAILABLE;
        }
    }

    function _buildOrders(
        AdvancedOrder[] memory orders,
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal {
        for (uint256 i; i < orders.length; ++i) {
            OrderParameters memory orderParameters = space.orders[i].generate(
                context,
                false // ensureDirectSupport false: allow native offer items
            );
            orders[i] = OrderLib
                .empty()
                .withParameters(orderParameters)
                .toAdvancedOrder({
                    numerator: 1,
                    denominator: 1,
                    extraData: bytes("")
                });
        }
    }

    function _adjustUnavailable(
        AdvancedOrder[] memory orders,
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal {
        for (uint256 i = 0; i < orders.length; ++i) {
            _adjustUnavailable(
                orders[i],
                space.orders[i].unavailableReason,
                context
            );
        }
    }

    function _adjustUnavailable(
        AdvancedOrder memory order,
        UnavailableReason reason,
        FuzzGeneratorContext memory context
    ) internal {
        OrderParameters memory parameters = order.parameters;
        // UnavailableReason.AVAILABLE => take no action
        if (reason == UnavailableReason.EXPIRED) {
            parameters = parameters.withGeneratedTime(
                Time(context.randEnum(3, 4)),
                context
            );
        } else if (reason == UnavailableReason.STARTS_IN_FUTURE) {
            parameters = parameters.withGeneratedTime(
                Time.STARTS_IN_FUTURE,
                context
            );
        } else if (reason == UnavailableReason.CANCELLED) {
            order.inscribeOrderStatusCanceled(true, context.seaport);
        } else if (reason == UnavailableReason.ALREADY_FULFILLED) {
            order.inscribeOrderStatusNumeratorAndDenominator(
                1,
                1,
                context.seaport
            );
        } else if (reason == UnavailableReason.GENERATE_ORDER_FAILURE) {
            // TODO: update offerer + order type (point to bad contract offerer)
            revert(
                "FuzzGenerators: no support for failing contract order fuzzing"
            );
        }
    }

    /**
     * @dev This function gets the remainders from the match and inserts them
     *      into the orders. This is done to ensure that the orders are
     *      matchable. If there are consideration remainders, they are inserted
     *      into the orders on the offer side.
     */
    function _squareUpRemainders(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        MatchComponent[] memory remainders;
        {
            CriteriaResolver[] memory resolvers = context
                .testHelpers
                .criteriaResolverHelper()
                .deriveCriteriaResolvers(orders);
            OrderDetails[] memory details = _getOrderDetails(orders, resolvers);
            // Get the remainders.
            (, , remainders) = context.testHelpers.getMatchedFulfillments(
                details
            );
        }

        // Iterate over the remainders and insert them into the orders.
        for (uint256 i = 0; i < remainders.length; ++i) {
            // Unpack the remainder from the MatchComponent into its
            // constituent parts.
            (uint256 amount, uint8 orderIndex, uint8 itemIndex) = remainders[i]
                .unpack();

            // Get the consideration item with the remainder.
            ConsiderationItem memory item = orders[orderIndex]
                .parameters
                .consideration[itemIndex];

            // Pick a random order to insert the remainder into.
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );

            // Create a new offer array with room for the remainder.
            OfferItem[] memory newOffer = new OfferItem[](
                orders[orderInsertionIndex].parameters.offer.length + 1
            );

            // If the targeted order has no offer, just add the remainder to the
            // new offer.
            if (orders[orderInsertionIndex].parameters.offer.length == 0) {
                newOffer[0] = OfferItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifierOrCriteria,
                    startAmount: uint256(amount),
                    endAmount: uint256(amount)
                });
            } else {
                // If the targeted order has an offer, pick a random index to
                // insert the remainder into.
                uint256 itemInsertionIndex = context.randRange(
                    0,
                    orders[orderInsertionIndex].parameters.offer.length - 1
                );

                // Copy the offer items from the targeted order into the new
                // offer array.  This loop handles everything before the
                // insertion index.
                for (uint256 j = 0; j < itemInsertionIndex; ++j) {
                    newOffer[j] = orders[orderInsertionIndex].parameters.offer[
                        j
                    ];
                }

                // Insert the remainder into the new offer array at the
                // insertion index.
                newOffer[itemInsertionIndex] = OfferItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifierOrCriteria,
                    startAmount: uint256(amount),
                    endAmount: uint256(amount)
                });

                // Copy the offer items after the insertion index into the new
                // offer array.
                for (
                    uint256 j = itemInsertionIndex + 1;
                    j < newOffer.length;
                    ++j
                ) {
                    newOffer[j] = orders[orderInsertionIndex].parameters.offer[
                        j - 1
                    ];
                }
            }

            // Replace the offer in the targeted order with the new offer.
            orders[orderInsertionIndex].parameters.offer = newOffer;
        }

        // TODO: remove this check once high confidence in the mechanic has been
        // established (this just fails fast to rule out downstream issues)
        if (remainders.length > 0) {
            CriteriaResolver[] memory resolvers = context
                .testHelpers
                .criteriaResolverHelper()
                .deriveCriteriaResolvers(orders);
            OrderDetails[] memory details = _getOrderDetails(orders, resolvers);
            // Get the remainders.
            (, , remainders) = context.testHelpers.getMatchedFulfillments(
                details
            );

            if (remainders.length > 0) {
                revert("FuzzGenerators: could not satisfy remainders");
            }
        }
    }

    function _getOrderDetails(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (OrderDetails[] memory) {
        OrderDetails[] memory orderDetails = new OrderDetails[](
            advancedOrders.length
        );
        for (uint256 i = 0; i < advancedOrders.length; i++) {
            orderDetails[i] = toOrderDetails(
                advancedOrders[i],
                i,
                criteriaResolvers
            );
        }
        return orderDetails;
    }

    function toOrderDetails(
        AdvancedOrder memory order,
        uint256 orderIndex,
        CriteriaResolver[] memory resolvers
    ) internal view returns (OrderDetails memory) {
        (
            SpentItem[] memory offer,
            ReceivedItem[] memory consideration
        ) = getSpentAndReceivedItems(
                order.parameters,
                order.numerator,
                order.denominator,
                orderIndex,
                resolvers
            );
        return
            OrderDetails({
                offerer: order.parameters.offerer,
                conduitKey: order.parameters.conduitKey,
                offer: offer,
                consideration: consideration
            });
    }

    function getSpentAndReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator,
        uint256 orderIndex,
        CriteriaResolver[] memory criteriaResolvers
    )
        private
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        spent = getSpentItems(parameters, numerator, denominator);
        received = getReceivedItems(parameters, numerator, denominator);

        applyCriteriaResolvers(spent, received, orderIndex, criteriaResolvers);
    }

    function applyCriteriaResolvers(
        SpentItem[] memory spentItems,
        ReceivedItem[] memory receivedItems,
        uint256 orderIndex,
        CriteriaResolver[] memory criteriaResolvers
    ) private pure {
        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            CriteriaResolver memory resolver = criteriaResolvers[i];
            if (resolver.orderIndex != orderIndex) {
                continue;
            }
            if (resolver.side == Side.OFFER) {
                SpentItem memory item = spentItems[resolver.index];
                item.itemType = convertCriteriaItemType(item.itemType);
                item.identifier = resolver.identifier;
            } else {
                ReceivedItem memory item = receivedItems[resolver.index];
                item.itemType = convertCriteriaItemType(item.itemType);
                item.identifier = resolver.identifier;
            }
        }
    }

    function convertCriteriaItemType(
        ItemType itemType
    ) internal pure returns (ItemType) {
        if (itemType == ItemType.ERC721_WITH_CRITERIA) {
            return ItemType.ERC721;
        } else if (itemType == ItemType.ERC1155_WITH_CRITERIA) {
            return ItemType.ERC1155;
        } else {
            revert(
                "ZoneParametersLib: amount deriver helper resolving non criteria item type"
            );
        }
    }

    function getSpentItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem[] memory) {
        return
            getSpentItems(
                parameters.offer,
                parameters.startTime,
                parameters.endTime,
                numerator,
                denominator
            );
    }

    function getReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem[] memory) {
        return
            getReceivedItems(
                parameters.consideration,
                parameters.startTime,
                parameters.endTime,
                numerator,
                denominator
            );
    }

    function getSpentItems(
        OfferItem[] memory items,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem[] memory) {
        SpentItem[] memory spentItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            spentItems[i] = getSpentItem(
                items[i],
                startTime,
                endTime,
                numerator,
                denominator
            );
        }
        return spentItems;
    }

    function getReceivedItems(
        ConsiderationItem[] memory considerationItems,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem[] memory) {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            considerationItems.length
        );
        for (uint256 i = 0; i < considerationItems.length; i++) {
            receivedItems[i] = getReceivedItem(
                considerationItems[i],
                startTime,
                endTime,
                numerator,
                denominator
            );
        }
        return receivedItems;
    }

    function getSpentItem(
        OfferItem memory item,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem memory spent) {
        spent = SpentItem({
            itemType: item.itemType,
            token: item.token,
            identifier: item.identifierOrCriteria,
            amount: _applyFraction({
                numerator: numerator,
                denominator: denominator,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                startTime: startTime,
                endTime: endTime,
                roundUp: false
            })
        });
    }

    function getReceivedItem(
        ConsiderationItem memory considerationItem,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem memory received) {
        received = ReceivedItem({
            itemType: considerationItem.itemType,
            token: considerationItem.token,
            identifier: considerationItem.identifierOrCriteria,
            amount: _applyFraction({
                numerator: numerator,
                denominator: denominator,
                startAmount: considerationItem.startAmount,
                endAmount: considerationItem.endAmount,
                startTime: startTime,
                endTime: endTime,
                roundUp: true
            }),
            recipient: considerationItem.recipient
        });
    }

    function _applyFraction(
        uint256 startAmount,
        uint256 endAmount,
        uint256 numerator,
        uint256 denominator,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (startAmount == endAmount) {
            // Apply fraction to end amount.
            amount = _getFraction(numerator, denominator, endAmount);
        } else {
            // Otherwise, apply fraction to both and interpolated final amount.
            amount = _locateCurrentAmount(
                _getFraction(numerator, denominator, startAmount),
                _getFraction(numerator, denominator, endAmount),
                startTime,
                endTime,
                roundUp
            );
        }
    }

    function _getFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        bool failure = false;

        // Ensure fraction can be applied to the value with no remainder. Note
        // that the denominator cannot be zero.
        assembly {
            // Ensure new value contains no remainder via mulmod operator.
            // Credit to @hrkrshnn + @axic for proposing this optimal solution.
            if mulmod(value, numerator, denominator) {
                failure := true
            }
        }

        if (failure) {
            revert("ZoneParametersLib: bad fraction");
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * numerator;

        // Divide and check for remainder. Note that denominator cannot be zero.
        assembly {
            // Perform division without zero check.
            newValue := div(valueTimesNumerator, denominator)
        }
    }

    function _locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            // Declare variables to derive in the subsequent unchecked scope.
            uint256 duration;
            uint256 elapsed;
            uint256 remaining;

            // Skip underflow checks as startTime <= block.timestamp < endTime.
            unchecked {
                // Derive the duration for the order and place it on the stack.
                duration = endTime - startTime;

                // Derive time elapsed since the order started & place on stack.
                elapsed = block.timestamp - startTime;

                // Derive time remaining until order expires and place on stack.
                remaining = duration - elapsed;
            }

            // Aggregate new amounts weighted by time with rounding factor.
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed));

            // Use assembly to combine operations and skip divide-by-zero check.
            assembly {
                // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
                // amount is set to zero if totalBeforeDivision is zero,
                // as intermediate overflow can occur if it is zero.
                amount := mul(
                    iszero(iszero(totalBeforeDivision)),
                    // Subtract 1 from the numerator and add 1 to the result if
                    // roundUp is true to get the proper rounding direction.
                    // Division is performed with no zero check as duration
                    // cannot be zero as long as startTime < endTime.
                    add(
                        div(sub(totalBeforeDivision, roundUp), duration),
                        roundUp
                    )
                )
            }

            // Return the current amount.
            return amount;
        }

        // Return the original amount as startAmount == endAmount.
        return endAmount;
    }

    function _handleInsertIfAllEmpty(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        bool allEmpty = true;

        // Iterate over the orders and check if they have any offer or
        // consideration items in them.  As soon as we find one that does, set
        // allEmpty to false and break out of the loop.
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderParameters memory orderParams = orders[i].parameters;
            if (
                orderParams.offer.length + orderParams.consideration.length > 0
            ) {
                allEmpty = false;
                break;
            }
        }

        // If all the orders are empty, insert a consideration item into a
        // random order.
        if (allEmpty) {
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );
            OrderParameters memory orderParams = orders[orderInsertionIndex]
                .parameters;

            ConsiderationItem[] memory consideration = new ConsiderationItem[](
                1
            );
            consideration[0] = TestStateGenerator
            .generateConsideration(1, context, true)[0].generate(
                    context,
                    orderParams.offerer
                );

            orderParams.consideration = consideration;
        }
    }

    function _handleInsertIfAllConsiderationEmpty(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        bool allEmpty = true;

        // Iterate over the orders and check if they have any consideration
        // items in them. As soon as we find one that does, set allEmpty to
        // false and break out of the loop.
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderParameters memory orderParams = orders[i].parameters;
            if (orderParams.consideration.length > 0) {
                allEmpty = false;
                break;
            }
        }

        // If all the orders are empty, insert a consideration item into a
        // random order.
        if (allEmpty) {
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );
            OrderParameters memory orderParams = orders[orderInsertionIndex]
                .parameters;

            ConsiderationItem[] memory consideration = new ConsiderationItem[](
                1
            );
            consideration[0] = TestStateGenerator
            .generateConsideration(1, context, true)[0].generate(
                    context,
                    orderParams.offerer
                );

            orderParams.consideration = consideration;
        }
    }

    /**
     * @dev Handle orders with only filtered executions. Note: technically
     *      orders with no unfiltered consideration items can still be called in
     *      some cases via fulfillAvailable as long as there are offer items
     *      that don't have to be filtered as well. Also note that this does not
     *      account for unfilterable matchOrders combinations yet. But the
     *      baseline behavior is that an order with no explicit executions,
     *      Seaport will revert.
     */
    function _handleInsertIfAllFilterable(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context,
        AdvancedOrdersSpace memory space
    ) internal {
        bool allFilterable = true;
        address caller = context.caller == address(0)
            ? address(this)
            : context.caller;

        // Iterate over the orders and check if there's a single instance of a
        // non-filterable consideration item. If there is, set allFilterable to
        // false and break out of the loop. Skip unavailable orders as well.
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderParameters memory order = orders[i].parameters;

            if (
                space.orders[i].unavailableReason != UnavailableReason.AVAILABLE
            ) {
                continue;
            }

            for (uint256 j = 0; j < order.consideration.length; ++j) {
                ConsiderationItem memory item = order.consideration[j];

                if (item.recipient != caller) {
                    allFilterable = false;
                    break;
                }
            }

            if (!allFilterable) {
                break;
            }
        }

        // If they're all filterable, then add a consideration item to one of
        // the orders and ensure that it is available.
        if (allFilterable) {
            OrderParameters memory orderParams;

            // Pick a random order to insert the consideration item into and
            // iterate from that index to the end of the orders array. At the
            // end of the loop, start back at the beginning
            // (orders[orderInsertionIndex % orders.length]) and iterate on. As
            // soon as an order with consideration items is found, break out of
            // the loop. The orderParams variable will be set to the order with
            // consideration items. There's chance that no order will have
            // consideration items, in which case the orderParams variable will
            // be set to those of the last order iterated over.
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );
            for (
                ;
                orderInsertionIndex < orders.length * 2;
                ++orderInsertionIndex
            ) {
                orderParams = orders[orderInsertionIndex % orders.length]
                    .parameters;

                if (orderParams.consideration.length != 0) {
                    break;
                }
            }

            // If there are no consideration items in any of the orders, then
            // add a consideration item to a random order.
            if (orderParams.consideration.length == 0) {
                // Pick a random order to insert the consideration item into.
                orderInsertionIndex = context.randRange(0, orders.length - 1);

                // Set the orderParams variable to the parameters of the order
                // that was picked.
                orderParams = orders[orderInsertionIndex].parameters;

                // Provision a new consideration item array with a single
                // element.
                ConsiderationItem[]
                    memory consideration = new ConsiderationItem[](1);

                // Generate a consideration item and add it to the consideration
                // item array.  The `true` argument indicates that the
                // consideration item will be unfilterable.
                consideration[0] = TestStateGenerator
                .generateConsideration(1, context, true)[0].generate(
                        context,
                        orderParams.offerer
                    );

                // Set the consideration item array on the order parameters.
                orderParams.consideration = consideration;
            }

            space
                .orders[orderInsertionIndex % orders.length]
                .unavailableReason = UnavailableReason.AVAILABLE;

            // Pick a random consideration item to modify.
            uint256 itemIndex = context.randRange(
                0,
                orderParams.consideration.length - 1
            );

            // Make the recipient an address other than the caller so that
            // it produces a non-filterable transfer.
            if (caller != context.alice.addr) {
                orderParams.consideration[itemIndex].recipient = payable(
                    context.alice.addr
                );
            } else {
                orderParams.consideration[itemIndex].recipient = payable(
                    context.bob.addr
                );
            }
        }
    }

    // TODO: figure out a better way to do this; right now it always inserts a
    // random consideration item on some order with a recipient that is never
    // used for offerers
    function _handleInsertIfAllMatchFilterable(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        OrderParameters memory orderParams;

        // Pick a random order to insert the consideration item into and
        // iterate from that index to the end of the orders array. At the
        // end of the loop, start back at the beginning
        // (orders[orderInsertionIndex % orders.length]) and iterate on. As
        // soon as an order with consideration items is found, break out of
        // the loop. The orderParams variable will be set to the order with
        // consideration items. There's chance that no order will have
        // consideration items, in which case the orderParams variable will
        // be set to those of the last order iterated over.
        for (
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );
            orderInsertionIndex < orders.length * 2;
            ++orderInsertionIndex
        ) {
            orderParams = orders[orderInsertionIndex % orders.length]
                .parameters;

            if (orderParams.consideration.length != 0) {
                break;
            }
        }

        // If there are no consideration items in any of the orders, then
        // add a consideration item to a random order.
        if (orderParams.consideration.length == 0) {
            // Pick a random order to insert the consideration item into.
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );

            // Set the orderParams variable to the parameters of the order
            // that was picked.
            orderParams = orders[orderInsertionIndex].parameters;

            // Provision a new consideration item array with a single
            // element.
            ConsiderationItem[] memory consideration = new ConsiderationItem[](
                1
            );

            // Generate a consideration item and add it to the consideration
            // item array.  The `true` argument indicates that the
            // consideration item will be unfilterable.
            consideration[0] = TestStateGenerator
            .generateConsideration(1, context, true)[0].generate(
                    context,
                    orderParams.offerer
                );

            // Set the consideration item array on the order parameters.
            orderParams.consideration = consideration;
        }

        // Pick a random consideration item to modify.
        uint256 itemIndex = context.randRange(
            0,
            orderParams.consideration.length - 1
        );

        // Make the recipient an address other than any offerer so that
        // it produces a non-filterable transfer.
        orderParams.consideration[itemIndex].recipient = payable(
            context.dillon.addr
        );
    }

    function _signOrders(
        AdvancedOrdersSpace memory space,
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        // Reset the order hashes array to the correct length.
        context.orderHashes = new bytes32[](orders.length);

        // Iterate over the orders and sign them.
        for (uint256 i = 0; i < orders.length; ++i) {
            // Set up variables.
            AdvancedOrder memory order = orders[i];
            bytes32 orderHash;

            {
                // Get the counter for the offerer.
                uint256 counter = context.seaport.getCounter(
                    order.parameters.offerer
                );

                // Convert the order parameters to order components.
                OrderComponents memory components = (
                    order.parameters.toOrderComponents(counter)
                );

                // Get the length of the consideration array.
                uint256 lengthWithTips = components.consideration.length;

                // Get a reference to the consideration array.
                ConsiderationItem[] memory considerationSansTips = (
                    components.consideration
                );

                // Get the length of the consideration array without tips.
                uint256 lengthSansTips = (
                    order.parameters.totalOriginalConsiderationItems
                );

                // Set proper length of the considerationSansTips array.
                assembly {
                    mstore(considerationSansTips, lengthSansTips)
                }

                // Get the order hash using the tweaked components.
                orderHash = context.seaport.getOrderHash(components);

                // Restore length of the considerationSansTips array.
                assembly {
                    mstore(considerationSansTips, lengthWithTips)
                }

                // Set the order hash in the context.
                context.orderHashes[i] = orderHash;
            }

            // Replace the unsigned order with a signed order.
            orders[i] = order.withGeneratedSignature(
                space.orders[i].signatureMethod,
                space.orders[i].eoaSignatureType,
                space.orders[i].offerer,
                orderHash,
                context
            );
        }
    }

    function _hasInvalidNativeOfferItems(
        AdvancedOrder[] memory orders
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderParameters memory orderParams = orders[i].parameters;
            if (orderParams.orderType == OrderType.CONTRACT) {
                continue;
            }

            for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                OfferItem memory item = orderParams.offer[j];

                if (item.itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        return false;
    }
}

library OrderComponentsSpaceGenerator {
    using OrderParametersLib for OrderParameters;

    using ConduitGenerator for ConduitChoice;
    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace[];
    using OffererGenerator for Offerer;
    using OfferItemSpaceGenerator for OfferItemSpace[];
    using PRNGHelpers for FuzzGeneratorContext;
    using TimeGenerator for OrderParameters;
    using ZoneGenerator for OrderParameters;

    function generate(
        OrderComponentsSpace memory space,
        FuzzGeneratorContext memory context,
        bool ensureDirectSupport
    ) internal returns (OrderParameters memory) {
        OrderParameters memory params;
        {
            address offerer = space.offerer.generate(context);

            params = OrderParametersLib
                .empty()
                .withOfferer(offerer)
                .withOffer(space.offer.generate(context, ensureDirectSupport))
                .withConsideration(
                    space.consideration.generate(context, offerer)
                )
                .withConduitKey(space.conduit.generate(context).key);
        }

        // Choose an arbitrary number of tips based on the tip space
        // (TODO: refactor as a library function)
        params.totalOriginalConsiderationItems = (
            (space.tips == Tips.TIPS && params.consideration.length != 0)
                ? params.consideration.length -
                    context.randRange(1, params.consideration.length)
                : params.consideration.length
        );

        return
            params
                .withGeneratedTime(space.time, context)
                .withGeneratedZone(space.zone, context)
                .withSalt(context.randRange(0, type(uint256).max));
    }
}

library ConduitGenerator {
    function generate(
        ConduitChoice conduit,
        FuzzGeneratorContext memory context
    ) internal pure returns (TestConduit memory) {
        if (conduit == ConduitChoice.NONE) {
            return
                TestConduit({
                    key: bytes32(0),
                    addr: address(context.seaport)
                });
        } else if (conduit == ConduitChoice.ONE) {
            return context.conduits[0];
        } else if (conduit == ConduitChoice.TWO) {
            return context.conduits[1];
        } else {
            revert("ConduitGenerator: invalid Conduit index");
        }
    }
}

library ZoneGenerator {
    using PRNGHelpers for FuzzGeneratorContext;
    using OrderParametersLib for OrderParameters;

    function withGeneratedZone(
        OrderParameters memory order,
        Zone zone,
        FuzzGeneratorContext memory context
    ) internal pure returns (OrderParameters memory) {
        if (zone == Zone.NONE) {
            return order;
        } else if (zone == Zone.PASS) {
            // generate random zone hash
            bytes32 zoneHash = bytes32(context.randRange(0, type(uint256).max));
            return
                order
                    .withOrderType(OrderType.FULL_RESTRICTED)
                    .withZone(address(context.validatorZone))
                    .withZoneHash(zoneHash);
        } else {
            revert("ZoneGenerator: invalid Zone");
        }
    }
}

library OfferItemSpaceGenerator {
    using OfferItemLib for OfferItem;

    using AmountGenerator for OfferItem;
    using CriteriaGenerator for OfferItem;
    using TokenIndexGenerator for TokenIndex;
    using PRNGHelpers for FuzzGeneratorContext;

    function generate(
        OfferItemSpace[] memory space,
        FuzzGeneratorContext memory context,
        bool ensureDirectSupport
    ) internal returns (OfferItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        OfferItem[] memory offerItems = new OfferItem[](len);

        for (uint256 i; i < len; ++i) {
            offerItems[i] = generate(space[i], context, ensureDirectSupport);
        }
        return offerItems;
    }

    function generate(
        OfferItemSpace memory space,
        FuzzGeneratorContext memory context,
        bool ensureDirectSupport
    ) internal returns (OfferItem memory) {
        ItemType itemType = space.itemType;

        if (ensureDirectSupport && itemType == ItemType.NATIVE) {
            itemType = ItemType(context.randRange(1, 5));
        }

        return
            OfferItemLib
                .empty()
                .withItemType(itemType)
                .withToken(space.tokenIndex.generate(itemType, context))
                .withGeneratedAmount(space.amount, context)
                .withGeneratedIdentifierOrCriteria(
                    space.itemType,
                    space.criteria,
                    context
                );
    }
}

library ConsiderationItemSpaceGenerator {
    using ConsiderationItemLib for ConsiderationItem;

    using AmountGenerator for ConsiderationItem;
    using CriteriaGenerator for ConsiderationItem;
    using RecipientGenerator for Recipient;
    using TokenIndexGenerator for TokenIndex;

    function generate(
        ConsiderationItemSpace[] memory space,
        FuzzGeneratorContext memory context,
        address offerer
    ) internal returns (ConsiderationItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            len
        );

        for (uint256 i; i < len; ++i) {
            considerationItems[i] = generate(space[i], context, offerer);
        }

        return considerationItems;
    }

    function generate(
        ConsiderationItemSpace memory space,
        FuzzGeneratorContext memory context,
        address offerer
    ) internal returns (ConsiderationItem memory) {
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(space.itemType)
            .withToken(space.tokenIndex.generate(space.itemType, context))
            .withGeneratedAmount(space.amount, context);

        return
            considerationItem
                .withRecipient(space.recipient.generate(context, offerer))
                .withGeneratedIdentifierOrCriteria(
                    space.itemType,
                    space.criteria,
                    context
                );
    }
}

library SignatureGenerator {
    using LibPRNG for LibPRNG.PRNG;

    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;

    using FuzzHelpers for AdvancedOrder;
    using OffererGenerator for Offerer;

    function withGeneratedSignature(
        AdvancedOrder memory order,
        SignatureMethod method,
        EOASignature eoaSignatureType,
        Offerer offerer,
        bytes32 orderHash,
        FuzzGeneratorContext memory context
    ) internal returns (AdvancedOrder memory) {
        if (method == SignatureMethod.EOA) {
            bytes32 digest;
            uint8 v;
            bytes32 r;
            bytes32 s;
            bytes memory signature;

            uint256 offererKey = offerer.getKey(context);

            if (eoaSignatureType == EOASignature.STANDARD) {
                digest = _getDigest(orderHash, context);
                (v, r, s) = context.vm.sign(offererKey, digest);
                signature = abi.encodePacked(r, s, v);

                _checkSig(digest, v, r, s, offerer, context);
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.EIP2098) {
                digest = _getDigest(orderHash, context);
                (v, r, s) = context.vm.sign(offererKey, digest);

                {
                    uint256 yParity;
                    if (v == 27) {
                        yParity = 0;
                    } else {
                        yParity = 1;
                    }
                    uint256 yParityAndS = (yParity << 255) | uint256(s);
                    signature = abi.encodePacked(r, yParityAndS);
                }

                _checkSig(digest, v, r, s, offerer, context);
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.BULK) {
                signature = _getBulkSig(order, offererKey, false, context);
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.BULK2098) {
                signature = _getBulkSig(order, offererKey, true, context);
                return order.withSignature(signature);
            } else {
                revert("SignatureGenerator: Invalid EOA signature type");
            }
        } else if (method == SignatureMethod.VALIDATE) {
            revert("Validate not implemented");
        } else if (method == SignatureMethod.EIP1271) {
            revert("EIP1271 not implemented");
        } else if (method == SignatureMethod.CONTRACT) {
            revert("Contract not implemented");
        } else if (method == SignatureMethod.SELF_AD_HOC) {
            revert("Self ad hoc not implemented");
        } else {
            revert("SignatureGenerator: Invalid signature method");
        }
    }

    function _getDigest(
        bytes32 orderHash,
        FuzzGeneratorContext memory context
    ) internal view returns (bytes32 digest) {
        (, bytes32 domainSeparator, ) = context.seaport.information();
        bytes memory message = abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        );
        digest = keccak256(message);
    }

    function _getBulkSig(
        AdvancedOrder memory order,
        uint256 offererKey,
        bool useEIP2098,
        FuzzGeneratorContext memory context
    ) internal returns (bytes memory signature) {
        EIP712MerkleTree merkleTree = new EIP712MerkleTree();

        // Pass the hash into `signSparseBulkOrder` instead of the order
        // components, since we need to neutralize the tip for validation to
        // work.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);
        uint256 height = bound(context.prng.next(), 1, 24);
        uint256 index = bound(context.prng.next(), 0, 2 ** height - 1);

        signature = merkleTree.signSparseBulkOrder(
            context.seaport,
            offererKey,
            orderHash,
            height,
            uint24(index),
            useEIP2098
        );
    }

    function _checkSig(
        bytes32 digest,
        uint8 v,
        bytes32 r,
        bytes32 s,
        Offerer offerer,
        FuzzGeneratorContext memory context
    ) internal pure {
        address recovered = ecrecover(digest, v, r, s);
        if (recovered != offerer.generate(context) || recovered == address(0)) {
            revert("SignatureGenerator: Invalid signature");
        }
    }
}

library TokenIndexGenerator {
    function generate(
        TokenIndex tokenIndex,
        ItemType itemType,
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        if (itemType == ItemType.NATIVE) {
            return address(0);
        }

        uint256 i = uint8(tokenIndex);

        // TODO: missing native tokens
        if (itemType == ItemType.ERC20) {
            return address(context.erc20s[i]);
        } else if (
            itemType == ItemType.ERC721 ||
            itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            return address(context.erc721s[i]);
        } else if (
            itemType == ItemType.ERC1155 ||
            itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            return address(context.erc1155s[i]);
        } else {
            revert("TokenIndexGenerator: Invalid itemType");
        }
    }
}

library TimeGenerator {
    using LibPRNG for LibPRNG.PRNG;
    using OrderParametersLib for OrderParameters;

    function withGeneratedTime(
        OrderParameters memory order,
        Time time,
        FuzzGeneratorContext memory context
    ) internal pure returns (OrderParameters memory) {
        uint256 low;
        uint256 high;

        if (time == Time.STARTS_IN_FUTURE) {
            uint256 a = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint256).max
            );
            uint256 b = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint256).max
            );
            low = a < b ? a : b;
            high = a > b ? a : b;
        }
        if (time == Time.EXACT_START) {
            low = context.timestamp;
            high = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint256).max
            );
        }
        if (time == Time.ONGOING) {
            low = bound(context.prng.next(), 0, context.timestamp - 1);
            high = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint256).max
            );
        }
        if (time == Time.EXACT_END) {
            low = bound(context.prng.next(), 0, context.timestamp - 1);
            high = context.timestamp;
        }
        if (time == Time.EXPIRED) {
            uint256 a = bound(context.prng.next(), 0, context.timestamp - 1);
            uint256 b = bound(context.prng.next(), 0, context.timestamp - 1);
            low = a < b ? a : b;
            high = a > b ? a : b;
        }
        return order.withStartTime(low).withEndTime(high);
    }
}

library AmountGenerator {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    using LibPRNG for LibPRNG.PRNG;

    function withGeneratedAmount(
        OfferItem memory item,
        Amount amount,
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItem memory) {
        // Assumes ordering, might be dangerous
        if (
            item.itemType == ItemType.ERC721 ||
            item.itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            return item.withStartAmount(1).withEndAmount(1);
        }

        uint256 a = bound(context.prng.next(), 1, 1_000_000e18);
        uint256 b = bound(context.prng.next(), 1, 1_000_000e18);

        // TODO: Work out a better way to handle this
        if (context.basicOrderCategory == BasicOrderCategory.BID) {
            a *= 1000;
            b *= 1000;
        }

        uint256 high = a > b ? a : b;
        uint256 low = a < b ? a : b;

        if (amount == Amount.FIXED) {
            return item.withStartAmount(high).withEndAmount(high);
        }
        if (amount == Amount.ASCENDING) {
            return item.withStartAmount(low).withEndAmount(high);
        }
        if (amount == Amount.DESCENDING) {
            return item.withStartAmount(high).withEndAmount(low);
        }
        return item;
    }

    function withGeneratedAmount(
        ConsiderationItem memory item,
        Amount amount,
        FuzzGeneratorContext memory context
    ) internal pure returns (ConsiderationItem memory) {
        // Assumes ordering, might be dangerous
        if (
            item.itemType == ItemType.ERC721 ||
            item.itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            return item.withStartAmount(1).withEndAmount(1);
        }

        uint256 a = bound(context.prng.next(), 1, 1_000_000e18);
        uint256 b = bound(context.prng.next(), 1, 1_000_000e18);

        uint256 high = a > b ? a : b;
        uint256 low = a < b ? a : b;

        if (amount == Amount.FIXED) {
            return item.withStartAmount(high).withEndAmount(high);
        }
        if (amount == Amount.ASCENDING) {
            return item.withStartAmount(low).withEndAmount(high);
        }
        if (amount == Amount.DESCENDING) {
            return item.withStartAmount(high).withEndAmount(low);
        }
        return item;
    }
}

library RecipientGenerator {
    using LibPRNG for LibPRNG.PRNG;

    function generate(
        Recipient recipient,
        FuzzGeneratorContext memory context,
        address offerer
    ) internal pure returns (address) {
        if (
            recipient == Recipient.OFFERER ||
            context.basicOrderCategory != BasicOrderCategory.NONE
        ) {
            return offerer;
        } else if (recipient == Recipient.RECIPIENT) {
            return context.caller;
        } else if (recipient == Recipient.DILLON) {
            return context.dillon.addr;
        } else if (recipient == Recipient.EVE) {
            return context.eve.addr;
        } else if (recipient == Recipient.FRANK) {
            return context.frank.addr;
        } else {
            revert("Invalid recipient");
        }
    }
}

library CriteriaGenerator {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    using LibPRNG for LibPRNG.PRNG;

    // TODO: bubble up OfferItems and ConsiderationItems along with CriteriaResolvers
    function withGeneratedIdentifierOrCriteria(
        ConsiderationItem memory item,
        ItemType itemType,
        Criteria criteria,
        FuzzGeneratorContext memory context
    ) internal returns (ConsiderationItem memory) {
        if (itemType == ItemType.NATIVE || itemType == ItemType.ERC20) {
            return item.withIdentifierOrCriteria(0);
        } else if (itemType == ItemType.ERC721) {
            item = item.withIdentifierOrCriteria(
                context.starting721offerIndex++
            );
            return item;
        } else if (itemType == ItemType.ERC1155) {
            return
                item.withIdentifierOrCriteria(
                    context.potential1155TokenIds[
                        context.prng.next() %
                            context.potential1155TokenIds.length
                    ]
                );
            // Else, item is a criteria-based item
        } else {
            if (criteria == Criteria.MERKLE) {
                // Resolve a random tokenId from a random number of random tokenIds
                uint256 derivedCriteria = context
                    .testHelpers
                    .criteriaResolverHelper()
                    .generateCriteriaMetadata(
                        context.prng,
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? context.starting721offerIndex++
                            : type(uint256).max
                    );
                // NOTE: resolvable identifier and proof are now registrated on CriteriaResolverHelper

                // Return the item with the Merkle root of the random tokenId
                // as criteria
                return item.withIdentifierOrCriteria(derivedCriteria);
            } else {
                // Return wildcard criteria item with identifier 0
                return item.withIdentifierOrCriteria(0);
            }
        }
    }

    function withGeneratedIdentifierOrCriteria(
        OfferItem memory item,
        ItemType itemType,
        Criteria criteria,
        FuzzGeneratorContext memory context
    ) internal returns (OfferItem memory) {
        if (itemType == ItemType.NATIVE || itemType == ItemType.ERC20) {
            return item.withIdentifierOrCriteria(0);
        } else if (itemType == ItemType.ERC721) {
            item = item.withIdentifierOrCriteria(
                context.starting721offerIndex++
            );
            return item;
        } else if (itemType == ItemType.ERC1155) {
            return
                item.withIdentifierOrCriteria(
                    context.potential1155TokenIds[
                        context.prng.next() %
                            context.potential1155TokenIds.length
                    ]
                );
        } else {
            if (criteria == Criteria.MERKLE) {
                // Resolve a random tokenId from a random number of random tokenIds
                uint256 derivedCriteria = context
                    .testHelpers
                    .criteriaResolverHelper()
                    .generateCriteriaMetadata(
                        context.prng,
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? context.starting721offerIndex++
                            : type(uint256).max
                    );
                // NOTE: resolvable identifier and proof are now registrated on CriteriaResolverHelper

                // Return the item with the Merkle root of the random tokenId
                // as criteria
                return item.withIdentifierOrCriteria(derivedCriteria);
            } else {
                // Return wildcard criteria item with identifier 0
                return item.withIdentifierOrCriteria(0);
            }
        }
    }
}

// execution lib generates fulfillments on the fly
// generation phase geared around buidling orders
// if some additional context needed,
// building up crit resolver array in generation phase is more akin to fulfillments array
// would rather we derive criteria resolvers rather than dictating what fuzz engine needs to do
// need one more helper function to take generator context and add withCriteriaResolvers

// right now, we're inserting item + order indexes whicih could get shuffled around in generation stage
// ideally we would have mapping of merkle root => criteria resolver
// when execution hits item w merkle root, look up root to get proof and identifier
// add storage mapping to CriteriaResolverHelper

library OffererGenerator {
    function generate(
        Offerer offerer,
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        if (offerer == Offerer.TEST_CONTRACT) {
            return context.self;
        } else if (offerer == Offerer.ALICE) {
            return context.alice.addr;
        } else if (offerer == Offerer.BOB) {
            return context.bob.addr;
        } else {
            revert("Invalid offerer");
        }
    }

    function getKey(
        Offerer offerer,
        FuzzGeneratorContext memory context
    ) internal pure returns (uint256) {
        if (offerer == Offerer.TEST_CONTRACT) {
            return 0;
        } else if (offerer == Offerer.ALICE) {
            return context.alice.key;
        } else if (offerer == Offerer.BOB) {
            return context.bob.key;
        } else {
            revert("Invalid offerer");
        }
    }
}

library PRNGHelpers {
    using LibPRNG for LibPRNG.PRNG;

    function randEnum(
        FuzzGeneratorContext memory context,
        uint8 min,
        uint8 max
    ) internal pure returns (uint8) {
        return uint8(bound(context.prng.next(), min, max));
    }

    function randRange(
        FuzzGeneratorContext memory context,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256) {
        return bound(context.prng.next(), min, max);
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
    if (x >= type(uint256).max - 3 && size > type(uint256).max - x)
        return max - (type(uint256).max - x);

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
