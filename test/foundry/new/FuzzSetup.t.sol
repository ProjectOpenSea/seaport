// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";

import {
    TestContext,
    TestContextLib,
    FuzzParams
} from "./helpers/TestContextLib.sol";
import { FuzzSetup } from "./helpers/FuzzSetup.sol";

contract FuzzSetupTest is BaseOrderTest, FuzzSetup {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using AdvancedOrderLib for AdvancedOrder;
    using FulfillmentLib for Fulfillment;
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];

    using TestContextLib for TestContext;
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    Account charlie = makeAccount("charlie");

    function test_setUpOfferItems_erc20() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 0);

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
            .withOffer(offerItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpOfferItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 200);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 200);
    }

    function xtest_setUpOfferItems_erc20_ascending() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 0);

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withStartAmount(100)
            .withEndAmount(200);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });

        vm.warp(block.timestamp);
        setUpOfferItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 200);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 200);
    }

    function test_setUpOfferItems_erc721() public {
        assertEq(erc721s[0].balanceOf(charlie.addr), 0);
        assertEq(erc721s[0].getApproved(1), address(0));
        assertEq(erc721s[0].getApproved(2), address(0));

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
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(2)
            .withAmount(1);

        OrderParameters memory orderParams = OrderParametersLib
            .empty()
            .withOfferer(charlie.addr)
            .withOffer(offerItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpOfferItems(context);

        assertEq(erc721s[0].balanceOf(charlie.addr), 2);
        assertEq(erc721s[0].getApproved(1), address(seaport));
        assertEq(erc721s[0].getApproved(2), address(seaport));
    }

    function test_setUpOfferItems_erc1155() public {
        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 0);
        assertFalse(
            erc1155s[0].isApprovedForAll(charlie.addr, address(seaport))
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
            .withOffer(offerItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpOfferItems(context);

        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 200);
        assertTrue(
            erc1155s[0].isApprovedForAll(charlie.addr, address(seaport))
        );
    }

    function test_setUpConsiderationItems_erc20() public {
        assertEq(erc20s[0].balanceOf(charlie.addr), 0);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 0);

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
            .withConsideration(considerationItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: charlie.addr,
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpConsiderationItems(context);

        assertEq(erc20s[0].balanceOf(charlie.addr), 200);
        assertEq(erc20s[0].allowance(charlie.addr, address(seaport)), 200);
    }

    function test_setUpConsiderationItems_erc721() public {
        assertEq(erc721s[0].balanceOf(charlie.addr), 0);
        assertEq(erc721s[0].getApproved(1), address(0));
        assertEq(erc721s[0].getApproved(2), address(0));

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
            .withConsideration(considerationItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: charlie.addr,
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpConsiderationItems(context);

        assertEq(erc721s[0].balanceOf(charlie.addr), 2);
        assertEq(erc721s[0].getApproved(1), address(seaport));
        assertEq(erc721s[0].getApproved(2), address(seaport));
    }

    function test_setUpConsiderationItems_erc1155() public {
        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 0);
        assertFalse(
            erc1155s[0].isApprovedForAll(charlie.addr, address(seaport))
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
            .withConsideration(considerationItems);
        Order memory order = OrderLib.empty().withParameters(orderParams);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: charlie.addr,
            fuzzParams: FuzzParams({ seed: 0 })
        });

        setUpConsiderationItems(context);

        assertEq(erc1155s[0].balanceOf(charlie.addr, 1), 200);
        assertTrue(
            erc1155s[0].isApprovedForAll(charlie.addr, address(seaport))
        );
    }
}
