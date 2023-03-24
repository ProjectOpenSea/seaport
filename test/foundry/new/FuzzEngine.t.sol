// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import {
    FuzzTestContext,
    FuzzParams,
    FuzzEngine,
    FuzzEngineLib,
    FuzzTestContextLib
} from "./helpers/FuzzEngine.sol";

import {
    HashValidationZoneOfferer
} from "../../../contracts/test/HashValidationZoneOfferer.sol";
import { AdvancedOrder, FuzzHelpers } from "./helpers/FuzzHelpers.sol";

contract FuzzEngineTest is FuzzEngine {
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
    using ZoneParametersLib for AdvancedOrder[];

    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];
    using FuzzEngineLib for FuzzTestContext;
    using FuzzTestContextLib for FuzzTestContext;

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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.fulfillOrder.selector);

        context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 1,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 1,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.fulfillAdvancedOrder.selector);
    }

    /// @dev Get one action for a single, basic order.
    function test_action_Single_Basic() public {
        AdvancedOrder[] memory orders = _setUpBasicOrder();

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 2,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.fulfillBasicOrder.selector);

        context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 3,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(
            context.action(),
            seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        );
    }

    /// @dev Get all actions for a single, basic order.
    function test_actions_Single_Basic() public {
        AdvancedOrder[] memory orders = _setUpBasicOrder();

        bytes4[] memory expectedActions = new bytes4[](4);
        expectedActions[0] = seaport.fulfillOrder.selector;
        expectedActions[1] = seaport.fulfillAdvancedOrder.selector;
        expectedActions[2] = seaport.fulfillBasicOrder.selector;
        expectedActions[3] = seaport
            .fulfillBasicOrder_efficient_6GL6yc
            .selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.actions(), expectedActions);
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

        bytes4[] memory expectedActions = new bytes4[](4);
        expectedActions[0] = seaport.fulfillAvailableOrders.selector;
        expectedActions[1] = seaport.fulfillAvailableAdvancedOrders.selector;
        expectedActions[2] = seaport.matchOrders.selector;
        expectedActions[3] = seaport.matchAdvancedOrders.selector;
        // TODO: undo pended actions (cancel, validate)
        /** expectedActions[4] = seaport.cancel.selector;
        expectedActions[5] = seaport.validate.selector; */

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this)
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.fulfillAvailableOrders.selector);

        context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 1,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(
            context.action(),
            seaport.fulfillAvailableAdvancedOrders.selector
        );

        context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 2,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.matchOrders.selector);

        context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 3,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );
        assertEq(context.action(), seaport.matchAdvancedOrders.selector);

        // TODO: undo pended actions (match, cancel, validate)
        /** context = FuzzTestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 4 })
        });
        assertEq(context.action(), seaport.cancel.selector);

        context = FuzzTestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            fuzzParams: FuzzParams({ seed: 5 })
        });
        assertEq(context.action(), seaport.validate.selector); */
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            );

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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withRecipient(address(0xbeef));

        exec(context);
        assertEq(context.returnValues.fulfilled, true);
    }

    function _setUpBasicOrder() internal returns (AdvancedOrder[] memory) {
        erc721s[0].mint(offerer1.addr, 1);

        OfferItem[] memory offerItems = new OfferItem[](1);
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);

        offerItems[0] = offerItem;

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(1);

        considerationItems[0] = considerationItem;

        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems);

        bytes memory signature = signOrder(
            seaport,
            offerer1.key,
            seaport.getOrderHash(orderComponents)
        );

        Order memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(
                orderComponents.toOrderParameters().withOrderType(
                    OrderType.FULL_OPEN
                )
            )
            .withSignature(signature);

        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        return orders;
    }

    /// @dev Call exec for a single basic order. Stub the fuzz seed so that it
    ///      always calls Seaport.fulfillBasicOrder.
    function test_exec_FulfillBasicOrder() public {
        AdvancedOrder[] memory orders = _setUpBasicOrder();

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_orderFulfilled.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(offerer1.addr)
            })
            .withFuzzParams(
                FuzzParams({
                    seed: 2,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withBasicOrderParameters(
                orders[0].toBasicOrderParameters(orders[0].getBasicOrderType())
            );

        exec(context);
    }

    /// @dev Call exec for a single basic order. Stub the fuzz seed so that it
    ///      always calls Seaport.fulfillBasicOrder_efficient_6GL6yc.
    function test_exec_FulfillBasicOrder_efficient_6GL6yc() public {
        AdvancedOrder[] memory orders = _setUpBasicOrder();

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_orderFulfilled.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: orders,
                seaport: seaport,
                caller: address(offerer1.addr)
            })
            .withFuzzParams(
                FuzzParams({
                    seed: 3,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withBasicOrderParameters(
                orders[0].toBasicOrderParameters(orders[0].getBasicOrderType())
            );

        exec(context);
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: address(this)
            })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
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

        bytes4[] memory checks = new bytes4[](2);
        checks[0] = this.check_allOrdersFilled.selector;
        checks[1] = this.check_executionsPresent.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: address(this)
            })
            .withFuzzParams(
                FuzzParams({
                    seed: 1,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks)
            .withOfferFulfillments(offerComponents)
            .withConsiderationFulfillments(considerationComponents)
            .withMaximumFulfilled(2);

        exec(context);
        checkAll(context);
    }

    /// @dev Call run for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.matchOrders.
    function test_exec_Combined_matchOrders() public {
        OfferItem[] memory offerItemsPrime = new OfferItem[](1);
        OfferItem[] memory offerItemsMirror = new OfferItem[](1);
        ConsiderationItem[]
            memory considerationItemsPrime = new ConsiderationItem[](1);
        ConsiderationItem[]
            memory considerationItemsMirror = new ConsiderationItem[](1);
        {
            // Offer ERC20
            OfferItem memory offerItemPrime = OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(1)
                .withEndAmount(1);
            offerItemsPrime[0] = offerItemPrime;

            // Consider single ERC721 to offerer1
            erc721s[0].mint(offerer2.addr, 1);
            ConsiderationItem
                memory considerationItemPrime = ConsiderationItemLib
                    .empty()
                    .withRecipient(offerer1.addr)
                    .withItemType(ItemType.ERC721)
                    .withToken(address(erc721s[0]))
                    .withIdentifierOrCriteria(1)
                    .withAmount(1);
            considerationItemsPrime[0] = considerationItemPrime;

            offerItemsMirror[0] = considerationItemsPrime[0].toOfferItem();

            considerationItemsMirror[0] = offerItemsPrime[0]
                .toConsiderationItem(offerer2.addr);
        }

        OrderComponents memory orderComponentsPrime = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItemsPrime)
            .withConsideration(considerationItemsPrime);

        OrderComponents memory orderComponentsMirror = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer2.addr)
            .withOffer(offerItemsMirror)
            .withConsideration(considerationItemsMirror);

        Order memory orderPrime = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponentsPrime.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer1.key,
                    seaport.getOrderHash(orderComponentsPrime)
                )
            );

        Order memory orderMirror = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponentsMirror.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer2.key,
                    seaport.getOrderHash(orderComponentsMirror)
                )
            );

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = orderPrime.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });
        orders[1] = orderMirror.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(orders);

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_executionsPresent.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: offerer1.addr })
            .withFuzzParams(
                FuzzParams({
                    seed: 2,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks)
            .withFulfillments(fulfillments);

        exec(context);
        checkAll(context);
    }

    /// @dev Call run for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.matchAdvancedOrders.
    function test_exec_Combined_matchAdvancedOrders() public {
        OfferItem[] memory offerItemsPrime = new OfferItem[](1);
        OfferItem[] memory offerItemsMirror = new OfferItem[](1);
        ConsiderationItem[]
            memory considerationItemsPrime = new ConsiderationItem[](1);
        ConsiderationItem[]
            memory considerationItemsMirror = new ConsiderationItem[](1);
        {
            // Offer ERC20
            OfferItem memory offerItemPrime = OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(1)
                .withEndAmount(1);
            offerItemsPrime[0] = offerItemPrime;

            // Consider single ERC721 to offerer1
            erc721s[0].mint(offerer2.addr, 1);
            ConsiderationItem
                memory considerationItemPrime = ConsiderationItemLib
                    .empty()
                    .withRecipient(offerer1.addr)
                    .withItemType(ItemType.ERC721)
                    .withToken(address(erc721s[0]))
                    .withIdentifierOrCriteria(1)
                    .withAmount(1);
            considerationItemsPrime[0] = considerationItemPrime;

            offerItemsMirror[0] = considerationItemsPrime[0].toOfferItem();

            considerationItemsMirror[0] = offerItemsPrime[0]
                .toConsiderationItem(offerer2.addr);
        }

        OrderComponents memory orderComponentsPrime = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItemsPrime)
            .withConsideration(considerationItemsPrime);

        OrderComponents memory orderComponentsMirror = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer2.addr)
            .withOffer(offerItemsMirror)
            .withConsideration(considerationItemsMirror);

        Order memory orderPrime = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponentsPrime.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer1.key,
                    seaport.getOrderHash(orderComponentsPrime)
                )
            );

        Order memory orderMirror = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponentsMirror.toOrderParameters())
            .withSignature(
                signOrder(
                    seaport,
                    offerer2.key,
                    seaport.getOrderHash(orderComponentsMirror)
                )
            );

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = orderPrime.toAdvancedOrder({
            numerator: 1,
            denominator: 1,
            extraData: bytes("")
        });
        advancedOrders[1] = orderMirror.toAdvancedOrder({
            numerator: 1,
            denominator: 1,
            extraData: bytes("")
        });

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(advancedOrders);

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_executionsPresent.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: offerer1.addr
            })
            .withFuzzParams(
                FuzzParams({
                    seed: 3,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks)
            .withFulfillments(fulfillments);

        exec(context);
        checkAll(context);
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.validate.
    function xtest_exec_Combined_Validate() public {
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 5,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks);

        exec(context);
        checkAll(context);
    }

    /// @dev Call exec for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.cancel.
    function xtest_exec_Combined_Cancel() public {
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: offerer1.addr })
            .withFuzzParams(
                FuzzParams({
                    seed: 4,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks);

        exec(context);

        vm.expectRevert("this check always reverts");
        checkAll(context);
    }

    /// @dev Call checkAll to run a check that uses the FuzzTestContext.
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: address(this) })
            .withFuzzParams(
                FuzzParams({
                    seed: 0,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
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

    function test_check_validateOrderExpectedDataHash() public {
        Order[] memory orders = new Order[](2);
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);

        // New scope for setup
        {
            HashValidationZoneOfferer zone = new HashValidationZoneOfferer(
                address(this)
            );
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
                .withZone(address(zone))
                .withOrderType(OrderType.FULL_RESTRICTED)
                .withConsideration(considerationItems1);

            OrderComponents memory orderComponents2 = OrderComponentsLib
                .fromDefault(STANDARD)
                .withOfferer(offerer1.addr)
                .withOffer(offerItems)
                .withZone(address(zone))
                .withOrderType(OrderType.FULL_RESTRICTED)
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

            orders[0] = order1;
            orders[1] = order2;

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
        }

        (
            FulfillmentComponent[][] memory offerComponents,
            FulfillmentComponent[][] memory considerationComponents
        ) = getNaiveFulfillmentComponents(orders);

        bytes32[] memory expectedCalldataHashes = new bytes32[](2);

        {
            // update to context.caller
            for (uint256 i; i < advancedOrders.length; i++) {
                expectedCalldataHashes[i] = advancedOrders
                    .getExpectedZoneCalldataHash(
                        address(seaport),
                        address(this)
                    )[i];
            }
        }

        bytes4[] memory checks = new bytes4[](1);
        checks[0] = this.check_validateOrderExpectedDataHash.selector;

        FuzzTestContext memory context = FuzzTestContextLib
            .from({
                orders: advancedOrders,
                seaport: seaport,
                caller: address(this)
            })
            .withOfferFulfillments(offerComponents)
            .withConsiderationFulfillments(considerationComponents)
            .withChecks(checks)
            .withMaximumFulfilled(2);

        context.expectedZoneCalldataHash = expectedCalldataHashes;

        run(context);
    }

    /// @dev Call run for a combined order. Stub the fuzz seed so that it
    ///      always calls Seaport.cancel.
    function xtest_run_Combined_Cancel() public {
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

        FuzzTestContext memory context = FuzzTestContextLib
            .from({ orders: orders, seaport: seaport, caller: offerer1.addr })
            .withFuzzParams(
                FuzzParams({
                    seed: 4,
                    totalOrders: 0,
                    maxOfferItems: 0,
                    maxConsiderationItems: 0
                })
            )
            .withChecks(checks);

        run(context);
    }

    /// @dev Example of a simple "check" function. This one takes no args.
    function check_alwaysRevert() public pure {
        revert("this check always reverts");
    }

    /// @dev Example of a "check" function that uses the test context.
    function check_revertWithContextData(
        FuzzTestContext memory context
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
