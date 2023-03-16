// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import { TestContext, FuzzParams, MOATEngine } from "./helpers/MOATEngine.sol";
import {
    MOATOrder,
    MOATHelpers,
    MOATOrderContext
} from "./helpers/MOATHelpers.sol";

contract MOATHelpersTest is BaseOrderTest {
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

    using MOATHelpers for AdvancedOrder;
    using MOATEngine for TestContext;

    function setUp() public virtual override {
        super.setUp();

        OrderParameters memory standardOrderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters();
        OrderLib.empty().withParameters(standardOrderParameters).saveDefault(
            STANDARD
        );
    }

    function test_Single_Standard_Actions() public {
        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        bytes4[] memory expectedActions = new bytes4[](2);
        expectedActions[0] = seaport.fulfillOrder.selector;
        expectedActions[1] = seaport.fulfillAdvancedOrder.selector;

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    function test_Single_Standard_Action() public {
        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.action(), seaport.fulfillOrder.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 1 })
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    function test_Single_Advanced_Actions() public {
        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();

        bytes4[] memory expectedActions = new bytes4[](1);
        expectedActions[0] = seaport.fulfillAdvancedOrder.selector;

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    function test_Single_Advanced_Action() public {
        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    function test_Combined_Actions() public {
        MOATOrder[] memory orders = new MOATOrder[](2);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();
        orders[1] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();

        bytes4[] memory expectedActions = new bytes4[](6);
        expectedActions[0] = seaport.fulfillAvailableOrders.selector;
        expectedActions[1] = seaport.fulfillAvailableAdvancedOrders.selector;
        expectedActions[2] = seaport.matchOrders.selector;
        expectedActions[3] = seaport.matchAdvancedOrders.selector;
        expectedActions[4] = seaport.cancel.selector;
        expectedActions[5] = seaport.validate.selector;

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    function test_Combined_Action() public {
        MOATOrder[] memory orders = new MOATOrder[](2);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();
        orders[1] = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("extra data")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.action(), seaport.fulfillAvailableOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 1 })
        });
        assertEq(
            context.action(),
            seaport.fulfillAvailableAdvancedOrders.selector
        );

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 2 })
        });
        assertEq(context.action(), seaport.matchOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 3 })
        });
        assertEq(context.action(), seaport.matchAdvancedOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 4 })
        });
        assertEq(context.action(), seaport.cancel.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 5 })
        });
        assertEq(context.action(), seaport.validate.selector);
    }

    function test_execute_StandardOrder() public {
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr);

        bytes memory signature = signOrder(
            seaport,
            offerer1.key,
            seaport.getOrderHash(orderComponents)
        );

        Order memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents.toOrderParameters())
            .withSignature(signature);

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        MOATOrderContext memory moatOrderContext = MOATOrderContext({
            signature: signature,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: criteriaResolvers,
            recipient: address(0)
        });

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder(moatOrderContext);

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });

        // Perform any registered setup actions
        //context.setUp()

        // Get an action
        context.exec();
    }

    function test_execute_AdvancedOrder() public {
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr);

        bytes memory signature = signOrder(
            seaport,
            offerer1.key,
            seaport.getOrderHash(orderComponents)
        );

        Order memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents.toOrderParameters())
            .withSignature(signature);

        MOATOrderContext memory moatOrderContext = MOATOrderContext({
            signature: signature,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0xbeef)
        });

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 1,
                denominator: 1,
                extraData: bytes("extra data")
            })
            .toMOATOrder(moatOrderContext);

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            fuzzParams: FuzzParams({ seed: 0 })
        });

        // Perform any registered setup actions
        //context.setUp()

        // Get an action
        context.exec();
    }

    function assertEq(bytes4[] memory a, bytes4[] memory b) internal {
        if (a.length != b.length) revert("Array length mismatch");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i]);
        }
    }
}
