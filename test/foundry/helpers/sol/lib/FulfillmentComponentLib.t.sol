// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    FulfillmentComponentLib
} from "../../../../../contracts/helpers/sol/lib/FulfillmentComponentLib.sol";
import {
    FulfillmentComponent
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract FulfillmentComponentLibTest is BaseTest {
    using FulfillmentComponentLib for FulfillmentComponent;

    function testRetrieveDefault(uint256 orderIndex, uint256 itemIndex) public {
        FulfillmentComponent
            memory fulfillmentComponent = FulfillmentComponent({
                orderIndex: orderIndex,
                itemIndex: itemIndex
            });
        FulfillmentComponentLib.saveDefault(fulfillmentComponent, "default");
        FulfillmentComponent
            memory defaultFulfillmentComponent = FulfillmentComponentLib
                .fromDefault("default");
        assertEq(fulfillmentComponent, defaultFulfillmentComponent);
    }

    function testComposeEmpty(uint256 orderIndex, uint256 itemIndex) public {
        FulfillmentComponent
            memory fulfillmentComponent = FulfillmentComponentLib
                .empty()
                .withOrderIndex(orderIndex)
                .withItemIndex(itemIndex);
        assertEq(
            fulfillmentComponent,
            FulfillmentComponent({
                orderIndex: orderIndex,
                itemIndex: itemIndex
            })
        );
    }

    function testCopy() public {
        FulfillmentComponent
            memory fulfillmentComponent = FulfillmentComponent({
                orderIndex: 1,
                itemIndex: 2
            });
        FulfillmentComponent memory copy = fulfillmentComponent.copy();
        assertEq(fulfillmentComponent, copy);
        fulfillmentComponent.orderIndex = 2;
        assertEq(copy.orderIndex, 1);
    }

    function testRetrieveDefaultMany(
        uint256[3] memory orderIndex,
        uint256[3] memory itemIndex
    ) public {
        FulfillmentComponent[]
            memory fulfillmentComponents = new FulfillmentComponent[](3);
        for (uint256 i = 0; i < 3; i++) {
            fulfillmentComponents[i] = FulfillmentComponent({
                orderIndex: orderIndex[i],
                itemIndex: itemIndex[i]
            });
        }
        FulfillmentComponentLib.saveDefaultMany(
            fulfillmentComponents,
            "default"
        );
        FulfillmentComponent[]
            memory defaultFulfillmentComponents = FulfillmentComponentLib
                .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(fulfillmentComponents[i], defaultFulfillmentComponents[i]);
        }
    }
}
