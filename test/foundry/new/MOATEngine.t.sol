// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import {
    TestContext,
    FuzzParams,
    MOATEngine,
    MOATEngineLib
} from "./helpers/MOATEngine.sol";
import { MOATOrder, MOATHelpers } from "./helpers/MOATHelpers.sol";

contract MOATEngineTest is MOATEngine {
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
    using MOATEngineLib for TestContext;

    error ExampleErrorWithContextData(bytes signature);

    function setUp() public virtual override {
        super.setUp();

        OrderParameters memory standardOrderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters();
        OrderLib.empty().withParameters(standardOrderParameters).saveDefault(
            STANDARD
        );
    }

    /// @dev Get all actions for a single, standard order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get one action for a single, standard order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.fulfillOrder.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 1 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    /// @dev Get all actions for a single, advanced order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get one action for a single, advanced order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    /// @dev Get all actions for a combined order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get a single action for a combined order.
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
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.fulfillAvailableOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 1 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(
            context.action(),
            seaport.fulfillAvailableAdvancedOrders.selector
        );

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 2 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.matchOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 3 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.matchAdvancedOrders.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 4 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.cancel.selector);

        context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 5 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });
        assertEq(context.action(), seaport.validate.selector);
    }

    /// @dev Call exec for a single standard order.
    function test_exec_StandardOrder() public {
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

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });

        exec(context);
    }

    /// @dev Call exec for a single advanced order.
    function test_exec_AdvancedOrder() public {
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

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 1,
                denominator: 1,
                extraData: bytes("extra data")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0xbeef)
        });

        exec(context);
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.validate.
    function test_exec_Combined_Validate() public {
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

        MOATOrder[] memory orders = new MOATOrder[](2);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();
        orders[1] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 5 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });

        exec(context);
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.cancel.
    function test_exec_Combined_Cancel() public {
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

        MOATOrder[] memory orders = new MOATOrder[](2);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();
        orders[1] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: offerer1.addr,
            fuzzParams: FuzzParams({ seed: 4 }),
            checks: new bytes4[](0),
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });

        exec(context);
    }

    /// @dev Call checkAll to run a simple check that always reverts.
    function test_check_StandardOrder_SimpleCheck() public {
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

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_alwaysRevert.selector;

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: checks,
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });

        exec(context);

        vm.expectRevert("this check always reverts");
        checkAll(context);
    }

    /// @dev Call checkAll to run a check that uses the TestContext.
    function test_check_StandardOrder_checkWithContext() public {
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

        MOATOrder[] memory orders = new MOATOrder[](1);
        orders[0] = order
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            })
            .toMOATOrder();

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_revertWithContextData.selector;

        TestContext memory context = TestContext({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 }),
            checks: checks,
            counter: 0,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: new CriteriaResolver[](0),
            recipient: address(0)
        });

        exec(context);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleErrorWithContextData.selector,
                context.orders[0].order.signature
            )
        );
        checkAll(context);
    }

    /// @dev Example of a simple "check" function. This one takes no args.
    function check_alwaysRevert() public {
        revert("this check always reverts");
    }

    /// @dev Example of a check" function that uses the test context.
    function check_revertWithContextData(TestContext memory context) public {
        revert ExampleErrorWithContextData(context.orders[0].order.signature);
    }

    function assertEq(bytes4[] memory a, bytes4[] memory b) internal {
        if (a.length != b.length) revert("Array length mismatch");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i]);
        }
    }
}
