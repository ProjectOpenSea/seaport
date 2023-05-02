// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    OrderLib
} from "../../../../../contracts/helpers/sol/lib/OrderLib.sol";
import {
    Order,
    OrderParameters
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

contract OrderLibTest is BaseTest {
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;

    function testRetrieveDefault(OrderBlob memory orderBlob) public {
        Order memory order = _fromBlob(orderBlob);
        Order memory dup = Order({
            parameters: _fromBlob(orderBlob.parameters),
            signature: orderBlob.signature
        });
        assertEq(order, dup);
        OrderLib.saveDefault(order, "default");
        Order memory defaultOrder = OrderLib.fromDefault("default");
        assertEq(order, defaultOrder);
    }

    function testRetrieveNonexistentDefault() public {
        vm.expectRevert("Empty Order selected.");
        OrderLib.fromDefault("nonexistent");

        vm.expectRevert("Empty Order array selected.");
        OrderLib.fromDefaultMany("nonexistent");
    }

    function testCopy() public {
        OrderParameters memory parameters = OrderParametersLib
            .empty()
            .withOfferer(address(123));
        Order memory order = Order({
            parameters: parameters,
            signature: "abc"
        });
        Order memory copy = order.copy();
        assertEq(order, copy);
        order.signature = "abcd";
        assertEq(copy.signature, "abc");
        order.parameters.offerer = address(5678);
        assertEq(copy.parameters.offerer, address(123));
    }

    function testRetrieveDefaultMany(OrderBlob[3] memory blob) public {
        Order[] memory orders = new Order[](3);
        for (uint256 i = 0; i < 3; i++) {
            orders[i] = _fromBlob(blob[i]);
        }
        OrderLib.saveDefaultMany(orders, "default");
        Order[] memory defaultOrders = OrderLib.fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(orders[i], defaultOrders[i]);
        }
    }
}
