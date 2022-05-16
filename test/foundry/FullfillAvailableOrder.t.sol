// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { Order, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract FulfillAvailableOrder is BaseOrderTest {
    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint248 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
    }

    function testMatchorderOverflow() public {}

    function _testMatchOrderOverflow(ConsiderationInterface _consideration)
        public
    {
        test721_1.mint(alice, 1);
        OrderParameters memory orderParameters = OrderParameters(
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

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            _consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(orderComponents)
        );

        test721_2.mint(bob, 2);
    }

    function testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        FuzzInputs memory args
    ) public {
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            Context(referenceConsideration, args)
        );
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            Context(consideration, args)
        );
    }

    function testFulfillAndAggregateMultipleOrdersViaFulfillAvailableOrdersEthToErc1155(
        FuzzInputs memory args,
        uint240 amount
    ) public {
        _testFulfillAndAggregateMultipleOrdersViaFulfillAvailableOrdersEthToErc1155(
            Context(referenceConsideration, args),
            amount
        );
        _testFulfillAndAggregateMultipleOrdersViaFulfillAvailableOrdersEthToErc1155(
            Context(consideration, args),
            amount
        );
    }

    function _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
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
                uint256(context.args.paymentAmts[0]),
                uint256(context.args.paymentAmts[0]),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]),
                uint256(context.args.paymentAmts[1]),
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]),
                uint256(context.args.paymentAmts[2]),
                payable(cal)
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

        Order[] memory orders = new Order[](1);
        orders[0] = Order(orderParameters, signature);

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        resetOfferComponents();

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        assertTrue(considerationComponentsArray.length == 3);

        context.consideration.fulfillAvailableOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );
    }

    function _testFulfillAndAggregateMultipleOrdersViaFulfillAvailableOrdersEthToErc1155(
        Context memory context,
        uint240 amount
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(amount > 0);
        vm.assume(
            uint256(context.args.paymentAmts[0]) +
                uint256(context.args.paymentAmts[1]) +
                uint256(context.args.paymentAmts[2]) <=
                2**128 - 1
        );
        vm.assume(
            context.args.paymentAmts[0] % 2 == 0 &&
                context.args.paymentAmts[1] % 2 == 0 &&
                context.args.paymentAmts[2] % 2 == 0
        );

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, uint256(amount) * 2);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                amount,
                amount
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[0]) / 2,
                uint256(context.args.paymentAmts[0]) / 2,
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]) / 2,
                uint256(context.args.paymentAmts[1]) / 2,
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]) / 2,
                uint256(context.args.paymentAmts[2]) / 2,
                payable(cal)
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

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            uint256(context.args.salt) + 1,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getNonce(alice)
        );

        bytes memory secondOrderSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(secondOrderParameters, secondOrderSignature);

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        resetOfferComponents();

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponents.push(FulfillmentComponent(1, 1));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponents.push(FulfillmentComponent(1, 2));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        context.consideration.fulfillAvailableOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );
    }
}
