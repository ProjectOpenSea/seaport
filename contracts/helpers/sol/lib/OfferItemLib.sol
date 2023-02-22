// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OfferItem, SpentItem } from "../../../lib/ConsiderationStructs.sol";
import { ItemType } from "../../../lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";

library OfferItemLib {
    bytes32 private constant OFFER_ITEM_MAP_POSITION =
        keccak256("seaport.OfferItemDefaults");
    bytes32 private constant OFFER_ITEMS_MAP_POSITION =
        keccak256("seaport.OfferItemsDefaults");

    function _clear(OfferItem storage item) internal {
        // clear all fields
        item.itemType = ItemType.NATIVE;
        item.token = address(0);
        item.identifierOrCriteria = 0;
        item.startAmount = 0;
        item.endAmount = 0;
    }

    /**
     * @notice clears a default OfferItem from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => OfferItem) storage offerItemMap = _offerItemMap();
        OfferItem storage item = offerItemMap[defaultName];
        _clear(item);
    }

    function clearMany(string memory defaultsName) internal {
        mapping(string => OfferItem[]) storage offerItemsMap = _offerItemsMap();
        OfferItem[] storage items = offerItemsMap[defaultsName];
        while (items.length > 0) {
            _clear(items[items.length - 1]);
            items.pop();
        }
    }

    /**
     * @notice gets a default OfferItem from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (OfferItem memory item) {
        mapping(string => OfferItem) storage offerItemMap = _offerItemMap();
        item = offerItemMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultsName
    ) internal view returns (OfferItem[] memory items) {
        mapping(string => OfferItem[]) storage offerItemsMap = _offerItemsMap();
        items = offerItemsMap[defaultsName];
    }

    /**
     * @notice saves an OfferItem as a named default
     * @param offerItem the OfferItem to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        OfferItem memory offerItem,
        string memory defaultName
    ) internal returns (OfferItem memory _offerItem) {
        mapping(string => OfferItem) storage offerItemMap = _offerItemMap();
        offerItemMap[defaultName] = offerItem;
        return offerItem;
    }

    function saveDefaultMany(
        OfferItem[] memory offerItems,
        string memory defaultsName
    ) internal returns (OfferItem[] memory _offerItems) {
        mapping(string => OfferItem[]) storage offerItemsMap = _offerItemsMap();
        OfferItem[] storage items = offerItemsMap[defaultsName];
        clearMany(defaultsName);
        StructCopier.setOfferItems(items, offerItems);
        return offerItems;
    }

    /**
     * @notice makes a copy of an OfferItem in-memory
     * @param item the OfferItem to make a copy of in-memory
     */
    function copy(
        OfferItem memory item
    ) internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount
            });
    }

    function copy(
        OfferItem[] memory items
    ) internal pure returns (OfferItem[] memory) {
        OfferItem[] memory copiedItems = new OfferItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            copiedItems[i] = copy(items[i]);
        }
        return copiedItems;
    }

    function empty() internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: 0,
                endAmount: 0
            });
    }

    /**
     * @notice gets the storage position of the default OfferItem map
     */
    function _offerItemMap()
        private
        pure
        returns (mapping(string => OfferItem) storage offerItemMap)
    {
        bytes32 position = OFFER_ITEM_MAP_POSITION;
        assembly {
            offerItemMap.slot := position
        }
    }

    /**
     * @notice gets the storage position of the default OfferItem[] map
     */
    function _offerItemsMap()
        private
        pure
        returns (mapping(string => OfferItem[]) storage offerItemMap)
    {
        bytes32 position = OFFER_ITEMS_MAP_POSITION;
        assembly {
            offerItemMap.slot := position
        }
    }

    // methods for configuring a single of each of an OfferItem's fields, which modifies the OfferItem in-place and
    // returns it

    /**
     * @notice sets the item type
     * @param item the OfferItem to modify
     * @param itemType the item type to set
     * @return the modified OfferItem
     */
    function withItemType(
        OfferItem memory item,
        ItemType itemType
    ) internal pure returns (OfferItem memory) {
        item.itemType = itemType;
        return item;
    }

    /**
     * @notice sets the token address
     * @param item the OfferItem to modify
     * @param token the token address to set
     * @return the modified OfferItem
     */
    function withToken(
        OfferItem memory item,
        address token
    ) internal pure returns (OfferItem memory) {
        item.token = token;
        return item;
    }

    /**
     * @notice sets the identifier or criteria
     * @param item the OfferItem to modify
     * @param identifierOrCriteria the identifier or criteria to set
     * @return the modified OfferItem
     */
    function withIdentifierOrCriteria(
        OfferItem memory item,
        uint256 identifierOrCriteria
    ) internal pure returns (OfferItem memory) {
        item.identifierOrCriteria = identifierOrCriteria;
        return item;
    }

    /**
     * @notice sets the start amount
     * @param item the OfferItem to modify
     * @param startAmount the start amount to set
     * @return the modified OfferItem
     */
    function withStartAmount(
        OfferItem memory item,
        uint256 startAmount
    ) internal pure returns (OfferItem memory) {
        item.startAmount = startAmount;
        return item;
    }

    /**
     * @notice sets the end amount
     * @param item the OfferItem to modify
     * @param endAmount the end amount to set
     * @return the modified OfferItem
     */
    function withEndAmount(
        OfferItem memory item,
        uint256 endAmount
    ) internal pure returns (OfferItem memory) {
        item.endAmount = endAmount;
        return item;
    }

    function toSpentItem(
        OfferItem memory item
    ) internal pure returns (SpentItem memory) {
        return
            SpentItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                amount: item.startAmount
            });
    }
}
