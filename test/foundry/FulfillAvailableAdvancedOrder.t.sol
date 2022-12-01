// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {
    OrderType,
    BasicOrderType,
    ItemType,
    Side
} from "../../contracts/lib/ConsiderationEnums.sol";
import {
    AdditionalRecipient
} from "../../contracts/lib/ConsiderationStructs.sol";
import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    Order,
    AdvancedOrder,
    OfferItem,
    OrderParameters,
    ConsiderationItem,
    OrderComponents,
    BasicOrderParameters,
    FulfillmentComponent,
    CriteriaResolver
} from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";
import { ERC1155Recipient } from "./utils/ERC1155Recipient.sol";
import { stdError } from "forge-std/Test.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillAvailableAdvancedOrder is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint80;

    FuzzInputs empty;

    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        address recipient;
        uint128[3] paymentAmts;
        bool useConduit;
        uint80 amount;
        uint80 numer;
        uint80 denom;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
        ItemType itemType;
    }

    modifier validateInputs(FuzzInputs memory inputs) {
        vm.assume(inputs.amount > 0);
        vm.assume(
            inputs.paymentAmts[0] > 0 &&
                inputs.paymentAmts[1] > 0 &&
                inputs.paymentAmts[2] > 0
        );
        vm.assume(
            inputs.paymentAmts[0].add(inputs.paymentAmts[1]).add(
                inputs.paymentAmts[2]
            ) <= 2**128 - 1
        );
        _;
    }

    modifier validateNumerDenom(FuzzInputs memory inputs) {
        vm.assume(inputs.amount > 0 && inputs.numer > 0 && inputs.denom > 0);
        if (inputs.numer > inputs.denom) {
            uint80 temp = inputs.numer;
            inputs.numer = inputs.denom;
            inputs.denom = temp;
        }
        vm.assume(
            inputs.paymentAmts[0].mul(inputs.denom) +
                inputs.paymentAmts[1].mul(inputs.denom) +
                inputs.paymentAmts[2].mul(inputs.denom) <=
                2**128 - 1
        );
        _;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNoNativeOffersFulfillAvailableAdvanced(
        uint8[8] memory itemTypes
    ) public {
        uint256 tokenId;
        for (uint256 i; i < 8; i++) {
            ItemType itemType = ItemType(itemTypes[i] % 4);
            if (itemType == ItemType.NATIVE) {
                addEthOfferItem(1);
            } else if (itemType == ItemType.ERC20) {
                addErc20OfferItem(1);
            } else if (itemType == ItemType.ERC1155) {
                test1155_1.mint(alice, tokenId, 1);
                addErc1155OfferItem(tokenId, 1);
            } else {
                test721_1.mint(alice, tokenId);
                addErc721OfferItem(tokenId);
            }
            tokenId++;
            offerComponents.push(FulfillmentComponent(1, i));
        }
        addEthOfferItem(1);

        addEthConsiderationItem(alice, 1);
        considerationComponents.push(FulfillmentComponent(1, 0));

        test(
            this.noNativeOfferItemsFulfillAvailableAdvanced,
            Context(consideration, empty, ItemType(0))
        );
        test(
            this.noNativeOfferItemsFulfillAvailableAdvanced,
            Context(referenceConsideration, empty, ItemType(0))
        );
    }

    function noNativeOfferItemsFulfillAvailableAdvanced(Context memory context)
        external
        stateless
    {
        configureOrderParameters(alice);
        uint256 counter = context.consideration.getCounter(alice);
        _configureOrderComponents(counter);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[1] = AdvancedOrder(baseOrderParameters, 1, 1, signature, "");
        offerComponentsArray.push(offerComponents);
        considerationComponentsArray.push(considerationComponents);

        delete offerItems;
        delete considerationItems;
        delete offerComponents;
        delete considerationComponents;

        token1.mint(alice, 100);
        addErc20OfferItem(100);
        addEthConsiderationItem(alice, 1);
        configureOrderParameters(alice);
        counter = context.consideration.getCounter(alice);
        _configureOrderComponents(counter);
        bytes32 orderHash2 = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature2 = signOrder(
            context.consideration,
            alicePk,
            orderHash2
        );
        offerComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        considerationComponentsArray.push(considerationComponents);

        orders[0] = AdvancedOrder(baseOrderParameters, 1, 1, signature2, "");

        vm.expectRevert(abi.encodeWithSignature("InvalidNativeOfferItem()"));
        context.consideration.fulfillAvailableAdvancedOrders{ value: 2 }(
            orders,
            new CriteriaResolver[](0),
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            2
        );
    }

    function testFulfillAvailableAdvancedOrderOverflow() public {
        for (uint256 i; i < 4; ++i) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.fulfillAvailableAdvancedOrdersOverflow,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.fulfillAvailableAdvancedOrdersOverflow,
                Context(referenceConsideration, empty, ItemType(i))
            );
        }
    }

    function testFulfillAvailableAdvancedOrderMissingItemAmount() public {
        for (uint256 i; i < 4; ++i) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.fulfillAvailableAdvancedOrdersMissingItemAmount,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.fulfillAvailableAdvancedOrdersMissingItemAmount,
                Context(referenceConsideration, empty, ItemType(i))
            );
        }
    }

    function testFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        FuzzInputs memory args
    )
        public
        validateInputs(args)
        onlyPayable(args.zone)
        only1155Receiver(args.zone)
        onlyPayable(args.recipient)
        only1155Receiver(args.recipient)
    {
        test(
            this
                .fulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155,
            Context(referenceConsideration, args, ItemType(0))
        );
        test(
            this
                .fulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155,
            Context(consideration, args, ItemType(0))
        );
    }

    function testPartialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        FuzzInputs memory args
    )
        public
        validateInputs(args)
        onlyPayable(args.zone)
        only1155Receiver(args.zone)
        onlyPayable(args.recipient)
        only1155Receiver(args.recipient)
        validateNumerDenom(args)
    {
        test(
            this
                .partialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155,
            Context(referenceConsideration, args, ItemType(0))
        );
        test(
            this
                .partialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155,
            Context(consideration, args, ItemType(0))
        );
    }

    function fulfillAvailableAdvancedOrdersOverflow(Context memory context)
        external
        stateless
    {
        test721_1.mint(alice, 1);
        addErc721OfferItem(1);
        addConsiderationItem(alice, context.itemType, 1, 100);

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
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        addErc721OfferItem(2);
        // try to overflow the aggregated amount sent to alice
        addConsiderationItem(alice, context.itemType, 1, MAX_INT);

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
            context.consideration.getCounter(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
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
        delete offerComponents;

        // aggregate eth considerations together
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        CriteriaResolver[] memory criteriaResolvers;

        vm.expectRevert(stdError.arithmeticError);
        context.consideration.fulfillAvailableAdvancedOrders{ value: 99 }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            100
        );
    }

    function fulfillAvailableAdvancedOrdersMissingItemAmount(
        Context memory context
    ) external stateless {
        test721_1.mint(alice, 1);
        addErc721OfferItem(1);
        addConsiderationItem(alice, context.itemType, 1, 100);

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
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        addErc721OfferItem(2);
        // try to overflow the aggregated amount sent to alice
        addConsiderationItem(alice, context.itemType, 1, MAX_INT);
        addConsiderationItem(alice, context.itemType, 1, 0);

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
            context.consideration.getCounter(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
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
        delete offerComponents;

        // aggregate eth considerations together
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponents.push(FulfillmentComponent(1, 1));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        CriteriaResolver[] memory criteriaResolvers;

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        context.consideration.fulfillAvailableAdvancedOrders{ value: 99 }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            100
        );
    }

    function fulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.args.amount);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.args.amount,
                context.args.amount
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                10,
                10,
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                10,
                10,
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                10,
                10,
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
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

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

        context.consideration.fulfillAvailableAdvancedOrders{ value: 30 }(
            advancedOrders,
            new CriteriaResolver[](0),
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            bob,
            100
        );

        assertEq(
            test1155_1.balanceOf(bob, context.args.id),
            context.args.amount
        );
    }

    function partialFulfillSingleOrderViaFulfillAvailableAdvancedOrdersEthToErc1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(
            alice,
            context.args.id,
            context.args.amount.mul(context.args.denom)
        );

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.args.amount.mul(context.args.denom),
                context.args.amount.mul(context.args.denom)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0].mul(context.args.denom),
                context.args.paymentAmts[0].mul(context.args.denom),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1].mul(context.args.denom),
                context.args.paymentAmts[1].mul(context.args.denom),
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2].mul(context.args.denom),
                context.args.paymentAmts[2].mul(context.args.denom),
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
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

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
            context.args.numer,
            context.args.denom,
            signature,
            "0x"
        );

        CriteriaResolver[] memory criteriaResolvers;
        uint256 value = (context.args.paymentAmts[0] +
            context.args.paymentAmts[1] +
            context.args.paymentAmts[2]).mul(context.args.denom);

        context.consideration.fulfillAvailableAdvancedOrders{ value: value }(
            advancedOrders,
            criteriaResolvers,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            address(0),
            100
        );

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, context.args.numer);
        assertEq(totalSize, context.args.denom);
    }

    function testPartialFulfillDenominatorOverflowEthToErc1155() public {
        test(
            this.partialFulfillDenominatorOverflowEthToErc1155,
            Context(referenceConsideration, empty, ItemType(0))
        );
        test(
            this.partialFulfillDenominatorOverflowEthToErc1155,
            Context(consideration, empty, ItemType(0))
        );
    }

    function partialFulfillDenominatorOverflowEthToErc1155(
        Context memory context
    ) external stateless {
        // Mint 100 tokens to alice.
        test1155_1.mint(alice, 1, 100);

        addErc1155OfferItem(1, 100);
        addEthConsiderationItem(alice, 100);

        _configureOrderParameters(alice, address(0), bytes32(0), 0, false);
        baseOrderParameters.orderType = OrderType.PARTIAL_OPEN;
        OrderComponents memory orderComponents = getOrderComponents(
            baseOrderParameters,
            context.consideration.getCounter(alice)
        );
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = context.consideration.getOrderStatus(orderHash);
            assertFalse(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, 0);
            assertEq(totalSize, 0);
        }

        // Aggregate the orders in an AdvancedOrder array.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = AdvancedOrder(
            baseOrderParameters,
            2**118,
            2**119,
            signature,
            ""
        );
        orders[1] = AdvancedOrder(baseOrderParameters, 1, 10, signature, "");

        // Aggregate the erc1155 offers together.
        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        // Aggregate the eth considerations together.
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        // Pass in the AdvancedOrder array and fulfill both partially-fulfillable orders.
        context.consideration.fulfillAvailableAdvancedOrders{ value: 60 }(
            orders,
            new CriteriaResolver[](0),
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            100
        );

        // Assert six-tenths of the offer has been fulfilled.
        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = context.consideration.getOrderStatus(orderHash);
            assertTrue(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, 6);

            assertEq(totalSize, 10);
            assertEq(60, test1155_1.balanceOf(address(this), 1));
        }
    }

    function testPartialFulfillDenominatorOverflowEthToErc1155NonAggregated()
        public
    {
        test(
            this.partialFulfillDenominatorOverflowEthToErc1155NonAggregated,
            Context(referenceConsideration, empty, ItemType(0))
        );
        test(
            this.partialFulfillDenominatorOverflowEthToErc1155NonAggregated,
            Context(consideration, empty, ItemType(0))
        );
    }

    function partialFulfillDenominatorOverflowEthToErc1155NonAggregated(
        Context memory context
    ) external stateless {
        // Mint 100 tokens to alice.
        test1155_1.mint(alice, 1, 100);

        addErc1155OfferItem(1, 100);
        addEthConsiderationItem(alice, 100);

        _configureOrderParameters(alice, address(0), bytes32(0), 0, false);
        baseOrderParameters.orderType = OrderType.PARTIAL_OPEN;
        OrderComponents memory orderComponents = getOrderComponents(
            baseOrderParameters,
            context.consideration.getCounter(alice)
        );
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = context.consideration.getOrderStatus(orderHash);
            assertFalse(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, 0);
            assertEq(totalSize, 0);
        }

        // Aggregate the orders in an AdvancedOrder array.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = AdvancedOrder(
            baseOrderParameters,
            2**118,
            2**119,
            signature,
            ""
        );
        orders[1] = AdvancedOrder(baseOrderParameters, 1, 10, signature, "");

        // Add the offer components of the two orders separately to the offer components array.
        // This results in two separate transfers of erc1155 tokens as opposed to one aggregated transfer.
        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        // Add the consideration components corresponding to the offer components.
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        // Pass in the AdvancedOrder array and fulfill both partially-fulfillable orders.
        context.consideration.fulfillAvailableAdvancedOrders{ value: 60 }(
            orders,
            new CriteriaResolver[](0),
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            100
        );

        // Assert six-tenths of the offer has been fulfilled.
        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = context.consideration.getOrderStatus(orderHash);
            assertTrue(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, 6);

            assertEq(totalSize, 10);
            assertEq(60, test1155_1.balanceOf(address(this), 1));
        }
    }
}
