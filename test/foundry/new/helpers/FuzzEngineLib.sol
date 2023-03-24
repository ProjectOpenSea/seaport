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
        bytes4[] memory _actions = actions(context);
        return _actions[context.fuzzParams.seed % _actions.length];
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

        if (family == Family.SINGLE) {
            AdvancedOrder memory order = context.orders[0];
            Structure structure = order.getStructure(address(context.seaport));

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

        if (family == Family.COMBINED) {
            (, , MatchComponent[] memory remainders) = context
                .testHelpers
                .getMatchedFulfillments(context.orders);

            if (remainders.length != 0) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                //selectors[2] = context.seaport.cancel.selector;
                //selectors[3] = context.seaport.validate.selector;
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

        revert("FuzzEngine: Actions not found");
    }
}
