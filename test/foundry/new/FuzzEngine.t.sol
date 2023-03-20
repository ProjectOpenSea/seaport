// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import {
    TestContext,
    FuzzParams,
    FuzzEngine,
    FuzzEngineLib,
    TestContextLib
} from "./helpers/FuzzEngine.sol";
import { AdvancedOrder, FuzzHelpers } from "./helpers/FuzzHelpers.sol";

contract FuzzEngineTest is FuzzEngine, FulfillAvailableHelper {
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

    using FuzzHelpers for AdvancedOrder;
    using FuzzEngineLib for TestContext;
    using TestContextLib for TestContext;

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
    function test_actions_Single_Standard() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory expectedActions = new bytes4[](2);
        expectedActions[0] = seaport.fulfillOrder.selector;
        expectedActions[1] = seaport.fulfillAdvancedOrder.selector;

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get one action for a single, standard order.
    function test_action_Single_Standard() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
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
        assertEq(context.action(), seaport.fulfillOrder.selector);

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 1 })
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    /// @dev Get all actions for a single, advanced order.
    function test_actions_Single_Advanced() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });

        bytes4[] memory expectedActions = new bytes4[](1);
        expectedActions[0] = seaport.fulfillAdvancedOrder.selector;

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get one action for a single, advanced order.
    function test_action_Single_Advanced() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    /// @dev Get all actions for a combined order.
    function test_actions_Combined() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });
        orders[1] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });

        bytes4[] memory expectedActions = new bytes4[](6);
        expectedActions[0] = seaport.fulfillAvailableOrders.selector;
        expectedActions[1] = seaport.fulfillAvailableAdvancedOrders.selector;
        expectedActions[2] = seaport.matchOrders.selector;
        expectedActions[3] = seaport.matchAdvancedOrders.selector;
        expectedActions[4] = seaport.cancel.selector;
        expectedActions[5] = seaport.validate.selector;

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.actions(), expectedActions);
    }

    /// @dev Get a single action for a combined order.
    function test_action_Combined() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });
        orders[1] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("extra data")
        });

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 0 })
        });
        assertEq(context.action(), seaport.fulfillAvailableOrders.selector);

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 1 })
        });
        assertEq(
            context.action(),
            seaport.fulfillAvailableAdvancedOrders.selector
        );

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 2 })
        });
        assertEq(context.action(), seaport.matchOrders.selector);

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 3 })
        });
        assertEq(context.action(), seaport.matchAdvancedOrders.selector);

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 4 })
        });
        assertEq(context.action(), seaport.cancel.selector);

        context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 5 })
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

        exec(context);
        assertEq(context.returnValues.fulfilled, true);
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 1,
            denominator: 1,
            extraData: bytes("extra data")
        });

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 0 })
            })
            .withRecipient(address(0xbeef));

        exec(context);
        assertEq(context.returnValues.fulfilled, true);
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.fulfillAvailableOrders.
    function test_exec_Combined_FulfillAvailable() public {
        // Offer ERC20
        OfferItem[] memory offerItems = new OfferItem[](1);
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withStartAmount(1)
            .withEndAmount(1);
        offerItems[0] = offerItem;

        // Consider single ERC721 to offerer1
        erc721s[0].mint(address(this), 1);
        ConsiderationItem[]
            memory considerationItems1 = new ConsiderationItem[](1);
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withRecipient(offerer1.addr)
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);
        considerationItems1[0] = considerationItem;

        // Consider single ERC721 to offerer1
        erc721s[0].mint(address(this), 2);
        ConsiderationItem[]
            memory considerationItems2 = new ConsiderationItem[](1);
        considerationItem = ConsiderationItemLib
            .empty()
            .withRecipient(offerer1.addr)
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(2)
            .withAmount(1);
        considerationItems2[0] = considerationItem;

        OrderComponents memory orderComponents1 = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems1);

        OrderComponents memory orderComponents2 = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems2);

        bytes memory signature1 = signOrder(
            seaport,
            offerer1.key,
            seaport.getOrderHash(orderComponents1)
        );

        Order memory order1 = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents1.toOrderParameters())
            .withSignature(signature1);

        bytes memory signature2 = signOrder(
            seaport,
            offerer1.key,
            seaport.getOrderHash(orderComponents2)
        );

        Order memory order2 = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents2.toOrderParameters())
            .withSignature(signature2);

        Order[] memory orders = new Order[](2);
        orders[0] = order1;
        orders[1] = order2;

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = order1.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });
        advancedOrders[1] = order2.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        (
            FulfillmentComponent[][] memory offerComponents,
            FulfillmentComponent[][] memory considerationComponents
        ) = getNaiveFulfillmentComponents(orders);

        TestContext memory context = TestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 0 })
            })
            .withOfferFulfillments(offerComponents)
            .withConsiderationFulfillments(considerationComponents)
            .withMaximumFulfilled(2);

        exec(context);

        assertEq(context.returnValues.availableOrders.length, 2);
        assertEq(context.returnValues.availableOrders[0], true);
        assertEq(context.returnValues.availableOrders[1], true);

        assertEq(context.returnValues.executions.length, 4);
        assertEq(
            context.returnValues.executions[0].item.itemType,
            ItemType.ERC20
        );
        assertEq(
            context.returnValues.executions[0].item.token,
            address(erc20s[0])
        );
        assertEq(context.returnValues.executions[0].item.identifier, 0);
        assertEq(context.returnValues.executions[0].item.amount, 1);
        assertEq(
            context.returnValues.executions[0].item.recipient,
            address(this)
        );

        assertEq(
            context.returnValues.executions[1].item.itemType,
            ItemType.ERC20
        );
        assertEq(
            context.returnValues.executions[1].item.token,
            address(erc20s[0])
        );
        assertEq(context.returnValues.executions[1].item.identifier, 0);
        assertEq(context.returnValues.executions[1].item.amount, 1);
        assertEq(
            context.returnValues.executions[1].item.recipient,
            address(this)
        );

        assertEq(
            context.returnValues.executions[2].item.itemType,
            ItemType.ERC721
        );
        assertEq(
            context.returnValues.executions[2].item.token,
            address(erc721s[0])
        );
        assertEq(context.returnValues.executions[2].item.identifier, 1);
        assertEq(context.returnValues.executions[2].item.amount, 1);
        assertEq(
            context.returnValues.executions[2].item.recipient,
            offerer1.addr
        );

        assertEq(
            context.returnValues.executions[3].item.itemType,
            ItemType.ERC721
        );
        assertEq(
            context.returnValues.executions[3].item.token,
            address(erc721s[0])
        );
        assertEq(context.returnValues.executions[3].item.identifier, 2);
        assertEq(context.returnValues.executions[3].item.amount, 1);
        assertEq(
            context.returnValues.executions[3].item.recipient,
            offerer1.addr
        );

        assertEq(context.returnValues.executions[0].offerer, offerer1.addr);
        assertEq(context.returnValues.executions[1].offerer, offerer1.addr);
        assertEq(context.returnValues.executions[2].offerer, address(this));
        assertEq(context.returnValues.executions[3].offerer, address(this));

        assertEq(
            context.returnValues.executions[0].conduitKey,
            context.fulfillerConduitKey
        );
        assertEq(
            context.returnValues.executions[1].conduitKey,
            context.fulfillerConduitKey
        );
        assertEq(
            context.returnValues.executions[2].conduitKey,
            context.fulfillerConduitKey
        );
        assertEq(
            context.returnValues.executions[3].conduitKey,
            context.fulfillerConduitKey
        );
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.fulfillAvailableAdvancedOrders.
    function test_exec_Combined_FulfillAvailableAdvanced() public {
        OfferItem[] memory offerItems = new OfferItem[](1);
        ConsiderationItem[]
            memory considerationItems1 = new ConsiderationItem[](1);
        ConsiderationItem[]
            memory considerationItems2 = new ConsiderationItem[](1);
        {
            // Offer ERC20
            OfferItem memory offerItem = OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(1)
                .withEndAmount(1);
            offerItems[0] = offerItem;

            // Consider single ERC721 to offerer1
            erc721s[0].mint(address(this), 1);
            ConsiderationItem memory considerationItem = ConsiderationItemLib
                .empty()
                .withRecipient(offerer1.addr)
                .withItemType(ItemType.ERC721)
                .withToken(address(erc721s[0]))
                .withIdentifierOrCriteria(1)
                .withAmount(1);
            considerationItems1[0] = considerationItem;

            // Consider single ERC721 to offerer1
            erc721s[0].mint(address(this), 2);
            considerationItem = ConsiderationItemLib
                .empty()
                .withRecipient(offerer1.addr)
                .withItemType(ItemType.ERC721)
                .withToken(address(erc721s[0]))
                .withIdentifierOrCriteria(2)
                .withAmount(1);
            considerationItems2[0] = considerationItem;
        }

        OrderComponents memory orderComponents1 = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems1);

        OrderComponents memory orderComponents2 = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems2);

        Order memory order1 = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents1.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer1.key,
                    seaport.getOrderHash(orderComponents1)
                )
            );

        Order memory order2 = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents2.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer1.key,
                    seaport.getOrderHash(orderComponents2)
                )
            );

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = order1.toAdvancedOrder({
            numerator: 1,
            denominator: 1,
            extraData: bytes("")
        });
        advancedOrders[1] = order2.toAdvancedOrder({
            numerator: 1,
            denominator: 1,
            extraData: bytes("")
        });

        (
            FulfillmentComponent[][] memory offerComponents,
            FulfillmentComponent[][] memory considerationComponents
        ) = getNaiveFulfillmentComponents(advancedOrders);

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_allOrdersFilled.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 1 })
            })
            .withChecks(checks)
            .withOfferFulfillments(offerComponents)
            .withConsiderationFulfillments(considerationComponents)
            .withMaximumFulfilled(2);

        run(context);
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });
        orders[1] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_orderValidated.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 5 })
            })
            .withChecks(checks);

        exec(context);
        checkAll(context);
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });
        orders[1] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_orderCancelled.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: offerer1.addr,
                fuzzParams: FuzzParams({ seed: 4 })
            })
            .withChecks(checks);

        exec(context);
        checkAll(context);
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_alwaysRevert.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 0 })
            })
            .withChecks(checks);

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

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_revertWithContextData.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(this),
                fuzzParams: FuzzParams({ seed: 0 })
            })
            .withChecks(checks);

        exec(context);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExampleErrorWithContextData.selector,
                context.orders[0].signature
            )
        );
        checkAll(context);
    }

    /// @dev Call run for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.cancel.
    function test_run_Combined_Cancel() public {
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });
        orders[1] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_orderCancelled.selector;

        TestContext memory context = TestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: offerer1.addr,
                fuzzParams: FuzzParams({ seed: 4 })
            })
            .withChecks(checks);

        run(context);
    }

    /// @dev Example of a simple "check" function. This one takes no args.
    function check_alwaysRevert() public pure {
        revert("this check always reverts");
    }

    /// @dev Example of a "check" function that uses the test context.
    function check_revertWithContextData(
        TestContext memory context
    ) public pure {
        revert ExampleErrorWithContextData(context.orders[0].signature);
    }

    function assertEq(bytes4[] memory a, bytes4[] memory b) internal {
        if (a.length != b.length) revert("Array length mismatch");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i]);
        }
    }

    function assertEq(ItemType a, ItemType b) internal {
        assertEq(uint8(a), uint8(b));
    }
}
