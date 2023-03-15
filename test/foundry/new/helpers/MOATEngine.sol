// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { MOATOrder, MOATHelpers, Structure, Family } from "./MOATHelpers.sol";

import "forge-std/console.sol";

struct FuzzParams {
    uint256 seed;
}
struct TestContext {
    MOATOrder[] orders;
    SeaportInterface seaport;
    FuzzParams fuzzParams;
}

library MOATEngine {
    using MOATHelpers for MOATOrder;
    using MOATHelpers for MOATOrder[];

    function action(TestContext memory context) internal pure returns (bytes4) {
        bytes4[] memory _actions = actions(context);
        return _actions[context.fuzzParams.seed % _actions.length];
    }

    function actions(
        TestContext memory context
    ) internal pure returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        if (family == Family.SINGLE) {
            MOATOrder memory order = context.orders[0];
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
