// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    BasicOrderParameters,
    OrderComponents,
    ConsiderationItem,
    OrderParameters,
    OfferItem,
    AdditionalRecipient
} from "../../../lib/ConsiderationStructs.sol";
import {
    OrderType,
    ItemType,
    BasicOrderType
} from "../../../lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";
import { OfferItemLib } from "./OfferItemLib.sol";
import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

library OrderComponentsLib {
    using OrderComponentsLib for OrderComponents;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem[];

    bytes32 private constant ORDER_COMPONENTS_MAP_POSITION =
        keccak256("seaport.OrderComponentsDefaults");
    bytes32 private constant ORDER_COMPONENTS_ARRAY_MAP_POSITION =
        keccak256("seaport.OrderComponentsArrayDefaults");

    function clear(OrderComponents storage components) internal {
        // uninitialized pointers take up no new memory (versus one word for initializing length-0)
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;

        // clear all fields
        components.offerer = address(0);
        components.zone = address(0);
        StructCopier.setOfferItems(components.offer, offer);
        StructCopier.setConsiderationItems(
            components.consideration,
            consideration
        );
        components.orderType = OrderType(0);
        components.startTime = 0;
        components.endTime = 0;
        components.zoneHash = bytes32(0);
        components.salt = 0;
        components.conduitKey = bytes32(0);
        components.counter = 0;
    }

    function clear(OrderComponents[] storage components) internal {
        while (components.length > 0) {
            clear(components[components.length - 1]);
            components.pop();
        }
    }

    /**
     * @notice clears a default OrderComponents from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => OrderComponents)
            storage orderComponentsMap = _orderComponentsMap();
        OrderComponents storage components = orderComponentsMap[defaultName];
        components.clear();
    }

    function empty() internal pure returns (OrderComponents memory item) {
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;
        item = OrderComponents({
            offerer: address(0),
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: OrderType(0),
            startTime: 0,
            endTime: 0,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            counter: 0
        });
    }

    /**
     * @notice gets a default OrderComponents from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (OrderComponents memory item) {
        mapping(string => OrderComponents)
            storage orderComponentsMap = _orderComponentsMap();
        item = orderComponentsMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (OrderComponents[] memory items) {
        mapping(string => OrderComponents[])
            storage orderComponentsArrayMap = _orderComponentsArrayMap();
        items = orderComponentsArrayMap[defaultName];
    }

    /**
     * @notice saves an OrderComponents as a named default
     * @param orderComponents the OrderComponents to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        OrderComponents memory orderComponents,
        string memory defaultName
    ) internal returns (OrderComponents memory _orderComponents) {
        mapping(string => OrderComponents)
            storage orderComponentsMap = _orderComponentsMap();
        OrderComponents storage destination = orderComponentsMap[defaultName];
        StructCopier.setOrderComponents(destination, orderComponents);
        return orderComponents;
    }

    function saveDefaultMany(
        OrderComponents[] memory orderComponents,
        string memory defaultName
    ) internal returns (OrderComponents[] memory _orderComponents) {
        mapping(string => OrderComponents[])
            storage orderComponentsArrayMap = _orderComponentsArrayMap();
        OrderComponents[] storage destination = orderComponentsArrayMap[
            defaultName
        ];
        StructCopier.setOrderComponents(destination, orderComponents);
        return orderComponents;
    }

    /**
     * @notice makes a copy of an OrderComponents in-memory
     * @param item the OrderComponents to make a copy of in-memory
     */
    function copy(
        OrderComponents memory item
    ) internal pure returns (OrderComponents memory) {
        return
            OrderComponents({
                offerer: item.offerer,
                zone: item.zone,
                offer: item.offer.copy(),
                consideration: item.consideration.copy(),
                orderType: item.orderType,
                startTime: item.startTime,
                endTime: item.endTime,
                zoneHash: item.zoneHash,
                salt: item.salt,
                conduitKey: item.conduitKey,
                counter: item.counter
            });
    }

    /**
     * @notice gets the storage position of the default OrderComponents map
     */
    function _orderComponentsMap()
        private
        pure
        returns (mapping(string => OrderComponents) storage orderComponentsMap)
    {
        bytes32 position = ORDER_COMPONENTS_MAP_POSITION;
        assembly {
            orderComponentsMap.slot := position
        }
    }

    function _orderComponentsArrayMap()
        private
        pure
        returns (
            mapping(string => OrderComponents[]) storage orderComponentsArrayMap
        )
    {
        bytes32 position = ORDER_COMPONENTS_ARRAY_MAP_POSITION;
        assembly {
            orderComponentsArrayMap.slot := position
        }
    }

    // methods for configuring a single of each of an in-memory OrderComponents's fields, which modifies the
    // OrderComponents in-memory and returns it

    function withOfferer(
        OrderComponents memory components,
        address offerer
    ) internal pure returns (OrderComponents memory) {
        components.offerer = offerer;
        return components;
    }

    function withZone(
        OrderComponents memory components,
        address zone
    ) internal pure returns (OrderComponents memory) {
        components.zone = zone;
        return components;
    }

    function withOffer(
        OrderComponents memory components,
        OfferItem[] memory offer
    ) internal pure returns (OrderComponents memory) {
        components.offer = offer;
        return components;
    }

    function withConsideration(
        OrderComponents memory components,
        ConsiderationItem[] memory consideration
    ) internal pure returns (OrderComponents memory) {
        components.consideration = consideration;
        return components;
    }

    function withOrderType(
        OrderComponents memory components,
        OrderType orderType
    ) internal pure returns (OrderComponents memory) {
        components.orderType = orderType;
        return components;
    }

    function withStartTime(
        OrderComponents memory components,
        uint256 startTime
    ) internal pure returns (OrderComponents memory) {
        components.startTime = startTime;
        return components;
    }

    function withEndTime(
        OrderComponents memory components,
        uint256 endTime
    ) internal pure returns (OrderComponents memory) {
        components.endTime = endTime;
        return components;
    }

    function withZoneHash(
        OrderComponents memory components,
        bytes32 zoneHash
    ) internal pure returns (OrderComponents memory) {
        components.zoneHash = zoneHash;
        return components;
    }

    function withSalt(
        OrderComponents memory components,
        uint256 salt
    ) internal pure returns (OrderComponents memory) {
        components.salt = salt;
        return components;
    }

    function withConduitKey(
        OrderComponents memory components,
        bytes32 conduitKey
    ) internal pure returns (OrderComponents memory) {
        components.conduitKey = conduitKey;
        return components;
    }

    function withCounter(
        OrderComponents memory components,
        uint256 counter
    ) internal pure returns (OrderComponents memory) {
        components.counter = counter;
        return components;
    }

    function toOrderParameters(
        OrderComponents memory components
    ) internal pure returns (OrderParameters memory parameters) {
        parameters.offerer = components.offerer;
        parameters.zone = components.zone;
        parameters.offer = components.offer.copy();
        parameters.consideration = components.consideration.copy();
        parameters.orderType = components.orderType;
        parameters.startTime = components.startTime;
        parameters.endTime = components.endTime;
        parameters.zoneHash = components.zoneHash;
        parameters.salt = components.salt;
        parameters.conduitKey = components.conduitKey;
        parameters.totalOriginalConsiderationItems = components
            .consideration
            .length;
    }
}
