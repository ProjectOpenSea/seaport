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

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testAdvancedPartialAscendingOfferAmount1155(
        FuzzInputs memory inputs,
        uint128 tokenAmount,
        uint256 warpAmount
    ) public validateInputs(inputs) {
        vm.assume(tokenAmount > 0);

        test(
            this.advancedPartialAscendingOfferAmount1155,
            Context(
                referenceConsideration,
                inputs,
                tokenAmount,
                warpAmount % 1000
            )
        );
        test(
            this.advancedPartialAscendingOfferAmount1155,
            Context(consideration, inputs, tokenAmount, warpAmount % 1000)
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

        vm.warp(block.timestamp + context.warpAmount);
        // calculate current amount of order based on warpAmount, round down since it's an offer
        // and divide by two to fulfill half of the order
        uint256 currentAmount = _locateCurrentAmount(
            context.tokenAmount * 2,
            context.tokenAmount * 4,
            context.warpAmount,
            1000 - context.warpAmount,
            1000,
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
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0));
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
        vm.assume(tokenAmount>0);
        test(this.advancedPartialAscendingConsiderationAmount1155,
            Context(referenceConsideration, inputs, tokenAmount, 0)
        );
        test(this.advancedPartialAscendingConsiderationAmount1155,
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
            value: context
                .args
                .paymentAmounts[0]
                .add(context.args.paymentAmounts[1])
                .add(context.args.paymentAmounts[2])
        }(advancedOrder, new CriteriaResolver[](0), bytes32(0));


        uint256 sumOfPaymentAmounts = (context.args.paymentAmounts[0].mul(4))
            .add((context.args.paymentAmounts[1].mul(2)))
            .add((context.args.paymentAmounts[2].mul(2)));

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

    function testAdvancedPartial1155(FuzzInputs memory args) public     
        validateInputs(args)
        validateNumerDenom(args)
        onlyPayable(args.zone) {
        test(this.advancedPartial1155,Context(consideration, args, 0, 0));
        test(this.advancedPartial1155,Context(referenceConsideration, args, 0, 0));
    }

    function testSingleAdvancedPartial1155() public {
        test1155_1.mint(alice, 1, 10);

        _configureERC1155OfferItem(1, 10);
        _configureEthConsiderationItem(alice, 10);
        _configureEthConsiderationItem(payable(address(0)), 10);
        _configureEthConsiderationItem(cal, 10);
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

    function advancedPartial1155(Context memory context)
        external stateless 
    {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        // mint offerAmt tokens
        test1155_1.mint(
            alice,
            context.args.tokenId,
            context.args.denom // mint 256x as many
        );

        _configureERC1155OfferItem(context.args.tokenId, context.args.denom);
        _configureEthConsiderationItem(
            alice,
            context.args.paymentAmounts[0].mul(context.args.denom)
        );
        _configureEthConsiderationItem(
            payable(context.args.zone),
            context.args.paymentAmounts[1].mul(context.args.denom)
        );
        _configureEthConsiderationItem(
            cal,
            context.args.paymentAmounts[2].mul(context.args.denom)
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
