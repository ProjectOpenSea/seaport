// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { SpentItem, OfferItem } from "../../../lib/ConsiderationStructs.sol";
import { ItemType } from "../../../lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";

library SpentItemLib {
    bytes32 private constant SPENT_ITEM_MAP_POSITION =
        keccak256("seaport.SpentItemDefaults");
    bytes32 private constant SPENT_ITEMS_MAP_POSITION =
        keccak256("seaport.SpentItemsDefaults");

    function empty() internal pure returns (SpentItem memory) {
        return SpentItem(ItemType(0), address(0), 0, 0);
    }

    function clear(SpentItem storage item) internal {
        // clear all fields
        item.itemType = ItemType(0);
        item.token = address(0);
        item.identifier = 0;
        item.amount = 0;
    }

    function clearMany(SpentItem[] storage items) internal {
        while (items.length > 0) {
            clear(items[items.length - 1]);
            items.pop();
        }
    }

    /**
     * @notice clears a default SpentItem from storage
     * @param defaultName the name of the default to clear
     */

    function clear(string memory defaultName) internal {
        mapping(string => SpentItem) storage spentItemMap = _spentItemMap();
        SpentItem storage item = spentItemMap[defaultName];
        clear(item);
    }

    function clearMany(string memory defaultsName) internal {
        mapping(string => SpentItem[]) storage spentItemsMap = _spentItemsMap();
        SpentItem[] storage items = spentItemsMap[defaultsName];
        clearMany(items);
    }

    /**
     * @notice gets a default SpentItem from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (SpentItem memory item) {
        mapping(string => SpentItem) storage spentItemMap = _spentItemMap();
        item = spentItemMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultsName
    ) internal view returns (SpentItem[] memory items) {
        mapping(string => SpentItem[]) storage spentItemsMap = _spentItemsMap();
        items = spentItemsMap[defaultsName];
    }

    /**
     * @notice saves an SpentItem as a named default
     * @param spentItem the SpentItem to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        SpentItem memory spentItem,
        string memory defaultName
    ) internal returns (SpentItem memory _spentItem) {
        mapping(string => SpentItem) storage spentItemMap = _spentItemMap();
        spentItemMap[defaultName] = spentItem;
        return spentItem;
    }

    function saveDefaultMany(
        SpentItem[] memory spentItems,
        string memory defaultsName
    ) internal returns (SpentItem[] memory _spentItems) {
        mapping(string => SpentItem[]) storage spentItemsMap = _spentItemsMap();
        SpentItem[] storage items = spentItemsMap[defaultsName];
        setSpentItems(items, spentItems);
        return spentItems;
    }

    function setSpentItems(
        SpentItem[] storage items,
        SpentItem[] memory newItems
    ) internal {
        clearMany(items);
        for (uint256 i = 0; i < newItems.length; i++) {
            items.push(newItems[i]);
        }
    }

    /**
     * @notice makes a copy of an SpentItem in-memory
     * @param item the SpentItem to make a copy of in-memory
     */
    function copy(
        SpentItem memory item
    ) internal pure returns (SpentItem memory) {
        return
            SpentItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifier,
                amount: item.amount
            });
    }

    function copy(
        SpentItem[] memory items
    ) internal pure returns (SpentItem[] memory) {
        SpentItem[] memory copiedItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            copiedItems[i] = copy(items[i]);
        }
        return copiedItems;
    }

    /**
     * @notice gets the storage position of the default SpentItem map
     */
    function _spentItemMap()
        private
        pure
        returns (mapping(string => SpentItem) storage spentItemMap)
    {
        bytes32 position = SPENT_ITEM_MAP_POSITION;
        assembly {
            spentItemMap.slot := position
        }
    }

    function _spentItemsMap()
        private
        pure
        returns (mapping(string => SpentItem[]) storage spentItemsMap)
    {
        bytes32 position = SPENT_ITEMS_MAP_POSITION;
        assembly {
            spentItemsMap.slot := position
        }
    }

    // methods for configuring a single of each of an SpentItem's fields, which modifies the SpentItem in-place and
    // returns it

    /**
     * @notice sets the item type
     * @param item the SpentItem to modify
     * @param itemType the item type to set
     * @return the modified SpentItem
     */
    function withItemType(
        SpentItem memory item,
        ItemType itemType
    ) internal pure returns (SpentItem memory) {
        item.itemType = itemType;
        return item;
    }

    /**
     * @notice sets the token address
     * @param item the SpentItem to modify
     * @param token the token address to set
     * @return the modified SpentItem
     */
    function withToken(
        SpentItem memory item,
        address token
    ) internal pure returns (SpentItem memory) {
        item.token = token;
        return item;
    }

    /**
     * @notice sets the identifier or criteria
     * @param item the SpentItem to modify
     * @param identifier the identifier or criteria to set
     * @return the modified SpentItem
     */
    function withIdentifier(
        SpentItem memory item,
        uint256 identifier
    ) internal pure returns (SpentItem memory) {
        item.identifier = identifier;
        return item;
    }

    /**
     * @notice sets the start amount
     * @param item the SpentItem to modify
     * @param amount the start amount to set
     * @return the modified SpentItem
     */
    function withAmount(
        SpentItem memory item,
        uint256 amount
    ) internal pure returns (SpentItem memory) {
        item.amount = amount;
        return item;
    }

    function toOfferItem(
        SpentItem memory item
    ) internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifier,
                startAmount: item.amount,
                endAmount: item.amount
            });
    }
}
