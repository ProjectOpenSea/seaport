// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

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
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
        uint256 erc1155amt;
        uint128 tipAmt;
        uint8 numTips;
        uint120 startAmount;
        uint120 endAmount;
        uint16 warpAmount;
    }

    function testFulfillAscendingDescendingOffer(
        FuzzInputsCommon memory inputs,
        uint120 startAmount,
        uint120 endAmount,
        uint16 warpAmount
    ) public {
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
        vm.assume(startAmount > 0 && endAmount > 0);
        _testFulfillAscendingDescendingOffer(
            Context(
                referenceConsideration,
                inputs,
                0,
                0,
                0,
                startAmount,
                endAmount,
                warpAmount % 1000
            )
        );
        _testFulfillAscendingDescendingOffer(
            Context(
                consideration,
                inputs,
                0,
                0,
                0,
                startAmount,
                endAmount,
                warpAmount % 1000
            )
        );
    }

    function _testFulfillAscendingDescendingOffer(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        emit log_named_uint("start amount", context.startAmount);
        emit log_named_uint("end amount", context.startAmount);

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);
        token1.mint(
            alice,
            (
                context.endAmount > context.startAmount
                    ? context.endAmount
                    : context.startAmount
            ).mul(1000)
        );
        _configureERC20OfferItem(
            context.startAmount.mul(1000),
            context.endAmount.mul(1000)
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        vm.warp(block.timestamp + context.warpAmount);
        uint256 expectedAmount = _locateCurrentAmount(
            context.startAmount.mul(1000),
            context.endAmount.mul(1000),
            context.warpAmount,
            1000 - context.warpAmount,
            1000,
            true // for consideration
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
        uint256 erc1155amt,
        uint120 startAmount,
        uint120 endAmount,
        uint16 warpAmount
    ) public {
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
        vm.assume(startAmount > 0 && endAmount > 0);
        vm.assume(erc1155amt > 0);
        _testFulfillAscendingDescendingConsideration(
            Context(
                referenceConsideration,
                inputs,
                erc1155amt,
                0,
                0,
                startAmount,
                endAmount,
                warpAmount % 1000
            )
        );
        _testFulfillAscendingDescendingConsideration(
            Context(
                consideration,
                inputs,
                erc1155amt,
                0,
                0,
                startAmount,
                endAmount,
                warpAmount % 1000
            )
        );
    }

    function _testFulfillAscendingDescendingConsideration(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.warpAmount %= 1000;
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155amt);
        _configureERC1155OfferItem(context.args.id, context.erc1155amt);

        _configureErc20ConsiderationItem(
            alice,
            context.startAmount.mul(1000),
            context.endAmount.mul(1000)
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        vm.warp(block.timestamp + context.warpAmount);
        uint256 expectedAmount = _locateCurrentAmount(
            context.startAmount.mul(1000),
            context.endAmount.mul(1000),
            context.warpAmount,
            1000 - context.warpAmount,
            1000,
            true // for consideration
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
    {
        _testFulfillOrderEthToErc721(
            Context(referenceConsideration, inputs, 0, 0, 0, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721(
            Context(consideration, inputs, 0, 0, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount
    ) public {
        _testFulfillOrderEthToErc1155(
            Context(referenceConsideration, inputs, tokenAmount, 0, 0, 0, 0, 0)
        );
        _testFulfillOrderEthToErc1155(
            Context(consideration, inputs, tokenAmount, 0, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithSingleTip(
        FuzzInputsCommon memory inputs,
        uint128 tipAmt
    ) public {
        _testFulfillOrderEthToErc721WithSingleEthTip(
            Context(referenceConsideration, inputs, 0, tipAmt, 0, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721WithSingleEthTip(
            Context(consideration, inputs, 0, tipAmt, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithSingleTip(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint128 tipAmt
    ) public {
        _testFulfillOrderEthToErc1155WithSingleEthTip(
            Context(
                referenceConsideration,
                inputs,
                tokenAmt,
                tipAmt,
                0,
                0,
                0,
                0
            )
        );
        _testFulfillOrderEthToErc1155WithSingleEthTip(
            Context(consideration, inputs, tokenAmt, tipAmt, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithMultipleTips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc721WithMultipleEthTips(
            Context(referenceConsideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721WithMultipleEthTips(
            Context(consideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithMultipleTips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc1155WithMultipleEthTips(
            Context(
                referenceConsideration,
                inputs,
                tokenAmt,
                0,
                numTips,
                0,
                0,
                0
            )
        );
        _testFulfillOrderEthToErc1155WithMultipleEthTips(
            Context(consideration, inputs, tokenAmt, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderSingleErc20ToSingleErc1155(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt
    ) public {
        _testFulfillOrderSingleErc20ToSingleErc1155(
            Context(referenceConsideration, inputs, tokenAmt, 0, 0, 0, 0, 0)
        );
        _testFulfillOrderSingleErc20ToSingleErc1155(
            Context(consideration, inputs, tokenAmt, 0, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithErc721Tips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc721WithErc721Tips(
            Context(referenceConsideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721WithErc721Tips(
            Context(consideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithErc721Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc1155WithErc721Tips(
            Context(
                referenceConsideration,
                inputs,
                tokenAmt,
                0,
                numTips,
                0,
                0,
                0
            )
        );
        _testFulfillOrderEthToErc1155WithErc721Tips(
            Context(consideration, inputs, tokenAmt, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithErc1155Tips(
        FuzzInputsCommon memory inputs,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc721WithErc1155Tips(
            Context(referenceConsideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721WithErc1155Tips(
            Context(consideration, inputs, 0, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithErc1155Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc1155WithErc1155Tips(
            Context(
                referenceConsideration,
                inputs,
                tokenAmt,
                0,
                numTips,
                0,
                0,
                0
            )
        );
        _testFulfillOrderEthToErc1155WithErc1155Tips(
            Context(consideration, inputs, tokenAmt, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721WithErc20Tips(
        FuzzInputsCommon memory inputs
    ) public {
        _testFulfillOrderEthToErc721WithErc20Tips(
            Context(referenceConsideration, inputs, 0, 0, 0, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721WithErc20Tips(
            Context(consideration, inputs, 0, 0, 0, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc1155WithErc20Tips(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmt,
        uint8 numTips
    ) public {
        _testFulfillOrderEthToErc1155WithErc20Tips(
            Context(
                referenceConsideration,
                inputs,
                tokenAmt,
                0,
                numTips,
                0,
                0,
                0
            )
        );
        _testFulfillOrderEthToErc1155WithErc20Tips(
            Context(consideration, inputs, tokenAmt, 0, numTips, 0, 0, 0)
        );
    }

    function testFulfillOrderEthToErc721FullRestricted(
        FuzzInputsCommon memory inputs
    ) public {
        _testFulfillOrderEthToErc721FullRestricted(
            Context(referenceConsideration, inputs, 0, 0, 0, 0, 0, 0)
        );
        _testFulfillOrderEthToErc721FullRestricted(
            Context(consideration, inputs, 0, 0, 0, 0, 0, 0)
        );
    }

    function _testFulfillOrderEthToErc721(Context memory context)
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
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
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

    function _testFulfillOrderEthToErc1155(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
        );
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
            context.consideration.getNonce(alice)
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

    function _testFulfillOrderSingleErc20ToSingleErc1155(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
        );
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
            context.consideration.getNonce(alice)
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

    function _testFulfillOrderEthToErc721WithSingleEthTip(
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
                context.args.paymentAmts[2] > 0 &&
                context.tipAmt > 0
        );
        vm.assume(
            context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.tipAmt) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
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

    function _testFulfillOrderEthToErc1155WithSingleEthTip(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0 &&
                context.tipAmt > 0
        );
        vm.assume(
            context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.tipAmt) <= 2**128 - 1
        );
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
            context.consideration.getNonce(alice)
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

    function _testFulfillOrderEthToErc721WithMultipleEthTips(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.numTips) *
                ((1 + context.numTips) / 2) <= // avg of tip amounts from 1 to numberOfTips eth
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        uint128 sumOfTips;
        for (uint128 i = 1; i < context.numTips + 1; i++) {
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

    function _testFulfillOrderEthToErc1155WithMultipleEthTips(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context
                .args
                .paymentAmts[0]
                .add(context.args.paymentAmts[1])
                .add(context.args.paymentAmts[2])
                .add(context.numTips) *
                ((1 + context.numTips) / 2) <= // avg of tip amounts from 1 to numberOfTips eth
                2**128 - 1
        );
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        uint128 sumOfTips;
        // push tip of amount i eth to considerationitems
        for (uint128 i = 1; i < context.numTips + 1; i++) {
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

    function _testFulfillOrderEthToErc721WithErc721Tips(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < context.numTips + 1; i++) {
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

    function _testFulfillOrderEthToErc1155WithErc721Tips(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
        );
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < context.numTips + 1; i++) {
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

    function _testFulfillOrderEthToErc721WithErc1155Tips(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        for (uint256 i = 1; i < context.numTips.add(1); i++) {
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

    function _testFulfillOrderEthToErc1155WithErc1155Tips(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
        );

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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        for (uint256 i = 1; i < context.numTips.add(1); i++) {
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

    function _testFulfillOrderEthToErc721WithErc20Tips(Context memory context)
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
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        for (uint256 i = 1; i < context.numTips.add(1); i++) {
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

    function _testFulfillOrderEthToErc1155WithErc20Tips(Context memory context)
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        context.numTips = (context.numTips % 64) + 1;
        vm.assume(context.erc1155amt > 0);
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
        );

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
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        for (uint256 i = 1; i < context.numTips.add(1); i++) {
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

    function _testFulfillOrderEthToErc721FullRestricted(Context memory context)
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
            context.args.paymentAmts[0].add(context.args.paymentAmts[1]).add(
                context.args.paymentAmts[2]
            ) <= 2**128 - 1
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
            context.consideration.getNonce(alice)
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
