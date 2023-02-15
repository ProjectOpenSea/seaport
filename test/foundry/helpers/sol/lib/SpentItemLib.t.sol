// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    SpentItemLib
} from "../../../../../contracts/helpers/sol/lib/SpentItemLib.sol";
import {
    SpentItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract SpentItemLibTest is BaseTest {
    using SpentItemLib for SpentItem;

    function testRetrieveDefault(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 amount
    ) public {
        itemType = uint8(bound(itemType, 0, 5));
        SpentItem memory spentItem = SpentItem(
            ItemType(itemType),
            token,
            identifier,
            amount
        );
        SpentItemLib.saveDefault(spentItem, "default");
        SpentItem memory defaultSpentItem = SpentItemLib.fromDefault("default");
        assertEq(spentItem, defaultSpentItem);
    }

    function testComposeEmpty(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 amount
    ) public {
        itemType = uint8(bound(itemType, 0, 5));
        SpentItem memory spentItem = SpentItemLib
            .empty()
            .withItemType(ItemType(itemType))
            .withToken(token)
            .withIdentifier(identifier)
            .withAmount(amount);
        assertEq(
            spentItem,
            SpentItem({
                itemType: ItemType(itemType),
                token: token,
                identifier: identifier,
                amount: amount
            })
        );
    }

    function testCopy() public {
        SpentItem memory spentItem = SpentItem(ItemType(1), address(1), 1, 1);
        SpentItem memory copy = spentItem.copy();
        assertEq(spentItem, copy);
        spentItem.itemType = ItemType(2);
        assertEq(uint8(copy.itemType), 1);
    }

    function testRetrieveDefaultMany(
        uint8[3] memory itemType,
        address[3] memory token,
        uint256[3] memory identifier,
        uint256[3] memory amount
    ) public {
        SpentItem[] memory spentItems = new SpentItem[](3);
        for (uint256 i = 0; i < 3; i++) {
            itemType[i] = uint8(bound(itemType[i], 0, 5));
            spentItems[i] = SpentItem(
                ItemType(itemType[i]),
                token[i],
                identifier[i],
                amount[i]
            );
        }
        SpentItemLib.saveDefaultMany(spentItems, "default");
        SpentItem[] memory defaultSpentItems = SpentItemLib.fromDefaultMany(
            "default"
        );
        for (uint256 i = 0; i < 3; i++) {
            assertEq(spentItems[i], defaultSpentItems[i]);
        }
    }
}
