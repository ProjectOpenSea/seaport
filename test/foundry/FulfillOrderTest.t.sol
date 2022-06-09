// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { Order, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillOrderTest is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;
    using ArithmeticUtil for uint8;

    struct FuzzInputsCommon {
        address zone;
        uint128 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint120 startAmount;
        uint120 endAmount;
        uint16 warpAmount;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
        uint256 erc1155amt;
        uint128 tipAmt;
        uint8 numTips;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    modifier validateInputs(FuzzInputsCommon memory args) {
        vm.assume(
            args.paymentAmts[0] > 0 &&
                args.paymentAmts[1] > 0 &&
                args.paymentAmts[2] > 0
        );
        vm.assume(
            args.paymentAmts[0].add(args.paymentAmts[1]).add(
                args.paymentAmts[2]
            ) <= uint128(MAX_INT)
        );
        _;
    }

    modifier validateInputsWithTip(
        FuzzInputsCommon memory args,
        uint256 tipAmt
    ) {
        vm.assume(
            args.paymentAmts[0] > 0 &&
                args.paymentAmts[1] > 0 &&
                args.paymentAmts[2] > 0 &&
                tipAmt > 0
        );
        vm.assume(
            args
                .paymentAmts[0]
                .add(args.paymentAmts[1])
                .add(args.paymentAmts[2])
                .add(tipAmt) <= uint128(MAX_INT)
        );
        _;
    }

    modifier validateInputsWithMultipleTips(
        FuzzInputsCommon memory args,
        uint256 numTips
    ) {
        {
            numTips = (numTips % 64) + 1;
            vm.assume(
                args.paymentAmts[0] > 0 &&
                    args.paymentAmts[1] > 0 &&
                    args.paymentAmts[2] > 0
            );
            vm.assume(
                args
                    .paymentAmts[0]
                    .add(args.paymentAmts[1])
                    .add(args.paymentAmts[2])
                    .add(numTips.mul(numTips + 1).div(2)) <= uint128(MAX_INT)
            );
        }
        _;
    }

    function testFulfillAscendingDescendingOffer(FuzzInputsCommon memory inputs)
        public
        validateInputs(inputs)
        onlyPayable(inputs.zone)
    {
        vm.assume(inputs.startAmount > 0 && inputs.endAmount > 0);
        inputs.warpAmount %= 1000;
        test(
            this.fulfillAscendingDescendingOffer,
            Context(referenceConsideration, inputs, 0, 0, 0)
        );
        test(
            this.fulfillAscendingDescendingOffer,
            Context(consideration, inputs, 0, 0, 0)
        );
    }

    function fulfillAscendingDescendingOffer(Context memory context)
        external
        stateless
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);
        token1.mint(
            alice,
            (
                context.args.endAmount > context.args.startAmount
                    ? context.args.endAmount
                    : context.args.startAmount
            ).mul(1000)
        );
        _configureERC20OfferItem(
            context.args.startAmount.mul(1000),
            context.args.endAmount.mul(1000)
        );
        _configureEthConsiderationItem(alice, 1000);
        OrderParameters memory orderParameters = OrderParameters(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            bytes32(0),
            context.args.salt,
            conduitKey,
            1
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + context.args.warpAmount);
        uint256 expectedAmount = _locateCurrentAmount(
            context.args.startAmount.mul(1000),
            context.args.endAmount.mul(1000),
            startTime,
            startTime + 1000,
            false // don't round up offers
        );
        vm.expectEmit(true, true, true, false, address(token1));
        emit Transfer(alice, address(this), expectedAmount);
        context.consideration.fulfillOrder{ value: 1000 }(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function testFulfillAscendingDescendingConsideration(
        FuzzInputsCommon memory inputs,
        uint256 erc1155amt
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(inputs.startAmount > 0 && inputs.endAmount > 0);
        vm.assume(erc1155amt > 0);
        test(
            this.fulfillAscendingDescendingConsideration,
            Context(referenceConsideration, inputs, erc1155amt, 0, 0)
        );
        test(
            this.fulfillAscendingDescendingConsideration,
            Context(consideration, inputs, erc1155amt, 0, 0)
        );
    }

    function fulfillAscendingDescendingConsideration(Context memory context)
        external
        stateless
    {
        context.args.warpAmount %= 1000;
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        _configureERC1155OfferItem(context.args.id, context.erc1155amt);

        _configureErc20ConsiderationItem(
            alice,
            context.args.startAmount.mul(1000),
            context.args.endAmount.mul(1000)
        );
        OrderParameters memory orderParameters = OrderParameters(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1000,
            bytes32(0),
            context.args.salt,
            conduitKey,
            1
        );
        delete offerItems;
        delete considerationItems;

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + context.args.warpAmount);
        uint256 expectedAmount = _locateCurrentAmount(
            context.args.startAmount.mul(1000),
            context.args.endAmount.mul(1000),
            startTime,
            startTime + 1000,
            true // round up considerations
        );
        token1.mint(address(this), expectedAmount);
        vm.expectEmit(true, true, true, false, address(token1));
        emit Transfer(address(this), address(alice), expectedAmount);
        context.consideration.fulfillOrder(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function testFulfillOrderEthToErc721(FuzzInputsCommon memory inputs)
        public
        validateInputs(inputs)
        onlyPayable(inputs.zone)
    {
        test(
            this.fulfillOrderEthToErc721,
            Context(referenceConsideration, inputs, 0, 0, 0)
        );
        test(
            this.fulfillOrderEthToErc721,
            Context(consideration, inputs, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(tokenAmount > 0);
        test(
            this.fulfillOrderEthToErc1155,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this.fulfillOrderEthToErc1155,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithSingleTip(
        FuzzInputsCommon memory inputs,
        uint128 tipAmt
    ) public onlyPayable(inputs.zone) {
        vm.assume(
            inputs.paymentAmts[0] > 0 &&
                inputs.paymentAmts[1] > 0 &&
                inputs.paymentAmts[2] > 0 &&
                tipAmt > 0
        );
        vm.assume(
            inputs.paymentAmts[0].add(inputs.paymentAmts[1]).add(
                inputs.paymentAmts[2].add(tipAmt)
            ) <= uint128(MAX_INT)
        );
        test(
            this.fulfillOrderEthToErc721WithSingleEthTip,
            Context(referenceConsideration, inputs, 0, tipAmt, 0)
        );
        test(
            this.fulfillOrderEthToErc721WithSingleEthTip,
            Context(consideration, inputs, 0, tipAmt, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithSingleTip(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint128 tipAmt
    ) public onlyPayable(inputs.zone) {
        vm.assume(tokenAmt > 0);
        vm.assume(
            inputs.paymentAmts[0] > 0 &&
                inputs.paymentAmts[1] > 0 &&
                inputs.paymentAmts[2] > 0 &&
                tipAmt > 0
        );
        vm.assume(
            inputs.paymentAmts[0].add(inputs.paymentAmts[1]).add(
                inputs.paymentAmts[2].add(tipAmt)
            ) <= uint128(MAX_INT)
        );
        test(
            this.fulfillOrderEthToErc1155WithSingleEthTip,
            Context(referenceConsideration, inputs, tokenAmt, tipAmt, 0)
        );
        test(
            this.fulfillOrderEthToErc1155WithSingleEthTip,
            Context(consideration, inputs, tokenAmt, tipAmt, 0)
        );
    }

    function testFulfillOrderEthToErc721WithMultipleTips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    )
        public
        validateInputsWithMultipleTips(inputs, numTips)
        onlyPayable(inputs.zone)
    {
        test(
            this.fulfillOrderEthToErc721WithMultipleEthTips,
            Context(referenceConsideration, inputs, 0, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc721WithMultipleEthTips,
            Context(consideration, inputs, 0, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc1155WithMultipleTips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    )
        public
        validateInputsWithMultipleTips(inputs, numTips)
        onlyPayable(inputs.zone)
    {
        vm.assume(tokenAmt > 0);

        test(
            this.fulfillOrderEthToErc1155WithMultipleEthTips,
            Context(referenceConsideration, inputs, tokenAmt, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc1155WithMultipleEthTips,
            Context(consideration, inputs, tokenAmt, 0, numTips)
        );
    }

    function testFulfillOrderSingleErc20ToSingleErc1155(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(tokenAmt > 0);
        test(
            this.fulfillOrderSingleErc20ToSingleErc1155,
            Context(referenceConsideration, inputs, tokenAmt, 0, 0)
        );
        test(
            this.fulfillOrderSingleErc20ToSingleErc1155,
            Context(consideration, inputs, tokenAmt, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithErc721Tips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    )
        public
        validateInputsWithMultipleTips(inputs, numTips)
        onlyPayable(inputs.zone)
    {
        vm.assume(numTips > 0);
        test(
            this.fulfillOrderEthToErc721WithErc721Tips,
            Context(referenceConsideration, inputs, 0, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc721WithErc721Tips,
            Context(consideration, inputs, 0, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc1155WithErc721Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    )
        public
        validateInputsWithMultipleTips(inputs, numTips)
        onlyPayable(inputs.zone)
    {
        vm.assume(tokenAmt > 0);
        test(
            this.fulfillOrderEthToErc1155WithErc721Tips,
            Context(referenceConsideration, inputs, tokenAmt, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc1155WithErc721Tips,
            Context(consideration, inputs, tokenAmt, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc721WithErc1155Tips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        test(
            this.fulfillOrderEthToErc721WithErc1155Tips,
            Context(referenceConsideration, inputs, 0, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc721WithErc1155Tips,
            Context(consideration, inputs, 0, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc1155WithErc1155Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(tokenAmt > 0);
        test(
            this.fulfillOrderEthToErc1155WithErc1155Tips,
            Context(referenceConsideration, inputs, tokenAmt, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc1155WithErc1155Tips,
            Context(consideration, inputs, tokenAmt, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc721WithErc20Tips(
        FuzzInputsCommon memory inputs
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        test(
            this.fulfillOrderEthToErc721WithErc20Tips,
            Context(referenceConsideration, inputs, 0, 0, 0)
        );
        test(
            this.fulfillOrderEthToErc721WithErc20Tips,
            Context(consideration, inputs, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithErc20Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    )
        public
        validateInputsWithMultipleTips(inputs, numTips)
        onlyPayable(inputs.zone)
    {
        vm.assume(tokenAmt > 0);
        test(
            this.fulfillOrderEthToErc1155WithErc20Tips,
            Context(referenceConsideration, inputs, tokenAmt, 0, numTips)
        );
        test(
            this.fulfillOrderEthToErc1155WithErc20Tips,
            Context(consideration, inputs, tokenAmt, 0, numTips)
        );
    }

    function testFulfillOrderEthToErc721FullRestricted(
        FuzzInputsCommon memory inputs
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        test(
            this.fulfillOrderEthToErc721FullRestricted,
            Context(referenceConsideration, inputs, 0, 0, 0)
        );
        test(
            this.fulfillOrderEthToErc721FullRestricted,
            Context(consideration, inputs, 0, 0, 0)
        );
    }

    function fulfillOrderEthToErc721(Context memory context)
        external
        stateless
    {
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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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
        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155(Context memory context)
        external
        stateless
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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
        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderSingleErc20ToSingleErc1155(Context memory context)
        external
        stateless
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721WithSingleEthTip(Context memory context)
        external
        stateless
    {
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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        // Add tip
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.tipAmt,
                context.tipAmt,
                payable(bob)
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
            considerationItems.length - 1
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.tipAmt)
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155WithSingleEthTip(Context memory context)
        external
        stateless
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        // Add tip
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.tipAmt,
                context.tipAmt,
                payable(bob)
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
            considerationItems.length - 1
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.tipAmt)
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721WithMultipleEthTips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        uint128 sumOfTips;
        for (uint128 i = 1; i < context.numTips + 1; ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            sumOfTips += i;
            considerationItems.push(
                ConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(sumOfTips)
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155WithMultipleEthTips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        uint128 sumOfTips;
        // push tip of amount i eth to considerationitems
        for (uint128 i = 1; i < context.numTips + 1; ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            sumOfTips += i;
            considerationItems.push(
                ConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(sumOfTips)
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721WithErc721Tips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < context.numTips + 1; ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test721_2.mint(address(this), i); // mint test721_2 tokens to avoid collision with fuzzed test721_1 tokenId
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC721,
                    address(test721_2),
                    i,
                    1,
                    1,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155WithErc721Tips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < context.numTips + 1; ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test721_2.mint(address(this), i); // mint test721_2 tokens to avoid collision with fuzzed test721_1 tokenId
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC721,
                    address(test721_2),
                    i,
                    1,
                    1,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721WithErc1155Tips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        for (uint256 i = 1; i < context.numTips.add(1); ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test1155_1.mint(address(this), context.args.id.add(i), i);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC1155,
                    address(test1155_1),
                    context.args.id.add(i),
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155WithErc1155Tips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        for (uint256 i = 1; i < context.numTips.add(1); ++i) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test1155_1.mint(address(this), context.args.id.add(i), i);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC1155,
                    address(test1155_1),
                    context.args.id.add(i),
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721WithErc20Tips(Context memory context)
        external
        stateless
    {
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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        for (uint256 i = 1; i < context.numTips.add(1); ++i) {
            uint256 tipPk = i;
            address tipAddr = vm.addr(tipPk);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC20,
                    address(token1),
                    0, // ignored for ERC20
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc1155WithErc20Tips(Context memory context)
        external
        stateless
    {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155amt,
                context.erc1155amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
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

        for (uint256 i = 1; i < context.numTips.add(1); ++i) {
            uint256 tipPk = i;
            address tipAddr = vm.addr(tipPk);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC20,
                    address(token1),
                    0, // ignored for ERC20
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - context.numTips
        );

        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }

    function fulfillOrderEthToErc721FullRestricted(Context memory context)
        external
        stateless
    {
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
                context.args.paymentAmts[0],
                context.args.paymentAmts[0],
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[1],
                context.args.paymentAmts[1],
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                context.args.paymentAmts[2],
                context.args.paymentAmts[2],
                payable(cal)
            )
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_RESTRICTED,
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

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_RESTRICTED,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );
        vm.prank(alice);
        context.consideration.fulfillOrder{
            value: context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
        }(Order(orderParameters, signature), conduitKey);
    }
}
