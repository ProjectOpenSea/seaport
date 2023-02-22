// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ReceivedItem,
    ConsiderationItem
} from "../../../lib/ConsiderationStructs.sol";
import { ItemType } from "../../../lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";

library ReceivedItemLib {
    bytes32 private constant RECEIVED_ITEM_MAP_POSITION =
        keccak256("seaport.ReceivedItemDefaults");
    bytes32 private constant RECEIVED_ITEMS_MAP_POSITION =
        keccak256("seaport.ReceivedItemsDefaults");

    /**
     * @notice clears a default ReceivedItem from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => ReceivedItem)
            storage receivedItemMap = _receivedItemMap();
        ReceivedItem storage item = receivedItemMap[defaultName];
        clear(item);
    }

    function clear(ReceivedItem storage item) internal {
        // clear all fields
        item.itemType = ItemType.NATIVE;
        item.token = address(0);
        item.identifier = 0;
        item.amount = 0;
        item.recipient = payable(address(0));
    }

    function clearMany(string memory defaultsName) internal {
        mapping(string => ReceivedItem[])
            storage receivedItemsMap = _receivedItemsMap();
        ReceivedItem[] storage items = receivedItemsMap[defaultsName];
        clearMany(items);
    }

    function clearMany(ReceivedItem[] storage items) internal {
        while (items.length > 0) {
            clear(items[items.length - 1]);
            items.pop();
        }
    }

    function empty() internal pure returns (ReceivedItem memory) {
        return
            ReceivedItem({
                itemType: ItemType(0),
                token: address(0),
                identifier: 0,
                amount: 0,
                recipient: payable(address(0))
            });
    }

    /**
     * @notice gets a default ReceivedItem from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (ReceivedItem memory item) {
        mapping(string => ReceivedItem)
            storage receivedItemMap = _receivedItemMap();
        item = receivedItemMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultsName
    ) internal view returns (ReceivedItem[] memory items) {
        mapping(string => ReceivedItem[])
            storage receivedItemsMap = _receivedItemsMap();
        items = receivedItemsMap[defaultsName];
    }

    /**
     * @notice saves an ReceivedItem as a named default
     * @param receivedItem the ReceivedItem to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        ReceivedItem memory receivedItem,
        string memory defaultName
    ) internal returns (ReceivedItem memory _receivedItem) {
        mapping(string => ReceivedItem)
            storage receivedItemMap = _receivedItemMap();
        receivedItemMap[defaultName] = receivedItem;
        return receivedItem;
    }

    function saveDefaultMany(
        ReceivedItem[] memory receivedItems,
        string memory defaultsName
    ) internal returns (ReceivedItem[] memory _receivedItems) {
        mapping(string => ReceivedItem[])
            storage receivedItemsMap = _receivedItemsMap();
        ReceivedItem[] storage items = receivedItemsMap[defaultsName];
        setReceivedItems(items, receivedItems);
        return receivedItems;
    }

    function setReceivedItems(
        ReceivedItem[] storage items,
        ReceivedItem[] memory newItems
    ) internal {
        clearMany(items);
        for (uint256 i = 0; i < newItems.length; i++) {
            items.push(newItems[i]);
        }
    }

    /**
     * @notice makes a copy of an ReceivedItem in-memory
     * @param item the ReceivedItem to make a copy of in-memory
     */
    function copy(
        ReceivedItem memory item
    ) internal pure returns (ReceivedItem memory) {
        return
            ReceivedItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifier,
                amount: item.amount,
                recipient: item.recipient
            });
    }

    function copy(
        ReceivedItem[] memory item
    ) internal pure returns (ReceivedItem[] memory) {
        ReceivedItem[] memory copies = new ReceivedItem[](item.length);
        for (uint256 i = 0; i < item.length; i++) {
            copies[i] = ReceivedItemLib.copy(item[i]);
        }
        return copies;
    }

    /**
     * @notice gets the storage position of the default ReceivedItem map
     */
    function _receivedItemMap()
        private
        pure
        returns (mapping(string => ReceivedItem) storage receivedItemMap)
    {
        bytes32 position = RECEIVED_ITEM_MAP_POSITION;
        assembly {
            receivedItemMap.slot := position
        }
    }

    /**
     * @notice gets the storage position of the default ReceivedItem map
     */
    function _receivedItemsMap()
        private
        pure
        returns (mapping(string => ReceivedItem[]) storage receivedItemsMap)
    {
        bytes32 position = RECEIVED_ITEMS_MAP_POSITION;
        assembly {
            receivedItemsMap.slot := position
        }
    }

    // methods for configuring a single of each of an ReceivedItem's fields, which modifies the ReceivedItem
    // in-place and
    // returns it

    /**
     * @notice sets the item type
     * @param item the ReceivedItem to modify
     * @param itemType the item type to set
     * @return the modified ReceivedItem
     */
    function withItemType(
        ReceivedItem memory item,
        ItemType itemType
    ) internal pure returns (ReceivedItem memory) {
        item.itemType = itemType;
        return item;
    }

    /**
     * @notice sets the token address
     * @param item the ReceivedItem to modify
     * @param token the token address to set
     * @return the modified ReceivedItem
     */
    function withToken(
        ReceivedItem memory item,
        address token
    ) internal pure returns (ReceivedItem memory) {
        item.token = token;
        return item;
    }

    /**
     * @notice sets the identifier or criteria
     * @param item the ReceivedItem to modify
     * @param identifier the identifier or criteria to set
     * @return the modified ReceivedItem
     */
    function withIdentifier(
        ReceivedItem memory item,
        uint256 identifier
    ) internal pure returns (ReceivedItem memory) {
        item.identifier = identifier;
        return item;
    }

    /**
     * @notice sets the start amount
     * @param item the ReceivedItem to modify
     * @param amount the start amount to set
     * @return the modified ReceivedItem
     */
    function withAmount(
        ReceivedItem memory item,
        uint256 amount
    ) internal pure returns (ReceivedItem memory) {
        item.amount = amount;
        return item;
    }

    /**
     * @notice sets the recipient
     * @param item the ReceivedItem to modify
     * @param recipient the recipient to set
     * @return the modified ReceivedItem
     */
    function withRecipient(
        ReceivedItem memory item,
        address recipient
    ) internal pure returns (ReceivedItem memory) {
        item.recipient = payable(recipient);
        return item;
    }

    function toConsiderationItem(
        ReceivedItem memory item
    ) internal pure returns (ConsiderationItem memory) {
        return
            ConsiderationItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifier,
                startAmount: item.amount,
                endAmount: item.amount,
                recipient: item.recipient
            });
    }
}
