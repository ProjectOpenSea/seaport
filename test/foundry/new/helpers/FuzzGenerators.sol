// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    MatchComponent,
    MatchComponentType,
    OfferItemLib,
    OrderLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Fulfillment,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType, Side } from "seaport-sol/src/SeaportEnums.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";
import { Solarray } from "solarray/Solarray.sol";
import {
    Amount,
    BasicOrderCategory,
    BroadOrderType,
    Caller,
    ConduitChoice,
    ContractOrderRebate,
    Criteria,
    EOASignature,
    ExtraData,
    FulfillmentRecipient,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    Tips,
    TokenIndex,
    UnavailableReason,
    Zone,
    ZoneHash
} from "seaport-sol/src/SpaceEnums.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/src/StructSpace.sol";

import { EIP712MerkleTree } from "../../utils/EIP712MerkleTree.sol";

import {
    FuzzGeneratorContext,
    TestConduit
} from "./FuzzGeneratorContextLib.sol";

import {
    _locateCurrentAmount,
    FuzzHelpers,
    Structure
} from "./FuzzHelpers.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { EIP1271Offerer } from "./EIP1271Offerer.sol";

import {
    AggregationStrategy,
    FulfillAvailableStrategy,
    MatchStrategy,
    FulfillmentGeneratorLib,
    FulfillmentStrategy,
    DefaultFulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

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
 *
 *       The TestStateGenerator library is responsible for step one: generating
 *       an AdvancedOrdersSpace struct representing a fuzzed order permutation.
 */
library TestStateGenerator {
    using PRNGHelpers for FuzzGeneratorContext;
    using MatchComponentType for MatchComponent;

    function generate(
        uint256 totalOrders,
        uint256 maxOfferItemsPerOrder,
        uint256 maxConsiderationItemsPerOrder,
        bytes memory seedInput,
        FuzzGeneratorContext memory context
    ) internal pure returns (AdvancedOrdersSpace memory) {
        context.prng.state = uint256(keccak256(seedInput));

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
                    ? UnavailableReason.AVAILABLE // Don't fuzz 5 (maxfulfilled satisfied), since it's a more // of a consequence (to be handled in derivers) than a // target.
                    : UnavailableReason(
                        context.choice(Solarray.uint256s(1, 2, 3, 4, 6))
                    )
            );

            if (reason == UnavailableReason.AVAILABLE) {
                someAvailable = true;
            }

            uint256 bulkSigHeight = context.randRange(1, 24);

            components[i] = OrderComponentsSpace({
                offerer: Offerer(context.choice(Solarray.uint256s(1, 2, 4))),
                zone: Zone(context.randEnum(0, 1)),
                offer: generateOffer(maxOfferItemsPerOrder, context),
                consideration: generateConsideration(
                    maxConsiderationItemsPerOrder,
                    context,
                    false
                ),
                orderType: BroadOrderType(context.randEnum(0, 2)),
                // NOTE: unavailable times are inserted downstream.
                time: Time(context.randEnum(1, 2)),
                zoneHash: ZoneHash(context.randEnum(0, 2)),
                signatureMethod: SignatureMethod(
                    context.choice(Solarray.uint256s(0, 1, 4))
                ),
                eoaSignatureType: EOASignature(context.randEnum(0, 3)),
                bulkSigHeight: bulkSigHeight,
                bulkSigIndex: context.randRange(0, 2 ** bulkSigHeight - 1),
                conduit: ConduitChoice(context.randEnum(0, 2)),
                tips: Tips(context.randEnum(0, 1)),
                unavailableReason: reason,
                extraData: ExtraData(context.randEnum(0, 1)),
                rebate: ContractOrderRebate(context.randEnum(0, 4))
            });

            // Set up order components specific to contract order
            if (components[i].orderType == BroadOrderType.CONTRACT) {
                components[i].offerer == Offerer.CONTRACT_OFFERER;
                components[i].signatureMethod == SignatureMethod.CONTRACT;
                components[i].tips = Tips.NONE;
                if (
                    components[i].unavailableReason ==
                    UnavailableReason.ALREADY_FULFILLED ||
                    components[i].unavailableReason ==
                    UnavailableReason.CANCELLED
                ) {
                    components[i].unavailableReason = UnavailableReason(
                        context.choice(Solarray.uint256s(1, 2, 6))
                    );
                }

                // Contract orders must have fixed amounts.
                for (uint256 j = 0; j < components[i].offer.length; ++j) {
                    components[i].offer[j].amount = Amount.FIXED;
                    // TODO: support wildcard resolution (note that the
                    // contract offerer needs to resolve these itself)
                    components[i].offer[j].criteria = Criteria.MERKLE;
                }

                for (
                    uint256 j = 0;
                    j < components[i].consideration.length;
                    ++j
                ) {
                    components[i].consideration[j].amount = Amount.FIXED;
                    // TODO: support offerer returning other recipients.
                    components[i].consideration[j].recipient = Recipient
                        .OFFERER;
                    // TODO: support wildcard resolution (note that the
                    // contract offerer needs to resolve these itself)
                    components[i].consideration[j].criteria = Criteria.MERKLE;
                }

                if (
                    components[i].consideration.length == 0 &&
                    (components[i].rebate ==
                        ContractOrderRebate.LESS_CONSIDERATION_ITEMS ||
                        components[i].rebate ==
                        ContractOrderRebate.LESS_CONSIDERATION_ITEM_AMOUNTS)
                ) {
                    components[i].rebate = ContractOrderRebate(
                        context.randEnum(0, 2)
                    );
                }

                if (
                    components[i].rebate ==
                    ContractOrderRebate.LESS_CONSIDERATION_ITEM_AMOUNTS
                ) {
                    bool canReduceAmounts;
                    for (
                        uint256 j = 0;
                        j < components[i].consideration.length;
                        ++j
                    ) {
                        ItemType itemType = components[i]
                            .consideration[j]
                            .itemType;
                        if (
                            itemType != ItemType.ERC721 &&
                            itemType != ItemType.ERC721_WITH_CRITERIA
                        ) {
                            // NOTE: theoretically there could still be items with amount 1
                            // that would not be eligible for reducing consideration amounts.
                            canReduceAmounts = true;
                            break;
                        }
                    }

                    if (!canReduceAmounts) {
                        components[i].rebate = ContractOrderRebate(
                            context.randEnum(0, 3)
                        );
                    }
                }

                if (
                    components[i].rebate ==
                    ContractOrderRebate.MORE_OFFER_ITEM_AMOUNTS
                ) {
                    bool canIncreaseAmounts;
                    for (uint256 j = 0; j < components[i].offer.length; ++j) {
                        ItemType itemType = components[i].offer[j].itemType;
                        if (
                            itemType != ItemType.ERC721 &&
                            itemType != ItemType.ERC721_WITH_CRITERIA
                        ) {
                            canIncreaseAmounts = true;
                            break;
                        }
                    }

                    if (!canIncreaseAmounts) {
                        components[i].rebate = ContractOrderRebate(
                            components[i].consideration.length == 0
                                ? context.randEnum(0, 1)
                                : context.choice(Solarray.uint256s(0, 1, 3))
                        );
                    }
                }

                // TODO: figure out how to support removing criteria items
                // (just need to filter removed items out of resolvers)
                if (
                    components[i].rebate ==
                    ContractOrderRebate.LESS_CONSIDERATION_ITEMS
                ) {
                    ItemType itemType = components[i]
                        .consideration[components[i].consideration.length - 1]
                        .itemType;
                    if (
                        itemType == ItemType.ERC721_WITH_CRITERIA ||
                        itemType == ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        components[i].rebate = ContractOrderRebate(
                            context.randEnum(0, 1)
                        );
                    }
                }
            } else if (
                components[i].unavailableReason ==
                UnavailableReason.GENERATE_ORDER_FAILURE
            ) {
                components[i].unavailableReason = UnavailableReason(
                    context.randEnum(1, 4)
                );
            }

            if (components[i].offerer == Offerer.EIP1271) {
                components[i].signatureMethod = SignatureMethod.EIP1271;
            }
        }

        if (!someAvailable) {
            components[context.randRange(0, totalOrders - 1)]
                .unavailableReason = UnavailableReason.AVAILABLE;
        }

        FulfillmentStrategy memory strategy = (
            DefaultFulfillmentGeneratorLib.getDefaultFulfillmentStrategy()
        );

        {
            strategy.aggregationStrategy = AggregationStrategy(
                context.randEnum(0, 2)
            );

            strategy.fulfillAvailableStrategy = FulfillAvailableStrategy(
                context.randEnum(0, 3) // TODO: fuzz on filterable as well
            );

            strategy.matchStrategy = MatchStrategy(
                context.randEnum(2, 2) // TODO: fuzz on more than MAX_INCLUSION
            );
        }

        return
            AdvancedOrdersSpace({
                orders: components,
                isMatchable: isMatchable,
                maximumFulfilled: maximumFulfilled,
                recipient: FulfillmentRecipient(context.randEnum(0, 3)),
                conduit: ConduitChoice(context.randEnum(0, 2)),
                caller: Caller(context.randEnum(0, 6)),
                strategy: strategy
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
                    itemType: ItemType(
                        context.randRange(0, 10) != 0
                            ? context.randEnum(0, 3)
                            : context.randEnum(4, 5)
                    ),
                    tokenIndex: TokenIndex(context.randEnum(0, 2)),
                    criteria: Criteria(context.randEnum(0, 1)),
                    amount: Amount(context.randEnum(0, 2))
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
                amount: Amount(context.randEnum(0, 2))
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
                    itemType: ItemType(
                        context.randRange(0, 10) != 0
                            ? context.randEnum(0, 3)
                            : context.randEnum(4, 5)
                    ),
                    tokenIndex: TokenIndex(context.randEnum(0, 2)),
                    criteria: Criteria(context.randEnum(0, 1)),
                    amount: atLeastOne
                        ? Amount.FIXED
                        : Amount(context.randEnum(0, 2)),
                    recipient: atLeastOne
                        ? Recipient.OFFERER
                        : Recipient(context.randEnum(0, 4))
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
                amount: Amount.FIXED, // Always fixed
                recipient: Recipient.OFFERER // Always offerer
            });

            for (uint256 i = 1; i < len; ++i) {
                consideration[i] = ConsiderationItemSpace({
                    itemType: context.basicOfferSpace.itemType,
                    tokenIndex: context.basicOfferSpace.tokenIndex,
                    criteria: Criteria(0),
                    // TODO: sum(amounts) must be less than offer amount, right
                    // now this is enforced in a hacky way
                    amount: Amount.FIXED, // Always fixed
                    recipient: atLeastOne
                        ? Recipient.OFFERER
                        : Recipient(context.randEnum(0, 4))
                });
            }
        }
        return consideration;
    }

    function empty() internal pure returns (AdvancedOrdersSpace memory) {
        return
            AdvancedOrdersSpace({
                orders: new OrderComponentsSpace[](0),
                isMatchable: false,
                maximumFulfilled: 0,
                recipient: FulfillmentRecipient.ZERO,
                conduit: ConduitChoice.NONE,
                caller: Caller.TEST_CONTRACT,
                strategy: DefaultFulfillmentGeneratorLib
                    .getDefaultFulfillmentStrategy()
            });
    }
}

/**
 * @dev Convert an AdvancedOrdersSpace struct representing a given order
 *      permutation into an array of AdvancedOrder structs with valid random
 *      parameters.
 */
library AdvancedOrdersSpaceGenerator {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using DefaultFulfillmentGeneratorLib for OrderDetails[];

    using BroadOrderTypeGenerator for AdvancedOrder;
    using ConduitGenerator for ConduitChoice;
    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace;
    using ExtraDataGenerator for AdvancedOrder;
    using FulfillmentRecipientGenerator for FulfillmentRecipient;
    using FuzzHelpers for AdvancedOrder[];
    using MatchComponentType for MatchComponent;
    using OfferItemSpaceGenerator for OfferItemSpace;
    using OrderComponentsSpaceGenerator for OrderComponentsSpace;
    using PRNGHelpers for FuzzGeneratorContext;
    using SignatureGenerator for AdvancedOrder;
    using TimeGenerator for OrderParameters;
    using CallerGenerator for Caller;

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
            _squareUpRemainders(orders, space, context);
            space.maximumFulfilled = orders.length;
        } else {
            if (len > 1) {
                _adjustUnavailable(orders, space, context);
            } else {
                _ensureAllAvailable(space);
            }
            _ensureDirectSupport(orders, space, context);
        }

        bool contractOrderFound;
        for (uint256 i = 0; i < orders.length; ++i) {
            AdvancedOrder memory order = orders[i];

            if (order.parameters.orderType == OrderType.CONTRACT) {
                contractOrderFound = true;
            }

            orders[i] = order.withCoercedAmountsForPartialFulfillment();

            OrderParameters memory orderParams = order.parameters;

            if (
                space.orders[i].tips == Tips.NONE ||
                orderParams.orderType == OrderType.CONTRACT
            ) {
                orders[i].parameters.totalOriginalConsiderationItems = (
                    orders[i].parameters.consideration.length
                );
            }

            if (orderParams.orderType == OrderType.CONTRACT) {
                order.parameters = orderParams
                    .withOrderType(OrderType.CONTRACT)
                    .withOfferer(address(context.contractOfferer));

                for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                    OfferItem memory item = orderParams.offer[j];

                    if (item.startAmount != 0) {
                        order.parameters.offer[j].endAmount = item.startAmount;
                    } else {
                        order.parameters.offer[j].startAmount = item.endAmount;
                    }

                    if (
                        uint256(item.itemType) > 3 &&
                        item.identifierOrCriteria == 0
                    ) {
                        order.parameters.offer[j].itemType = ItemType(
                            uint256(item.itemType) - 2
                        );
                        bytes32 itemHash = keccak256(
                            abi.encodePacked(uint256(i), uint256(j), Side.OFFER)
                        );
                        order.parameters.offer[j].identifierOrCriteria = context
                            .testHelpers
                            .criteriaResolverHelper()
                            .wildcardIdentifierForGivenItemHash(itemHash);
                    }
                }

                for (uint256 j = 0; j < orderParams.consideration.length; ++j) {
                    ConsiderationItem memory item = (
                        orderParams.consideration[j]
                    );

                    if (item.startAmount != 0) {
                        order.parameters.consideration[j].endAmount = (
                            item.startAmount
                        );
                    } else {
                        order.parameters.consideration[j].startAmount = (
                            item.endAmount
                        );
                    }

                    if (
                        uint256(item.itemType) > 3 &&
                        item.identifierOrCriteria == 0
                    ) {
                        order.parameters.consideration[j].itemType = ItemType(
                            uint256(item.itemType) - 2
                        );
                        bytes32 itemHash = keccak256(
                            abi.encodePacked(
                                uint256(i),
                                uint256(j),
                                Side.CONSIDERATION
                            )
                        );
                        order
                            .parameters
                            .consideration[j]
                            .identifierOrCriteria = context
                            .testHelpers
                            .criteriaResolverHelper()
                            .wildcardIdentifierForGivenItemHash(itemHash);
                    }

                    // TODO: support offerer returning other recipients.
                    order.parameters.consideration[j].recipient = payable(
                        address(context.contractOfferer)
                    );
                }
            }
        }

        // Set up a random base counter and nonce, which will be used to set the
        // counter and nonce for each offerer in the `_signOrders` function.
        context.counter = context.randRange(0, type(uint128).max);
        context.contractOffererNonce = context.randRange(0, type(uint128).max);

        // Sign orders and add the hashes to the context.
        _signOrders(space, orders, context);

        return orders;
    }

    function generateRecipient(
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        return space.recipient.generate(context);
    }

    function generateCaller(
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal view returns (address) {
        return space.caller.generate(context);
    }

    function generateFulfillerConduitKey(
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure returns (bytes32) {
        return space.conduit.generate(context).key;
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
                    orders[i].parameters.offer[j] = space
                        .orders[i]
                        .offer[j]
                        .generate(context, true, i, j);
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
                false, // ensureDirectSupport false: allow native offer items
                i
            );
            orders[i] = OrderLib
                .empty()
                .withParameters(orderParameters)
                .toAdvancedOrder({
                    numerator: 1,
                    denominator: 1,
                    extraData: bytes("")
                })
                .withBroadOrderType(space.orders[i].orderType, context)
                .withGeneratedExtraData(space.orders[i].extraData, context);
        }
    }

    function _adjustUnavailable(
        AdvancedOrder[] memory orders,
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal pure {
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
    ) internal pure {
        OrderParameters memory parameters = order.parameters;
        // UnavailableReason.AVAILABLE => take no action
        // UnavailableReason.CANCELLED => state will be conformed in amend phase
        // UnavailableReason.ALREADY_FULFILLED => state will be conformed in
        //                                        amend phase
        // UnavailableReason.MAX_FULFILLED_SATISFIED => should never hit this
        // UnavailableReason.GENERATE_ORDER_FAILURE => handled downstream
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
        }
    }

    struct SquareUpRemaindersInfra {
        MatchComponent[] remainders;
        CriteriaResolver[] resolvers;
        uint256 resolvedIdentifier;
        ItemType resolvedItemType;
        ConsiderationItem item;
        uint256 amount;
    }

    /**
     * @dev This function gets the remainders from the match and inserts them
     *      into the orders. This is done to ensure that the orders are
     *      matchable. If there are consideration remainders, they are inserted
     *      into the orders on the offer side.
     */
    function _squareUpRemainders(
        AdvancedOrder[] memory orders,
        AdvancedOrdersSpace memory space,
        FuzzGeneratorContext memory context
    ) internal {
        // Toss a bunch of stuff into a struct to avoid stack too deep errors.
        SquareUpRemaindersInfra memory infra;

        for (uint256 i = 0; i < orders.length; ++i) {
            AdvancedOrder memory order = orders[i];
            orders[i] = order.withCoercedAmountsForPartialFulfillment();
        }

        UnavailableReason[] memory unavailableReasons = new UnavailableReason[](
            space.orders.length
        );

        for (uint256 i; i < space.orders.length; ++i) {
            unavailableReasons[i] = space.orders[i].unavailableReason;
        }

        {
            infra.resolvers = context
                .testHelpers
                .criteriaResolverHelper()
                .deriveCriteriaResolvers(orders);

            bytes32[] memory orderHashes = orders.getOrderHashes(
                address(context.seaport)
            );

            OrderDetails[] memory details = orders.getOrderDetails(
                infra.resolvers,
                orderHashes,
                unavailableReasons
            );
            // Get the remainders.
            (, , infra.remainders) = details.getMatchedFulfillments();
        }

        // Iterate over the remainders and insert them into the orders.
        for (uint256 i = 0; i < infra.remainders.length; ++i) {
            {
                uint8 orderIndex;
                uint8 itemIndex;

                // Unpack the remainder from the MatchComponent into its
                // constituent parts.
                (infra.amount, orderIndex, itemIndex) = infra
                    .remainders[i]
                    .unpack();

                // Get the consideration item with the remainder.
                infra.item = orders[orderIndex].parameters.consideration[
                    itemIndex
                ];

                infra.resolvedIdentifier = infra.item.identifierOrCriteria;
                infra.resolvedItemType = infra.item.itemType;
                if (
                    infra.item.itemType == ItemType.ERC721_WITH_CRITERIA ||
                    infra.item.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    infra.resolvedItemType = _convertCriteriaItemType(
                        infra.item.itemType
                    );
                    if (infra.item.identifierOrCriteria == 0) {
                        bytes32 itemHash = keccak256(
                            abi.encodePacked(
                                uint256(orderIndex),
                                uint256(itemIndex),
                                Side.CONSIDERATION
                            )
                        );
                        infra.resolvedIdentifier = context
                            .testHelpers
                            .criteriaResolverHelper()
                            .wildcardIdentifierForGivenItemHash(itemHash);
                    } else {
                        infra.resolvedIdentifier = context
                            .testHelpers
                            .criteriaResolverHelper()
                            .resolvableIdentifierForGivenCriteria(
                                infra.item.identifierOrCriteria
                            )
                            .resolvedIdentifier;
                    }
                }
            }

            // Pick a random order to insert the remainder into.
            uint256 orderInsertionIndex = context.randRange(
                0,
                orders.length - 1
            );

            OfferItem memory newItem;
            {
                uint256 amountGivenPartial = _applyInverseAndRoundUp(
                    infra.amount,
                    uint256(orders[orderInsertionIndex].numerator),
                    uint256(orders[orderInsertionIndex].denominator)
                );

                newItem = OfferItem({
                    itemType: infra.resolvedItemType,
                    token: infra.item.token,
                    identifierOrCriteria: infra.resolvedIdentifier,
                    startAmount: amountGivenPartial,
                    endAmount: amountGivenPartial
                });
            }

            // Create a new offer array with room for the remainder.
            OfferItem[] memory newOffer = new OfferItem[](
                orders[orderInsertionIndex].parameters.offer.length + 1
            );

            // If the targeted order has no offer, just add the remainder to the
            // new offer.
            if (orders[orderInsertionIndex].parameters.offer.length == 0) {
                newOffer[0] = newItem;
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
                newOffer[itemInsertionIndex] = newItem;

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

                // shift any wildcard offer items.
                context.testHelpers.criteriaResolverHelper().shiftWildcards(
                    orderInsertionIndex,
                    Side.OFFER,
                    itemInsertionIndex,
                    newOffer.length - 1
                );
            }

            bytes32 newOfferHash = keccak256(abi.encode(newOffer));

            bytes32 existingOfferHash = keccak256(
                abi.encode(orders[orderInsertionIndex].parameters.offer)
            );

            if (newOfferHash == existingOfferHash) {
                // If the offer hash is the same, then the offer is unchanged.
                // This can happen if the offer is empty and the remainder is
                // inserted at index 0.  In this case, we can just skip this
                // iteration.
                revert("FuzzGenerators: offer hash unchanged");
            }

            // Replace the offer in the targeted order with the new offer.
            orders[orderInsertionIndex].parameters.offer = newOffer;
        }

        // TODO: remove this check once high confidence in the mechanic has been
        // established (this just fails fast to rule out downstream issues)
        if (infra.remainders.length > 0) {
            infra.resolvers = context
                .testHelpers
                .criteriaResolverHelper()
                .deriveCriteriaResolvers(orders);
            bytes32[] memory orderHashes = orders.getOrderHashes(
                address(context.seaport)
            );
            OrderDetails[] memory details = orders.getOrderDetails(
                infra.resolvers,
                orderHashes,
                unavailableReasons
            );
            // Get the remainders.
            (, , infra.remainders) = details.getMatchedFulfillments();

            if (infra.remainders.length > 0) {
                // NOTE: this may be caused by inserting offer items into orders
                // with partial fill fractions. The amount on the item that is
                // inserted should be increased based on fraction in that case.
                revert("FuzzGenerators: could not satisfy remainders");
            }
        }
    }

    function _convertCriteriaItemType(
        ItemType itemType
    ) internal pure returns (ItemType) {
        if (itemType == ItemType.ERC721_WITH_CRITERIA) {
            return ItemType.ERC721;
        } else if (itemType == ItemType.ERC1155_WITH_CRITERIA) {
            return ItemType.ERC1155;
        } else {
            revert(
                "AdvancedOrdersSpaceGenerator: amount deriver helper resolving non criteria item type"
            );
        }
    }

    function _applyInverseAndRoundUp(
        uint256 amount,
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 newAmount) {
        if (numerator == denominator) {
            return amount;
        }

        uint256 newAmountSansRounding = (amount * denominator) / numerator;

        newAmount =
            newAmountSansRounding +
            ((denominator -
                ((newAmountSansRounding * numerator) % denominator)) /
                numerator);

        if ((newAmount * numerator) % denominator != 0) {
            revert("AdvancedOrdersSpaceGenerator: inverse change failed");
        }

        if ((newAmount * numerator) / denominator < amount) {
            revert("AdvancedOrdersSpaceGenerator: inverse not rounded up");
        }
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
                    orderParams.offerer,
                    orderInsertionIndex,
                    0
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
                    orderParams.offerer,
                    orderInsertionIndex,
                    0
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
                        orderParams.offerer,
                        orderInsertionIndex,
                        0
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
            if (orderParams.orderType != OrderType.CONTRACT) {
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
                    orderParams.offerer,
                    orderInsertionIndex,
                    0
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
            orderParams.orderType != OrderType.CONTRACT
                ? context.dillon.addr
                : address(context.contractOfferer)
        );
    }

    function _signOrders(
        AdvancedOrdersSpace memory space,
        AdvancedOrder[] memory orders,
        FuzzGeneratorContext memory context
    ) internal {
        // Iterate over the orders and sign them.
        for (uint256 i = 0; i < orders.length; ++i) {
            // Set up variables.
            AdvancedOrder memory order = orders[i];

            // Skip contract orders since they do not have signatures
            if (order.parameters.orderType == OrderType.CONTRACT) {
                uint256 contractOffererSpecificContractNonce = context
                    .contractOffererNonce +
                    uint256(uint160(order.parameters.offerer));
                // Just for convenience of having them both in one place.
                FuzzInscribers.inscribeContractOffererNonce(
                    order.parameters.offerer,
                    contractOffererSpecificContractNonce,
                    context.seaport
                );
                continue;
            }

            // Get the counter for the offerer.
            uint256 offererSpecificCounter = context.counter +
                uint256(uint160(order.parameters.offerer));

            FuzzInscribers.inscribeCounter(
                order.parameters.offerer,
                offererSpecificCounter,
                context.seaport
            );

            bytes32 orderHash = order.getTipNeutralizedOrderHash(
                context.seaport,
                offererSpecificCounter
            );

            // Replace the unsigned order with a signed order.
            orders[i] = order.withGeneratedSignature(
                space.orders[i].signatureMethod,
                space.orders[i].eoaSignatureType,
                space.orders[i].bulkSigHeight,
                space.orders[i].bulkSigIndex,
                space.orders[i].offerer,
                order.parameters.offerer,
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

/**
 * @dev Convert an OrderComponentsSpace struct into actual OrderParameters.
 */
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
        bool ensureDirectSupport,
        uint256 orderIndex
    ) internal returns (OrderParameters memory) {
        if (
            space.offerer == Offerer.EIP1271 &&
            space.signatureMethod == SignatureMethod.EOA
        ) {
            space.signatureMethod = SignatureMethod.EIP1271;
        }

        OrderParameters memory params;
        {
            address offerer;
            if (space.signatureMethod == SignatureMethod.SELF_AD_HOC) {
                offerer = context.caller;
            } else {
                offerer = space.offerer.generate(context);
            }

            params = OrderParametersLib
                .empty()
                .withOfferer(offerer)
                .withOffer(
                    space.offer.generate(
                        context,
                        ensureDirectSupport,
                        orderIndex
                    )
                )
                .withConsideration(
                    space.consideration.generate(context, offerer, orderIndex)
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

/**
 * @dev Select a conduit.
 */
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

/**
 * @dev Generate parameters related to an order's "broad" type: full, partial,
 *      or contract.
 */
library BroadOrderTypeGenerator {
    using PRNGHelpers for FuzzGeneratorContext;
    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;

    function withBroadOrderType(
        AdvancedOrder memory order,
        BroadOrderType broadOrderType,
        FuzzGeneratorContext memory context
    ) internal pure returns (AdvancedOrder memory) {
        OrderParameters memory orderParams = order.parameters;
        // NOTE: this assumes that the order type has been set to either
        // FULL_OPEN (by .empty()) or FULL_RESTRICTED (by ZoneGenerator).
        if (broadOrderType == BroadOrderType.PARTIAL) {
            // Adjust the order type based on whether it is restricted
            if (orderParams.orderType == OrderType.FULL_RESTRICTED) {
                order.parameters = orderParams.withOrderType(
                    OrderType.PARTIAL_RESTRICTED
                );
            } else if (orderParams.orderType == OrderType.FULL_OPEN) {
                order.parameters = orderParams.withOrderType(
                    OrderType.PARTIAL_OPEN
                );
            }

            // TODO: get more sophisticated about this down the line
            uint120 numerator = uint120(context.randRange(1, type(uint80).max));
            uint120 denominator = uint120(
                numerator * context.randRange(1, type(uint40).max)
            );

            return
                order
                    .withNumerator(numerator)
                    .withDenominator(denominator)
                    .withCoercedAmountsForPartialFulfillment();
        } else if (broadOrderType == BroadOrderType.CONTRACT) {
            order.parameters = orderParams.withOrderType(OrderType.CONTRACT);
        }

        return order;
    }
}

/**
 * @dev Generate extra data on an order.
 */
library ExtraDataGenerator {
    using PRNGHelpers for FuzzGeneratorContext;
    using AdvancedOrderLib for AdvancedOrder;

    function withGeneratedExtraData(
        AdvancedOrder memory order,
        ExtraData extraData,
        FuzzGeneratorContext memory context
    ) internal pure returns (AdvancedOrder memory) {
        if (extraData == ExtraData.NONE) {
            return order.withExtraData("");
        } else if (extraData == ExtraData.RANDOM) {
            return
                order.withExtraData(generateRandomBytesArray(context, 1, 4096));
        } else {
            revert("ExtraDataGenerator: unsupported ExtraData value");
        }
    }

    function generateRandomBytesArray(
        FuzzGeneratorContext memory context,
        uint256 minSize,
        uint256 maxSize
    ) internal pure returns (bytes memory) {
        uint256 length = context.randRange(minSize, maxSize);

        // Allocate & round the size up to a whole word.
        bytes memory arr = new bytes(((length + 31) / 32) * 32);

        // Insert each random word in.
        for (uint256 i = 0; i < length; i += 32) {
            uint256 randomWord = context.rand();

            assembly {
                mstore(add(add(arr, 32), i), randomWord)
            }
        }

        // Resize the array to the actual length.
        assembly {
            mstore(arr, length)
        }

        // Return the array.
        return arr;
    }
}

/**
 * @dev Generate zone-related parameters for an order.
 */
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

/**
 * @dev Convert an array of generated OfferItemSpace structs into actual
 *      OfferItem structs.
 */
library OfferItemSpaceGenerator {
    using OfferItemLib for OfferItem;

    using AmountGenerator for OfferItem;
    using CriteriaGenerator for OfferItem;
    using TokenIndexGenerator for TokenIndex;
    using PRNGHelpers for FuzzGeneratorContext;

    function generate(
        OfferItemSpace[] memory space,
        FuzzGeneratorContext memory context,
        bool ensureDirectSupport,
        uint256 orderIndex
    ) internal returns (OfferItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        OfferItem[] memory offerItems = new OfferItem[](len);

        for (uint256 i; i < len; ++i) {
            offerItems[i] = generate(
                space[i],
                context,
                ensureDirectSupport,
                orderIndex,
                i
            );
        }
        return offerItems;
    }

    function generate(
        OfferItemSpace memory space,
        FuzzGeneratorContext memory context,
        bool ensureDirectSupport,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal returns (OfferItem memory) {
        ItemType itemType = space.itemType;

        if (ensureDirectSupport && itemType == ItemType.NATIVE) {
            itemType = ItemType(context.randRange(1, 5));
        }

        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(itemType)
            .withToken(space.tokenIndex.generate(itemType, context))
            .withGeneratedAmount(space.amount, context);

        return
            offerItem.withGeneratedIdentifierOrCriteria(
                itemType,
                space.criteria,
                context,
                orderIndex,
                itemIndex
            );
    }
}

/**
 * @dev Convert an array of generated ConsiderationItemSpace structs into actual
 *      ConsiderationItem structs.
 */
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
        uint256 orderIndex
    ) internal returns (ConsiderationItem[] memory) {
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
                i
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
    ) internal returns (ConsiderationItem memory) {
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(space.itemType)
            .withToken(space.tokenIndex.generate(space.itemType, context))
            .withGeneratedAmount(space.amount, context)
            .withRecipient(space.recipient.generate(context, offerer));

        return
            considerationItem.withGeneratedIdentifierOrCriteria(
                space.itemType,
                space.criteria,
                context,
                orderIndex,
                itemIndex
            );
    }
}

/**
 * @dev Generate an order signature using the given method and params.
 */
library SignatureGenerator {
    using LibPRNG for LibPRNG.PRNG;

    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;

    using FuzzHelpers for AdvancedOrder;
    using OffererGenerator for Offerer;

    using ExtraDataGenerator for FuzzGeneratorContext;

    struct SigInfra {
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function withGeneratedSignature(
        AdvancedOrder memory order,
        SignatureMethod method,
        EOASignature eoaSignatureType,
        uint256 bulkSigHeight,
        uint256 bulkSigIndex,
        Offerer offerer,
        address offererAddress,
        bytes32 orderHash,
        FuzzGeneratorContext memory context
    ) internal returns (AdvancedOrder memory) {
        if (order.parameters.orderType == OrderType.CONTRACT) {
            return order;
        }

        bytes memory signature;

        SigInfra memory infra = SigInfra({
            digest: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        if (method == SignatureMethod.EOA) {
            uint256 offererKey = offerer.getKey(context);

            if (eoaSignatureType == EOASignature.STANDARD) {
                infra.digest = _getDigest(orderHash, context);
                (infra.v, infra.r, infra.s) = context.vm.sign(
                    offererKey,
                    infra.digest
                );
                signature = abi.encodePacked(infra.r, infra.s, infra.v);

                _checkSig(
                    infra.digest,
                    infra.v,
                    infra.r,
                    infra.s,
                    offerer,
                    context
                );
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.EIP2098) {
                infra.digest = _getDigest(orderHash, context);
                (infra.v, infra.r, infra.s) = context.vm.sign(
                    offererKey,
                    infra.digest
                );

                {
                    uint256 yParity;
                    if (infra.v == 27) {
                        yParity = 0;
                    } else {
                        yParity = 1;
                    }
                    uint256 yParityAndS = (yParity << 255) | uint256(infra.s);
                    signature = abi.encodePacked(infra.r, yParityAndS);
                }

                _checkSig(
                    infra.digest,
                    infra.v,
                    infra.r,
                    infra.s,
                    offerer,
                    context
                );
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.BULK) {
                signature = _getBulkSig(
                    order,
                    bulkSigHeight,
                    bulkSigIndex,
                    offererKey,
                    false,
                    context
                );
                return order.withSignature(signature);
            } else if (eoaSignatureType == EOASignature.BULK2098) {
                signature = _getBulkSig(
                    order,
                    bulkSigHeight,
                    bulkSigIndex,
                    offererKey,
                    true,
                    context
                );
                return order.withSignature(signature);
            } else {
                revert("SignatureGenerator: Invalid EOA signature type");
            }
        } else {
            // For all others, generate a random signature half the time
            if (context.prng.next() % 2 == 0) {
                signature = context.generateRandomBytesArray(1, 4096);
            }

            if (method == SignatureMethod.EIP1271) {
                infra.digest = _getDigest(orderHash, context);
                EIP1271Offerer(payable(offererAddress)).registerSignature(
                    infra.digest,
                    signature
                );
            } else if (
                method != SignatureMethod.SELF_AD_HOC &&
                method != SignatureMethod.CONTRACT &&
                method != SignatureMethod.VALIDATE
            ) {
                revert("SignatureGenerator: Invalid signature method");
            }

            return order.withSignature(signature);
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
        uint256 height,
        uint256 index,
        uint256 offererKey,
        bool useEIP2098,
        FuzzGeneratorContext memory context
    ) internal returns (bytes memory signature) {
        EIP712MerkleTree merkleTree = new EIP712MerkleTree();

        // Pass the hash into `signSparseBulkOrder` instead of the order
        // components, since we need to neutralize the tip for validation to
        // work.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);

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

/**
 * @dev Select a test token by index.
 */
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

/**
 * @dev Generate order start and end timestamps.
 */
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
                type(uint40).max
            );
            uint256 b = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint40).max
            );
            low = a < b ? a : b;
            high = a > b ? a : b;
        }
        if (time == Time.EXACT_START) {
            low = context.timestamp;
            high = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint40).max
            );
        }
        if (time == Time.ONGOING) {
            low = bound(context.prng.next(), 0, context.timestamp - 1);
            high = bound(
                context.prng.next(),
                context.timestamp + 1,
                type(uint40).max
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

/**
 * @dev Generate offer and consideration item amounts.
 */
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

        uint256 a = bound(context.prng.next(), 1, 100_000_000e18);
        uint256 b = bound(context.prng.next(), 1, 100_000_000e18);

        // TODO: Work out a better way to handle this
        if (context.basicOrderCategory == BasicOrderCategory.BID) {
            a *= 1000;
            b *= 1000;
        }

        uint256 high = a > b ? a : b;
        uint256 low = a < b ? a : b;

        if (
            amount == Amount.FIXED ||
            context.basicOrderCategory != BasicOrderCategory.NONE
        ) {
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

        uint256 a = bound(context.prng.next(), 1, 100_000_000e18);
        uint256 b = bound(context.prng.next(), 1, 100_000_000e18);

        uint256 high = a > b ? a : b;
        uint256 low = a < b ? a : b;

        if (
            amount == Amount.FIXED ||
            context.basicOrderCategory != BasicOrderCategory.NONE
        ) {
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

/**
 * @dev Generate a recipient address.
 */
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

/**
 * @dev Generate offer and consideration criteria.
 */
library CriteriaGenerator {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    using LibPRNG for LibPRNG.PRNG;

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
                // Select and register an identifier
                context.testHelpers.criteriaResolverHelper().generateWildcard(
                    context.prng,
                    itemType == ItemType.ERC721_WITH_CRITERIA
                        ? context.starting721offerIndex++
                        : type(uint256).max,
                    orderIndex,
                    itemIndex,
                    Side.CONSIDERATION
                );

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
                // Select and register an identifier
                context.testHelpers.criteriaResolverHelper().generateWildcard(
                    context.prng,
                    itemType == ItemType.ERC721_WITH_CRITERIA
                        ? context.starting721offerIndex++
                        : type(uint256).max,
                    orderIndex,
                    itemIndex,
                    Side.OFFER
                );

                // Return wildcard criteria item with identifier 0
                return item.withIdentifierOrCriteria(0);
            }
        }
    }
}

/**
 * @dev Generate offerer address and key.
 */
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
        } else if (offerer == Offerer.CONTRACT_OFFERER) {
            return address(context.contractOfferer);
        } else if (offerer == Offerer.EIP1271) {
            return address(context.eip1271Offerer);
        } else {
            revert("OffererGenerator: invalid offerer");
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
        } else if (offerer == Offerer.CONTRACT_OFFERER) {
            revert("getKey -- contract offerer");
        } else {
            revert("Invalid offerer");
        }
    }
}

/**
 * @dev Generate a fulfillment recipient address.
 */
library FulfillmentRecipientGenerator {
    function generate(
        FulfillmentRecipient recipient,
        FuzzGeneratorContext memory context
    ) internal pure returns (address) {
        if (recipient == FulfillmentRecipient.ZERO) {
            return address(0);
        } else if (recipient == FulfillmentRecipient.ALICE) {
            return context.alice.addr;
        } else if (recipient == FulfillmentRecipient.BOB) {
            return context.bob.addr;
        } else if (recipient == FulfillmentRecipient.EVE) {
            return context.eve.addr;
        } else {
            revert("Invalid fulfillment recipient");
        }
    }
}

/**
 * @dev Generate a caller address.
 */
library CallerGenerator {
    function generate(
        Caller caller,
        FuzzGeneratorContext memory context
    ) internal view returns (address) {
        if (caller == Caller.TEST_CONTRACT) {
            return address(this);
        } else if (caller == Caller.ALICE) {
            return context.alice.addr;
        } else if (caller == Caller.BOB) {
            return context.bob.addr;
        } else if (caller == Caller.CAROL) {
            return context.carol.addr;
        } else if (caller == Caller.DILLON) {
            return context.dillon.addr;
        } else if (caller == Caller.EVE) {
            return context.eve.addr;
        } else if (caller == Caller.FRANK) {
            return context.frank.addr;
        } else {
            revert("Invalid caller");
        }
    }
}

/**
 * @dev Helpers for generating random values
 */
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

    function rand(
        FuzzGeneratorContext memory context
    ) internal pure returns (uint256) {
        return context.prng.next();
    }

    function choice(
        FuzzGeneratorContext memory context,
        uint256[] memory arr
    ) internal pure returns (uint256) {
        return arr[context.prng.next() % arr.length];
    }
}

/**
 * @dev Implementation cribbed from forge-std bound
 */
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
    if (x >= type(uint256).max - 3 && size > type(uint256).max - x) {
        return max - (type(uint256).max - x);
    }

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
