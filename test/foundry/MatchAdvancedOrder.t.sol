// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { Order, Fulfillment } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";
import { Merkle } from "../../lib/murky/src/Merkle.sol";
import { stdError } from "forge-std/Test.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract MatchAdvancedOrder is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;

    FuzzInputs empty;

    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128 amount;
        bool useConduit;
    }
    struct FuzzInputsAscendingDescending {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128 baseStart;
        uint128 baseEnd;
        uint120 multiplier;
        uint120 fractionalComponent;
        bool useConduit;
        uint256 warp;
    }
    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
        ItemType itemType;
    }
    struct ContextAscendingDescending {
        ConsiderationInterface consideration;
        FuzzInputsAscendingDescending args;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function test(
        function(ContextAscendingDescending memory) external fn,
        ContextAscendingDescending memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testMatchAdvancedOrdersOverflowOrderSide() public {
        // start at 1 to skip eth
        for (uint256 i = 1; i < 4; i++) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.matchAdvancedOrdersOverflowOrderSide,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.matchAdvancedOrdersOverflowOrderSide,
                Context(consideration, empty, ItemType(i))
            );
        }
    }

    function testMatchAdvancedOrdersOverflowConsiderationSide() public {
        // start at 1 to skip eth
        for (uint256 i = 1; i < 4; i++) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.matchAdvancedOrdersOverflowConsiderationSide,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.matchAdvancedOrdersOverflowConsiderationSide,
                Context(consideration, empty, ItemType(i))
            );
        }
    }

    function testMatchAdvancedOrdersWithEmptyCriteriaEthToErc721(
        FuzzInputs memory args
    ) public {
        vm.assume(args.amount > 0);
        test(
            this.matchAdvancedOrdersWithEmptyCriteriaEthToErc721,
            Context(referenceConsideration, args, ItemType(0))
        );
        test(
            this.matchAdvancedOrdersWithEmptyCriteriaEthToErc721,
            Context(consideration, args, ItemType(0))
        );
    }

    function testMatchOrdersAscendingDescendingOfferAmountPartialFill(
        FuzzInputsAscendingDescending memory args
    ) public {
        vm.assume(args.baseStart != args.baseEnd);
        vm.assume(args.baseStart > 0 && args.baseEnd > 0);
        test(
            this.matchOrdersAscendingDescendingOfferAmountPartialFill,
            ContextAscendingDescending(consideration, args)
        );
        test(
            this.matchOrdersAscendingDescendingOfferAmountPartialFill,
            ContextAscendingDescending(referenceConsideration, args)
        );
    }

    function testMatchOrdersAscendingDescendingConsiderationAmountPartialFill(
        FuzzInputsAscendingDescending memory args
    ) public {
        vm.assume(args.baseStart != args.baseEnd);
        vm.assume(args.baseStart > 0 && args.baseEnd > 0);
        test(
            this.matchOrdersAscendingDescendingConsiderationAmountPartialFill,
            ContextAscendingDescending(consideration, args)
        );
        test(
            this.matchOrdersAscendingDescendingConsiderationAmountPartialFill,
            ContextAscendingDescending(referenceConsideration, args)
        );
    }

    function matchAdvancedOrdersOverflowOrderSide(Context memory context)
        external
        stateless
    {
        _configureOfferItem(context.itemType, 1, 100);
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
            context.consideration.getNonce(bob)
        );
        bytes memory firstSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(context.itemType, 1, 2**256 - 1);
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
        _configureConsiderationItem(bob, context.itemType, 1, 99);

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
            context.consideration.getNonce(alice)
        );

        bytes memory thirdSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(thirdOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](3);
        advancedOrders[0] = AdvancedOrder(
            firstOrderParameters,
            uint120(1),
            uint120(1),
            firstSignature,
            "0x"
        );
        advancedOrders[1] = AdvancedOrder(
            secondOrderParameters,
            uint120(1),
            uint120(1),
            secondSignature,
            "0x"
        );
        advancedOrders[2] = AdvancedOrder(
            thirdOrderParameters,
            uint120(1),
            uint120(1),
            thirdSignature,
            "0x"
        );

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
        context.consideration.matchAdvancedOrders{ value: 99 }(
            advancedOrders,
            new CriteriaResolver[](0),
            fulfillments
        );
    }

    function matchAdvancedOrdersOverflowConsiderationSide(
        Context memory context
    ) external stateless {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureConsiderationItem(alice, context.itemType, 1, 100);

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
        _configureConsiderationItem(alice, context.itemType, 1, 2**256 - 1);

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
            context.consideration.getNonce(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        _configureOfferItem(context.itemType, 1, 99);
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
            context.consideration.getNonce(bob)
        );

        bytes memory thirdSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(thirdOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](3);
        advancedOrders[0] = AdvancedOrder(
            firstOrderParameters,
            uint120(1),
            uint120(1),
            firstSignature,
            "0x"
        );
        advancedOrders[1] = AdvancedOrder(
            secondOrderParameters,
            uint120(1),
            uint120(1),
            secondSignature,
            "0x"
        );
        advancedOrders[2] = AdvancedOrder(
            thirdOrderParameters,
            uint120(1),
            uint120(1),
            thirdSignature,
            "0x"
        );

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
        context.consideration.matchAdvancedOrders{ value: 99 }(
            advancedOrders,
            new CriteriaResolver[](0),
            fulfillments
        );
    }

    function matchAdvancedOrdersWithEmptyCriteriaEthToErc721(
        Context memory context
    ) external stateless {
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
                context.args.amount,
                context.args.amount,
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

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = AdvancedOrder(
            orderParameters,
            uint120(1),
            uint120(1),
            signature,
            "0x"
        );
        advancedOrders[1] = AdvancedOrder(
            mirrorOrderParameters,
            uint120(1),
            uint120(1),
            mirrorSignature,
            "0x"
        );

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        firstFulfillment.offerComponents = fulfillmentComponents;
        secondFulfillment.considerationComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        firstFulfillment.considerationComponents = fulfillmentComponents;
        secondFulfillment.offerComponents = fulfillmentComponents;

        fulfillments.push(firstFulfillment);
        fulfillments.push(secondFulfillment);

        context.consideration.matchAdvancedOrders{ value: context.args.amount }(
            advancedOrders,
            new CriteriaResolver[](0), // no criteria resolvers
            fulfillments
        );
    }

    function matchOrdersAscendingDescendingOfferAmountPartialFill(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(bob, context.args.id, 20);
        token1.mint(
            alice,
            context.args.baseEnd > context.args.baseStart
                ? context.args.baseEnd.mul(20)
                : context.args.baseStart.mul(20)
        );

        emit log_named_uint(
            "start amount * final multiplier",
            context.args.baseStart.mul(20)
        );
        emit log_named_uint(
            "end amount * final multiplier",
            context.args.baseEnd.mul(20)
        );
        // multiply start and end amounts by multiplier and fractional component
        _configureOfferItem(
            ItemType.ERC20,
            0,
            context.args.baseStart.mul(20),
            context.args.baseEnd.mul(20)
        );
        _configureConsiderationItem(
            alice,
            ItemType.ERC1155,
            context.args.id,
            20
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
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

        // current amount should be mean of start and end amounts
        uint256 currentAmount = _locateCurrentAmount(
            context.args.baseStart.mul(20), // start amount
            context.args.baseEnd.mul(20), // end amount
            500, // elapsed
            500, // remaining
            1000, // duration
            false // roundUp
        );

        emit log_named_uint("current amount", currentAmount);
        emit log_named_uint(
            "current amount scaled down by partial fill",
            currentAmount.mul(2) / 10
        );

        _configureERC1155OfferItem(context.args.id, 20);
        // create mirror consideration item with current amount
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
            OrderType.PARTIAL_OPEN,
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        // create advanced order with multiplier and fractional component as numerator and denominator
        orders[0] = AdvancedOrder(orderParameters, 2, 10, signature, "0x");
        // also tried scaling down current amount and passing in full open order
        orders[1] = AdvancedOrder(
            mirrorOrderParameters,
            2,
            10,
            mirrorSignature,
            "0x"
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

        vm.warp(block.timestamp + 500);

        uint256 balanceBeforeOrder = token1.balanceOf(bob);
        context.consideration.matchAdvancedOrders(
            orders,
            new CriteriaResolver[](0),
            fulfillments
        );
        uint256 balanceAfterOrder = token1.balanceOf(bob);
        // check the difference in alice's balance is equal to partial fill of current amount
        assertEq(
            balanceAfterOrder - balanceBeforeOrder,
            currentAmount.mul(2) / 10
        );
    }

    function matchOrdersAscendingDescendingConsiderationAmountPartialFill(
        ContextAscendingDescending memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, 20);
        token1.mint(
            bob,
            context.args.baseEnd > context.args.baseStart
                ? context.args.baseEnd.mul(20)
                : context.args.baseStart.mul(20)
        );

        emit log_named_uint(
            "start amount * final multiplier",
            context.args.baseStart.mul(20)
        );
        emit log_named_uint(
            "end amount * final multiplier",
            context.args.baseEnd.mul(20)
        );
        // multiply start and end amounts by multiplier and fractional component
        _configureOfferItem(ItemType.ERC1155, context.args.id, 20, 20);
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            context.args.baseStart.mul(20),
            context.args.baseEnd.mul(20),
            alice
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
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

        // current amount should be mean of start and end amounts
        uint256 currentAmount = _locateCurrentAmount(
            context.args.baseStart.mul(20), // start amount
            context.args.baseEnd.mul(20), // end amount
            500, // elapsed
            500, // remaining
            1000, // duration
            false // roundUp
        );

        emit log_named_uint("current amount", currentAmount);
        emit log_named_uint(
            "current amount scaled down by partial fill",
            currentAmount.mul(2) / 10
        );

        _configureOfferItem(
            ItemType.ERC20,
            address(token1),
            0,
            currentAmount,
            currentAmount
        );
        // create mirror consideration item with current amount
        _configureConsiderationItem(
            ItemType.ERC1155,
            address(test1155_1),
            context.args.id,
            20,
            20,
            bob
        );

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(bob),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
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

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        // create advanced order with multiplier and fractional component as numerator and denominator
        orders[0] = AdvancedOrder(orderParameters, 2, 10, signature, "0x");
        // also tried scaling down current amount and passing in full open order
        orders[1] = AdvancedOrder(
            mirrorOrderParameters,
            2,
            10,
            mirrorSignature,
            "0x"
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

        vm.warp(block.timestamp + 500);

        uint256 balanceBeforeOrder = token1.balanceOf(alice);
        context.consideration.matchAdvancedOrders(
            orders,
            new CriteriaResolver[](0),
            fulfillments
        );
        uint256 balanceAfterOrder = token1.balanceOf(alice);
        // check the difference in alice's balance is equal to partial fill of current amount
        assertEq(
            balanceAfterOrder - balanceBeforeOrder,
            currentAmount.mul(2) / 10
        );
    }
}
