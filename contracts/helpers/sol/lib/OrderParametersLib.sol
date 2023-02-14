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

library OrderParametersLib {
    using OrderParametersLib for OrderParameters;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using OfferItemLib for OfferItem;

    bytes32 private constant ORDER_PARAMETERS_MAP_POSITION =
        keccak256("seaport.OrderParametersDefaults");
    bytes32 private constant ORDER_PARAMETERS_ARRAY_MAP_POSITION =
        keccak256("seaport.OrderParametersArrayDefaults");

    function clear(OrderParameters storage parameters) internal {
        // uninitialized pointers take up no new memory (versus one word for initializing length-0)
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;

        // clear all fields
        parameters.offerer = address(0);
        parameters.zone = address(0);
        StructCopier.setOfferItems(parameters.offer, offer);
        StructCopier.setConsiderationItems(
            parameters.consideration,
            consideration
        );
        parameters.orderType = OrderType(0);
        parameters.startTime = 0;
        parameters.endTime = 0;
        parameters.zoneHash = bytes32(0);
        parameters.salt = 0;
        parameters.conduitKey = bytes32(0);
        parameters.totalOriginalConsiderationItems = 0;
    }

    function clear(OrderParameters[] storage parameters) internal {
        while (parameters.length > 0) {
            clear(parameters[parameters.length - 1]);
            parameters.pop();
        }
    }

    /**
     * @notice clears a default OrderParameters from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => OrderParameters)
            storage orderParametersMap = _orderParametersMap();
        OrderParameters storage parameters = orderParametersMap[defaultName];
        parameters.clear();
    }

    function empty() internal pure returns (OrderParameters memory item) {
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;
        item = OrderParameters({
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
            totalOriginalConsiderationItems: 0
        });
    }

    /**
     * @notice gets a default OrderParameters from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (OrderParameters memory item) {
        mapping(string => OrderParameters)
            storage orderParametersMap = _orderParametersMap();
        item = orderParametersMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (OrderParameters[] memory items) {
        mapping(string => OrderParameters[])
            storage orderParametersArrayMap = _orderParametersArrayMap();
        items = orderParametersArrayMap[defaultName];
    }

    /**
     * @notice saves an OrderParameters as a named default
     * @param orderParameters the OrderParameters to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        OrderParameters memory orderParameters,
        string memory defaultName
    ) internal returns (OrderParameters memory _orderParameters) {
        mapping(string => OrderParameters)
            storage orderParametersMap = _orderParametersMap();
        OrderParameters storage destination = orderParametersMap[defaultName];
        StructCopier.setOrderParameters(destination, orderParameters);
        return orderParameters;
    }

    function saveDefaultMany(
        OrderParameters[] memory orderParameters,
        string memory defaultName
    ) internal returns (OrderParameters[] memory _orderParameters) {
        mapping(string => OrderParameters[])
            storage orderParametersArrayMap = _orderParametersArrayMap();
        OrderParameters[] storage destination = orderParametersArrayMap[
            defaultName
        ];
        StructCopier.setOrderParameters(destination, orderParameters);
        return orderParameters;
    }

    /**
     * @notice makes a copy of an OrderParameters in-memory
     * @param item the OrderParameters to make a copy of in-memory
     */
    function copy(
        OrderParameters memory item
    ) internal pure returns (OrderParameters memory) {
        return
            OrderParameters({
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
                totalOriginalConsiderationItems: item
                    .totalOriginalConsiderationItems
            });
    }

    /**
     * @notice gets the storage position of the default OrderParameters map
     */
    function _orderParametersMap()
        private
        pure
        returns (mapping(string => OrderParameters) storage orderParametersMap)
    {
        bytes32 position = ORDER_PARAMETERS_MAP_POSITION;
        assembly {
            orderParametersMap.slot := position
        }
    }

    function _orderParametersArrayMap()
        private
        pure
        returns (
            mapping(string => OrderParameters[]) storage orderParametersArrayMap
        )
    {
        bytes32 position = ORDER_PARAMETERS_ARRAY_MAP_POSITION;
        assembly {
            orderParametersArrayMap.slot := position
        }
    }

    // methods for configuring a single of each of an in-memory OrderParameters's fields, which modifies the
    // OrderParameters in-memory and returns it

    function withOfferer(
        OrderParameters memory parameters,
        address offerer
    ) internal pure returns (OrderParameters memory) {
        parameters.offerer = offerer;
        return parameters;
    }

    function withZone(
        OrderParameters memory parameters,
        address zone
    ) internal pure returns (OrderParameters memory) {
        parameters.zone = zone;
        return parameters;
    }

    function withOffer(
        OrderParameters memory parameters,
        OfferItem[] memory offer
    ) internal pure returns (OrderParameters memory) {
        parameters.offer = offer;
        return parameters;
    }

    function withConsideration(
        OrderParameters memory parameters,
        ConsiderationItem[] memory consideration
    ) internal pure returns (OrderParameters memory) {
        parameters.consideration = consideration;
        return parameters;
    }

    function withOrderType(
        OrderParameters memory parameters,
        OrderType orderType
    ) internal pure returns (OrderParameters memory) {
        parameters.orderType = orderType;
        return parameters;
    }

    function withStartTime(
        OrderParameters memory parameters,
        uint256 startTime
    ) internal pure returns (OrderParameters memory) {
        parameters.startTime = startTime;
        return parameters;
    }

    function withEndTime(
        OrderParameters memory parameters,
        uint256 endTime
    ) internal pure returns (OrderParameters memory) {
        parameters.endTime = endTime;
        return parameters;
    }

    function withZoneHash(
        OrderParameters memory parameters,
        bytes32 zoneHash
    ) internal pure returns (OrderParameters memory) {
        parameters.zoneHash = zoneHash;
        return parameters;
    }

    function withSalt(
        OrderParameters memory parameters,
        uint256 salt
    ) internal pure returns (OrderParameters memory) {
        parameters.salt = salt;
        return parameters;
    }

    function withConduitKey(
        OrderParameters memory parameters,
        bytes32 conduitKey
    ) internal pure returns (OrderParameters memory) {
        parameters.conduitKey = conduitKey;
        return parameters;
    }

    function withTotalOriginalConsiderationItems(
        OrderParameters memory parameters,
        uint256 totalOriginalConsiderationItems
    ) internal pure returns (OrderParameters memory) {
        parameters
            .totalOriginalConsiderationItems = totalOriginalConsiderationItems;
        return parameters;
    }

    function toOrderComponents(
        OrderParameters memory parameters,
        uint256 counter
    ) internal pure returns (OrderComponents memory components) {
        components.offerer = parameters.offerer;
        components.zone = parameters.zone;
        components.offer = parameters.offer.copy();
        components.consideration = parameters.consideration.copy();
        components.orderType = parameters.orderType;
        components.startTime = parameters.startTime;
        components.endTime = parameters.endTime;
        components.zoneHash = parameters.zoneHash;
        components.salt = parameters.salt;
        components.conduitKey = parameters.conduitKey;
        components.counter = counter;
    }
}
