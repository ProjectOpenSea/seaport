// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import { OneWord } from "../../contracts/lib/ConsiderationConstants.sol";
import {
    OrderType,
    ItemType
} from "../../contracts/lib/ConsiderationEnums.sol";
import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    AdvancedOrder,
    OrderParameters,
    OrderComponents,
    CriteriaResolver
} from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { ERC1155Recipient } from "./utils/ERC1155Recipient.sol";
import {
    ConsiderationEventsAndErrors
} from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillAdvancedOrder is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;
    using ArithmeticUtil for uint8;

    FuzzInputs empty;
    struct FuzzInputs {
        uint256 tokenId;
        address zone;
        bytes32 zoneHash;
        uint256 salt;
        uint16 offerAmt;
        // uint16 fulfillAmt;
        address recipient;
        uint120[3] paymentAmounts;
        bool useConduit;
        uint8 numer;
        uint8 denom;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
        uint256 tokenAmount;
        uint256 warpAmount;
    }

    modifier validateInputs(FuzzInputs memory args) {
        vm.assume(args.offerAmt > 0);
        vm.assume(
            args.paymentAmounts[0] > 0 &&
                args.paymentAmounts[1] > 0 &&
                args.paymentAmounts[2] > 0
        );
        vm.assume(
            args.paymentAmounts[0].add(args.paymentAmounts[1]).add(
                args.paymentAmounts[2]
            ) <= 2 ** 120 - 1
        );
        _;
    }

    modifier validateNumerDenom(FuzzInputs memory args) {
        vm.assume(args.numer > 0 && args.denom > 0);
        if (args.numer > args.denom) {
            uint8 temp = args.denom;
            args.denom = args.numer;
            args.numer = temp;
        }
        vm.assume(
            args.paymentAmounts[0] > 0 &&
                args.paymentAmounts[1] > 0 &&
                args.paymentAmounts[2] > 0
        );
        vm.assume(
            args.paymentAmounts[0].add(args.paymentAmounts[1]).add(
                args.paymentAmounts[2]
            ) <= 2 ** 120 - 1
        );
        _;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNoNativeOffersFulfillAdvanced(
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
        }
        addEthOfferItem(1);

        addEthConsiderationItem(alice, 1);

        test(
            this.noNativeOfferItemsFulfillAdvanced,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.noNativeOfferItemsFulfillAdvanced,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function noNativeOfferItemsFulfillAdvanced(
        Context memory context
    ) external stateless {
        configureOrderParameters(alice);
        uint256 counter = context.consideration.getCounter(alice);
        configureOrderComponents(counter);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidNativeOfferItem()"));
        context.consideration.fulfillAdvancedOrder(
            AdvancedOrder(baseOrderParameters, 1, 1, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testAdvancedPartialAscendingOfferAmount1155(
        FuzzInputs memory args,
        uint128 tokenAmount,
        uint256 warpAmount
    ) public validateInputs(args) {
        vm.assume(tokenAmount > 0);

        test(
            this.advancedPartialAscendingOfferAmount1155,
            Context(
                referenceConsideration,
                args,
                tokenAmount,
                warpAmount % 1000
            )
        );
        test(
            this.advancedPartialAscendingOfferAmount1155,
            Context(consideration, args, tokenAmount, warpAmount % 1000)
        );
    }

    function advancedPartialAscendingOfferAmount1155(
        Context memory context
    ) external stateless {
        uint256 sumOfPaymentAmounts = (context.args.paymentAmounts[0].mul(2))
            .add(context.args.paymentAmounts[1].mul(2))
            .add(context.args.paymentAmounts[2].mul(2));
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(
            alice,
            context.args.tokenId,
            context.tokenAmount.mul(4)
        );

        addOfferItem(
            ItemType.ERC1155,
            context.args.tokenId,
            context.tokenAmount.mul(2),
            context.tokenAmount.mul(4)
        );
        // set endAmount to 2 * startAmount
        addEthConsiderationItem(alice, context.args.paymentAmounts[0].mul(2));
        addEthConsiderationItem(alice, context.args.paymentAmounts[1].mul(2));
        addEthConsiderationItem(alice, context.args.paymentAmounts[2].mul(2));

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
            context.consideration.getCounter(alice)
        );

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        delete offerItems;
        delete considerationItems;

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            orderParameters,
            1,
            2,
            signature,
            ""
        );

        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + context.warpAmount);
        // calculate current amount of order based on warpAmount, round down since it's an offer
        // and divide by two to fulfill half of the order
        uint256 currentAmount = _locateCurrentAmount(
            context.tokenAmount * 2,
            context.tokenAmount * 4,
            startTime,
            startTime + 1000,
            false // don't round up offers
        ) / 2;
        // set transaction value to sum of eth consideration items (including endAmount of considerationItem[0])
        vm.expectEmit(false, true, true, true, address(test1155_1));
        emit TransferSingle(
            address(0),
            alice,
            address(this),
            context.args.tokenId,
            currentAmount
        );
        context.consideration.fulfillAdvancedOrder{
            value: sumOfPaymentAmounts
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0), address(0));
        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, 1);
        assertEq(totalSize, 2);
    }

    function testAdvancedPartialAscendingConsiderationAmount1155(
        FuzzInputs memory inputs,
        uint128 tokenAmount
    ) public validateInputs(inputs) {
        vm.assume(tokenAmount > 0);
        test(
            this.advancedPartialAscendingConsiderationAmount1155,
            Context(referenceConsideration, inputs, tokenAmount, 0)
        );
        test(
            this.advancedPartialAscendingConsiderationAmount1155,
            Context(consideration, inputs, tokenAmount, 0)
        );
    }

    function advancedPartialAscendingConsiderationAmount1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(
            alice,
            context.args.tokenId,
            context.tokenAmount.mul(1000)
        );

        addOfferItem(
            ItemType.ERC1155,
            context.args.tokenId,
            context.tokenAmount.mul(1000)
        );
        // set endAmount to 2 * startAmount
        addEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0].mul(2),
            context.args.paymentAmounts[0].mul(4)
        );
        addEthConsiderationItem(alice, context.args.paymentAmounts[1].mul(2));
        addEthConsiderationItem(alice, context.args.paymentAmounts[2].mul(2));

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
            context.consideration.getCounter(alice)
        );

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        delete offerItems;
        delete considerationItems;

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            orderParameters,
            1,
            2,
            signature,
            ""
        );

        // set blockTimestamp to right before endTime and set insufficient value for transaction
        vm.warp(block.timestamp + 999);
        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientEtherSupplied.selector
        );
        context.consideration.fulfillAdvancedOrder{
            value: context
                .args
                .paymentAmounts[0]
                .add(context.args.paymentAmounts[1])
                .add(context.args.paymentAmounts[2])
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0), address(0));

        uint256 sumOfPaymentAmounts = (context.args.paymentAmounts[0].mul(4))
            .add((context.args.paymentAmounts[1].mul(2)))
            .add((context.args.paymentAmounts[2].mul(2)));

        // set transaction value to sum of eth consideration items (including endAmount of considerationItem[0])
        context.consideration.fulfillAdvancedOrder{
            value: sumOfPaymentAmounts
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0), address(0));

        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, 1);
        assertEq(totalSize, 2);
    }

    function testSingleAdvanced1155(
        FuzzInputs memory inputs,
        uint128 tokenAmount
    )
        public
        validateInputs(inputs)
        validateNumerDenom(inputs)
        onlyPayable(inputs.zone)
        only1155Receiver(inputs.recipient)
    {
        vm.assume(tokenAmount > 0);

        test(
            this.singleAdvanced1155,
            Context(consideration, inputs, tokenAmount, 0)
        );
        test(
            this.singleAdvanced1155,
            Context(referenceConsideration, inputs, tokenAmount, 0)
        );
    }

    function singleAdvanced1155(Context memory context) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        addErc1155OfferItem(context.args.tokenId, context.tokenAmount);
        addEthConsiderationItem(payable(0), 10);
        addEthConsiderationItem(alice, 10);
        addEthConsiderationItem(bob, 10);
        uint256 counter = referenceConsideration.getCounter(alice);
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
            counter
        );
        bytes32 orderHash = consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(consideration, alicePk, orderHash);

        OrderParameters memory orderParameters = OrderParameters(
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
            3
        );
        uint256 value = 30;

        consideration.fulfillAdvancedOrder{ value: value }(
            AdvancedOrder(orderParameters, 1, 1, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            context.args.recipient
        );

        assertEq(
            context.tokenAmount,
            test1155_1.balanceOf(context.args.recipient, context.args.tokenId)
        );
    }

    function testPartialFulfillEthTo1155DenominatorOverflow() public {
        test(
            this.partialFulfillEthTo1155DenominatorOverflow,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155DenominatorOverflow,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155DenominatorOverflow(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        // Create an order to fulfill half of the original offer.
        context.consideration.fulfillAdvancedOrder{ value: 50 }(
            AdvancedOrder(
                baseOrderParameters,
                2 ** 118,
                2 ** 119,
                signature,
                ""
            ),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );

        // Create a second order to fulfill one-tenth of the original offer.
        // The denominator will overflow when combined with that of the first order.
        context.consideration.fulfillAdvancedOrder{ value: 10 }(
            AdvancedOrder(baseOrderParameters, 1, 10, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );

        // Assert six-tenths of the order has been fulfilled.
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

    function testPartialFulfillEthTo1155DenominatorOverflowToZero() public {
        test(
            this.partialFulfillEthTo1155DenominatorOverflowToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155DenominatorOverflowToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155DenominatorOverflowToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            baseOrderParameters,
            2 ** 119,
            2 ** 119,
            signature,
            ""
        );

        // set denominator to 2 ** 120
        assembly {
            mstore(add(0x40, advancedOrder), shl(120, 1))
        }

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        context.consideration.fulfillAdvancedOrder(
            advancedOrder,
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testPartialFulfillEthTo1155NumeratorOverflowToZero() public {
        test(
            this.partialFulfillEthTo1155NumeratorOverflowToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155NumeratorOverflowToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155NumeratorOverflowToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            baseOrderParameters,
            2 ** 119,
            2 ** 119,
            signature,
            ""
        );

        // set numerator to 2 ** 120
        assembly {
            mstore(add(0x20, advancedOrder), shl(120, 1))
        }

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        context.consideration.fulfillAdvancedOrder(
            advancedOrder,
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testPartialFulfillEthTo1155NumeratorDenominatorOverflowToZero()
        public
    {
        test(
            this.partialFulfillEthTo1155NumeratorDenominatorOverflowToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155NumeratorDenominatorOverflowToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155NumeratorDenominatorOverflowToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            baseOrderParameters,
            2 ** 119,
            2 ** 119,
            signature,
            ""
        );

        // set both numerator and denominator to 2 ** 120
        assembly {
            mstore(add(0x20, advancedOrder), shl(120, 1))
            mstore(add(0x40, advancedOrder), shl(120, 1))
        }

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        context.consideration.fulfillAdvancedOrder(
            advancedOrder,
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testPartialFulfillEthTo1155NumeratorSetToZero() public {
        test(
            this.partialFulfillEthTo1155NumeratorSetToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155NumeratorSetToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155NumeratorSetToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        // Call fulfillAdvancedOrder with an order with a numerator of 0.
        context.consideration.fulfillAdvancedOrder{ value: 50 }(
            AdvancedOrder(baseOrderParameters, 0, 2, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testPartialFulfillEthTo1155DenominatorSetToZero() public {
        test(
            this.partialFulfillEthTo1155DenominatorSetToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155DenominatorSetToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155DenominatorSetToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        // Call fulfillAdvancedOrder with an order with a denominator of 0.
        context.consideration.fulfillAdvancedOrder{ value: 50 }(
            AdvancedOrder(baseOrderParameters, 1, 0, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function testpartialFulfillEthTo1155NumeratorDenominatorSetToZero() public {
        test(
            this.partialFulfillEthTo1155NumeratorDenominatorSetToZero,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.partialFulfillEthTo1155NumeratorDenominatorSetToZero,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function partialFulfillEthTo1155NumeratorDenominatorSetToZero(
        Context memory context
    ) external stateless {
        // mint 100 tokens
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

        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        // Call fulfillAdvancedOrder with an order with a numerator and denominator of 0.
        context.consideration.fulfillAdvancedOrder{ value: 50 }(
            AdvancedOrder(baseOrderParameters, 0, 0, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }
}
