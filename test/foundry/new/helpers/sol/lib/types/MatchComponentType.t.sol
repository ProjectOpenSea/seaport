// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    MatchComponent,
    MatchComponentType
} from "seaport-core/helpers/sol/lib/types/MatchComponentType.sol";

contract MatchComponentTypeTest is Test {
    function testCreateGetAndUnpack() public {
        MatchComponent component =
            MatchComponentType.createMatchComponent(1, 2, 3);
        assertEq(component.getAmount(), 1, "amount");
        assertEq(component.getOrderIndex(), 2, "orderIndex");
        assertEq(component.getItemIndex(), 3, "itemIndex");

        (uint256 amount, uint256 orderIndex, uint256 itemIndex) =
            component.unpack();
        assertEq(amount, 1, "unpacked amount");
        assertEq(orderIndex, 2, "unpacked orderIndex");
        assertEq(itemIndex, 3, "unpacked itemIndex");
    }

    function testCreateGetAndUnpack(
        uint240 amount,
        uint8 orderIndex,
        uint8 itemIndex
    ) public {
        MatchComponent component = MatchComponentType.createMatchComponent(
            amount, orderIndex, itemIndex
        );
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
        MatchComponent component =
            MatchComponentType.createMatchComponent(1, 2, 3);

        MatchComponent newComponent = component.setAmount(4);
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

    function testSetters(uint240 amount, uint8 orderIndex, uint8 itemIndex)
        public
    {
        MatchComponent component =
            MatchComponentType.createMatchComponent(1, 2, 3);

        MatchComponent newComponent = component.setAmount(amount);
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

    function testToFromUints() public {
        MatchComponent component =
            MatchComponentType.createMatchComponent(1, 2, 3);
        MatchComponent[] memory components = new MatchComponent[](1);
        components[0] = component;
        uint256[] memory uints = MatchComponentType.toUints(components);
        assertEq(uints.length, 1, "length");
        assertEq(uints[0], 1 << 16 | 2 << 8 | 3, "uints[0]");
        MatchComponent[] memory newComponents =
            MatchComponentType.fromUints(uints);
        assertEq(newComponents.length, 1, "length");
        assertEq(newComponents[0].getAmount(), 1, "amount");
        assertEq(newComponents[0].getOrderIndex(), 2, "orderIndex");
        assertEq(newComponents[0].getItemIndex(), 3, "itemIndex");
    }
}
