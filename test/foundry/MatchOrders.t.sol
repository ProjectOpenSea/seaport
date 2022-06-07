// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { OrderType, ItemType } from "../../contracts/lib/ConsiderationEnums.sol";
import { Order, Fulfillment, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { ConsiderationEventsAndErrors } from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";
import { stdError } from "forge-std/Test.sol";

contract MatchOrders is BaseOrderTest {
    using ArithmeticUtil for uint128;
    struct FuzzInputsCommon {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct FuzzInputsAscendingDescending {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128 amount;
        bool useConduit;
        uint256 warp;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
    }

    struct ContextAscendingDescending {
        ConsiderationInterface consideration;
        FuzzInputsAscendingDescending args;
    }

    modifier validateInputs(Context memory context) {
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(context.args.paymentAmts[0]) +
                uint256(context.args.paymentAmts[1]) +
                uint256(context.args.paymentAmts[2]) <=
                2**128 - 1
        );
        _;
    }

    modifier validateInputsAscendingDescending(
        ContextAscendingDescending memory context
    ) {
        vm.assume(context.args.amount > 100);
        vm.assume(uint256(context.args.amount) * 2 <= 2**128 - 1);
        vm.assume(context.args.warp > 10 && context.args.warp < 1000);
        _;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testAscendingDescending(
        function(ContextAscendingDescending memory) external fn,
        ContextAscendingDescending memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testOverflow(
        function(Context memory, ItemType) external fn,
        Context memory context,
        ItemType itemType
    ) internal {
        try fn(context, itemType) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testMatchOrdersSingleErc721OfferSingleEthConsideration(
        FuzzInputsCommon memory inputs
    ) public validateInputs(Context(consideration, inputs)) {
        _configureERC721OfferItem(inputs.id);
        _configureEthConsiderationItem(alice, 1);
        _configureOrderParameters(
            alice,
            inputs.zone,
            inputs.zoneHash,
            inputs.salt,
            inputs.useConduit
        );
        _configureOrderComponents(consideration.getNonce(alice));
        test(
            this.matchOrdersSingleErc721OfferSingleEthConsideration,
            Context(consideration, inputs)
        );
        test(
            this.matchOrdersSingleErc721OfferSingleEthConsideration,
            Context(referenceConsideration, inputs)
        );
    }

    function testMatchOrdersOverflowOfferSide(FuzzInputsCommon memory inputs)
        public
        validateInputs(Context(consideration, inputs))
    {
        for (uint256 i = 1; i < 4; ++i) {
            if (i == 2) {
                continue;
            }
            testOverflow(
                this.matchOrdersOverflowOfferSide,
                Context(referenceConsideration, inputs),
                ItemType(i)
            );
            testOverflow(
                this.matchOrdersOverflowOfferSide,
                Context(consideration, inputs),
                ItemType(i)
            );
            delete offerItems;
            delete considerationItems;
        }
    }

    function testMatchOrdersOverflowConsiderationSide(
        FuzzInputsCommon memory inputs
    ) public validateInputs(Context(consideration, inputs)) {
        // start at 1 to skip eth
        for (uint256 i = 1; i < 4; ++i) {
            if (i == 2) {
                continue;
            }
            testOverflow(
                this.matchOrdersOverflowConsiderationSide,
                Context(referenceConsideration, inputs),
                ItemType(i)
            );
            testOverflow(
                this.matchOrdersOverflowConsiderationSide,
                Context(consideration, inputs),
                ItemType(i)
            );
            delete offerItems;
            delete considerationItems;
        }
    }

    function testMatchOrdersAscendingOfferAmount(
        FuzzInputsAscendingDescending memory inputs
    )
        public
        validateInputsAscendingDescending(
            ContextAscendingDescending(consideration, inputs)
        )
    {
        _configureOfferItem(
            ItemType.ERC20,
            0,
            inputs.amount,
            inputs.amount * 2
        );
        _configureConsiderationItem(alice, ItemType.ERC721, inputs.id, 1);
        _configureOrderParametersSetEndTime(
            alice,
            inputs.zone,
            1001,
            inputs.zoneHash,
            inputs.salt,
            inputs.useConduit
        );
        _configureOrderComponents(consideration.getNonce(alice));
        testAscendingDescending(
            this.matchOrdersAscendingOfferAmount,
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        testAscendingDescending(
            this.matchOrdersAscendingOfferAmount,
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersAscendingConsiderationAmount(
        FuzzInputsAscendingDescending memory inputs
    )
        public
        validateInputsAscendingDescending(
            ContextAscendingDescending(consideration, inputs)
        )
    {
        _configureOfferItem(ItemType.ERC721, inputs.id, 1);
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            inputs.amount,
            inputs.amount * 2,
            alice
        );
        _configureOrderParametersSetEndTime(
            alice,
            inputs.zone,
            1001,
            inputs.zoneHash,
            inputs.salt,
            inputs.useConduit
        );
        _configureOrderComponents(consideration.getNonce(alice));
        testAscendingDescending(
            this.matchOrdersAscendingConsiderationAmount,
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        testAscendingDescending(
            this.matchOrdersAscendingConsiderationAmount,
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersDescendingOfferAmount(
        FuzzInputsAscendingDescending memory inputs
    )
        public
        validateInputsAscendingDescending(
            ContextAscendingDescending(consideration, inputs)
        )
    {
        _configureOfferItem(
            ItemType.ERC20,
            0,
            inputs.amount * 2,
            inputs.amount
        );
        _configureErc721ConsiderationItem(alice, inputs.id);
        _configureOrderParametersSetEndTime(
            alice,
            inputs.zone,
            1001,
            inputs.zoneHash,
            inputs.salt,
            inputs.useConduit
        );
        _configureOrderComponents(consideration.getNonce(alice));
        testAscendingDescending(
            this.matchOrdersDescendingOfferAmount,
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        testAscendingDescending(
            this.matchOrdersDescendingOfferAmount,
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersDescendingConsiderationAmount(
        FuzzInputsAscendingDescending memory inputs
    )
        public
        validateInputsAscendingDescending(
            ContextAscendingDescending(consideration, inputs)
        )
    {
        _configureOfferItem(ItemType.ERC721, inputs.id, 1);
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            inputs.amount * 2,
            inputs.amount,
            alice
        );
        _configureOrderParametersSetEndTime(
            alice,
            inputs.zone,
            1001,
            inputs.zoneHash,
            inputs.salt,
            inputs.useConduit
        );
        _configureOrderComponents(consideration.getNonce(alice));
        testAscendingDescending(
            this.matchOrdersDescendingConsiderationAmount,
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        testAscendingDescending(
            this.matchOrdersDescendingConsiderationAmount,
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function matchOrdersOverflowOfferSide(
        Context memory context,
        ItemType itemType
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        _configureOfferItem(itemType, 1, 100);
        _configureErc721ConsiderationItem(alice, 1);
        _configureOrderParameters(
            bob,
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            context.args.useConduit
        );
        _configureOrderComponents(consideration.getNonce(bob));
        bytes memory baseSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(itemType, 1, 2**256 - 1);
        _configureErc721ConsiderationItem(alice, 2);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getNonce(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(alice, 1);
        test721_1.mint(alice, 2);
        _configureERC721OfferItem(1);
        _configureERC721OfferItem(2);
        _configureConsiderationItem(bob, itemType, 1, 99);

        OrderParameters memory thirdOrderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory thirdOrderComponents = getOrderComponents(
            thirdOrderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory thirdSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(thirdOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        Order[] memory orders = new Order[](3);
        orders[0] = Order(baseOrderParameters, baseSignature);
        orders[1] = Order(secondOrderParameters, secondSignature);
        orders[2] = Order(thirdOrderParameters, thirdSignature);

        fulfillmentComponent = FulfillmentComponent(2, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(2, 1);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(2, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.expectRevert(stdError.arithmeticError);
        context.consideration.matchOrders{ value: 99 }(orders, fulfillments);
    }

    function matchOrdersOverflowConsiderationSide(
        Context memory context,
        ItemType itemType
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureConsiderationItem(alice, itemType, 1, 100);

        OrderParameters memory firstOrderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory firstOrderComponents = getOrderComponents(
            firstOrderParameters,
            context.consideration.getNonce(alice)
        );
        bytes memory firstSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        _configureERC721OfferItem(2);
        _configureConsiderationItem(alice, itemType, 1, 2**256 - 1);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getNonce(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(itemType, 1, 99);
        _configureErc721ConsiderationItem(alice, 1);
        _configureErc721ConsiderationItem(bob, 2);

        OrderParameters memory thirdOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory thirdOrderComponents = getOrderComponents(
            thirdOrderParameters,
            context.consideration.getNonce(bob)
        );

        bytes memory thirdSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(thirdOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        Order[] memory orders = new Order[](3);
        orders[0] = Order(firstOrderParameters, firstSignature);
        orders[1] = Order(secondOrderParameters, secondSignature);
        orders[2] = Order(thirdOrderParameters, thirdSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(2, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(2, 1);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(2, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.expectRevert(stdError.arithmeticError);
        context.consideration.matchOrders(orders, fulfillments);
    }

    function matchOrdersSingleErc721OfferSingleEthConsideration(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        OrderParameters
            memory mirrorOrderParameters = createMirrorOrderParameters(
                baseOrderParameters,
                cal,
                context.args.zone,
                conduitKey
            );

        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(cal)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            calPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(baseOrderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        context.consideration.matchOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(orders, fulfillments);
    }

    function matchOrdersAscendingOfferAmount(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(bob, context.args.id);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        uint256 currentAmount = _locateCurrentAmount(
            context.args.amount, // start amount
            context.args.amount * 2, // end amount
            context.args.warp, // elapsed
            1000 - context.args.warp, // remaining
            1000, // duration
            false // roundUp
        );

        _configureOfferItem(ItemType.ERC721, context.args.id, 1);
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            currentAmount,
            currentAmount,
            bob
        );

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            1,
            1001,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );
        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(bob)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(baseOrderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.warp(1 + context.args.warp);

        uint256 balanceBeforeOrder = token1.balanceOf(bob);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(bob);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }

    function matchOrdersAscendingConsiderationAmount(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        uint256 currentAmount = _locateCurrentAmount(
            context.args.amount, // start amount
            context.args.amount * 2, // end amount
            context.args.warp, // elapsed
            1000 - context.args.warp, // remaining
            1000, // duration
            true // roundUp
        );
        _configureOfferItem(ItemType.ERC20, 0, currentAmount, currentAmount);
        _configureConsiderationItem(bob, ItemType.ERC721, context.args.id, 1);

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            1,
            1001,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );
        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(bob)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(baseOrderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.warp(1 + context.args.warp);

        uint256 balanceBeforeOrder = token1.balanceOf(alice);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(alice);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }

    function matchOrdersDescendingOfferAmount(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(bob, context.args.id);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        uint256 currentAmount = _locateCurrentAmount(
            context.args.amount * 2, // start amount
            context.args.amount, // end amount
            context.args.warp, // elapsed
            1000 - context.args.warp, // remaining
            1000, // duration
            false // roundUp
        );

        _configureOfferItem(ItemType.ERC721, context.args.id, 1);
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            currentAmount,
            currentAmount,
            bob
        );

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            1,
            1001,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(bob)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(baseOrderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.warp(1 + context.args.warp);

        uint256 balaceBeforeOrder = token1.balanceOf(bob);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(bob);
        // check the difference in balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balaceBeforeOrder, currentAmount);
    }

    function matchOrdersDescendingConsiderationAmount(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(baseOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        uint256 currentAmount = _locateCurrentAmount(
            context.args.amount * 2,
            context.args.amount,
            context.args.warp,
            1000 - context.args.warp,
            1000,
            true
        );
        emit log_named_uint("Current Amount: ", currentAmount);

        _configureOfferItem(
            ItemType.ERC20,
            address(token1),
            0,
            currentAmount,
            currentAmount
        );
        _configureConsiderationItem(bob, ItemType.ERC721, context.args.id, 1);

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            1,
            1001,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(bob)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(baseOrderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        vm.warp(1 + context.args.warp);
        uint256 balanceBeforeOrder = token1.balanceOf(alice);
        context.consideration.matchOrders(orders, fulfillments);

        uint256 balanceAfterOrder = token1.balanceOf(alice);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }
}
