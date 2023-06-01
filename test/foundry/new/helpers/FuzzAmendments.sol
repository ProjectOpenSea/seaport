// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { AdvancedOrderLib } from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType, Side } from "seaport-sol/src/SeaportEnums.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import {
    OrderStatusEnum,
    ContractOrderRebate
} from "seaport-sol/src/SpaceEnums.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

import {
    OffererZoneFailureReason
} from "../../../../contracts/test/OffererZoneFailureReason.sol";

import { FuzzGeneratorContext } from "./FuzzGeneratorContextLib.sol";
import { PRNGHelpers } from "./FuzzGenerators.sol";

import {
    FractionResults,
    FractionStatus,
    FractionUtil
} from "./FractionUtil.sol";

/**
 *  @dev "Amendments" are changes to Seaport state that are required to execute
 *       a given order configuration. Amendments do not modify the orders, test
 *       context, or test environment, but rather set up Seaport state like
 *       order statuses, counters, and contract offerer nonces. Amendments run
 *       after order generation, but before derivers.
 */
abstract contract FuzzAmendments is Test {
    using AdvancedOrderLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;

    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzInscribers for AdvancedOrder;
    using FuzzInscribers for address;
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for OrderParameters;

    using PRNGHelpers for FuzzGeneratorContext;

    /**
     *  @dev Configure the contract offerer to provide rebates if required.
     */
    function prepareRebates(FuzzTestContext memory context) public {
        // TODO: make it so it adds / removes / modifies more than a single thing
        // and create arbitrary new items.
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory orderParams = (
                context.executionState.orders[i].parameters
            );

            if (orderParams.orderType == OrderType.CONTRACT) {
                uint256 contractNonce;
                HashCalldataContractOfferer offerer;
                {
                    ContractOrderRebate rebate = (
                        context.advancedOrdersSpace.orders[i].rebate
                    );

                    if (rebate == ContractOrderRebate.NONE) {
                        continue;
                    }

                    offerer = (
                        HashCalldataContractOfferer(
                            payable(orderParams.offerer)
                        )
                    );

                    bytes32 orderHash = context
                        .executionState
                        .orderDetails[i]
                        .orderHash;

                    if (rebate == ContractOrderRebate.MORE_OFFER_ITEMS) {
                        offerer.addExtraItemMutation(
                            Side.OFFER,
                            ReceivedItem({
                                itemType: ItemType.NATIVE,
                                token: address(0),
                                identifier: 0,
                                amount: 1,
                                recipient: payable(orderParams.offerer)
                            }),
                            orderHash
                        );
                    } else if (
                        rebate == ContractOrderRebate.MORE_OFFER_ITEM_AMOUNTS
                    ) {
                        uint256 itemIdx = _findFirstNon721Index(
                            orderParams.offer
                        );
                        offerer.addItemAmountMutation(
                            Side.OFFER,
                            itemIdx,
                            orderParams.offer[itemIdx].startAmount + 1,
                            orderHash
                        );
                    } else if (
                        rebate == ContractOrderRebate.LESS_CONSIDERATION_ITEMS
                    ) {
                        offerer.addDropItemMutation(
                            Side.CONSIDERATION,
                            orderParams.consideration.length - 1,
                            orderHash
                        );
                    } else if (
                        rebate ==
                        ContractOrderRebate.LESS_CONSIDERATION_ITEM_AMOUNTS
                    ) {
                        uint256 itemIdx = _findFirstNon721Index(
                            orderParams.consideration
                        );
                        offerer.addItemAmountMutation(
                            Side.CONSIDERATION,
                            itemIdx,
                            orderParams.consideration[itemIdx].startAmount - 1,
                            orderHash
                        );
                    } else {
                        revert("FuzzAmendments: unknown rebate type");
                    }

                    uint256 shiftedOfferer = (uint256(
                        uint160(orderParams.offerer)
                    ) << 96);
                    contractNonce = uint256(orderHash) ^ shiftedOfferer;
                }

                uint256 originalContractNonce = (
                    context.seaport.getContractOffererNonce(orderParams.offerer)
                );

                // Temporarily adjust the contract nonce and reset it after.
                orderParams.offerer.inscribeContractOffererNonce(
                    contractNonce,
                    context.seaport
                );

                (
                    SpentItem[] memory offer,
                    ReceivedItem[] memory consideration
                ) = offerer.previewOrder(
                        address(context.seaport),
                        context.executionState.caller,
                        _toSpent(orderParams.offer),
                        _toSpent(orderParams.consideration),
                        context.executionState.orders[i].extraData
                    );

                orderParams.offerer.inscribeContractOffererNonce(
                    originalContractNonce,
                    context.seaport
                );

                context
                    .executionState
                    .previewedOrders[i]
                    .parameters
                    .offer = _toOffer(offer);
                context
                    .executionState
                    .previewedOrders[i]
                    .parameters
                    .consideration = _toConsideration(consideration);
            }
        }
    }

    /**
     *  @dev Validate orders that should be in "Validated" state.
     *
     * @param context The test context.
     */
    function validateOrdersAndRegisterCheck(
        FuzzTestContext memory context
    ) public {
        for (
            uint256 i = 0;
            i < context.executionState.preExecOrderStatuses.length;
            ++i
        ) {
            if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.VALIDATED
            ) {
                bool validated = context
                    .executionState
                    .orders[i]
                    .validateTipNeutralizedOrder(context);

                require(validated, "Failed to validate orders.");
            }
        }

        context.registerCheck(FuzzChecks.check_ordersValidated.selector);
    }

    /**
     *  @dev Set up partial fill fractions for orders.
     *
     * @param context The test context.
     */
    function setPartialFills(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (
                context.executionState.preExecOrderStatuses[i] !=
                OrderStatusEnum.PARTIAL
            ) {
                continue;
            }

            AdvancedOrder memory order = context.executionState.orders[i];

            if (
                order.parameters.orderType != OrderType.PARTIAL_OPEN &&
                order.parameters.orderType != OrderType.PARTIAL_RESTRICTED
            ) {
                revert(
                    "FuzzAmendments: invalid order type for partial fill state"
                );
            }

            (uint256 denominator, bool canScaleUp) = order
                .parameters
                .getSmallestDenominator();

            // If the denominator is 0 or 1, the order cannot have a partial
            // fill fraction applied.
            if (denominator > 1) {
                // All partially-filled orders are de-facto valid.
                order.inscribeOrderStatusValidated(true, context.seaport);

                uint256 numerator = context.generatorContext.randRange(
                    1,
                    canScaleUp ? (denominator - 1) : 1
                );

                uint256 maxScaleFactor = type(uint120).max / denominator;

                uint256 scaleFactor = context.generatorContext.randRange(
                    1,
                    maxScaleFactor
                );

                numerator *= scaleFactor;
                denominator *= scaleFactor;

                if (
                    numerator == 0 ||
                    denominator < 2 ||
                    numerator >= denominator ||
                    numerator > type(uint120).max ||
                    denominator > type(uint120).max
                ) {
                    revert("FuzzAmendments: partial fill sanity check failed");
                }

                order.inscribeOrderStatusNumeratorAndDenominator(
                    uint120(numerator),
                    uint120(denominator),
                    context.seaport
                );

                // Derive the realized and final fill fractions and status.
                FractionResults memory fractionResults = (
                    FractionUtil.getPartialFillResults(
                        uint120(numerator),
                        uint120(denominator),
                        order.numerator,
                        order.denominator
                    )
                );

                // Register the realized and final fill fractions and status.
                context.expectations.expectedFillFractions[i] = fractionResults;

                // Update "previewed" orders with the realized numerator and
                // denominator so orderDetails derivation is based on realized.
                context.executionState.previewedOrders[i].numerator = (
                    fractionResults.realizedNumerator
                );
                context.executionState.previewedOrders[i].denominator = (
                    fractionResults.realizedDenominator
                );
            } else {
                // TODO: log these occurrences?
                context.executionState.preExecOrderStatuses[i] = (
                    OrderStatusEnum.AVAILABLE
                );
            }
        }
    }

    /**
     *  @dev Ensure each order's on chain status matches its generated status.
     *
     * @param context The test context.
     */
    function conformOnChainStatusToExpected(
        FuzzTestContext memory context
    ) public {
        for (
            uint256 i = 0;
            i < context.executionState.preExecOrderStatuses.length;
            ++i
        ) {
            if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.VALIDATED
            ) {
                validateOrdersAndRegisterCheck(context);
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.CANCELLED_EXPLICIT
            ) {
                context.executionState.orders[i].inscribeOrderStatusCancelled(
                    true,
                    context.seaport
                );
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.FULFILLED
            ) {
                context
                    .executionState
                    .orders[i]
                    .inscribeOrderStatusNumeratorAndDenominator(
                        1,
                        1,
                        context.seaport
                    );
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.AVAILABLE
            ) {
                context
                    .executionState
                    .orders[i]
                    .inscribeOrderStatusNumeratorAndDenominator(
                        0,
                        0,
                        context.seaport
                    );
                context.executionState.orders[i].inscribeOrderStatusCancelled(
                    false,
                    context.seaport
                );
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.REVERT
            ) {
                OrderParameters memory orderParams = context
                    .executionState
                    .orders[i]
                    .parameters;
                bytes32 orderHash = context
                    .executionState
                    .orderDetails[i]
                    .orderHash;
                if (orderParams.orderType != OrderType.CONTRACT) {
                    revert("FuzzAmendments: bad pre-exec order status");
                }

                HashCalldataContractOfferer(payable(orderParams.offerer))
                    .setFailureReason(
                        orderHash,
                        OffererZoneFailureReason.ContractOfferer_generateReverts
                    );
            }
        }
    }

    /**
     *  @dev Set up offerer's counter value.
     *
     * @param context The test context.
     */
    function setCounter(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = (
                context.executionState.orders[i].parameters
            );

            if (order.orderType == OrderType.CONTRACT) {
                continue;
            }

            uint256 offererSpecificCounter = context.executionState.counter +
                uint256(uint160(order.offerer));

            order.offerer.inscribeCounter(
                offererSpecificCounter,
                context.seaport
            );
        }
    }

    /**
     *  @dev Set up contract offerer's nonce value.
     *
     * @param context The test context.
     */
    function setContractOffererNonce(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = (
                context.executionState.orders[i].parameters
            );

            if (order.orderType != OrderType.CONTRACT) {
                continue;
            }

            uint256 contractOffererSpecificContractNonce = context
                .executionState
                .contractOffererNonce + uint256(uint160(order.offerer));

            order.offerer.inscribeContractOffererNonce(
                contractOffererSpecificContractNonce,
                context.seaport
            );
        }
    }

    function _findFirstNon721Index(
        OfferItem[] memory items
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < items.length; ++i) {
            ItemType itemType = items[i].itemType;
            if (
                itemType != ItemType.ERC721 &&
                itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                return i;
            }
        }

        revert("FuzzAmendments: could not locate non-721 offer item index");
    }

    function _findFirstNon721Index(
        ConsiderationItem[] memory items
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < items.length; ++i) {
            ItemType itemType = items[i].itemType;
            if (
                itemType != ItemType.ERC721 &&
                itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                return i;
            }
        }

        revert(
            "FuzzAmendments: could not locate non-721 consideration item index"
        );
    }

    function _toSpent(
        OfferItem[] memory offer
    ) internal pure returns (SpentItem[] memory spent) {
        spent = new SpentItem[](offer.length);
        for (uint256 i = 0; i < offer.length; ++i) {
            OfferItem memory item = offer[i];
            spent[i] = SpentItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                amount: item.startAmount
            });
        }
    }

    function _toSpent(
        ConsiderationItem[] memory consideration
    ) internal pure returns (SpentItem[] memory spent) {
        spent = new SpentItem[](consideration.length);
        for (uint256 i = 0; i < consideration.length; ++i) {
            ConsiderationItem memory item = consideration[i];
            spent[i] = SpentItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                amount: item.startAmount
            });
        }
    }

    function _toOffer(
        SpentItem[] memory spent
    ) internal pure returns (OfferItem[] memory offer) {
        offer = new OfferItem[](spent.length);
        for (uint256 i = 0; i < spent.length; ++i) {
            SpentItem memory item = spent[i];
            offer[i] = OfferItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifier,
                startAmount: item.amount,
                endAmount: item.amount
            });
        }
    }

    function _toConsideration(
        ReceivedItem[] memory received
    ) internal pure returns (ConsiderationItem[] memory consideration) {
        consideration = new ConsiderationItem[](received.length);
        for (uint256 i = 0; i < received.length; ++i) {
            ReceivedItem memory item = received[i];
            consideration[i] = ConsiderationItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifier,
                startAmount: item.amount,
                endAmount: item.amount,
                recipient: item.recipient
            });
        }
    }
}
