// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import "seaport-sol/SeaportSol.sol";

import { ItemType } from "seaport-sol/SeaportEnums.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/StructSpace.sol";
import {
    Amount,
    BroadOrderType,
    Criteria,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    TokenIndex,
    Zone,
    ZoneHash,
    ConduitChoice
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
    ) internal pure returns (AdvancedOrdersSpace memory) {
        bool isMatchable = context.randRange(0, 1) == 1 ? true : false;
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
                offer: generateOffer(maxOfferItemsPerOrder, context),
                consideration: generateConsideration(
                    maxConsiderationItemsPerOrder,
                    context
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
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItemSpace[] memory) {
        uint256 len = context.randRange(0, maxOfferItemsPerOrder);
        OfferItemSpace[] memory offer = new OfferItemSpace[](len);
        for (uint256 i; i < len; ++i) {
            offer[i] = OfferItemSpace({
                // TODO: Native items + criteria - should be 0-5
                itemType: ItemType(context.randEnum(1, 3)),
                tokenIndex: TokenIndex(context.randEnum(0, 2)),
                criteria: Criteria(context.randEnum(0, 2)),
                // TODO: Fixed amounts only, should be 0-2
                amount: Amount(context.randEnum(0, 0))
            });
        }
        return offer;
    }

    function generateConsideration(
        uint256 maxConsiderationItemsPerOrder,
        FuzzGeneratorContext memory context
    ) internal pure returns (ConsiderationItemSpace[] memory) {
        // TODO: Can we handle zero?
        uint256 len = context.randRange(1, maxConsiderationItemsPerOrder);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](len);
        for (uint256 i; i < len; ++i) {
            consideration[i] = ConsiderationItemSpace({
                // TODO: Native items + criteria - should be 0-5
                itemType: ItemType(context.randEnum(1, 3)),
                tokenIndex: TokenIndex(context.randEnum(0, 2)),
                criteria: Criteria(context.randEnum(0, 2)),
                // TODO: Fixed amounts only, should be 0-2
                amount: Amount(context.randEnum(0, 0)),
                recipient: Recipient(context.randEnum(0, 4))
            });
        }
        return consideration;
    }
}

library AdvancedOrdersSpaceGenerator {
    using AdvancedOrderLib for AdvancedOrder;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using OrderComponentsSpaceGenerator for OrderComponentsSpace;
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

    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace[];
    using OffererGenerator for Offerer;
    using OfferItemSpaceGenerator for OfferItemSpace[];
    using PRNGHelpers for FuzzGeneratorContext;
    using TimeGenerator for OrderParameters;
    using ZoneGenerator for OrderParameters;
    using ConduitGenerator for ConduitChoice;

    function generate(
        OrderComponentsSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure returns (OrderParameters memory) {
        OrderParameters memory params;
        {
            params = OrderParametersLib
                .empty()
                .withOfferer(space.offerer.generate(context))
                .withOffer(space.offer.generate(context))
                .withConsideration(space.consideration.generate(context))
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
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        OfferItem[] memory offerItems = new OfferItem[](len);

        for (uint256 i; i < len; ++i) {
            offerItems[i] = generate(space[i], context);
        }
        return offerItems;
    }

    function generate(
        OfferItemSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItem memory) {
        return
            OfferItemLib
                .empty()
                .withItemType(space.itemType)
                .withToken(space.tokenIndex.generate(space.itemType, context))
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
        FuzzGeneratorContext memory context
    ) internal pure returns (ConsiderationItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            len
        );

        for (uint256 i; i < len; ++i) {
            considerationItems[i] = generate(space[i], context);
        }
        return considerationItems;
    }

    function generate(
        ConsiderationItemSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure returns (ConsiderationItem memory) {
        return
            ConsiderationItemLib
                .empty()
                .withItemType(space.itemType)
                .withToken(space.tokenIndex.generate(space.itemType, context))
                .withGeneratedAmount(space.amount, context)
                .withRecipient(space.recipient.generate(context))
                .withGeneratedIdentifierOrCriteria(
                    space.itemType,
                    space.criteria,
                    context
                );
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
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        if (recipient == Recipient.OFFERER) {
            return context.offerer.addr;
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

    function withGeneratedIdentifierOrCriteria(
        ConsiderationItem memory item,
        ItemType itemType,
        Criteria /** criteria */,
        FuzzGeneratorContext memory context
    ) internal pure returns (ConsiderationItem memory) {
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
        }
        revert("CriteriaGenerator: invalid ItemType");
    }

    function withGeneratedIdentifierOrCriteria(
        OfferItem memory item,
        ItemType itemType,
        Criteria /** criteria */,
        FuzzGeneratorContext memory context
    ) internal pure returns (OfferItem memory) {
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
        }
        revert("CriteriaGenerator: invalid ItemType");
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
