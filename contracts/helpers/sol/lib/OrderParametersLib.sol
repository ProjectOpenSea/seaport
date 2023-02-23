// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    OrderComponents,
    ConsiderationItem,
    OrderParameters,
    OfferItem
} from "../../../lib/ConsiderationStructs.sol";

import { OrderType } from "../../../lib/ConsiderationEnums.sol";

import { StructCopier } from "./StructCopier.sol";

import { OfferItemLib } from "./OfferItemLib.sol";

import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

/**
 * @title OrderParametersLib
 * @author James Wenzel (emo.eth)
 * @notice OrderParametersLib is a library for managing OrderParameters structs
 *         and arrays. It allows chaining of functions to make struct creation
 *         more readable.
 */
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

    /**
     * @dev Clears an OrderParameters from storage.
     *
     * @param parameters the OrderParameters to clear
     */
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

    /**
     * @dev Clears an array of OrderParameters from storage.
     *
     * @param parameters the OrderParameters array to clear
     */
    function clear(OrderParameters[] storage parameters) internal {
        while (parameters.length > 0) {
            clear(parameters[parameters.length - 1]);
            parameters.pop();
        }
    }

    /**
     * @dev Clears a default OrderParameters from storage.
     *
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => OrderParameters)
            storage orderParametersMap = _orderParametersMap();
        OrderParameters storage parameters = orderParametersMap[defaultName];
        parameters.clear();
    }

    /**
     * @dev Creates a new empty OrderParameters struct.
     *
     * @return item the new OrderParameters
     */
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
     * @dev Gets a default OrderParameters from storage.
     *
     * @param defaultName the name of the default for retrieval
     *
     * @return item the default OrderParameters
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (OrderParameters memory item) {
        mapping(string => OrderParameters)
            storage orderParametersMap = _orderParametersMap();
        item = orderParametersMap[defaultName];
    }

    /**
     * @dev Gets a default OrderParameters array from storage.
     *
     * @param defaultName the name of the default for retrieval
     *
     * @return items the default OrderParameters array
     */
    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (OrderParameters[] memory items) {
        mapping(string => OrderParameters[])
            storage orderParametersArrayMap = _orderParametersArrayMap();
        items = orderParametersArrayMap[defaultName];
    }

    /**
     * @dev Saves an OrderParameters as a named default.
     *
     * @param orderParameters the OrderParameters to save as a default
     * @param defaultName     the name of the default for retrieval
     *
     * @return _orderParameters the OrderParameters that was saved
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

    /**
     * @dev Saves an OrderParameters array as a named default.
     *
     * @param orderParameters the OrderParameters array to save as a default
     * @param defaultName     the name of the default for retrieval
     *
     * @return _orderParameters the OrderParameters array that was saved
     */
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
     * @dev Makes a copy of an OrderParameters in-memory.
     *
     * @param item the OrderParameters to make a copy of in-memory
     *
     * @custom:return copiedOrderParameters the copied OrderParameters
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
     * @dev Gets the storage position of the default OrderParameters map.
     *
     * @custom:return position the storage position of the default
     *                         OrderParameters map
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

    /**
     * @dev Gets the storage position of the default OrderParameters array map.
     *
     * @custom:return position the storage position of the default
     *                         OrderParameters array map
     */
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

    // Methods for configuring a single of each of a OrderParameters's fields,
    // which modify the OrderParameters struct in-place and return it.

    /**
     * @dev Sets the offerer field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param offerer    the new value for the offerer field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withOfferer(
        OrderParameters memory parameters,
        address offerer
    ) internal pure returns (OrderParameters memory) {
        parameters.offerer = offerer;
        return parameters;
    }

    /**
     * @dev Sets the zone field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param zone       the new value for the zone field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withZone(
        OrderParameters memory parameters,
        address zone
    ) internal pure returns (OrderParameters memory) {
        parameters.zone = zone;
        return parameters;
    }

    /**
     * @dev Sets the offer field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param offer      the new value for the offer field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withOffer(
        OrderParameters memory parameters,
        OfferItem[] memory offer
    ) internal pure returns (OrderParameters memory) {
        parameters.offer = offer;
        return parameters;
    }

    /**
     * @dev Sets the consideration field of a OrderParameters struct in-place.
     *
     * @param parameters    the OrderParameters struct to modify
     * @param consideration the new value for the consideration field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withConsideration(
        OrderParameters memory parameters,
        ConsiderationItem[] memory consideration
    ) internal pure returns (OrderParameters memory) {
        parameters.consideration = consideration;
        return parameters;
    }

    /**
     * @dev Sets the orderType field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param orderType  the new value for the orderType field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withOrderType(
        OrderParameters memory parameters,
        OrderType orderType
    ) internal pure returns (OrderParameters memory) {
        parameters.orderType = orderType;
        return parameters;
    }

    /**
     * @dev Sets the startTime field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param startTime  the new value for the startTime field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withStartTime(
        OrderParameters memory parameters,
        uint256 startTime
    ) internal pure returns (OrderParameters memory) {
        parameters.startTime = startTime;
        return parameters;
    }

    /**
     * @dev Sets the endTime field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param endTime    the new value for the endTime field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withEndTime(
        OrderParameters memory parameters,
        uint256 endTime
    ) internal pure returns (OrderParameters memory) {
        parameters.endTime = endTime;
        return parameters;
    }

    /**
     * @dev Sets the zoneHash field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param zoneHash   the new value for the zoneHash field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withZoneHash(
        OrderParameters memory parameters,
        bytes32 zoneHash
    ) internal pure returns (OrderParameters memory) {
        parameters.zoneHash = zoneHash;
        return parameters;
    }

    /**
     * @dev Sets the salt field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param salt       the new value for the salt field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withSalt(
        OrderParameters memory parameters,
        uint256 salt
    ) internal pure returns (OrderParameters memory) {
        parameters.salt = salt;
        return parameters;
    }

    /**
     * @dev Sets the conduitKey field of a OrderParameters struct in-place.
     *
     * @param parameters the OrderParameters struct to modify
     * @param conduitKey the new value for the conduitKey field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withConduitKey(
        OrderParameters memory parameters,
        bytes32 conduitKey
    ) internal pure returns (OrderParameters memory) {
        parameters.conduitKey = conduitKey;
        return parameters;
    }

    /**
     * @dev Sets the totalOriginalConsiderationItems field of a OrderParameters
     *      struct in-place.
     *
     * @param parameters                      the OrderParameters struct to
     *                                        modify
     * @param totalOriginalConsiderationItems the new value for the
     *                                        totalOriginalConsiderationItems
     *                                        field
     *
     * @custom:return _parameters the modified OrderParameters struct
     */
    function withTotalOriginalConsiderationItems(
        OrderParameters memory parameters,
        uint256 totalOriginalConsiderationItems
    ) internal pure returns (OrderParameters memory) {
        parameters
            .totalOriginalConsiderationItems = totalOriginalConsiderationItems;
        return parameters;
    }

    /**
     * @dev Converts an OrderParameters struct into an OrderComponents struct.
     *
     * @param parameters the OrderParameters struct to convert
     * @param counter    the counter to use for the OrderComponents struct
     *
     * @return components the OrderComponents struct
     */
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
