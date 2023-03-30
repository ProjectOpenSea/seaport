// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { Family, FuzzHelpers, Structure } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

/**
 * @notice Stateless helpers for FuzzEngine.
 */
library FuzzEngineLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    /**
     * @dev Select an available "action," i.e. "which Seaport function to call,"
     *      based on the orders in a given FuzzTestContext. Selects a random action
     *      using the context's fuzzParams.seed when multiple actions are
     *      available for the given order config.
     *
     * @param context A Fuzz test context.
     * @return bytes4 selector of a SeaportInterface function.
     */
    function action(FuzzTestContext memory context) internal returns (bytes4) {
        if (context._action != bytes4(0)) return context._action;
        bytes4[] memory _actions = actions(context);
        return (context._action = _actions[
            context.fuzzParams.seed % _actions.length
        ]);
    }

    function actionName(
        FuzzTestContext memory context
    ) internal returns (string memory) {
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
     *      functions can we call," based on the orders in a given FuzzTestContext.
     *
     * @param context A Fuzz test context.
     * @return bytes4[] of SeaportInterface function selectors.
     */
    function actions(
        FuzzTestContext memory context
    ) internal returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        bool invalidNativeOfferItemsLocated = (
            hasInvalidNativeOfferItems(context)
        );

        Structure structure = context.orders.getStructure(
            address(context.seaport)
        );

        if (family == Family.SINGLE && !invalidNativeOfferItemsLocated) {
            AdvancedOrder memory order = context.orders[0];

            if (structure == Structure.BASIC) {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillBasicOrder.selector;
                selectors[3] = context
                    .seaport
                    .fulfillBasicOrder_efficient_6GL6yc
                    .selector;
                return selectors;
            }

            if (structure == Structure.STANDARD) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }

            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }
        }

        (, , MatchComponent[] memory remainders) = context
            .testHelpers
            .getMatchedFulfillments(context.orders, context.criteriaResolvers);

        if (remainders.length != 0 && invalidNativeOfferItemsLocated) {
            revert("FuzzEngineLib: cannot fulfill provided combined order");
        }

        if (remainders.length != 0) {
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
        } else if (invalidNativeOfferItemsLocated) {
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

    function hasInvalidNativeOfferItems(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
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

    function getNativeTokensToSupply(
        FuzzTestContext memory context
    ) internal pure returns (uint256) {
        uint256 value = 0;

        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                OfferItem memory item = orderParams.offer[j];

                // TODO: support ascending / descending
                if (item.startAmount != item.endAmount) {
                    revert(
                        "FuzzEngineLib: ascending/descending not yet supported"
                    );
                }

                if (item.itemType == ItemType.NATIVE) {
                    value += item.startAmount;
                }
            }

            for (uint256 j = 0; j < orderParams.consideration.length; ++j) {
                ConsiderationItem memory item = orderParams.consideration[j];

                // TODO: support ascending / descending
                if (item.startAmount != item.endAmount) {
                    revert(
                        "FuzzEngineLib: ascending/descending not yet supported"
                    );
                }

                if (item.itemType == ItemType.NATIVE) {
                    value += item.startAmount;
                }
            }
        }

        return value;
    }
}
