// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { Order, AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, FulfillmentComponent, CriteriaResolver } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";
import { stdError } from "forge-std/Test.sol";

contract FulfillAvailableAdvancedOrder is BaseOrderTest {
    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
    }

    function testFulfillAvailableAdvancedOrderOverflow() public {
        for (uint256 i; i < 4; i++) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            _testFulfillAvailableAdvancedOrdersOverflow(
                consideration,
                ItemType(i)
            );
            _testFulfillAvailableAdvancedOrdersOverflow(
                referenceConsideration,
                ItemType(i)
            );
        }
    }

    function testFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToSingleErc721(
        FuzzInputs memory args
    ) public {
        _testFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToSingleErc721(
            Context(referenceConsideration, args)
        );
        _testFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToSingleErc721(
            Context(consideration, args)
        );
    }

    function testPartialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        FuzzInputs memory args,
        uint80 amount,
        uint80 numerator,
        uint80 denominator
    ) public {
        _testPartialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
            Context(referenceConsideration, args),
            amount,
            numerator,
            denominator
        );
        _testPartialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
            Context(consideration, args),
            amount,
            numerator,
            denominator
        );
    }

    function _testFulfillAvailableAdvancedOrdersOverflow(
        ConsiderationInterface _consideration,
        ItemType itemType
    ) internal resetTokenBalancesBetweenRuns {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureConsiderationItem(alice, itemType, 1, 100);

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

        OrderComponents memory firstOrderComponents = getOrderComponents(
            orderParameters,
            _consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        _configureERC721OfferItem(2);
        // try to overflow the aggregated amount of eth sent to alice
        _configureConsiderationItem(alice, itemType, 1, MAX_INT);

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

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = AdvancedOrder(
            orderParameters,
            uint120(1),
            uint120(1),
            signature,
            "0x"
        );
        advancedOrders[1] = AdvancedOrder(
            secondOrderParameters,
            uint120(1),
            uint120(1),
            secondSignature,
            "0x"
        );

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        resetOfferComponents();

        // agregate eth considerations together
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        CriteriaResolver[] memory criteriaResolvers;

        vm.expectRevert(stdError.arithmeticError);
        _consideration.fulfillAvailableAdvancedOrders{ value: 99 }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            100
        );
    }

    function _testFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToSingleErc721(
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
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

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

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = AdvancedOrder(
            orderParameters,
            uint120(1),
            uint120(1),
            signature,
            "0x"
        );

        CriteriaResolver[] memory criteriaResolvers;

        context.consideration.fulfillAvailableAdvancedOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );
    }

    function _testPartialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        Context memory context,
        uint80 amount,
        uint80 numerator,
        uint80 denominator
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            amount > 0 &&
                numerator > 0 &&
                denominator > 0 &&
                numerator < denominator
        );
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(context.args.paymentAmts[0]) *
                denominator +
                uint256(context.args.paymentAmts[1]) *
                denominator +
                uint256(context.args.paymentAmts[2]) *
                denominator <=
                2**128 - 1
        );

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, uint256(amount) * denominator);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                uint256(amount) * denominator,
                uint256(amount) * denominator
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[0]) * denominator,
                uint256(context.args.paymentAmts[0]) * denominator,
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]) * denominator,
                uint256(context.args.paymentAmts[1]) * denominator,
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]) * denominator,
                uint256(context.args.paymentAmts[2]) * denominator,
                payable(cal)
            )
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

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

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = AdvancedOrder(
            orderParameters,
            numerator,
            denominator,
            signature,
            "0x"
        );

        CriteriaResolver[] memory criteriaResolvers;
        uint256 value = (context.args.paymentAmts[0] +
            context.args.paymentAmts[1] +
            context.args.paymentAmts[2]) * uint256(denominator);

        context.consideration.fulfillAvailableAdvancedOrders{ value: value }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, uint256(numerator));
        assertEq(totalSize, uint256(denominator));
    }
}
