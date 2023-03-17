// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { MOATHelpers, Structure, Family } from "./MOATHelpers.sol";
import { TestContext, TestContextLib } from "./TestContextLib.sol";

/**
 * @notice Stateless helpers for MOATEngine.
 */
library MOATEngineLib {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;
    using MOATHelpers for AdvancedOrder;
    using MOATHelpers for AdvancedOrder[];

    /**
     * @dev Select an available "action," i.e. "which Seaport function to call,"
     *      based on the orders in a given TestContext. Selects a random action
     *      using the context's fuzzParams.seed when multiple actions are
     *      available for the given order config.
     *
     * @param context A MOAT test context.
     * @return bytes4 selector of a SeaportInterface function.
     */
    function action(TestContext memory context) internal pure returns (bytes4) {
        bytes4[] memory _actions = actions(context);
        return _actions[context.fuzzParams.seed % _actions.length];
    }

    /**
     * @dev Get an array of all possible "actions," i.e. "which Seaport
     *      functions can we call," based on the orders in a given TestContext.
     *
     * @param context A MOAT test context.
     * @return bytes4[] of SeaportInterface function selectors.
     */
    function actions(
        TestContext memory context
    ) internal pure returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        if (family == Family.SINGLE) {
            AdvancedOrder memory order = context.orders[0];
            Structure structure = order.getStructure();
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
            bytes4[] memory selectors = new bytes4[](6);
            selectors[0] = context.seaport.fulfillAvailableOrders.selector;
            selectors[1] = context
                .seaport
                .fulfillAvailableAdvancedOrders
                .selector;
            selectors[2] = context.seaport.matchOrders.selector;
            selectors[3] = context.seaport.matchAdvancedOrders.selector;
            selectors[4] = context.seaport.cancel.selector;
            selectors[5] = context.seaport.validate.selector;
            return selectors;
        }
        revert("MOATEngine: Actions not found");
    }
}
