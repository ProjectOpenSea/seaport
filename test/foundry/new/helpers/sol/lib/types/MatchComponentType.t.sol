// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    MatchComponent,
    MatchComponentType
} from "seaport-sol/src/lib/types/MatchComponentType.sol";

contract MatchComponentTypeTest is Test {
    using MatchComponentType for MatchComponent;

    function testCreateGetAndUnpack() public {
        MatchComponent memory component = MatchComponentType
            .createMatchComponent(1, 2, 3);
        assertEq(component.getAmount(), 1, "amount");
        assertEq(component.getOrderIndex(), 2, "orderIndex");
        assertEq(component.getItemIndex(), 3, "itemIndex");

        (uint256 amount, uint256 orderIndex, uint256 itemIndex) = component
            .unpack();
        assertEq(amount, 1, "unpacked amount");
        assertEq(orderIndex, 2, "unpacked orderIndex");
        assertEq(itemIndex, 3, "unpacked itemIndex");
    }

    function testCreateGetAndUnpack(
        uint240 amount,
        uint8 orderIndex,
        uint8 itemIndex
    ) public {
        MatchComponent memory component = MatchComponentType
            .createMatchComponent(amount, orderIndex, itemIndex);
        assertEq(component.getAmount(), amount, "amount");
        assertEq(component.getOrderIndex(), orderIndex, "orderIndex");
        assertEq(component.getItemIndex(), itemIndex, "itemIndex");

        (
            uint256 unpackedAmount,
            uint256 unpackedOrderIndex,
            uint256 unpackedItemIndex
        ) = component.unpack();
        assertEq(unpackedAmount, amount, "unpacked amount");
        assertEq(unpackedOrderIndex, orderIndex, "unpacked orderIndex");
        assertEq(unpackedItemIndex, itemIndex, "unpacked itemIndex");
    }

    function testSetters() public {
        MatchComponent memory component = MatchComponentType
            .createMatchComponent(1, 2, 3);

        MatchComponent memory newComponent = component.setAmount(4);
        assertEq(newComponent.getAmount(), 4, "amount");
        assertEq(newComponent.getOrderIndex(), 2, "orderIndex");
        assertEq(newComponent.getItemIndex(), 3, "itemIndex");

        newComponent = component.setOrderIndex(5);
        assertEq(newComponent.getAmount(), 1, "amount");
        assertEq(newComponent.getOrderIndex(), 5, "orderIndex");
        assertEq(newComponent.getItemIndex(), 3, "itemIndex");

        newComponent = component.setItemIndex(6);
        assertEq(newComponent.getAmount(), 1, "amount");
        assertEq(newComponent.getOrderIndex(), 2, "orderIndex");
        assertEq(newComponent.getItemIndex(), 6, "itemIndex");
    }

    function testSetters(
        uint240 amount,
        uint8 orderIndex,
        uint8 itemIndex
    ) public {
        MatchComponent memory component = MatchComponentType
            .createMatchComponent(1, 2, 3);

        MatchComponent memory newComponent = component.setAmount(amount);
        assertEq(newComponent.getAmount(), amount, "amount");
        assertEq(newComponent.getOrderIndex(), 2, "orderIndex");
        assertEq(newComponent.getItemIndex(), 3, "itemIndex");

        newComponent = component.setOrderIndex(orderIndex);
        assertEq(newComponent.getAmount(), 1, "amount");
        assertEq(newComponent.getOrderIndex(), orderIndex, "orderIndex");
        assertEq(newComponent.getItemIndex(), 3, "itemIndex");

        newComponent = component.setItemIndex(itemIndex);
        assertEq(newComponent.getAmount(), 1, "amount");
        assertEq(newComponent.getOrderIndex(), 2, "orderIndex");
        assertEq(newComponent.getItemIndex(), itemIndex, "itemIndex");
    }
}
