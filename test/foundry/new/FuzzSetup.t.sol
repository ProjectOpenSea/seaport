// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    FulfillmentComponentLib,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import { OrderComponentsSpace } from "seaport-sol/src/StructSpace.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    OrderStatusEnum,
    UnavailableReason
} from "seaport-sol/src/SpaceEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

import {
    FuzzParams,
    FuzzTestContext,
    FuzzTestContextLib
} from "./helpers/FuzzTestContextLib.sol";

import { FuzzEngineLib } from "./helpers/FuzzEngineLib.sol";

import { FuzzSetup } from "./helpers/FuzzSetup.sol";

import { FuzzDerivers } from "./helpers/FuzzDerivers.sol";

contract FuzzSetupTest is BaseOrderTest, FuzzSetup {
    using AdvancedOrderLib for AdvancedOrder;
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using FulfillmentLib for Fulfillment;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzTestContextLib for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzDerivers for FuzzTestContext;

    Account charlie = makeAccountWrapper("charlie");

    function test_setUpOfferItems_erc20() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 0);

        OfferItem[] memory offerItems = new OfferItem[](2);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(100);

        offerItems[1] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(100);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 200);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 200);
    }

    function test_setUpOfferItems_erc20_ascending() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 0);

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withStartAmount(500)
            .withEndAmount(1000);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1000);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        vm.warp(block.timestamp + 500);

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 750);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 750);
    }

    function test_setUpOfferItems_erc20_descending() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 0);

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withStartAmount(1000)
            .withEndAmount(500);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1000);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        vm.warp(block.timestamp + 500);

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 750);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 750);
    }

    function test_setUpOfferItems_erc721() public {
        assertEq(erc721s[0].balanceOf(charlie.addr), 0);
        assertEq(erc721s[1].balanceOf(charlie.addr), 0);
        assertFalse(
            erc721s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
        assertFalse(
            erc721s[1].isApprovedForAll(charlie.addr, address(getSeaport()))
        );

        OfferItem[] memory offerItems = new OfferItem[](2);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);

        offerItems[1] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[1]))
            .withIdentifierOrCriteria(2)
            .withAmount(1);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc721s[0].balanceOf(charlie.addr), 1);
        assertEq(erc721s[1].balanceOf(charlie.addr), 1);
        assertTrue(
            erc721s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
        assertTrue(
            erc721s[1].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
    }

    function test_setUpOfferItems_erc1155() public {
        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 0);
        assertFalse(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );

        OfferItem[] memory offerItems = new OfferItem[](2);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(100);

        offerItems[1] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(100);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 200);
        assertTrue(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
    }

    function test_setUpOfferItems_erc1155_ascending() public {
        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 0);
        assertFalse(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withStartAmount(500)
            .withStartAmount(1000);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1000);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        vm.warp(block.timestamp + 500);

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpOfferItems(context);

        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 500);
        assertTrue(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
    }

    function test_setUpConsiderationItems_erc20() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 0);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            2
        );
        considerationItems[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(100);

        considerationItems[1] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(100);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withConsideration(considerationItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpConsiderationItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 200);
        assertEq(erc20s[0].allowance(charlie.addr, address(getSeaport())), 200);
    }

    function test_setUpConsiderationItems_erc721() public {
        assertEq(erc721s[0].balanceOf(charlie.addr), 0);
        assertEq(
            erc721s[0].isApprovedForAll(charlie.addr, address(getSeaport())),
            false
        );

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            2
        );
        considerationItems[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);

        considerationItems[1] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(2)
            .withAmount(1);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withConsideration(considerationItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpConsiderationItems(context);

        assertEq(erc721s[0].balanceOf(charlie.addr), 2);
        assertEq(
            erc721s[0].isApprovedForAll(charlie.addr, address(getSeaport())),
            true
        );
    }

    function test_setUpConsiderationItems_erc1155() public {
        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 0);
        assertFalse(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            2
        );
        considerationItems[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(100);

        considerationItems[1] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(100);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withConsideration(considerationItems)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: getSeaport(),
            caller: charlie.addr
        });

        // Provision arrays to avoid index errors.
        context.advancedOrdersSpace.orders = new OrderComponentsSpace[](1);
        context.executionState.preExecOrderStatuses = new OrderStatusEnum[](1);

        context = context.withDerivedOrderDetails();

        // Do some surgery on the context so that the setup function thinks
        // that the order is available and worth providing balance and approvals
        // for.
        context
            .executionState
            .orderDetails[0]
            .unavailableReason = UnavailableReason.AVAILABLE;

        setUpConsiderationItems(context);

        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 200);
        assertTrue(
            erc1155s[0].isApprovedForAll(charlie.addr, address(getSeaport()))
        );
    }
}
