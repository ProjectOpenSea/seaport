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

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
    }

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

    function testMatchOrdersAscendingConsiderationAmount(
        FuzzInputsCommon memory inputs
    ) public {
        _testMatchOrdersAscendingConsiderationAmount(
            Context(referenceConsideration, inputs)
        );
        _testMatchOrdersAscendingConsiderationAmount(
            Context(consideration, inputs)
        );
    }

    function testMatchOrdersDescendingOfferAmount(
        FuzzInputsCommon memory inputs
    ) public {
        _testMatchOrdersDescendingOfferAmount(Context(consideration, inputs));
        _testMatchOrdersDescendingOfferAmount(
            Context(referenceConsideration, inputs)
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

    function _testMatchOrdersAscendingConsiderationAmount(
        Context memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(context.args.paymentAmts[0]) *
                2 +
                uint256(context.args.paymentAmts[1]) +
                uint256(context.args.paymentAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);

        _configureOfferItem(ItemType.ERC721, context.args.id, 1);
        // set endAmount to 2 * startAmount
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmts[0],
            context.args.paymentAmts[0] * 2
        );
        _configureEthConsiderationItem(alice, context.args.paymentAmts[1]);
        _configureEthConsiderationItem(alice, context.args.paymentAmts[2]);

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

        // minimum amount of eth required to match orders at endTime
        uint256 sumOfPaymentAmts = uint256(context.args.paymentAmts[0]) *
            2 +
            context.args.paymentAmts[1] +
            context.args.paymentAmts[2];

        // aggregate original order's eth consideration items into one mirror offer item
        _configureOfferItem(ItemType.NATIVE, 0, sumOfPaymentAmts);

        // push the original order's offer item into mirrorConsiderationItems
        _configureConsiderationItem(cal, ItemType.ERC721, context.args.id, 1);

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(cal),
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
        fulfillmentComponent = FulfillmentComponent(0, 1);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillmentComponent = FulfillmentComponent(0, 2);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);
        delete fulfillmentComponents;
        delete fulfillment;

        delete offerItems;
        delete considerationItems;

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);

        // set blockTimestamp to right before endTime and set insufficient value for transaction
        vm.warp(block.timestamp + 999);
        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientEtherSupplied.selector
        );
        context.consideration.matchOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(orders, fulfillments);

        // set transaction value to sum of eth consideration items (including endAmount of considerationItem[0])
        context.consideration.matchOrders{ value: sumOfPaymentAmts }(
            orders,
            fulfillments
        );
        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, 1);
        assertEq(totalSize, 1);
    }

    function _testMatchOrdersDescendingOfferAmount(Context memory context)
        internal resetTokenBalancesBetweenRuns
    {
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(uint256(context.args.paymentAmts[0]) * 2 <= 2**128 - 1);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(bob, context.args.id);

        _configureOfferItem(
            ItemType.ERC20,
            context.args.paymentAmts[0] * 2,
            context.args.paymentAmts[0]
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

        OrderParameters
            memory mirrorOrderParameters = createMirrorOrderParameters(
                orderParameters,
                bob,
                context.args.zone,
                conduitKey
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

        // set timeStamp to endTime
        vm.warp(block.timestamp + 999);
        context.consideration.matchOrders(orders, fulfillments);
        assertEq(
            orders[1].parameters.consideration[0].endAmount,
            context.args.paymentAmts[0]
        );
        assertEq(
            orders[0].parameters.offer[0].endAmount,
            orders[1].parameters.consideration[0].endAmount
        );

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, 1);
        assertEq(totalSize, 1);
    }
}
