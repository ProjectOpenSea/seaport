// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    Execution,
    SpentItem,
    ReceivedItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";

import { Family, Structure, OrderStructureLib } from "./OrderStructureLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

library NavigatorSuggestedActionLib {
    using OrderStructureLib for AdvancedOrder;
    using OrderStructureLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];

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
        Family family = context.response.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.response.orders.getStructure(
            address(context.request.seaport)
        );

        bool hasUnavailable = context.request.maximumFulfilled <
            context.response.orders.length;
        uint256 contextResponseOrderDetailsLength =
            context.response.orderDetails.length;
        for (uint256 i = 0; i < contextResponseOrderDetailsLength; ++i) {
            if (
                context.response.orderDetails[i].unavailableReason !=
                UnavailableReason.AVAILABLE
            ) {
                hasUnavailable = true;
                break;
            }
        }

        if (hasUnavailable) {
            if (invalidOfferItemsLocated) {
                revert InvalidNativeTokenUnavailableCombination();
            }

            if (structure == Structure.ADVANCED) {
                return _doFulfillAvailableAdvancedOrders(context);
            } else {
                return _doFulfillAvailableOrders(context);
            }
        }

        if (family == Family.SINGLE && !invalidOfferItemsLocated) {
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

        bool cannotMatch = (context
            .response
            .unmetConsiderationComponents
            .length !=
            0 ||
            hasUnavailable);

        if (cannotMatch && invalidOfferItemsLocated) {
            revert CannotFulfillProvidedCombinedOrder();
        }

        if (cannotMatch) {
            if (structure == Structure.ADVANCED) {
                return _doFulfillAvailableAdvancedOrders(context);
            } else {
                return _doFulfillAvailableOrders(context);
            }
        } else if (invalidOfferItemsLocated) {
            if (structure == Structure.ADVANCED) {
                return _doFulfillAvailableAdvancedOrders(context);
            } else {
                return _doMatchOrders(context);
                    
            }
        } else {
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
                    return _doFulfillAvailableAdvancedOrders(context);
                }
            } else {
                if (context.request.preferMatch) {
                    return _doMatchOrders(context);
                } else {
                    return _doFulfillAvailableOrders(context);
                }
            }
        }
    }

    /**
     * @dev Return whether the provided orders must be matched using matchOrders
     *      or matchAdvancedOrders.
     */
    function mustUseMatch(NavigatorContext memory context)
        internal
        pure
        returns (bool)
    {
        OrderDetails[] memory orders = context.response.orderDetails;

        uint256 ordersLength = orders.length;

        for (uint256 i = 0; i < ordersLength; ++i) {
            OrderDetails memory order = orders[i];

            if (order.isContract) {
                continue;
            }

            uint256 orderOfferLength = order.offer.length;
            for (uint256 j = 0; j < orderOfferLength; ++j) {
                if (order.offer[j].itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        if (context.request.caller == context.request.recipient) {
            return false;
        }

        for (uint256 i = 0; i < ordersLength; ++i) {
            OrderDetails memory order = orders[i];

            uint256 orderOfferLength = order.offer.length;
            for (uint256 j = 0; j < orderOfferLength; ++j) {
                SpentItem memory item = order.offer[j];

                if (item.itemType != ItemType.ERC721) {
                    continue;
                }

                for (uint256 k = 0; k < ordersLength; ++k) {
                    OrderDetails memory comparisonOrder = orders[k];
                    for (
                        uint256 l = 0;
                        l < comparisonOrder.consideration.length;
                        ++l
                    ) {
                        ReceivedItem memory considerationItem =
                            comparisonOrder.consideration[l];

                        if (
                            considerationItem.itemType == ItemType.ERC721
                                && considerationItem.identifier == item.identifier
                                && considerationItem.token == item.token
                        ) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }

    /**
     * @dev Helper to fulfill the provided orders using the fulfillAvailableAdvancedOrders method.
     */
    function _doFulfillAvailableAdvancedOrders(NavigatorContext memory context)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
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
    }

    /**
     * @dev Helper to fulfill the provided orders using the fulfillAvailableOrders method.
     */
    function _doFulfillAvailableOrders(NavigatorContext memory context)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
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

    /**
     * @dev Helper to fulfill the provided orders using the matchOrders method.
     */
    function _doMatchOrders(NavigatorContext memory context)
        private
        pure
        returns (bytes memory){
            return 
                abi.encodeCall(
                    ConsiderationInterface.matchOrders,
                    (
                        context.response.orders.toOrders(),
                        context.response.fulfillments
                    )
                );
        }
}
