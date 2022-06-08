// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { OrderType, ItemType } from "../../contracts/lib/ConsiderationEnums.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { AdvancedOrder, OrderParameters, OrderComponents, CriteriaResolver } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { ERC1155Recipient } from "./utils/ERC1155Recipient.sol";
import { ConsiderationEventsAndErrors } from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
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
            ) <= 2**120 - 1
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
            ) <= 2**120 - 1
        );
        _;
    }

    modifier only1155Receiver(address recipient) {
        vm.assume(recipient != address(0));
        if (recipient.code.length > 0) {
            try
                ERC1155Recipient(recipient).onERC1155Received(
                    address(1),
                    address(1),
                    1,
                    1,
                    ""
                )
            returns (bytes4 response) {
                vm.assume(response == onERC1155Received.selector);
            } catch (bytes memory reason) {
                vm.assume(false);
            }
        }
        _;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
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

    function advancedPartialAscendingOfferAmount1155(Context memory context)
        external
        stateless
    {
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

        _configureOfferItem(
            ItemType.ERC1155,
            context.args.tokenId,
            context.tokenAmount.mul(2),
            context.tokenAmount.mul(4)
        );
        // set endAmount to 2 * startAmount
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0].mul(2)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[1].mul(2)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[2].mul(2)
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
            false
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

        _configureOfferItem(
            ItemType.ERC1155,
            context.args.tokenId,
            context.tokenAmount.mul(1000)
        );
        // set endAmount to 2 * startAmount
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0].mul(2),
            context.args.paymentAmounts[0].mul(4)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[1].mul(2)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[2].mul(2)
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

    function testSingleAdvancedPartial1155(
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
            this.singleAdvancedPartial1155,
            Context(consideration, inputs, tokenAmount, 0)
        );
        test(
            this.singleAdvancedPartial1155,
            Context(referenceConsideration, inputs, tokenAmount, 0)
        );
    }

    function singleAdvancedPartial1155(Context memory context)
        external
        stateless
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        _configureERC1155OfferItem(context.args.tokenId, context.tokenAmount);
        _configureEthConsiderationItem(payable(0), 10);
        _configureEthConsiderationItem(alice, 10);
        _configureEthConsiderationItem(bob, 10);
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

    function testAdvancedPartial1155DenominatorOverflow() public {
        test(
            this.advancedPartial1155DenominatorOverflow,
            Context(consideration, empty, 0, 0)
        );
        test(
            this.advancedPartial1155DenominatorOverflow,
            Context(referenceConsideration, empty, 0, 0)
        );
    }

    function advancedPartial1155DenominatorOverflow(Context memory context)
        external
        stateless
    {
        // mint 100 tokens
        test1155_1.mint(alice, 1, 100);

        _configureERC1155OfferItem(1, 100);
        _configureEthConsiderationItem(alice, 100);

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
            AdvancedOrder(baseOrderParameters, 2**118, 2**119, signature, ""),
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
}
