// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";

import { Family, OrderStructureLib, Structure } from "./OrderStructureLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

library NavigatorSuggestedActionLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderStructureLib for AdvancedOrder;
    using OrderStructureLib for AdvancedOrder[];

    /**
     * @dev Bad request error: provided orders cannot be fulfilled.
     */
    error CannotFulfillProvidedCombinedOrder();

    /**
     * @dev Bad request error: provided orders include an invalid combination of
     *      native tokens and unavailable orders.
     */
    error InvalidNativeTokenUnavailableCombination();

    /**
     * @dev Internal error: Could not find selector for the suggested action.
     */
    error UnknownSelector();

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders and add it to the NavigatorResponse.
     */
    function withSuggestedAction(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        bytes memory callData = suggestedCallData(context);
        bytes4 selector = bytes4(callData);
        context.response.suggestedActionName = actionName(selector);
        context.response.suggestedCallData = callData;
        return context;
    }

    /**
     * @dev Add the human-readable name of the selected fulfillment method to
     *      the NavigatorResponse.
     */
    function actionName(bytes4 selector) internal pure returns (string memory) {
        if (selector == 0xe7acab24) return "fulfillAdvancedOrder";
        if (selector == 0x87201b41) return "fulfillAvailableAdvancedOrders";
        if (selector == 0xed98a574) return "fulfillAvailableOrders";
        if (selector == 0xfb0f3ee1) return "fulfillBasicOrder";
        if (selector == 0x00000000) return "fulfillBasicOrder_efficient_6GL6yc";
        if (selector == 0xb3a34c4c) return "fulfillOrder";
        if (selector == 0xf2d12b12) return "matchAdvancedOrders";
        if (selector == 0xa8174404) return "matchOrders";

        revert UnknownSelector();
    }

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders.
     */
    function suggestedCallData(
        NavigatorContext memory context
    ) internal view returns (bytes memory) {
        // Get the family of the orders (single or combined).
        Family family = context.response.orders.getFamily();

        // `mustUseMatch` returns true if the orders require the use of one of
        // the match* methods.
        //
        //TODO: why is this a proxy for an invalid offer
        // item?
        bool invalidOfferItemsLocated = mustUseMatch(context);

        // Get the structure of the orders (basic, standard, or advanced).
        Structure structure = context.response.orders.getStructure(
            address(context.request.seaport)
        );

        // TODO: figure out why this is the formula for determining if there are
        // unavailable orders.
        bool hasUnavailable = context.request.maximumFulfilled <
            context.response.orders.length;

        // The match* methods are only an option if everything is going to find
        // a partner (the first half of the if statement below) and if there are
        // no unavailable orders (the second half of the if statement below).
        bool cannotMatch = (context
            .response
            .unmetConsiderationComponents
            .length !=
            0 ||
            hasUnavailable);

        // Iterate through the orders and check if any of the orders has an
        // unavailable reason.
        for (uint256 i = 0; i < context.response.orderDetails.length; ++i) {
            if (
                context.response.orderDetails[i].unavailableReason !=
                UnavailableReason.AVAILABLE
            ) {
                hasUnavailable = true;
                break;
            }
        }

        // If there are unavailable orders, follow this branch.
        if (hasUnavailable) {
            // If there are unavailable orders and the orders could only be
            // fulfilled using match*, it's a no-go.
            if (invalidOfferItemsLocated) {
                revert InvalidNativeTokenUnavailableCombination();
            }

            // If there are unavailable orders and the orders are advanced, use
            // fulfillAvailableAdvancedOrders.
            if (structure == Structure.ADVANCED) {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAvailableAdvancedOrders,
                        (
                            context.response.orders,
                            context.response.criteriaResolvers,
                            context.response.offerFulfillments,
                            context.response.considerationFulfillments,
                            context.request.fulfillerConduitKey,
                            context.request.recipient,
                            context.request.maximumFulfilled
                        )
                    );
            } else {
                // If there are unavailable orders and the orders are not
                // advanced, use fulfillAvailableOrders.
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAvailableOrders,
                        (
                            context.response.orders.toOrders(),
                            context.response.offerFulfillments,
                            context.response.considerationFulfillments,
                            context.request.fulfillerConduitKey,
                            context.request.maximumFulfilled
                        )
                    );
            }
        }

        // If there are no unavailable orders, follow this branch.

        // If the order family is single (just one being fulfilled) and it
        // doesn't require using match*, use the appropriate fulfill* method.
        if (family == Family.SINGLE && !invalidOfferItemsLocated) {
            // If the order structure is basic, use
            // fulfillBasicOrder_efficient_6GL6yc for maximum gas efficiency.
            if (structure == Structure.BASIC) {
                AdvancedOrder memory order = context.response.orders[0];
                return
                    abi.encodeCall(
                        ConsiderationInterface
                            .fulfillBasicOrder_efficient_6GL6yc,
                        (
                            order.toBasicOrderParameters(
                                order.getBasicOrderType()
                            )
                        )
                    );
            }

            // If the order structure is standard, use fulfillOrder.
            if (structure == Structure.STANDARD) {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillOrder,
                        (
                            context.response.orders[0].toOrder(),
                            context.request.fulfillerConduitKey
                        )
                    );
            }

            // If the order structure is advanced, use fulfillAdvancedOrder.
            if (structure == Structure.ADVANCED) {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAdvancedOrder,
                        (
                            context.response.orders[0],
                            context.response.criteriaResolvers,
                            context.request.fulfillerConduitKey,
                            context.request.recipient
                        )
                    );
            }
        }

        // This is like saying "if it's not possible to use match* but it's
        // mandatory to use match*, revert."
        if (cannotMatch && invalidOfferItemsLocated) {
            revert CannotFulfillProvidedCombinedOrder();
        }

        // If it's not mandatory to use match* and it's not possible to use
        // match*, use fulfillAvailable*.
        if (cannotMatch) {
            if (structure == Structure.ADVANCED) {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAvailableAdvancedOrders,
                        (
                            context.response.orders,
                            context.response.criteriaResolvers,
                            context.response.offerFulfillments,
                            context.response.considerationFulfillments,
                            context.request.fulfillerConduitKey,
                            context.request.recipient,
                            context.request.maximumFulfilled
                        )
                    );
            } else {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAvailableOrders,
                        (
                            context.response.orders.toOrders(),
                            context.response.offerFulfillments,
                            context.response.considerationFulfillments,
                            context.request.fulfillerConduitKey,
                            context.request.maximumFulfilled
                        )
                    );
            }
        } else if (invalidOfferItemsLocated) {
            // Even if match* is an option, if there are invalid offer items and
            // the structure is advanced use fulfillAvailable*.
            if (structure == Structure.ADVANCED) {
                return
                    abi.encodeCall(
                        ConsiderationInterface.fulfillAvailableAdvancedOrders,
                        (
                            context.response.orders,
                            context.response.criteriaResolvers,
                            context.response.offerFulfillments,
                            context.response.considerationFulfillments,
                            context.request.fulfillerConduitKey,
                            context.request.recipient,
                            context.request.maximumFulfilled
                        )
                    );
            } else {
                // TODO: document.
                return
                    abi.encodeCall(
                        ConsiderationInterface.matchOrders,
                        (
                            context.response.orders.toOrders(),
                            context.response.fulfillments
                        )
                    );
            }
        } else {
            // If match* is an option and there are no invalid offer items,
            // follow this branch.
            //
            // If the structure is advanced, use matchAdvancedOrders or use
            // fulfillAvailableAdvancedOrders depending on the caller's request.
            if (structure == Structure.ADVANCED) {
                if (context.request.preferMatch) {
                    return
                        abi.encodeCall(
                            ConsiderationInterface.matchAdvancedOrders,
                            (
                                context.response.orders,
                                context.response.criteriaResolvers,
                                context.response.fulfillments,
                                context.request.recipient
                            )
                        );
                } else {
                    return
                        abi.encodeCall(
                            ConsiderationInterface
                                .fulfillAvailableAdvancedOrders,
                            (
                                context.response.orders,
                                context.response.criteriaResolvers,
                                context.response.offerFulfillments,
                                context.response.considerationFulfillments,
                                context.request.fulfillerConduitKey,
                                context.request.recipient,
                                context.request.maximumFulfilled
                            )
                        );
                }
            } else {
                // If the structure is not advanced, use matchOrders or
                // fulfillAvailableOrders depending on the caller's request.
                if (context.request.preferMatch) {
                    return
                        abi.encodeCall(
                            ConsiderationInterface.matchOrders,
                            (
                                context.response.orders.toOrders(),
                                context.response.fulfillments
                            )
                        );
                } else {
                    return
                        abi.encodeCall(
                            ConsiderationInterface.fulfillAvailableOrders,
                            (
                                context.response.orders.toOrders(),
                                context.response.offerFulfillments,
                                context.response.considerationFulfillments,
                                context.request.fulfillerConduitKey,
                                context.request.maximumFulfilled
                            )
                        );
                }
            }
        }
    }

    /**
     * @dev Return whether the provided orders must be matched using matchOrders
     *      or matchAdvancedOrders.
     */
    function mustUseMatch(
        NavigatorContext memory context
    ) internal pure returns (bool) {
        OrderDetails[] memory orders = context.response.orderDetails;

        // Iterate through the orders and check if any of the  non-contract
        // orders has a native token in the offer.
        for (uint256 i = 0; i < orders.length; ++i) {
            OrderDetails memory order = orders[i];

            if (order.isContract) {
                continue;
            }

            // If the order has a native token in the offer, use match.
            for (uint256 j = 0; j < order.offer.length; ++j) {
                if (order.offer[j].itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        // If the caller is the recipient, it's never necessary to use match.
        if (context.request.caller == context.request.recipient) {
            return false;
        }

        // This basically checks if there's an ERC721 in the offer of one order
        // that is also in the consideration of another order. If yes, use
        // match.
        for (uint256 i = 0; i < orders.length; ++i) {
            // Get the order.
            OrderDetails memory order = orders[i];

            // Iterate over the offer items.
            for (uint256 j = 0; j < order.offer.length; ++j) {
                // Get the item.
                SpentItem memory item = order.offer[j];

                // If the item is not an ERC721, skip it.
                if (item.itemType != ItemType.ERC721) {
                    continue;
                }

                // Iterate over the orders again.
                for (uint256 k = 0; k < orders.length; ++k) {
                    // Get an order to compare against.
                    OrderDetails memory comparisonOrder = orders[k];

                    // Iterate over the consideration items.
                    for (
                        uint256 l = 0;
                        l < comparisonOrder.consideration.length;
                        ++l
                    ) {
                        // Get the consideration item.
                        ReceivedItem memory considerationItem = comparisonOrder
                            .consideration[l];

                        // If the consideration item is an ERC721, and the ID is
                        // the same as the offer item, and the token address is
                        // the same as the offer item, use match.
                        if (
                            considerationItem.itemType == ItemType.ERC721 &&
                            considerationItem.identifier == item.identifier &&
                            considerationItem.token == item.token
                        ) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }
}
