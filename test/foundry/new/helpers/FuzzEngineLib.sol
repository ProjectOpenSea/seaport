// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrderLib,
    MatchComponent,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    Execution,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    SpentItem,
    ReceivedItem
} from "seaport-sol/src/SeaportStructs.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { ItemType, Side, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import {
    _locateCurrentAmount,
    Family,
    FuzzHelpers,
    Structure
} from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { FuzzDerivers } from "./FuzzDerivers.sol";

import {
    DefaultFulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

/**
 * @notice Stateless helpers for FuzzEngine. The FuzzEngine uses functions in
 *         this library to select which Seaport action it should call.
 */
library FuzzEngineLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;
    using DefaultFulfillmentGeneratorLib for OrderDetails[];

    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];
    using FuzzDerivers for FuzzTestContext;

    /**
     * @dev Select an available "action," i.e. "which Seaport function to call,"
     *      based on the orders in a given FuzzTestContext. Selects a random
     *      action using the context's fuzzParams.seed when multiple actions are
     *      available for the given order config.
     *
     * @param context A Fuzz test context.
     * @return bytes4 selector of a SeaportInterface function.
     */
    function action(
        FuzzTestContext memory context
    ) internal view returns (bytes4) {
        if (context.actionSelected) return context._action;
        bytes4[] memory _actions = actions(context);
        context.actionSelected = true;
        return (context._action = _actions[
            context.fuzzParams.seed % _actions.length
        ]);
    }

    /**
     * @dev Get the human-readable name of the selected action.
     *
     * @param context A Fuzz test context.
     * @return string name of the selected action.
     */
    function actionName(
        FuzzTestContext memory context
    ) internal view returns (string memory) {
        bytes4 selector = action(context);
        if (selector == 0xe7acab24) return "fulfillAdvancedOrder";
        if (selector == 0x87201b41) return "fulfillAvailableAdvancedOrders";
        if (selector == 0xed98a574) return "fulfillAvailableOrders";
        if (selector == 0xfb0f3ee1) return "fulfillBasicOrder";
        if (selector == 0x00000000) return "fulfillBasicOrder_efficient_6GL6yc";
        if (selector == 0xb3a34c4c) return "fulfillOrder";
        if (selector == 0xf2d12b12) return "matchAdvancedOrders";
        if (selector == 0xa8174404) return "matchOrders";

        revert("Unknown selector");
    }

    /**
     * @dev Get an array of all possible "actions," i.e. "which Seaport
     *      functions can we call," based on the generated orders in a given
     *      `FuzzTestContext`.
     *
     * @param context A Fuzz test context.
     * @return bytes4[] of SeaportInterface function selectors.
     */
    function actions(
        FuzzTestContext memory context
    ) internal view returns (bytes4[] memory) {
        Family family = context.executionState.orders.getFamily();

        bool containsOrderThatDemandsMatch = mustUseMatch(context);

        Structure structure = context.executionState.orders.getStructure(
            address(context.seaport)
        );

        bool hasUnavailable = context.executionState.maximumFulfilled <
            context.executionState.orders.length;
        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            if (
                context.executionState.orderDetails[i].unavailableReason !=
                UnavailableReason.AVAILABLE
            ) {
                hasUnavailable = true;
                break;
            }
        }

        if (hasUnavailable) {
            if (containsOrderThatDemandsMatch) {
                revert(
                    "FuzzEngineLib: invalid native token + unavailable combination"
                );
            }

            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }
        }

        if (family == Family.SINGLE && !containsOrderThatDemandsMatch) {
            if (structure == Structure.BASIC) {
                bytes4[] memory selectors = new bytes4[](6);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillBasicOrder.selector;
                selectors[3] = context
                    .seaport
                    .fulfillBasicOrder_efficient_6GL6yc
                    .selector;
                selectors[4] = context.seaport.fulfillAvailableOrders.selector;
                selectors[5] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }

            if (structure == Structure.STANDARD) {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillAvailableOrders.selector;
                selectors[3] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }

            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }
        }

        bool cannotMatch = (context.executionState.hasRemainders ||
            hasUnavailable);

        if (cannotMatch && containsOrderThatDemandsMatch) {
            revert("FuzzEngineLib: cannot fulfill provided combined order");
        }

        if (cannotMatch) {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                //selectors[2] = context.seaport.cancel.selector;
                //selectors[3] = context.seaport.validate.selector;
                return selectors;
            }
        } else if (containsOrderThatDemandsMatch) {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.matchOrders.selector;
                selectors[1] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            }
        } else {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                selectors[1] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                selectors[2] = context.seaport.matchOrders.selector;
                selectors[3] = context.seaport.matchAdvancedOrders.selector;
                //selectors[4] = context.seaport.cancel.selector;
                //selectors[5] = context.seaport.validate.selector;
                return selectors;
            }
        }
    }

    /**
     * @dev Determine whether a matching function (either `matchOrders` or
     *      `matchAdvancedOrders`) will be selected, based on the given order
     *      configuration.
     *
     * @param context A Fuzz test context.
     * @return bool whether a matching function will be called.
     */
    function mustUseMatch(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        OrderDetails[] memory orders = context.executionState.orderDetails;

        for (uint256 i = 0; i < orders.length; ++i) {
            OrderDetails memory order = orders[i];

            if (order.isContract) {
                continue;
            }

            for (uint256 j = 0; j < order.offer.length; ++j) {
                if (order.offer[j].itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        if (context.executionState.caller == context.executionState.recipient) {
            return false;
        }

        for (uint256 i = 0; i < orders.length; ++i) {
            OrderDetails memory order = orders[i];

            for (uint256 j = 0; j < order.offer.length; ++j) {
                SpentItem memory item = order.offer[j];

                if (item.itemType != ItemType.ERC721) {
                    continue;
                }

                for (uint256 k = 0; k < orders.length; ++k) {
                    OrderDetails memory comparisonOrder = orders[k];
                    for (
                        uint256 l = 0;
                        l < comparisonOrder.consideration.length;
                        ++l
                    ) {
                        ReceivedItem memory considerationItem = comparisonOrder
                            .consideration[l];

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

    /**
     * @dev Determine the amount of native tokens the caller must supply.
     *
     * @param context A Fuzz test context.
     * @return value The amount of native tokens to supply.
     * @return minimum The minimum amount of native tokens to supply.
     */
    function getNativeTokensToSupply(
        FuzzTestContext memory context
    ) internal returns (uint256 value, uint256 minimum) {
        bool isMatch = action(context) ==
            context.seaport.matchAdvancedOrders.selector ||
            action(context) == context.seaport.matchOrders.selector;

        uint256 valueToCreditBack = 0;

        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            OrderDetails memory order = context.executionState.orderDetails[i];
            OrderParameters memory orderParams = context
                .executionState
                .previewedOrders[i]
                .parameters;

            if (isMatch) {
                for (uint256 j = 0; j < order.offer.length; ++j) {
                    SpentItem memory item = order.offer[j];

                    if (
                        item.itemType == ItemType.NATIVE &&
                        orderParams.orderType != OrderType.CONTRACT
                    ) {
                        value += item.amount;
                    }
                }
            } else {
                for (uint256 j = 0; j < order.offer.length; ++j) {
                    SpentItem memory item = order.offer[j];

                    if (item.itemType == ItemType.NATIVE) {
                        if (orderParams.orderType == OrderType.CONTRACT) {
                            valueToCreditBack += item.amount;
                        }
                        value += item.amount;
                    }
                }

                for (uint256 j = 0; j < order.consideration.length; ++j) {
                    ReceivedItem memory item = order.consideration[j];

                    if (item.itemType == ItemType.NATIVE) {
                        value += item.amount;
                    }
                }
            }
        }

        if (valueToCreditBack >= value) {
            value = 0;
        } else {
            value = value - valueToCreditBack;
        }

        minimum = getMinimumNativeTokensToSupply(context);

        if (minimum > value) {
            value = minimum;
        }
    }

    function getMinimumNativeTokensToSupply(
        FuzzTestContext memory context
    ) internal returns (uint256) {
        bytes4 _action = action(context);
        if (
            _action == context.seaport.fulfillBasicOrder.selector ||
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            // TODO: handle OOR orders or items just in case
            if (
                context.executionState.orderDetails[0].offer[0].itemType ==
                ItemType.ERC20
            ) {
                // Basic order bids cannot supply any native tokens
                return 0;
            }
        }

        uint256 hugeCallValue = uint256(type(uint128).max);
        (, , , uint256 nativeTokensReturned) = context.getDerivedExecutions(
            hugeCallValue
        );

        if (nativeTokensReturned > hugeCallValue) {
            return 0;
        }

        return hugeCallValue - nativeTokensReturned;
    }

    /**
     * @dev Determine whether or not an order configuration has remainders.
     */
    function withDetectedRemainders(
        FuzzTestContext memory context
    ) internal pure returns (FuzzTestContext memory) {
        (, , MatchComponent[] memory remainders) = context
            .executionState
            .orderDetails
            .getMatchedFulfillments();

        context.executionState.hasRemainders = remainders.length != 0;

        return context;
    }
}
