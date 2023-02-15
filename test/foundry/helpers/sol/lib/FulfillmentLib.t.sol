// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    FulfillmentLib,
    FulfillmentComponentLib
} from "../../../../../contracts/helpers/sol/lib/FulfillmentLib.sol";
import {
    Fulfillment,
    FulfillmentComponent
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    SeaportArrays
} from "../../../../../contracts/helpers/sol/lib/SeaportArrays.sol";

contract FulfillmentLibTest is BaseTest {
    using FulfillmentLib for Fulfillment;
    using FulfillmentComponentLib for FulfillmentComponent;

    function testRetrieveDefault(
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent[] memory considerationComponents
    ) public {
        Fulfillment memory fulfillment = Fulfillment({
            offerComponents: offerComponents,
            considerationComponents: considerationComponents
        });
        FulfillmentLib.saveDefault(fulfillment, "default");
        Fulfillment memory defaultFulfillment = FulfillmentLib.fromDefault(
            "default"
        );
        assertEq(fulfillment, defaultFulfillment);
    }

    function testComposeEmpty(
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent[] memory considerationComponents
    ) public {
        Fulfillment memory fulfillment = FulfillmentLib
            .empty()
            .withOfferComponents(offerComponents)
            .withConsiderationComponents(considerationComponents);
        assertEq(
            fulfillment,
            Fulfillment({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents
            })
        );
    }

    function testCopy() public {
        FulfillmentComponent[] memory offerComponents = SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 1, itemIndex: 1 })
            );
        FulfillmentComponent[] memory considerationComponents = SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 2, itemIndex: 2 })
            );
        Fulfillment memory fulfillment = Fulfillment({
            offerComponents: offerComponents,
            considerationComponents: considerationComponents
        });
        Fulfillment memory copy = fulfillment.copy();
        assertEq(fulfillment, copy);
        fulfillment.considerationComponents = offerComponents;
        assertEq(copy.considerationComponents, considerationComponents);
    }

    function testRetrieveDefaultMany(
        FulfillmentComponent[][3] memory offerComponents,
        FulfillmentComponent[][3] memory considerationComponents
    ) public {
        Fulfillment[] memory fulfillments = new Fulfillment[](3);
        for (uint256 i = 0; i < 3; i++) {
            fulfillments[i] = Fulfillment({
                offerComponents: offerComponents[i],
                considerationComponents: considerationComponents[i]
            });
        }
        FulfillmentLib.saveDefaultMany(fulfillments, "default");
        Fulfillment[] memory defaultFulfillments = FulfillmentLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(fulfillments[i], defaultFulfillments[i]);
        }
    }
}
