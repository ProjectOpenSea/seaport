// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";
import {
    AdditionalRecipientLib
} from "../../../../../contracts/helpers/sol/lib/AdditionalRecipientLib.sol";
import {
    OrderParameters,
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
} from "../../../../../contracts/helpers/sol/lib/SeaportArrays.sol";

contract OrderParametersLibTest is BaseTest {
    using OrderParametersLib for OrderParameters;
    using OrderParametersLib for OrderParameters;

    function testRetrieveDefault(OrderParametersBlob memory blob) public {
        OrderParameters memory orderParameters = _fromBlob(blob);
        OrderParameters memory dup = OrderParametersLib.empty();
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
        dup.totalOriginalConsiderationItems = blob
            .totalOriginalConsiderationItems;
        assertEq(orderParameters, dup);

        OrderParametersLib.saveDefault(orderParameters, "default");
        OrderParameters memory defaultOrderParameters = OrderParametersLib
            .fromDefault("default");
        assertEq(orderParameters, defaultOrderParameters);
    }

    function testRetrieveNonexistentDefault() public {
        vm.expectRevert("Empty OrderParameters selected.");
        OrderParametersLib.fromDefault("nonexistent");

        vm.expectRevert("Empty OrderParameters array selected.");
        OrderParametersLib.fromDefaultMany("nonexistent");
    }

    function testCopy() public {
        OrderParameters memory orderParameters = OrderParametersLib.empty();
        orderParameters = orderParameters.withOfferer(address(1));
        orderParameters = orderParameters.withZone(address(2));
        orderParameters = orderParameters.withOrderType(OrderType(3));
        orderParameters = orderParameters.withStartTime(4);
        orderParameters = orderParameters.withEndTime(5);
        orderParameters = orderParameters.withZoneHash(bytes32(uint256(6)));
        orderParameters = orderParameters.withSalt(7);
        orderParameters = orderParameters.withConduitKey(bytes32(uint256(8)));
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

            orderParameters = orderParameters.withOffer(offer);
            orderParameters = orderParameters.withConsideration(consideration);
        }

        OrderParameters memory copy = orderParameters.copy();
        assertEq(orderParameters, copy);
        orderParameters.offerer = address(5678);
        assertEq(copy.offerer, address(1), "copy changed");

        offer[0].identifierOrCriteria = 123;
        assertEq(
            copy.offer[0].identifierOrCriteria,
            3,
            "copy offer identifier changed"
        );
    }

    function testRetrieveDefaultMany(
        OrderParametersBlob[3] memory blobs
    ) public {
        OrderParameters[] memory orderParameters = new OrderParameters[](3);
        for (uint256 i = 0; i < 3; i++) {
            orderParameters[i] = _fromBlob(blobs[i]);
        }
        OrderParametersLib.saveDefaultMany(orderParameters, "default");
        OrderParameters[] memory defaultOrderParameterss = OrderParametersLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(orderParameters[i], defaultOrderParameterss[i]);
        }
    }
}
