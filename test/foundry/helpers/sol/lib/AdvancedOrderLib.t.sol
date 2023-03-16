// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    AdvancedOrderLib
} from "../../../../../contracts/helpers/sol/lib/AdvancedOrderLib.sol";
import {
    AdvancedOrder,
    OrderParameters
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

contract AdvancedOrderLibTest is BaseTest {
    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;

    function testRetrieveDefault(
        uint120 numerator,
        uint120 denominator,
        bytes memory signature,
        bytes memory extraData
    ) public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOfferer(address(1234));
        AdvancedOrder memory advancedOrder = AdvancedOrder({
            parameters: orderParameters,
            numerator: numerator,
            denominator: denominator,
            signature: signature,
            extraData: extraData
        });
        AdvancedOrderLib.saveDefault(advancedOrder, "default");
        AdvancedOrder memory defaultAdvancedOrder = AdvancedOrderLib
            .fromDefault("default");
        assertEq(advancedOrder, defaultAdvancedOrder);
    }

    function testRetrieveNonexistentDefault() public {
        vm.expectRevert("Empty AdvancedOrder selected.");
        AdvancedOrderLib.fromDefault("nonexistent");

        vm.expectRevert("Empty AdvancedOrder array selected.");
        AdvancedOrderLib.fromDefaultMany("nonexistent");
    }

    function testComposeEmpty(
        uint120 numerator,
        uint120 denominator,
        bytes memory signature,
        bytes memory extraData
    ) public {
        AdvancedOrder memory advancedOrder = AdvancedOrderLib
            .empty()
            .withParameters(OrderParametersLib.empty())
            .withNumerator(numerator)
            .withDenominator(denominator)
            .withSignature(signature)
            .withExtraData(extraData);
        assertEq(
            advancedOrder,
            AdvancedOrder({
                parameters: OrderParametersLib.empty(),
                numerator: numerator,
                denominator: denominator,
                signature: signature,
                extraData: extraData
            })
        );
    }

    function testCopy() public {
        AdvancedOrder memory advancedOrder = AdvancedOrder({
            parameters: OrderParametersLib.empty(),
            numerator: 1,
            denominator: 1,
            signature: "signature",
            extraData: "extraData"
        });
        AdvancedOrder memory copy = advancedOrder.copy();
        assertEq(advancedOrder, copy);
        advancedOrder.numerator = 2;
        assertEq(copy.numerator, 1);

        advancedOrder.parameters = OrderParametersLib.empty().withOfferer(
            address(1234)
        );
        assertEq(copy.parameters.offerer, address(0));
    }

    function testRetrieveDefaultMany(
        uint120[3] memory numerator,
        uint120[3] memory denominator,
        bytes[3] memory signature,
        bytes[3] memory extraData
    ) public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](3);
        for (uint256 i = 0; i < 3; i++) {
            advancedOrders[i] = AdvancedOrder({
                parameters: OrderParametersLib.empty().withOfferer(
                    address(1234)
                ),
                numerator: numerator[i],
                denominator: denominator[i],
                signature: signature[i],
                extraData: extraData[i]
            });
        }
        AdvancedOrderLib.saveDefaultMany(advancedOrders, "default");
        AdvancedOrder[] memory defaultAdvancedOrders = AdvancedOrderLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(advancedOrders[i], defaultAdvancedOrders[i]);
        }
    }

    function assertEq(AdvancedOrder memory a, AdvancedOrder memory b) internal {
        assertEq(a.parameters, b.parameters);
        assertEq(a.numerator, b.numerator, "numerator");
        assertEq(a.denominator, b.denominator, "denominator");
        assertEq(a.signature, b.signature, "signature");
        assertEq(a.extraData, b.extraData, "extraData");
    }
}
