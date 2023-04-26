// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {
    OrderType,
    ItemType
} from "../../contracts/lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";

import {
    Order,
    OfferItem,
    OrderParameters,
    ConsiderationItem,
    OrderComponents
} from "../../contracts/lib/ConsiderationStructs.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillOrderTest is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;
    using ArithmeticUtil for uint8;

    FuzzInputsCommon empty;
    bytes signature1271;

    uint256 badIdentifier;
    address badToken;
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
        uint256 erc1155Amt;
        uint128 tipAmt;
        uint8 numTips;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
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

    function testNoNativeOffers(uint8[8] memory itemTypes) public {
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

        test(this.noNativeOfferItems, Context(consideration, empty, 0, 0, 0));
        test(
            this.noNativeOfferItems,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
    }

    function noNativeOfferItems(Context memory context) external stateless {
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

        context.consideration.fulfillOrder{ value: 1 ether }(
            Order(baseOrderParameters, signature),
            bytes32(0)
        );
    }

    function testNullAddressSpendReverts() public {
        // mint token to null address
        preapproved721.mint(address(0), 1);
        // mint erc token to test address
        token1.mint(address(this), 1);
        // offer burnt erc721
        addErc721OfferItem(address(preapproved721), 1);
        // consider erc20 to null address
        addErc20ConsiderationItem(payable(0), 1);
        // configure baseOrderParameters with null address as offerer
        configureOrderParameters(address(0));
        test(
            this.nullAddressSpendReverts,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
        test(
            this.nullAddressSpendReverts,
            Context(consideration, empty, 0, 0, 0)
        );
    }

    function nullAddressSpendReverts(
        Context memory context
    ) external stateless {
        // create a bad signature
        bytes memory signature = abi.encodePacked(
            bytes32(0),
            bytes32(0),
            bytes1(uint8(27))
        );
        // test that signature is recognized as invalid even though signer recovered is null address
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));

        context.consideration.fulfillOrder(
            Order(baseOrderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillAscendingDescendingOffer(
        FuzzInputsCommon memory inputs
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
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

    function fulfillAscendingDescendingOffer(
        Context memory context
    ) external stateless {
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
        addErc20OfferItem(
            context.args.startAmount.mul(1000),
            context.args.endAmount.mul(1000)
        );
        addEthConsiderationItem(alice, 1000);
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
        vm.expectEmit(true, true, false, true, address(token1));
        emit Transfer(alice, address(this), expectedAmount);
        context.consideration.fulfillOrder{ value: 1000 }(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function testFulfillAscendingDescendingConsideration(
        FuzzInputsCommon memory inputs,
        uint256 erc1155Amt
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(inputs.startAmount > 0 && inputs.endAmount > 0);
        vm.assume(erc1155Amt > 0);
        test(
            this.fulfillAscendingDescendingConsideration,
            Context(referenceConsideration, inputs, erc1155Amt, 0, 0)
        );
        test(
            this.fulfillAscendingDescendingConsideration,
            Context(consideration, inputs, erc1155Amt, 0, 0)
        );
    }

    function fulfillAscendingDescendingConsideration(
        Context memory context
    ) external stateless {
        context.args.warpAmount %= 1000;
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        addErc1155OfferItem(context.args.id, context.erc1155Amt);

        addErc20ConsiderationItem(
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
        vm.expectEmit(true, true, false, true, address(token1));
        emit Transfer(address(this), address(alice), expectedAmount);
        context.consideration.fulfillOrder(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function testFulfillOrderEthToErc721(
        FuzzInputsCommon memory inputs
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
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

    function testFulfillOrder64And65Byte1271Signatures() public {
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));
        assertEq(signature1271.length, 65);
        test(
            this.fulfillOrder64And65Byte1271Signatures,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
        test(
            this.fulfillOrder64And65Byte1271Signatures,
            Context(consideration, empty, 0, 0, 0)
        );
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));
        assertEq(signature1271.length, 64);
        test(
            this.fulfillOrder64And65Byte1271Signatures,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
        test(
            this.fulfillOrder64And65Byte1271Signatures,
            Context(consideration, empty, 0, 0, 0)
        );
    }

    function fulfillOrder64And65Byte1271Signatures(
        Context memory context
    ) external stateless {
        test1155_1.mint(address(this), 1, 1);
        addErc1155OfferItem(1, 1);
        addEthConsiderationItem(payable(this), 1);

        _configureOrderParameters(
            address(this),
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );

        Order memory order = Order(baseOrderParameters, signature1271);
        vm.prank(bob);
        context.consideration.fulfillOrder{ value: 1 }(order, bytes32(0));
    }

    function testFulfillOrder2098() public {
        test(
            this.fulfillOrder2098,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
        test(this.fulfillOrder2098, Context(consideration, empty, 0, 0, 0));
    }

    function fulfillOrder2098(Context memory context) external stateless {
        test1155_1.mint(bob, 1, 1);
        addErc1155OfferItem(1, 1);
        addEthConsiderationItem(payable(bob), 1);

        _configureOrderParameters(
            bob,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        configureOrderComponents(context.consideration.getCounter(bob));
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder2098(
            context.consideration,
            bobPk,
            orderHash
        );

        Order memory order = Order(baseOrderParameters, signature);

        context.consideration.fulfillOrder{ value: 1 }(order, bytes32(0));
    }

    function testFulfillOrderRevertInvalidConsiderationItemsLength(
        uint256 fuzzTotalConsiderationItems,
        uint256 fuzzAmountToSubtractFromConsiderationItemsLength
    ) public {
        uint256 totalConsiderationItems = fuzzTotalConsiderationItems % 200;
        // Set amount to subtract from consideration item length
        // to be at most totalConsiderationItems.
        uint256 amountToSubtractFromConsiderationItemsLength = totalConsiderationItems >
                0
                ? fuzzAmountToSubtractFromConsiderationItemsLength %
                    totalConsiderationItems
                : 0;

        // Create order
        (
            Order memory _order,
            OrderParameters memory _orderParameters,

        ) = _prepareOrder(1, totalConsiderationItems);

        // Get the calldata that will be passed into fulfillOrder.
        bytes memory fulfillOrderCalldata = abi.encodeWithSelector(
            consideration.fulfillOrder.selector,
            _order,
            conduitKeyOne
        );

        _performTestFulfillOrderRevertInvalidArrayLength(
            consideration,
            _order,
            fulfillOrderCalldata,
            // Order parameters starts at 0xa4 relative to the start of the
            // order calldata because the order calldata starts with 0x20 bytes
            // for order calldata length, 0x04 bytes for selector, and 0x80
            // bytes until the start of order parameters.
            0xa4,
            0x60,
            _orderParameters.consideration.length,
            amountToSubtractFromConsiderationItemsLength
        );
    }

    function fulfillOrderEthToErc721(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderSingleErc20ToSingleErc1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721WithSingleEthTip(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155WithSingleEthTip(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721WithMultipleEthTips(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155WithMultipleEthTips(
        Context memory context
    ) external stateless {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721WithErc721Tips(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155WithErc721Tips(
        Context memory context
    ) external stateless {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721WithErc1155Tips(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155WithErc1155Tips(
        Context memory context
    ) external stateless {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721WithErc20Tips(
        Context memory context
    ) external stateless {
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

    function fulfillOrderEthToErc1155WithErc20Tips(
        Context memory context
    ) external stateless {
        context.numTips = (context.numTips % 64) + 1;

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.erc1155Amt,
                context.erc1155Amt
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

    function fulfillOrderEthToErc721FullRestricted(
        Context memory context
    ) external stateless {
        context.args.zone = address(
            uint160(bound(uint160(context.args.zone), 1, type(uint160).max))
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

        uint256 value = context
            .args
            .paymentAmts[0]
            .add(context.args.paymentAmts[1])
            .add(context.args.paymentAmts[2]);
        hoax(context.args.zone, value);
        context.consideration.fulfillOrder{ value: value }(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function testFulfillOrderRevertUnusedItemParametersAddressSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount,
        address _badToken
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(_badToken != address(0));
        badToken = _badToken;

        vm.assume(inputs.id > 0);
        vm.assume(tokenAmount > 0);
        test(
            this
                .fulfillOrderRevertUnusedItemParametersAddressSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this
                .fulfillOrderRevertUnusedItemParametersAddressSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
    }

    function fulfillOrderRevertUnusedItemParametersAddressSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        addErc1155OfferItem(context.args.id, context.erc1155Amt);
        addEthConsiderationItem(alice, 100);

        considerationItems[0].token = badToken;

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
            bytes32(0),
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
            bytes32(0),
            considerationItems.length
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillOrder{ value: 100 }(
            Order(orderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillOrderRevertUnusedItemParametersIdentifierSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount,
        uint256 _badIdentifier
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(_badIdentifier != 0);
        badIdentifier = _badIdentifier;

        vm.assume(inputs.id > 0);
        vm.assume(tokenAmount > 0);
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
    }

    function fulfillOrderRevertUnusedItemParametersIdentifierSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        addErc1155OfferItem(context.args.id, context.erc1155Amt);
        addEthConsiderationItem(alice, 100);

        considerationItems[0].identifierOrCriteria = badIdentifier;

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
            bytes32(0),
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
            bytes32(0),
            considerationItems.length
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillOrder{ value: 100 }(
            Order(orderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillOrderRevertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount,
        uint256 _badIdentifier,
        address _badToken
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(_badIdentifier != 0 || _badToken != address(0));
        badIdentifier = _badIdentifier;
        badToken = _badToken;

        vm.assume(inputs.id > 0);
        vm.assume(tokenAmount > 0);
        test(
            this
                .fulfillOrderRevertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this
                .fulfillOrderRevertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
    }

    function fulfillOrderRevertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.id, context.erc1155Amt);
        addErc1155OfferItem(context.args.id, context.erc1155Amt);
        addEthConsiderationItem(alice, 100);

        considerationItems[0].identifierOrCriteria = badIdentifier;
        considerationItems[0].token = badToken;

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
            bytes32(0),
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
            bytes32(0),
            considerationItems.length
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillOrder{ value: 100 }(
            Order(orderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Offer(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount,
        uint256 _badIdentifier
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(_badIdentifier != 0);
        badIdentifier = _badIdentifier;

        vm.assume(inputs.id > 0);
        vm.assume(tokenAmount > 0);
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Offer,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Offer,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
    }

    function fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Offer(
        Context memory context
    ) external stateless {
        test721_1.mint(bob, context.args.id);

        addErc20OfferItem(100);
        addErc721ConsiderationItem(alice, context.args.id);

        offerItems[0].identifierOrCriteria = badIdentifier;

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
            bytes32(0),
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
            bytes32(0),
            considerationItems.length
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillOrder(
            Order(orderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Consideration(
        FuzzInputsCommon memory inputs,
        uint256 tokenAmount,
        uint256 _badIdentifier
    ) public validateInputs(inputs) onlyPayable(inputs.zone) {
        vm.assume(_badIdentifier != 0);
        badIdentifier = _badIdentifier;

        vm.assume(inputs.id > 0);
        vm.assume(tokenAmount > 0);
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Consideration,
            Context(consideration, inputs, tokenAmount, 0, 0)
        );
        test(
            this
                .fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Consideration,
            Context(referenceConsideration, inputs, tokenAmount, 0, 0)
        );
    }

    function fulfillOrderRevertUnusedItemParametersIdentifierSetOnErc20Consideration(
        Context memory context
    ) external stateless {
        test721_1.mint(alice, context.args.id);
        addErc721OfferItem(context.args.id);
        addErc20ConsiderationItem(alice, 100);

        considerationItems[0].identifierOrCriteria = badIdentifier;

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
            bytes32(0),
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
            bytes32(0),
            considerationItems.length
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillOrder(
            Order(orderParameters, signature),
            bytes32(0)
        );
    }

    function testFulfillOrderRevertCounterIncremented() public {
        test(
            this.fulfillOrderRevertCounterIncremented,
            Context(referenceConsideration, empty, 0, 0, 0)
        );
        test(
            this.fulfillOrderRevertCounterIncremented,
            Context(consideration, empty, 0, 0, 0)
        );
    }

    function fulfillOrderRevertCounterIncremented(
        Context memory context
    ) external stateless {
        test1155_1.mint(bob, 1, 1);
        addErc1155OfferItem(1, 1);
        addEthConsiderationItem(payable(bob), 1);

        _configureOrderParameters(
            bob,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        configureOrderComponents(context.consideration.getCounter(bob));
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder2098(
            context.consideration,
            bobPk,
            orderHash
        );

        Order memory order = Order(baseOrderParameters, signature);

        _validateOrder(order, context.consideration);

        vm.prank(bob);
        context.consideration.incrementCounter();

        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        _validateOrder(order, context.consideration);

        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        context.consideration.fulfillOrder{ value: 1 }(order, bytes32(0));

        configureOrderComponents(context.consideration.getCounter(bob));
        orderHash = context.consideration.getOrderHash(baseOrderComponents);
        signature = signOrder(context.consideration, bobPk, orderHash);

        order = Order(baseOrderParameters, signature);

        _validateOrder(order, context.consideration);

        vm.prank(bob);
        context.consideration.incrementCounter();

        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        _validateOrder(order, context.consideration);

        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        context.consideration.fulfillOrder{ value: 1 }(order, bytes32(0));
    }
}
