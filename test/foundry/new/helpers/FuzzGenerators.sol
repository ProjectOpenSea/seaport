// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import "seaport-sol/SeaportSol.sol";

import { ItemType, Side } from "seaport-sol/SeaportEnums.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/StructSpace.sol";

import {
    CriteriaResolverHelper,
    CriteriaMetadata
} from "./CriteriaResolverHelper.sol";

import {
    Amount,
    BasicOrderCategory,
    BroadOrderType,
    ConduitChoice,
    Criteria,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    TokenIndex,
    Zone,
    ZoneHash
} from "seaport-sol/SpaceEnums.sol";

import {
    FuzzGeneratorContext,
    TestConduit
} from "./FuzzGeneratorContextLib.sol";

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

    function generate(
        uint256 totalOrders,
        uint256 maxOfferItemsPerOrder,
        uint256 maxConsiderationItemsPerOrder,
        FuzzGeneratorContext memory context
    ) internal returns (AdvancedOrdersSpace memory) {
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

        if (context.basicOrderCategory != BasicOrderCategory.NONE) {
            totalOrders = 1;
            maxOfferItemsPerOrder = 1;
            if (maxConsiderationItemsPerOrder == 0) {
                maxConsiderationItemsPerOrder = 1;
            }
        } else {
            isMatchable = context.randRange(0, 1) == 1 ? true : false;
        }

        if (maxOfferItemsPerOrder == 0 && maxConsiderationItemsPerOrder == 0) {
            maxOfferItemsPerOrder = context.randRange(0, 1);
            maxConsiderationItemsPerOrder = 1 - maxOfferItemsPerOrder;
        }

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            totalOrders
        );

        for (uint256 i; i < totalOrders; ++i) {
            components[i] = OrderComponentsSpace({
                // TODO: Restricted range to 1 and 2 to avoid test contract.
                //       Range should be 0-2.
                offerer: Offerer(context.randEnum(1, 2)),
                // TODO: Ignoring fail for now. Should be 0-2.
                zone: Zone(context.randEnum(0, 1)),
                offer: generateOffer(maxOfferItemsPerOrder, i, context),
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
                conduit: ConduitChoice(context.randEnum(0, 2))
            });
        }

        return
            AdvancedOrdersSpace({
                orders: components,
                isMatchable: isMatchable
            });
    }

    function generateOffer(
        uint256 maxOfferItemsPerOrder,
        uint256 orderIndex,
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItemSpace[] memory) {
        if (context.basicOrderCategory == BasicOrderCategory.NONE) {
            uint256 len = context.randRange(0, maxOfferItemsPerOrder);

            OfferItemSpace[] memory offer = new OfferItemSpace[](len);
            for (uint256 i; i < len; ++i) {
                offer[i] = OfferItemSpace({
                    // TODO: Native items + criteria - should be 0-5
                    itemType: ItemType(context.randEnum(0, 5)),
                    tokenIndex: TokenIndex(context.randEnum(0, 1)),
                    criteria: Criteria(context.randEnum(1, 2)),
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
                    // TODO: Native items + criteria - should be 0-5
                    itemType: ItemType(context.randEnum(0, 5)),
                    tokenIndex: TokenIndex(context.randEnum(0, 2)),
                    criteria: Criteria(context.randEnum(1, 2)),
                    // TODO: Fixed amounts only, should be 0-2
                    amount: Amount(context.randEnum(0, 0)),
                    recipient: Recipient(context.randEnum(0, 4))
                });
            }
        } else {
            consideration[0] = ConsiderationItemSpace({
                // TODO: Native items + criteria - should be 0-5
                itemType: ItemType(
                    context.basicOrderCategory == BasicOrderCategory.BID
                        ? context.randEnum(2, 3)
                        : 1
                ),
                tokenIndex: TokenIndex(context.randEnum(0, 2)),
                criteria: Criteria(0),
                // TODO: Fixed amounts only, should be 0-2
                amount: Amount(context.randEnum(0, 0)),
                recipient: Recipient(0) // Always offerer
            });

            for (uint256 i = 1; i < len; ++i) {
                consideration[i] = ConsiderationItemSpace({
                    // TODO: Native items + criteria - should be 0-5
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

    using OrderComponentsSpaceGenerator for OrderComponentsSpace;
    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace;
    using PRNGHelpers for FuzzGeneratorContext;
    using SignatureGenerator for AdvancedOrder;

    function generate(
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal returns (AdvancedOrder[] memory) {
        uint256 len = bound(space.orders.length, 0, 10);
        AdvancedOrder[] memory orders = new AdvancedOrder[](len);
        context.orderHashes = new bytes32[](len);

        // Build orders
        for (uint256 i; i < len; ++i) {
            OrderParameters memory orderParameters = space.orders[i].generate(
                context
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

        // Handle matches
        if (space.isMatchable) {
            (, , MatchComponent[] memory remainders) = context
                .testHelpers
                .getMatchedFulfillments(orders);

            for (uint256 i = 0; i < remainders.length; ++i) {
                (
                    uint240 amount,
                    uint8 orderIndex,
                    uint8 itemIndex
                ) = remainders[i].unpack();

                ConsiderationItem memory item = orders[orderIndex]
                    .parameters
                    .consideration[itemIndex];

                uint256 orderInsertionIndex = context.randRange(
                    0,
                    orders.length - 1
                );

                OfferItem[] memory newOffer = new OfferItem[](
                    orders[orderInsertionIndex].parameters.offer.length + 1
                );

                if (orders[orderInsertionIndex].parameters.offer.length == 0) {
                    newOffer[0] = OfferItem({
                        itemType: item.itemType,
                        token: item.token,
                        identifierOrCriteria: item.identifierOrCriteria,
                        startAmount: uint256(amount),
                        endAmount: uint256(amount)
                    });
                } else {
                    uint256 itemInsertionIndex = context.randRange(
                        0,
                        orders[orderInsertionIndex].parameters.offer.length - 1
                    );

                    for (uint256 j = 0; j < itemInsertionIndex; ++j) {
                        newOffer[j] = orders[orderInsertionIndex]
                            .parameters
                            .offer[j];
                    }

                    newOffer[itemInsertionIndex] = OfferItem({
                        itemType: item.itemType,
                        token: item.token,
                        identifierOrCriteria: item.identifierOrCriteria,
                        startAmount: uint256(amount),
                        endAmount: uint256(amount)
                    });

                    for (
                        uint256 j = itemInsertionIndex + 1;
                        j < newOffer.length;
                        ++j
                    ) {
                        newOffer[j] = orders[orderInsertionIndex]
                            .parameters
                            .offer[j - 1];
                    }
                }

                orders[orderInsertionIndex].parameters.offer = newOffer;
            }
        }

        // Handle combined orders (need to have at least one execution)
        if (len > 1) {
            // handle orders with no items
            bool allEmpty = true;
            for (uint256 i = 0; i < len; ++i) {
                OrderParameters memory orderParams = orders[i].parameters;
                if (
                    orderParams.offer.length +
                        orderParams.consideration.length >
                    0
                ) {
                    allEmpty = false;
                    break;
                }
            }

            if (allEmpty) {
                uint256 orderInsertionIndex = context.randRange(0, len - 1);
                OrderParameters memory orderParams = orders[orderInsertionIndex]
                    .parameters;

                ConsiderationItem[]
                    memory consideration = new ConsiderationItem[](1);
                consideration[0] = TestStateGenerator
                .generateConsideration(1, context, true)[0].generate(
                        context,
                        orderParams.offerer
                    );

                orderParams.consideration = consideration;
            }

            // handle orders with only filtered executions Note: technically
            // orders with no unfiltered consideration items can still be called
            // in some cases via fulfillAvailable as long as there are offer
            // items that don't have to be filtered as well. Also note that this
            // does not account for unfilterable matchOrders combinations yet.
            bool allFilterable = true;
            address caller = context.caller == address(0)
                ? address(this)
                : context.caller;
            for (uint256 i = 0; i < len; ++i) {
                OrderParameters memory order = orders[i].parameters;

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

            if (allFilterable) {
                OrderParameters memory orderParams;

                for (
                    uint256 orderInsertionIndex = context.randRange(0, len - 1);
                    orderInsertionIndex < len * 2;
                    ++orderInsertionIndex
                ) {
                    orderParams = orders[orderInsertionIndex % len].parameters;

                    if (orderParams.consideration.length != 0) {
                        break;
                    }
                }

                if (orderParams.consideration.length == 0) {
                    uint256 orderInsertionIndex = context.randRange(0, len - 1);
                    orderParams = orders[orderInsertionIndex].parameters;

                    ConsiderationItem[]
                        memory consideration = new ConsiderationItem[](1);
                    consideration[0] = TestStateGenerator
                    .generateConsideration(1, context, true)[0].generate(
                            context,
                            orderParams.offerer
                        );

                    orderParams.consideration = consideration;
                }

                uint256 itemIndex = context.randRange(
                    0,
                    orderParams.consideration.length - 1
                );

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

        // Sign phase
        for (uint256 i = 0; i < len; ++i) {
            AdvancedOrder memory order = orders[i];

            // TODO: choose an arbitrary number of tips
            order.parameters.totalOriginalConsiderationItems = (
                order.parameters.consideration.length
            );

            bytes32 orderHash;
            {
                uint256 counter = context.seaport.getCounter(
                    order.parameters.offerer
                );
                orderHash = context.seaport.getOrderHash(
                    order.parameters.toOrderComponents(counter)
                );

                context.orderHashes[i] = orderHash;
            }

            orders[i] = order.withGeneratedSignature(
                space.orders[i].signatureMethod,
                space.orders[i].offerer,
                orderHash,
                context
            );
        }
        return orders;
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
        FuzzGeneratorContext memory context
    ) internal pure returns (OrderParameters memory) {
        OrderParameters memory params;
        {
            address offerer = space.offerer.generate(context);

            params = OrderParametersLib
                .empty()
                .withOfferer(offerer)
                .withOffer(space.offer.generate(context))
                .withConsideration(
                    space.consideration.generate(context, offerer)
                )
                .withConduitKey(space.conduit.generate(context).key);
        }

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

    function generate(
        OfferItemSpace[] memory space,
        FuzzGeneratorContext memory context,
        uint256 orderIndex
    ) internal pure returns (OfferItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        OfferItem[] memory offerItems = new OfferItem[](len);

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            len
        );

        // Deploy criteria helper with maxLeaves of 10
        CriteriaResolverHelper criteriaResolverHelper = new CriteriaResolverHelper(
                10
            );
        for (uint256 i; i < len; ++i) {
            offerItems[i] = generate(
                space[i],
                context,
                criteriaResolverHelper,
                orderIndex,
                i
            );
        }
        return offerItems;
    }

    function generate(
        OfferItemSpace memory space,
        FuzzGeneratorContext memory context,
        CriteriaResolverHelper criteriaResolverHelper,
        uint256 orderIndex,
        uint256 itemIndex
    )
        internal
        returns (
            OfferItem memory offerItem,
            CriteriaResolver memory criteriaResolver
        )
    {
        offerItem = OfferItemLib
            .empty()
            .withItemType(space.itemType)
            .withToken(space.tokenIndex.generate(space.itemType, context))
            .withGeneratedAmount(space.amount, context)
            .withGeneratedIdentifierOrCriteria(
                space.itemType,
                space.criteria,
                context,
                orderIndex,
                itemIndex
            );

        criteriaResolver = CriteriaResolver({
            orderIndex: orderIndex,
            side: Side.OFFER,
            index: itemIndex,
            identifier: 0,
            criteriaProof: new bytes32[](0)
        });

        if (
            offerItem.itemType == ItemType.ERC721_WITH_CRITERIA ||
            offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            if (space.criteria == Criteria.MERKLE) {
                (
                    uint256 resolvedIdentifier,
                    bytes32 root,
                    bytes32[] memory proof
                ) = criteriaResolverHelper.generateCriteriaMetadata(
                        context.prng
                    );

                offerItem = offerItem.withIdentifierOrCriteria(uint256(root));

                criteriaResolver = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.OFFER,
                    index: itemIndex,
                    identifier: resolvedIdentifier,
                    criteriaProof: proof
                });
            } else {
                // Item is a "wildcard" criteria-based item
                offerItem = offerItem.withIdentifierOrCriteria(0);
            }
        }
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
        address offerer,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal pure returns (ConsiderationItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            len
        );

        for (uint256 i; i < len; ++i) {
            considerationItems[i] = generate(
                space[i],
                context,
                offerer,
                orderIndex,
                itemIndex
            );
        }

        return considerationItems;
    }

    function generate(
        ConsiderationItemSpace memory space,
        FuzzGeneratorContext memory context,
        address offerer,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal pure returns (ConsiderationItem memory) {
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
                    context,
                    orderIndex,
                    itemIndex
                );
    }
}

library CriteriaResolverGenerator {
    function generate(
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal returns (CriteriaResolver[] memory) {
        uint256 len = orders.length;

        // Iterate over each order to generate criteria resolvers
        for (uint256 i; i < len; ++i) {
            AdvancedOrder memory order = orders[i];
            OfferItem[] memory offerItems = order.offerItems;
        }
    }
}

library SignatureGenerator {
    using AdvancedOrderLib for AdvancedOrder;

    using OffererGenerator for Offerer;

    function withGeneratedSignature(
        AdvancedOrder memory order,
        SignatureMethod method,
        Offerer offerer,
        bytes32 orderHash,
        FuzzGeneratorContext memory context
    ) internal view returns (AdvancedOrder memory) {
        if (method == SignatureMethod.EOA) {
            (, bytes32 domainSeparator, ) = context.seaport.information();
            bytes memory message = abi.encodePacked(
                bytes2(0x1901),
                domainSeparator,
                orderHash
            );
            bytes32 digest = keccak256(message);
            (uint8 v, bytes32 r, bytes32 s) = context.vm.sign(
                offerer.getKey(context),
                digest
            );
            bytes memory signature = abi.encodePacked(r, s, v);
            address recovered = ecrecover(digest, v, r, s);
            if (
                recovered != offerer.generate(context) ||
                recovered == address(0)
            ) {
                revert("SignatureGenerator: Invalid signature");
            }
            return order.withSignature(signature);
        }
        revert("SignatureGenerator: Invalid signature method");
    }
}

library TokenIndexGenerator {
    function generate(
        TokenIndex tokenIndex,
        ItemType itemType,
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        uint256 i = uint8(tokenIndex);

        // TODO: missing native tokens
        if (itemType == ItemType.ERC20) {
            return address(context.erc20s[i]);
        } else if (itemType == ItemType.ERC721) {
            return address(context.erc721s[i]);
        } else if (itemType == ItemType.ERC1155) {
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
        if (item.itemType == ItemType.ERC721) {
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
        if (item.itemType == ItemType.ERC721) {
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
        FuzzGeneratorContext memory context,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal returns (ConsiderationItem memory) {
        if (itemType == ItemType.NATIVE || itemType == ItemType.ERC20) {
            return item.withIdentifierOrCriteria(0);
        } else if (itemType == ItemType.ERC721) {
            item = item.withIdentifierOrCriteria(context.starting721offerIndex);
            ++context.starting721offerIndex;
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
                // TODO: deploy only once
                // Deploy criteria helper with maxLeaves of 10
                CriteriaResolverHelper criteriaResolverHelper = new CriteriaResolverHelper(
                        10
                    );

                // Resolve a random tokenId from a random number of random tokenIds
                (
                    uint256 resolvedIdentifier,
                    bytes32 root,
                    bytes32[] memory proof
                ) = criteriaResolverHelper.generateCriteriaMetadata(
                        context.prng
                    );

                // Create a new CriteriaResolver from the returned values from
                // the call to generateCriteriaMetadata
                CriteriaResolver memory criteriaResolver = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.CONSIDERATION,
                    index: itemIndex,
                    identifier: resolvedIdentifier,
                    criteriaProof: proof
                });

                // Get the length of the current criteriaResolver array
                uint256 criteriaResolverLength = context
                    .criteriaResolvers
                    .length;

                // Create a new CriteriaResolver array and increment length
                // to include the new criteriaResolver
                CriteriaResolver[]
                    memory tempCriteriaResolvers = new CriteriaResolver[](
                        criteriaResolverLength + 1
                    );

                // Copy over the existing criteriaResolvers to tempCriteriaResolvers
                for (uint256 i; i < context.criteriaResolver.length; i++) {
                    tempCriteriaResolvers[i] = context.criteriaResolver[i];
                }

                // Add the new criteriaResolver to the end of the array
                tempCriteriaResolvers[
                    criteriaResolverLength
                ] = criteriaResolver;

                // Set the context's criteriaResolver to the new array
                context.criteriaResolver = tempCriteriaResolvers;

                // Return the item with the Merkle root of the random tokenId
                // as criteria
                return item.withIdentifierOrCriteria(uint256(root));
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
        FuzzGeneratorContext memory context,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal returns (OfferItem memory) {
        if (itemType == ItemType.NATIVE || itemType == ItemType.ERC20) {
            return item.withIdentifierOrCriteria(0);
        } else if (itemType == ItemType.ERC721) {
            item = item.withIdentifierOrCriteria(context.starting721offerIndex);
            ++context.starting721offerIndex;
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
                // TODO: deploy only once
                // Deploy criteria helper with maxLeaves of 10
                CriteriaResolverHelper criteriaResolverHelper = new CriteriaResolverHelper(
                        10
                    );

                // Resolve a random tokenId from a random number of random tokenIds
                (
                    uint256 resolvedIdentifier,
                    bytes32 root,
                    bytes32[] memory proof
                ) = criteriaResolverHelper.generateCriteriaMetadata(
                        context.prng
                    );

                // Create a new CriteriaResolver from the returned values from
                // the call to generateCriteriaMetadata
                CriteriaResolver
                    memory criteriaResolver = new CriteriaResolver({
                        orderIndex: orderIndex,
                        side: Side.OFFER,
                        index: itemIndex,
                        identifier: resolvedIdentifier,
                        criteriaProof: proof
                    });

                // Get the length of the current criteriaResolver array
                uint256 criteriaResolverLength = context
                    .criteriaResolver
                    .length;

                // Create a new CriteriaResolver array and increment length
                // to include the new criteriaResolver
                CriteriaResolver[]
                    memory tempCriteriaResolvers = new CriteriaResolver[](
                        criteriaResolverLength + 1
                    );

                // Copy over the existing criteriaResolvers to tempCriteriaResolvers
                for (uint256 i; i < context.criteriaResolver.length; i++) {
                    tempCriteriaResolvers[i] = context.criteriaResolver[i];
                }

                // Add the new criteriaResolver to the end of the array
                tempCriteriaResolvers[
                    criteriaResolverLength
                ] = criteriaResolver;

                // Set the context's criteriaResolver to the new array
                context.criteriaResolver = tempCriteriaResolvers;

                // Return the item with the Merkle root of the random tokenId
                // as criteria
                return item.withIdentifierOrCriteria(uint256(root));
            } else {
                // Return wildcard criteria item with identifier 0
                return item.withIdentifierOrCriteria(0);
            }
        }
    }
}

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
