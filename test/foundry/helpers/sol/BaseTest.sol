// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    AdditionalRecipient,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    OrderComponentsLib
} from "../../../../contracts/helpers/sol/lib/OrderComponentsLib.sol";

import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

import { OrderLib } from "../../../../contracts/helpers/sol/lib/OrderLib.sol";

contract BaseTest is Test {
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;

    struct OrderParametersBlob {
        address offerer; // 0x00
        address zone; // 0x20
        OfferItemBlob[] offer; // 0x40
        ConsiderationItemBlob[] consideration; // 0x60
        uint8 _orderType; // 0x80
        uint256 startTime; // 0xa0
        uint256 endTime; // 0xc0
        bytes32 zoneHash; // 0xe0
        uint256 salt; // 0x100
        bytes32 conduitKey; // 0x120
        uint256 totalOriginalConsiderationItems; // 0x140
    }

    struct OrderBlob {
        OrderParametersBlob parameters;
        bytes signature;
    }

    function _fromBlob(
        OrderBlob memory orderBlob
    ) internal view returns (Order memory order) {
        order = OrderLib.empty();
        order.parameters = _fromBlob(orderBlob.parameters);
        order.signature = orderBlob.signature;
    }

    function assertEq(Order memory a, Order memory b) internal {
        assertEq(a.parameters, b.parameters);
        assertEq(a.signature, b.signature, "signature");
    }

    function assertEq(Order[] memory a, Order[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function setUp() public virtual {}

    function assertEq(OfferItem memory a, OfferItem memory b) internal {
        assertEq(uint8(a.itemType), uint8(b.itemType), "itemType");
        assertEq(a.token, b.token, "token");
        assertEq(
            a.identifierOrCriteria,
            b.identifierOrCriteria,
            "identifierOrCriteria"
        );
        assertEq(a.startAmount, b.startAmount, "startAmount");
        assertEq(a.endAmount, b.endAmount, "endAmount");
    }

    function assertEq(
        ConsiderationItem memory a,
        ConsiderationItem memory b
    ) internal {
        assertEq(uint8(a.itemType), uint8(b.itemType), "itemType");
        assertEq(a.token, b.token, "token");
        assertEq(
            a.identifierOrCriteria,
            b.identifierOrCriteria,
            "identifierOrCriteria"
        );
        assertEq(a.startAmount, b.startAmount, "startAmount");
        assertEq(a.endAmount, b.endAmount, "endAmount");
        assertEq(a.recipient, b.recipient, "recipient");
    }

    function assertEq(OfferItem[] memory a, OfferItem[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(
        ConsiderationItem[] memory a,
        ConsiderationItem[] memory b
    ) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(
        OrderParameters memory a,
        OrderParameters memory b
    ) internal {
        assertEq(a.offerer, b.offerer, "offerer");
        assertEq(a.zone, b.zone, "zone");
        assertEq(a.offer, b.offer);
        assertEq(a.consideration, b.consideration);
        assertEq(uint8(a.orderType), uint8(b.orderType), "orderType");
        assertEq(a.startTime, b.startTime, "startTime");
        assertEq(a.endTime, b.endTime, "endTime");
        assertEq(a.zoneHash, b.zoneHash, "zoneHash");
        assertEq(a.salt, b.salt, "salt");
        assertEq(a.conduitKey, b.conduitKey, "conduitKey");
        assertEq(
            a.totalOriginalConsiderationItems,
            b.totalOriginalConsiderationItems,
            "totalOriginalConsiderationItems"
        );
    }

    function assertEq(SpentItem memory a, SpentItem memory b) internal {
        assertEq(uint8(a.itemType), uint8(b.itemType), "itemType");
        assertEq(a.token, b.token, "token");
        assertEq(a.identifier, b.identifier, "identifier");
        assertEq(a.amount, b.amount, "amount");
    }

    function assertEq(SpentItem[] memory a, SpentItem[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(
        AdditionalRecipient memory a,
        AdditionalRecipient memory b
    ) internal {
        assertEq(a.amount, b.amount, "amount");
        assertEq(a.recipient, b.recipient, "recipient");
    }

    function assertEq(
        AdditionalRecipient[] memory a,
        AdditionalRecipient[] memory b
    ) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(ReceivedItem memory a, ReceivedItem memory b) internal {
        assertEq(uint8(a.itemType), uint8(b.itemType), "itemType");
        assertEq(a.token, b.token, "token");
        assertEq(a.identifier, b.identifier, "identifier");
        assertEq(a.amount, b.amount, "amount");
        assertEq(a.recipient, b.recipient, "recipient");
    }

    function assertEq(
        ReceivedItem[] memory a,
        ReceivedItem[] memory b
    ) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(
        CriteriaResolver memory a,
        CriteriaResolver memory b
    ) internal {
        assertEq(a.orderIndex, b.orderIndex, "orderIndex");
        assertEq(uint8(a.side), uint8(b.side), "side");
        assertEq(a.index, b.index, "index");
        assertEq(a.identifier, b.identifier, "identifier");
        assertEq(a.criteriaProof, b.criteriaProof);
    }

    function assertEq(
        CriteriaResolver[] memory a,
        CriteriaResolver[] memory b
    ) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(bytes32[] memory a, bytes32[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(Execution memory a, Execution memory b) internal {
        assertEq(a.item, b.item);
        assertEq(a.offerer, b.offerer, "offerer");
        assertEq(a.conduitKey, b.conduitKey, "conduitKey");
    }

    function assertEq(Execution[] memory a, Execution[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function toItemType(uint8 _itemType) internal view returns (ItemType) {
        return ItemType(bound(_itemType, 0, 5));
    }

    function assertEq(
        FulfillmentComponent memory a,
        FulfillmentComponent memory b
    ) internal {
        assertEq(a.orderIndex, b.orderIndex, "orderIndex");
        assertEq(a.itemIndex, b.itemIndex, "itemIndex");
    }

    function assertEq(
        FulfillmentComponent[] memory a,
        FulfillmentComponent[] memory b
    ) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(Fulfillment memory a, Fulfillment memory b) internal {
        assertEq(a.offerComponents, b.offerComponents);
        assertEq(a.considerationComponents, b.considerationComponents);
    }

    function assertEq(Fulfillment[] memory a, Fulfillment[] memory b) internal {
        assertEq(a.length, b.length, "length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function toOrderType(uint8 _orderType) internal view returns (OrderType) {
        return OrderType(bound(_orderType, 0, 3));
    }

    struct OfferItemBlob {
        uint8 _itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItemBlob {
        uint8 _itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }

    struct OrderComponentsBlob {
        address offerer;
        address zone;
        OfferItemBlob[] offer;
        ConsiderationItemBlob[] consideration;
        uint8 _orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 counter;
    }

    function _fromBlob(
        OfferItemBlob memory blob
    ) internal view returns (OfferItem memory) {
        return
            OfferItem(
                toItemType(blob._itemType),
                blob.token,
                blob.identifierOrCriteria,
                blob.startAmount,
                blob.endAmount
            );
    }

    function _fromBlob(
        ConsiderationItemBlob memory blob
    ) internal view returns (ConsiderationItem memory) {
        return
            ConsiderationItem(
                toItemType(blob._itemType),
                blob.token,
                blob.identifierOrCriteria,
                blob.startAmount,
                blob.endAmount,
                blob.recipient
            );
    }

    function _fromBlobs(
        OfferItemBlob[] memory blob
    ) internal view returns (OfferItem[] memory) {
        OfferItem[] memory items = new OfferItem[](blob.length);
        for (uint256 i = 0; i < blob.length; i++) {
            items[i] = _fromBlob(blob[i]);
        }
        return items;
    }

    function _fromBlobs(
        ConsiderationItemBlob[] memory blob
    ) internal view returns (ConsiderationItem[] memory) {
        ConsiderationItem[] memory items = new ConsiderationItem[](blob.length);
        for (uint256 i = 0; i < blob.length; i++) {
            items[i] = _fromBlob(blob[i]);
        }
        return items;
    }

    function _fromBlob(
        OrderComponentsBlob memory blob
    ) internal view returns (OrderComponents memory) {
        OrderComponents memory components = OrderComponentsLib.empty();
        components = components.withOfferer(blob.offerer);
        components = components.withZone(blob.zone);
        components = components.withOffer(_fromBlobs(blob.offer));
        components = components.withConsideration(
            _fromBlobs(blob.consideration)
        );
        components = components.withOrderType(toOrderType(blob._orderType));
        components = components.withStartTime(blob.startTime);
        components = components.withEndTime(blob.endTime);
        components = components.withZoneHash(blob.zoneHash);
        components = components.withSalt(blob.salt);
        components = components.withConduitKey(blob.conduitKey);
        components = components.withCounter(blob.counter);
        return components;
    }

    function _fromBlob(
        OrderParametersBlob memory blob
    ) internal view returns (OrderParameters memory) {
        OrderParameters memory parameters = OrderParametersLib.empty();
        parameters = parameters.withOfferer(blob.offerer);
        parameters = parameters.withZone(blob.zone);
        parameters = parameters.withOffer(_fromBlobs(blob.offer));
        parameters = parameters.withConsideration(
            _fromBlobs(blob.consideration)
        );
        parameters = parameters.withOrderType(toOrderType(blob._orderType));
        parameters = parameters.withStartTime(blob.startTime);
        parameters = parameters.withEndTime(blob.endTime);
        parameters = parameters.withZoneHash(blob.zoneHash);
        parameters = parameters.withSalt(blob.salt);
        parameters = parameters.withConduitKey(blob.conduitKey);
        parameters = parameters.withTotalOriginalConsiderationItems(
            blob.totalOriginalConsiderationItems
        );
        return parameters;
    }

    function assertEq(
        OrderComponents memory a,
        OrderComponents memory b
    ) internal {
        assertEq(a.offerer, b.offerer, "offerer");
        assertEq(a.zone, b.zone, "zone");
        assertEq(a.offer, b.offer);
        assertEq(a.consideration, b.consideration);
        assertEq(uint8(a.orderType), uint8(b.orderType), "orderType");
        assertEq(a.startTime, b.startTime, "startTime");
        assertEq(a.endTime, b.endTime, "endTime");
        assertEq(a.zoneHash, b.zoneHash, "zoneHash");
        assertEq(a.salt, b.salt, "salt");
        assertEq(a.conduitKey, b.conduitKey, "conduitKey");
        assertEq(a.counter, b.counter, "counter");
    }
}
