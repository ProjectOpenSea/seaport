// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, ItemType } from "../../contracts/lib/ConsiderationEnums.sol";
import { Order, Fulfillment, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { ConsiderationEventsAndErrors } from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { stdError } from "forge-std/Test.sol";

contract MatchOrders is BaseOrderTest {
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

    event Transfer(address from, address to, uint256 amount);

    function testMatchOrdersSingleErc721OfferSingleEthConsideration(
        FuzzInputsCommon memory inputs
    ) public {
        _testMatchOrdersSingleErc721OfferSingleEthConsideration(
            Context(referenceConsideration, inputs)
        );
        _testMatchOrdersSingleErc721OfferSingleEthConsideration(
            Context(consideration, inputs)
        );
    }

    function testMatchOrdersOverflowOrderSide() public {
        // start at 1 to skip eth
        for (uint256 i = 1; i < 4; i++) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            _testMatchOrdersOverflowOrderSide(consideration, ItemType(i));
            _testMatchOrdersOverflowOrderSide(
                referenceConsideration,
                ItemType(i)
            );
        }
    }

    function testMatchOrdersOverflowConsiderationSide() public {
        // start at 1 to skip eth
        for (uint256 i = 1; i < 4; i++) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            _testMatchOrdersOverflowConsiderationSide(
                consideration,
                ItemType(i)
            );
            _testMatchOrdersOverflowConsiderationSide(
                referenceConsideration,
                ItemType(i)
            );
        }
    }

    function testMatchOrdersAscendingOfferAmount(
        FuzzInputsAscendingDescending memory inputs
    ) public {
        _testMatchOrdersAscendingOfferAmount(
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        _testMatchOrdersAscendingOfferAmount(
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersAscendingConsiderationAmount(
        FuzzInputsAscendingDescending memory inputs
    ) public {
        _testMatchOrdersAscendingConsiderationAmount(
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        _testMatchOrdersAscendingConsiderationAmount(
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersDescendingOfferAmount(
        FuzzInputsAscendingDescending memory inputs
    ) public {
        _testMatchOrdersDescendingOfferAmount(
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        _testMatchOrdersDescendingOfferAmount(
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function testMatchOrdersDescendingConsiderationAmount(
        FuzzInputsAscendingDescending memory inputs
    ) public {
        _testMatchOrdersDescendingConsiderationAmount(
            ContextAscendingDescending(referenceConsideration, inputs)
        );
        _testMatchOrdersDescendingConsiderationAmount(
            ContextAscendingDescending(consideration, inputs)
        );
    }

    function _testMatchOrdersOverflowOrderSide(
        ConsiderationInterface _consideration,
        ItemType itemType
    ) internal resetTokenBalancesBetweenRuns {
        _configureOfferItem(itemType, 1, 100);
        _configureErc721ConsiderationItem(alice, 1);

        OrderParameters memory firstOrderParameters = OrderParameters(
            address(bob),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory firstOrderComponents = getOrderComponents(
            firstOrderParameters,
            _consideration.getNonce(bob)
        );
        bytes memory firstSignature = signOrder(
            _consideration,
            bobPk,
            _consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(itemType, 1, 2**256 - 1);
        _configureErc721ConsiderationItem(alice, 2);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(bob),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            _consideration.getNonce(bob)
        );
        bytes memory secondSignature = signOrder(
            _consideration,
            bobPk,
            _consideration.getOrderHash(secondOrderComponents)
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
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory thirdOrderComponents = getOrderComponents(
            thirdOrderParameters,
            _consideration.getNonce(alice)
        );

        bytes memory thirdSignature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(thirdOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        Order[] memory orders = new Order[](3);
        orders[0] = Order(firstOrderParameters, firstSignature);
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
        _consideration.matchOrders{ value: 99 }(orders, fulfillments);
    }

    function _testMatchOrdersOverflowConsiderationSide(
        ConsiderationInterface _consideration,
        ItemType itemType
    ) internal resetTokenBalancesBetweenRuns {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureConsiderationItem(alice, itemType, 1, 100);

        OrderParameters memory firstOrderParameters = OrderParameters(
            address(alice),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory firstOrderComponents = getOrderComponents(
            firstOrderParameters,
            _consideration.getNonce(alice)
        );
        bytes memory firstSignature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        _configureERC721OfferItem(2);
        _configureConsiderationItem(alice, itemType, 1, 2**256 - 1);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(bob),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            _consideration.getNonce(bob)
        );
        bytes memory secondSignature = signOrder(
            _consideration,
            bobPk,
            _consideration.getOrderHash(secondOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(itemType, 1, 99);
        _configureErc721ConsiderationItem(alice, 1);
        _configureErc721ConsiderationItem(bob, 2);

        OrderParameters memory thirdOrderParameters = OrderParameters(
            address(bob),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory thirdOrderComponents = getOrderComponents(
            thirdOrderParameters,
            _consideration.getNonce(bob)
        );

        bytes memory thirdSignature = signOrder(
            _consideration,
            bobPk,
            _consideration.getOrderHash(thirdOrderComponents)
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
        _consideration.matchOrders(orders, fulfillments);
    }

    function _testMatchOrdersSingleErc721OfferSingleEthConsideration(
        Context memory context
    ) internal resetTokenBalancesBetweenRuns {
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
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        offerItems.push(
            OfferItem(
                ItemType.ERC721,
                address(test721_1),
                context.args.id,
                1,
                1
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(1),
                uint256(1),
                payable(alice)
            )
        );

        OrderParameters memory orderParameters = OrderParameters(
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

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        OfferItem[] memory mirrorOfferItems = new OfferItem[](1);

        // push the original order's consideration item into mirrorOfferItems
        mirrorOfferItems[0] = OfferItem(
            considerationItems[0].itemType,
            considerationItems[0].token,
            considerationItems[0].identifierOrCriteria,
            considerationItems[0].startAmount,
            considerationItems[0].endAmount
        );

        ConsiderationItem[]
            memory mirrorConsiderationItems = new ConsiderationItem[](1);

        // push the original order's offer item into mirrorConsiderationItems
        mirrorConsiderationItems[0] = ConsiderationItem(
            offerItems[0].itemType,
            offerItems[0].token,
            offerItems[0].identifierOrCriteria,
            offerItems[0].startAmount,
            offerItems[0].endAmount,
            payable(cal)
        );

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(cal),
            context.args.zone,
            mirrorOfferItems,
            mirrorConsiderationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            mirrorConsiderationItems.length
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
        orders[0] = Order(orderParameters, signature);
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

    function _testMatchOrdersAscendingOfferAmount(
        ContextAscendingDescending memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(context.args.amount > 100);
        vm.assume(uint256(context.args.amount) * 2 <= 2**128 - 1);
        vm.assume(context.args.warp > 10 && context.args.warp < 1000);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(bob, context.args.id);

        _configureOfferItem(
            ItemType.ERC20,
            0,
            context.args.amount,
            context.args.amount * 2
        );
        _configureConsiderationItem(alice, ItemType.ERC721, context.args.id, 1);

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
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
            block.timestamp,
            block.timestamp + 1000,
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
        orders[0] = Order(orderParameters, signature);
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

        vm.warp(block.timestamp + context.args.warp);

        uint256 balanceBeforeOrder = token1.balanceOf(bob);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(bob);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }

    function _testMatchOrdersAscendingConsiderationAmount(
        ContextAscendingDescending memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(context.args.amount > 100);
        vm.assume(uint256(context.args.amount) * 2 <= 2**128 - 1);
        vm.assume(context.args.warp > 10 && context.args.warp < 1000);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        _configureOfferItem(ItemType.ERC721, context.args.id, 1);
        // set endAmount to 2 * startAmount
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            context.args.amount,
            context.args.amount * 2,
            alice
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
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
            block.timestamp,
            block.timestamp + 1000,
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
        orders[0] = Order(orderParameters, signature);
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

        vm.warp(block.timestamp + context.args.warp);

        uint256 balanceBeforeOrder = token1.balanceOf(alice);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(alice);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }

    function _testMatchOrdersDescendingOfferAmount(
        ContextAscendingDescending memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(context.args.amount > 100);
        vm.assume(uint256(context.args.amount) * 2 <= 2**128 - 1);
        vm.assume(context.args.warp > 10 && context.args.warp < 1000);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(bob, context.args.id);

        _configureOfferItem(
            ItemType.ERC20,
            0,
            context.args.amount * 2,
            context.args.amount
        );
        _configureErc721ConsiderationItem(alice, context.args.id);

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
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
            block.timestamp,
            block.timestamp + 1000,
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
        orders[0] = Order(orderParameters, signature);
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

        vm.warp(block.timestamp + context.args.warp);

        uint256 balaceBeforeOrder = token1.balanceOf(bob);
        context.consideration.matchOrders(orders, fulfillments);
        uint256 balanceAfterOrder = token1.balanceOf(bob);
        // check the difference in balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balaceBeforeOrder, currentAmount);
    }

    function _testMatchOrdersDescendingConsiderationAmount(
        ContextAscendingDescending memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(context.args.amount > 100);
        vm.assume(uint256(context.args.amount) * 2 <= 2**128 - 1);
        vm.assume(context.args.warp > 10 && context.args.warp < 1000);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        assert(considerationItems.length == 0);

        _configureOfferItem(ItemType.ERC721, context.args.id, 1);
        considerationItems.push(
            ConsiderationItem(
                ItemType.ERC20,
                address(token1),
                1,
                context.args.amount * 2, // start amount
                context.args.amount, // end amount
                alice
            )
        );
        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        delete offerItems;
        delete considerationItems;

        vm.warp(block.timestamp + context.args.warp);
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
            1,
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
            block.timestamp,
            block.timestamp + 1000,
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
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);
        emit log_named_uint(
            "Mirror Offer Start Amount: ",
            mirrorOrderParameters.offer[0].startAmount
        );
        emit log_named_uint(
            "Mirror Offer End Amount: ",
            mirrorOrderParameters.offer[0].endAmount
        );
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

        uint256 balanceBeforeOrder = token1.balanceOf(alice);
        context.consideration.matchOrders(orders, fulfillments);

        uint256 balanceAfterOrder = token1.balanceOf(alice);
        // check the difference in alice's balance is equal to endAmount of offer item
        assertEq(balanceAfterOrder - balanceBeforeOrder, currentAmount);
    }
}
