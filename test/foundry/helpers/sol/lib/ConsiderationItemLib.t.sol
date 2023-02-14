// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    ConsiderationItemLib
} from "../../../../../contracts/helpers/sol/lib/ConsiderationItemLib.sol";
import {
    ConsiderationItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract ConsiderationItemLibTest is BaseTest {
    using ConsiderationItemLib for ConsiderationItem;

    function testRetrieveDefault(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount,
        address payable recipient
    ) public {
        itemType = uint8(bound(itemType, 0, 5));
        ConsiderationItem memory considerationItem = ConsiderationItem({
            itemType: ItemType(itemType),
            token: token,
            identifierOrCriteria: identifier,
            startAmount: startAmount,
            endAmount: endAmount,
            recipient: recipient
        });
        ConsiderationItemLib.saveDefault(considerationItem, "default");
        ConsiderationItem memory defaultConsiderationItem = ConsiderationItemLib
            .fromDefault("default");
        assertEq(considerationItem, defaultConsiderationItem);
    }

    function testComposeEmpty(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount,
        address payable recipient
    ) public {
        ItemType _itemType = ItemType(bound(itemType, 0, 5));
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withRecipient(recipient)
            .withEndAmount(endAmount)
            .withStartAmount(startAmount)
            .withIdentifierOrCriteria(identifier)
            .withToken(token)
            .withItemType(_itemType);
        assertEq(
            considerationItem,
            ConsiderationItem({
                itemType: _itemType,
                token: token,
                identifierOrCriteria: identifier,
                startAmount: startAmount,
                endAmount: endAmount,
                recipient: recipient
            })
        );
    }

    function testCopy() public {
        ConsiderationItem memory considerationItem = ConsiderationItem({
            itemType: ItemType(1),
            token: address(1),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(1234))
        });
        ConsiderationItem memory copy = considerationItem.copy();
        assertEq(considerationItem, copy);
        considerationItem.itemType = ItemType(2);
        assertEq(uint8(copy.itemType), 1);
    }

    function testRetrieveDefaultMany(
        uint8[3] memory itemType,
        address[3] memory token,
        uint256[3] memory identifier,
        uint256[3] memory startAmount,
        uint256[3] memory endAmount,
        address payable[3] memory recipient
    ) public {
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        for (uint256 i = 0; i < 3; i++) {
            itemType[i] = uint8(bound(itemType[i], 0, 5));
            considerationItems[i] = ConsiderationItem({
                itemType: ItemType(itemType[i]),
                token: token[i],
                identifierOrCriteria: identifier[i],
                startAmount: startAmount[i],
                endAmount: endAmount[i],
                recipient: recipient[i]
            });
        }
        ConsiderationItemLib.saveDefaultMany(considerationItems, "default");
        ConsiderationItem[]
            memory defaultConsiderationItems = ConsiderationItemLib
                .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(considerationItems[i], defaultConsiderationItems[i]);
        }
    }
}
