// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    Order,
    OrderParameters
} from "../../../lib/ConsiderationStructs.sol";

import { OrderParametersLib } from "./OrderParametersLib.sol";

import { StructCopier } from "./StructCopier.sol";

/**
 * @title AdvancedOrderLib
 * @author James Wenzel (emo.eth)
 * @notice AdditionalRecipientLib is a library for managing AdvancedOrder
 *         structs and arrays. It allows chaining of functions to make struct
 *         creation more readable.
 */
library AdvancedOrderLib {
    bytes32 private constant ADVANCED_ORDER_MAP_POSITION =
        keccak256("seaport.AdvancedOrderDefaults");
    bytes32 private constant ADVANCED_ORDERS_MAP_POSITION =
        keccak256("seaport.AdvancedOrdersDefaults");

    using OrderParametersLib for OrderParameters;

    /**
     * @dev Clears a default AdvancedOrder from storage.
     *
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => AdvancedOrder)
            storage advancedOrderMap = _advancedOrderMap();
        AdvancedOrder storage item = advancedOrderMap[defaultName];
        clear(item);
    }

    /**
     * @dev Clears all fields on an AdvancedOrder.
     *
     * @param item the AdvancedOrder to clear
     */
    function clear(AdvancedOrder storage item) internal {
        // clear all fields
        item.parameters.clear();
        item.signature = "";
        item.numerator = 0;
        item.denominator = 0;
        item.extraData = "";
    }

    /**
     * @dev Clears an array of AdvancedOrders from storage.
     *
     * @param items the AdvancedOrders to clear
     */
    function clear(AdvancedOrder[] storage items) internal {
        while (items.length > 0) {
            clear(items[items.length - 1]);
            items.pop();
        }
    }

    /**
     * @dev Gets a default AdvancedOrder from storage.
     *
     * @param defaultName the name of the default for retrieval
     *
     * @return item the AdvancedOrder retrieved from storage
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (AdvancedOrder memory item) {
        mapping(string => AdvancedOrder)
            storage advancedOrderMap = _advancedOrderMap();
        item = advancedOrderMap[defaultName];
    }

    /**
     * @dev Gets an array of default AdvancedOrders from storage.
     *
     * @param defaultName the name of the default for retrieval
     *
     * @return items the AdvancedOrders retrieved from storage
     */
    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (AdvancedOrder[] memory items) {
        mapping(string => AdvancedOrder[])
            storage advancedOrdersMap = _advancedOrdersMap();
        items = advancedOrdersMap[defaultName];
    }

    /**
     * @dev Returns an empty AdvancedOrder.
     *
     * @custom:return item the empty AdvancedOrder
     */
    function empty() internal pure returns (AdvancedOrder memory) {
        return AdvancedOrder(OrderParametersLib.empty(), 0, 0, "", "");
    }

    /**
     * @dev Saves an AdvancedOrder as a named default.
     *
     * @param advancedOrder the AdvancedOrder to save as a default
     * @param defaultName   the name of the new default
     *
     * @return _advancedOrder the AdvancedOrder saved as a default
     */
    function saveDefault(
        AdvancedOrder memory advancedOrder,
        string memory defaultName
    ) internal returns (AdvancedOrder memory _advancedOrder) {
        mapping(string => AdvancedOrder)
            storage advancedOrderMap = _advancedOrderMap();
        StructCopier.setAdvancedOrder(
            advancedOrderMap[defaultName],
            advancedOrder
        );
        return advancedOrder;
    }

    /**
     * @dev Saves an array of AdvancedOrders as a named default.
     *
     * @param advancedOrders the AdvancedOrders to save as a default
     * @param defaultName    the name of the new default
     *
     * @return _advancedOrders the AdvancedOrders saved as a default
     */
    function saveDefaultMany(
        AdvancedOrder[] memory advancedOrders,
        string memory defaultName
    ) internal returns (AdvancedOrder[] memory _advancedOrders) {
        mapping(string => AdvancedOrder[])
            storage advancedOrdersMap = _advancedOrdersMap();
        StructCopier.setAdvancedOrders(
            advancedOrdersMap[defaultName],
            advancedOrders
        );
        return advancedOrders;
    }

    /**
     * @dev Makes a copy of an AdvancedOrder in-memory.
     *
     * @param item the AdvancedOrder to make a copy of in-memory
     *
     * @custom:return item the copied AdvancedOrder
     */
    function copy(
        AdvancedOrder memory item
    ) internal pure returns (AdvancedOrder memory) {
        return
            AdvancedOrder({
                parameters: item.parameters.copy(),
                numerator: item.numerator,
                denominator: item.denominator,
                signature: item.signature,
                extraData: item.extraData
            });
    }

    /**
     * @dev Makes a copy of an array of AdvancedOrders in-memory.
     *
     * @param items the AdvancedOrders to make a copy of in-memory
     *
     * @custom:return items the copied AdvancedOrders
     */
    function copy(
        AdvancedOrder[] memory items
    ) internal pure returns (AdvancedOrder[] memory) {
        AdvancedOrder[] memory copiedItems = new AdvancedOrder[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            copiedItems[i] = copy(items[i]);
        }
        return copiedItems;
    }

    /**
     * @dev Gets the storage position of the default AdvancedOrder map.
     *
     * @return advancedOrderMap the storage position of the default
     *                          AdvancedOrder map
     */
    function _advancedOrderMap()
        private
        pure
        returns (mapping(string => AdvancedOrder) storage advancedOrderMap)
    {
        bytes32 position = ADVANCED_ORDER_MAP_POSITION;
        assembly {
            advancedOrderMap.slot := position
        }
    }

    /**
     * @dev Gets the storage position of the default AdvancedOrder array map.
     *
     * @return advancedOrdersMap the storage position of the default
     *                           AdvancedOrder array map
     */
    function _advancedOrdersMap()
        private
        pure
        returns (mapping(string => AdvancedOrder[]) storage advancedOrdersMap)
    {
        bytes32 position = ADVANCED_ORDERS_MAP_POSITION;
        assembly {
            advancedOrdersMap.slot := position
        }
    }

    // Methods for configuring a single of each of an AdvancedOrder's fields,
    // which modify the AdvancedOrder in-place and return it.

    /**
     * @dev Configures an AdvancedOrder's parameters.
     *
     * @param advancedOrder the AdvancedOrder to configure
     * @param parameters    the parameters to set
     *
     * @custom:return _advancedOrder the configured AdvancedOrder
     */
    function withParameters(
        AdvancedOrder memory advancedOrder,
        OrderParameters memory parameters
    ) internal pure returns (AdvancedOrder memory) {
        advancedOrder.parameters = parameters.copy();
        return advancedOrder;
    }

    /**
     * @dev Configures an AdvancedOrder's numerator.
     *
     * @param advancedOrder the AdvancedOrder to configure
     * @param numerator     the numerator to set
     *
     * @custom:return _advancedOrder the configured AdvancedOrder
     */
    function withNumerator(
        AdvancedOrder memory advancedOrder,
        uint120 numerator
    ) internal pure returns (AdvancedOrder memory) {
        advancedOrder.numerator = numerator;
        return advancedOrder;
    }

    /**
     * @dev Configures an AdvancedOrder's denominator.
     *
     * @param advancedOrder the AdvancedOrder to configure
     * @param denominator   the denominator to set
     *
     * @custom:return _advancedOrder the configured AdvancedOrder
     */
    function withDenominator(
        AdvancedOrder memory advancedOrder,
        uint120 denominator
    ) internal pure returns (AdvancedOrder memory) {
        advancedOrder.denominator = denominator;
        return advancedOrder;
    }

    /**
     * @dev Configures an AdvancedOrder's signature.
     *
     * @param advancedOrder the AdvancedOrder to configure
     * @param signature     the signature to set
     *
     * @custom:return _advancedOrder the configured AdvancedOrder
     */
    function withSignature(
        AdvancedOrder memory advancedOrder,
        bytes memory signature
    ) internal pure returns (AdvancedOrder memory) {
        advancedOrder.signature = signature;
        return advancedOrder;
    }

    /**
     * @dev Configures an AdvancedOrder's extra data.
     *
     * @param advancedOrder the AdvancedOrder to configure
     * @param extraData     the extra data to set
     *
     * @custom:return _advancedOrder the configured AdvancedOrder
     */
    function withExtraData(
        AdvancedOrder memory advancedOrder,
        bytes memory extraData
    ) internal pure returns (AdvancedOrder memory) {
        advancedOrder.extraData = extraData;
        return advancedOrder;
    }

    /**
     * @dev Converts an AdvancedOrder to an Order.
     *
     * @param advancedOrder the AdvancedOrder to convert
     *
     * @return order the converted Order
     */
    function toOrder(
        AdvancedOrder memory advancedOrder
    ) internal pure returns (Order memory order) {
        order.parameters = advancedOrder.parameters.copy();
        order.signature = advancedOrder.signature;
    }
}
