// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    ReceivedItemLib
} from "../../../../../contracts/helpers/sol/lib/ReceivedItemLib.sol";
import {
    ReceivedItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract ReceivedItemLibTest is BaseTest {
    using ReceivedItemLib for ReceivedItem;

    function testRetrieveDefault(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 amount,
        address payable recipient
    ) public {
        itemType = uint8(bound(itemType, 0, 5));
        ReceivedItem memory receivedItem = ReceivedItem(
            ItemType(itemType),
            token,
            identifier,
            amount,
            recipient
        );
        ReceivedItemLib.saveDefault(receivedItem, "default");
        ReceivedItem memory defaultReceivedItem = ReceivedItemLib.fromDefault(
            "default"
        );
        assertEq(receivedItem, defaultReceivedItem);
    }

    function testComposeEmpty(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 amount,
        address payable recipient
    ) public {
        itemType = uint8(bound(itemType, 0, 5));
        ReceivedItem memory receivedItem = ReceivedItemLib
            .empty()
            .withItemType(ItemType(itemType))
            .withToken(token)
            .withIdentifier(identifier)
            .withAmount(amount)
            .withRecipient(recipient);
        assertEq(
            receivedItem,
            ReceivedItem({
                itemType: ItemType(itemType),
                token: token,
                identifier: identifier,
                amount: amount,
                recipient: recipient
            })
        );
    }

    function testCopy() public {
        ReceivedItem memory receivedItem = ReceivedItem(
            ItemType(1),
            address(1),
            1,
            1,
            payable(address(1234))
        );
        ReceivedItem memory copy = receivedItem.copy();
        assertEq(receivedItem, copy);
        receivedItem.itemType = ItemType(2);
        assertEq(uint8(copy.itemType), 1);
    }

    function testRetrieveDefaultMany(
        uint8[3] memory itemType,
        address[3] memory token,
        uint256[3] memory identifier,
        uint256[3] memory amount,
        address payable[3] memory recipient
    ) public {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](3);
        for (uint256 i = 0; i < 3; i++) {
            itemType[i] = uint8(bound(itemType[i], 0, 5));
            receivedItems[i] = ReceivedItem(
                ItemType(itemType[i]),
                token[i],
                identifier[i],
                amount[i],
                recipient[i]
            );
        }
        ReceivedItemLib.saveDefaultMany(receivedItems, "default");
        ReceivedItem[] memory defaultReceivedItems = ReceivedItemLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(receivedItems[i], defaultReceivedItems[i]);
        }
    }
}
