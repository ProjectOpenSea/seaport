// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";
import { Merkle } from "murky/Merkle.sol";
import { ConsiderationEventsAndErrors } from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillAdvancedOrder is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;
    // todo: add numer/denom, swap if numer > denom
    struct FuzzInputs {
        uint256 tokenId;
        address zone;
        bytes32 zoneHash;
        uint256 salt;
        uint16 offerAmt;
        // uint16 fulfillAmt;
        uint120[3] paymentAmounts;
        bool useConduit;
        uint8 numer;
        uint8 denom;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
        uint256 tokenAmount;
    }

    modifier validateInputs(FuzzInputs memory args) {
        vm.assume(
            args.paymentAmounts[0] > 0 &&
                args.paymentAmounts[1] > 0 &&
                args.paymentAmounts[2] > 0
        );
        vm.assume(
            uint256(args.paymentAmounts[0]) +
                uint256(args.paymentAmounts[1]) +
                uint256(args.paymentAmounts[2]) <=
                2**120 - 1
        );
        vm.assume(args.offerAmt > 0);
        vm.assume(args.numer <= args.denom);
        vm.assume(args.numer > 0);
        _;
    }

    function testAdvancedPartialAscendingConsiderationAmount1155(
        FuzzInputs memory inputs,
        uint128 tokenId
    ) public {
        _testAdvancedPartialAscendingConsiderationAmount1155(
            Context(referenceConsideration, inputs, tokenId)
        );
        _testAdvancedPartialAscendingConsiderationAmount1155(
            Context(consideration, inputs, tokenId)
        );
    }

    function _testAdvancedPartialAscendingConsiderationAmount1155(
        Context memory context
    ) internal resetTokenBalancesBetweenRuns {
        vm.assume(
            context.args.paymentAmounts[0] > 0 &&
                context.args.paymentAmounts[1] > 0 &&
                context.args.paymentAmounts[2] > 0
        );
        uint256 sumOfPaymentAmounts = (context.args.paymentAmounts[0].mul(4))
            .add((context.args.paymentAmounts[1].mul(2)))
            .add((context.args.paymentAmounts[2].mul(2)));
        vm.assume(sumOfPaymentAmounts <= 2**128 - 1);

        vm.assume(context.tokenAmount > 0);
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(
            alice,
            context.args.tokenId,
            uint256(context.tokenAmount) * 1000
        );

        _configureOfferItem(
            ItemType.ERC1155,
            context.args.tokenId,
            uint256(context.tokenAmount) * 1000
        );
        // set endAmount to 2 * startAmount
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0] * uint256(2),
            context.args.paymentAmounts[0] * uint256(4)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[1] * uint256(2)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[2] * uint256(2)
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
            value: uint256(context.args.paymentAmounts[0]) +
                context.args.paymentAmounts[1] +
                context.args.paymentAmounts[2]
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0));

        // set transaction value to sum of eth consideration items (including endAmount of considerationItem[0])
        context.consideration.fulfillAdvancedOrder{
            value: sumOfPaymentAmounts
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0));

        (, , uint256 totalFilled, uint256 totalSize) = context
            .consideration
            .getOrderStatus(orderHash);
        assertEq(totalFilled, 1);
        assertEq(totalSize, 2);
    }

    function testAdvancedPartial1155(FuzzInputs memory args) public {
        _advancedPartial1155(Context(consideration, args, 0));
        _advancedPartial1155(Context(referenceConsideration, args, 0));
    }

    function testAdvancedPartial1155Static() public {
        test1155_1.mint(alice, 1, 10);

        _configureERC1155OfferItem(1, uint256(10));
        _configureEthConsiderationItem(alice, uint256(10));
        _configureEthConsiderationItem(payable(address(0)), uint256(10));
        _configureEthConsiderationItem(cal, uint256(10));
        uint256 nonce = referenceConsideration.getNonce(alice);
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            address(0),
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            nonce
        );
        bytes32 orderHash = referenceConsideration.getOrderHash(
            orderComponents
        );

        bytes memory signature = signOrder(
            referenceConsideration,
            alicePk,
            orderHash
        );

        OrderParameters memory orderParameters = OrderParameters(
            alice,
            address(0),
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            3
        );
        uint256 value = 30;

        referenceConsideration.fulfillAdvancedOrder{ value: value }(
            AdvancedOrder(orderParameters, 1, 1, signature, ""),
            new CriteriaResolver[](0),
            bytes32(0)
        );
    }

    function _advancedPartial1155(Context memory context)
        internal
        validateInputs(context.args)
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        // vm.assume(context.args.fulfillAmt > 0);
        // vm.assume(
        //     context.args.offerAmt > context.args.fulfillAmt
        // );
        // todo: swap fulfillment and tokenAmount if we exceed global rejects with above assume
        // if (context.args.offerAmt < context.args.fulfillAmt) {
        //     uint256 temp = context.args.fulfillAmt;
        //     context.args.fulfillAmt = context.args.offerAmt;
        //     context.args.offerAmt = temp;
        // }

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        // mint offerAmt tokens
        test1155_1.mint(
            alice,
            context.args.tokenId,
            context.args.denom // mint 256x as many
        );

        _configureERC1155OfferItem(
            context.args.tokenId,
            uint256(context.args.denom)
        );
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0] * uint256(context.args.denom)
        );
        _configureEthConsiderationItem(
            payable(context.args.zone),
            context.args.paymentAmounts[1] * uint256(context.args.denom)
        );
        _configureEthConsiderationItem(
            cal,
            context.args.paymentAmounts[2] * uint256(context.args.denom)
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
            considerationItems.length
        );
        uint256 value = uint128(context.args.numer) *
            (uint128(context.args.paymentAmounts[0]) +
                context.args.paymentAmounts[1] +
                context.args.paymentAmounts[2]);
        emit log_named_uint("numer", context.args.numer);
        emit log_named_uint("denom", context.args.denom);
        emit log_named_uint("value", value);
        // uint120 numer = uint120(context.args.offerAmt) * 2;
        context.consideration.fulfillAdvancedOrder{ value: value }(
            AdvancedOrder(
                orderParameters,
                context.args.numer,
                context.args.denom,
                signature,
                ""
            ),
            new CriteriaResolver[](0),
            conduitKey
        );

        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = context.consideration.getOrderStatus(orderHash);
            assertTrue(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, context.args.numer);
            assertEq(totalSize, context.args.denom);
        }
    }
}
