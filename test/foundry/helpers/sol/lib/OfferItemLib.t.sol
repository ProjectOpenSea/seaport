// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    OfferItemLib
} from "../../../../../contracts/helpers/sol/lib/OfferItemLib.sol";
import {
    OfferItem
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract OfferItemLibTest is BaseTest {
    using OfferItemLib for OfferItem;

    function testRetrieveDefault(
        uint8 _itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) public {
        ItemType itemType = toItemType(_itemType);
        OfferItem memory offerItem = OfferItem({
            itemType: ItemType(itemType),
            token: token,
            identifierOrCriteria: identifier,
            startAmount: startAmount,
            endAmount: endAmount
        });
        OfferItemLib.saveDefault(offerItem, "default");
        OfferItem memory defaultOfferItem = OfferItemLib.fromDefault("default");
        assertEq(offerItem, defaultOfferItem);
    }

    function testComposeEmpty(
        uint8 itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) public {
        ItemType _itemType = ItemType(bound(itemType, 0, 5));
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withEndAmount(endAmount)
            .withStartAmount(startAmount)
            .withIdentifierOrCriteria(identifier)
            .withToken(token)
            .withItemType(_itemType);
        assertEq(
            offerItem,
            OfferItem({
                itemType: _itemType,
                token: token,
                identifierOrCriteria: identifier,
                startAmount: startAmount,
                endAmount: endAmount
            })
        );
    }

    function testCopy() public {
        OfferItem memory offerItem = OfferItem({
            itemType: ItemType(1),
            token: address(1),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1
        });
        OfferItem memory copy = offerItem.copy();
        assertEq(offerItem, copy);
        offerItem.itemType = ItemType(2);
        assertEq(uint8(copy.itemType), 1);
    }

    function testRetrieveDefaultMany(
        uint8[3] memory itemType,
        address[3] memory token,
        uint256[3] memory identifier,
        uint256[3] memory startAmount,
        uint256[3] memory endAmount
    ) public {
        OfferItem[] memory offerItems = new OfferItem[](3);
        for (uint256 i = 0; i < 3; i++) {
            itemType[i] = uint8(bound(itemType[i], 0, 5));
            offerItems[i] = OfferItem({
                itemType: ItemType(itemType[i]),
                token: token[i],
                identifierOrCriteria: identifier[i],
                startAmount: startAmount[i],
                endAmount: endAmount[i]
            });
        }
        OfferItemLib.saveDefaultMany(offerItems, "default");
        OfferItem[] memory defaultOfferItems = OfferItemLib.fromDefaultMany(
            "default"
        );
        for (uint256 i = 0; i < 3; i++) {
            assertEq(offerItems[i], defaultOfferItems[i]);
        }
    }
}
