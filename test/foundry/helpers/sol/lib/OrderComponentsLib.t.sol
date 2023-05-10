// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    OrderComponentsLib
} from "../../../../../contracts/helpers/sol/lib/OrderComponentsLib.sol";
import {
    AdditionalRecipientLib
} from "../../../../../contracts/helpers/sol/lib/AdditionalRecipientLib.sol";
import {
    OrderComponents,
    OrderParameters,
    OfferItem,
    ConsiderationItem,
    AdditionalRecipient
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import {
    ItemType,
    BasicOrderType,
    OrderType
} from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";
import {
    SeaportArrays
} from "../../../../../contracts/helpers/sol/lib/SeaportStructLib.sol";

contract OrderComponentsLibTest is BaseTest {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;

    function testRetrieveDefault(OrderComponentsBlob memory blob) public {
        OrderComponents memory orderComponents = _fromBlob(blob);
        OrderComponents memory dup = OrderComponentsLib.empty();
        dup.offerer = blob.offerer;
        dup.zone = blob.zone;
        dup.offer = _fromBlobs(blob.offer);
        dup.consideration = _fromBlobs(blob.consideration);
        dup.orderType = toOrderType(blob._orderType);
        dup.startTime = blob.startTime;
        dup.endTime = blob.endTime;
        dup.zoneHash = blob.zoneHash;
        dup.salt = blob.salt;
        dup.conduitKey = blob.conduitKey;
        dup.counter = blob.counter;
        assertEq(orderComponents, dup);

        OrderComponentsLib.saveDefault(orderComponents, "default");
        OrderComponents memory defaultOrderComponents = OrderComponentsLib
            .fromDefault("default");
        assertEq(orderComponents, defaultOrderComponents);
    }

    function testRetrieveNonexistentDefault() public {
        vm.expectRevert("Empty OrderComponents selected.");
        OrderComponentsLib.fromDefault("nonexistent");

        vm.expectRevert("Empty OrderComponents array selected.");
        OrderComponentsLib.fromDefaultMany("nonexistent");
    }

    function testCopy() public {
        OrderComponents memory orderComponents = OrderComponentsLib.empty();
        orderComponents = orderComponents.withOfferer(address(1));
        orderComponents = orderComponents.withZone(address(2));
        orderComponents = orderComponents.withOrderType(OrderType(3));
        orderComponents = orderComponents.withStartTime(4);
        orderComponents = orderComponents.withEndTime(5);
        orderComponents = orderComponents.withZoneHash(bytes32(uint256(6)));
        orderComponents = orderComponents.withSalt(7);
        orderComponents = orderComponents.withConduitKey(bytes32(uint256(8)));
        orderComponents = orderComponents.withCounter(9);
        OfferItem[] memory offer;

        {
            offer = SeaportArrays.OfferItems(
                OfferItem({
                    itemType: ItemType(1),
                    token: address(2),
                    identifierOrCriteria: 3,
                    startAmount: 4,
                    endAmount: 5
                })
            );
            ConsiderationItem[] memory consideration = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItem({
                        itemType: ItemType(2),
                        token: address(7),
                        identifierOrCriteria: 8,
                        startAmount: 9,
                        endAmount: 10,
                        recipient: payable(address(11))
                    })
                );

            orderComponents = orderComponents.withOffer(offer);
            orderComponents = orderComponents.withConsideration(consideration);
        }

        OrderComponents memory copy = orderComponents.copy();
        assertEq(orderComponents, copy);
        orderComponents.offerer = address(5678);
        assertEq(copy.offerer, address(1), "copy changed");

        offer[0].identifierOrCriteria = 123;
        assertEq(
            copy.offer[0].identifierOrCriteria,
            3,
            "copy offer identifier changed"
        );
    }

    function testRetrieveDefaultMany(
        OrderComponentsBlob[3] memory blobs
    ) public {
        OrderComponents[] memory orderComponents = new OrderComponents[](3);
        for (uint256 i = 0; i < 3; i++) {
            orderComponents[i] = _fromBlob(blobs[i]);
        }
        OrderComponentsLib.saveDefaultMany(orderComponents, "default");
        OrderComponents[] memory defaultOrderComponentss = OrderComponentsLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(orderComponents[i], defaultOrderComponentss[i]);
        }
    }
}
