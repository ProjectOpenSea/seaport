// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity >=0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient, Order } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { TestERC721 } from "../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";

import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

import { OrderParameters } from "./utils/reentrancy/ReentrantStructs.sol";

contract FulfillBasicOrderTest is BaseOrderTest {
    using ArithmeticUtil for uint128;

    uint256 badIdentifier;
    address badToken;
    BasicOrderParameters basicOrderParameters;

    struct FuzzInputsCommon {
        address zone;
        uint256 tokenId;
        uint128 paymentAmount;
        bytes32 zoneHash;
        uint256 salt;
    }
    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
        uint128 tokenAmount;
    }

    modifier validateInputs(Context memory context) {
        vm.assume(context.args.paymentAmount > 0);
        _;
    }

    modifier validateInputsWithAmount(Context memory context) {
        vm.assume(context.args.paymentAmount > 0);
        vm.assume(context.args.tokenId > 0);
        vm.assume(context.tokenAmount > 0);
        _;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testBasicEthTo721(FuzzInputsCommon memory inputs)
        public
        validateInputs(Context(consideration, inputs, 0))
    {
        addErc721OfferItem(inputs.tokenId);
        addEthConsiderationItem(alice, inputs.paymentAmount);
        _configureBasicOrderParametersEthTo721(inputs);

        test(this.basicEthTo721, Context(consideration, inputs, 0));
        test(this.basicEthTo721, Context(referenceConsideration, inputs, 0));
    }

    function testBasicErc20To721(FuzzInputsCommon memory inputs)
        public
        validateInputs(Context(consideration, inputs, 0))
    {
        addErc721OfferItem(inputs.tokenId);
        addErc20ConsiderationItem(alice, inputs.paymentAmount);
        _configureBasicOrderParametersErc20To721(inputs);

        test(this.basicErc20To721, Context(consideration, inputs, 0));
        test(this.basicErc20To721, Context(referenceConsideration, inputs, 0));
    }

    function testBasicEthTo1155(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        addErc1155OfferItem(inputs.tokenId, tokenAmount);
        addEthConsiderationItem(alice, inputs.paymentAmount);
        _configureBasicOrderParametersEthTo1155(inputs, tokenAmount);

        test(this.basicEthTo1155, Context(consideration, inputs, tokenAmount));
        test(
            this.basicEthTo1155,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function testBasicErc20To1155(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        addErc1155OfferItem(inputs.tokenId, tokenAmount);
        addErc20ConsiderationItem(alice, inputs.paymentAmount);
        _configureBasicOrderParametersErc20To1155(inputs, tokenAmount);

        test(
            this.basicErc20To1155,
            Context(consideration, inputs, tokenAmount)
        );
        test(
            this.basicErc20To1155,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function testFulfillBasicOrderRevertInvalidAdditionalRecipientsLength(
        uint256 fuzzTotalRecipients,
        uint256 fuzzAmountToSubtractFromTotalRecipients
    ) public {
        uint256 totalRecipients = fuzzTotalRecipients % 200;
        // Set amount to subtract from total recipients
        // to be at most totalRecipients.
        uint256 amountToSubtractFromTotalRecipients = totalRecipients > 0
            ? fuzzAmountToSubtractFromTotalRecipients % totalRecipients
            : 0;

        // Create basic order
        (
            Order memory myOrder,
            BasicOrderParameters memory _basicOrderParameters
        ) = prepareBasicOrder(1);

        // Add additional recipients
        _basicOrderParameters.additionalRecipients = new AdditionalRecipient[](
            totalRecipients
        );
        for (
            uint256 i = 0;
            i < _basicOrderParameters.additionalRecipients.length;
            i++
        ) {
            _basicOrderParameters.additionalRecipients[
                i
            ] = AdditionalRecipient({ recipient: alice, amount: 1 });
        }

        // Get the calldata that will be passed into fulfillOrder.
        bytes memory fulfillOrderCalldata = abi.encodeWithSelector(
            consideration.fulfillBasicOrder.selector,
            _basicOrderParameters
        );

        _performTestFulfillOrderRevertInvalidArrayLength(
            consideration,
            myOrder,
            fulfillOrderCalldata,
            // Order parameters starts at 0x44 relative to the start of the
            // order calldata because the order calldata starts with 0x20 bytes
            // for order calldata length, 0x04 bytes for selector, and 0x20
            // bytes until the start of order parameters.
            0x44,
            0x200,
            _basicOrderParameters.additionalRecipients.length,
            amountToSubtractFromTotalRecipients
        );
    }

    function testRevertUnusedItemParametersAddressSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount,
        address _badToken
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        vm.assume(_badToken != address(0));
        badToken = _badToken;

        addErc1155OfferItem(inputs.tokenId, tokenAmount);
        addEthConsiderationItem(alice, 100);
        test(
            this.revertUnusedItemParametersAddressSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount)
        );
        test(
            this.revertUnusedItemParametersAddressSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function revertUnusedItemParametersAddressSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        considerationItems[0].token = badToken;

        _configureOrderParameters(
            alice,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        _configureOrderComponents(context.consideration.getCounter(alice));

        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory _basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
                signature
            );

        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillBasicOrder{ value: 100 }(
            _basicOrderParameters
        );
    }

    function testRevertUnusedItemParametersIdentifierSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount,
        uint256 _badIdentifier
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        vm.assume(_badIdentifier != 0);
        badIdentifier = _badIdentifier;

        addErc1155OfferItem(inputs.tokenId, tokenAmount);
        addEthConsiderationItem(alice, 100);
        test(
            this.revertUnusedItemParametersIdentifierSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount)
        );
        test(
            this.revertUnusedItemParametersIdentifierSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function revertUnusedItemParametersIdentifierSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        considerationItems[0].identifierOrCriteria = badIdentifier;

        _configureOrderParameters(
            alice,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        _configureOrderComponents(context.consideration.getCounter(alice));

        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory _basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
                signature
            );

        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillBasicOrder{ value: 100 }(
            _basicOrderParameters
        );
    }

    function testRevertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount,
        uint256 _badIdentifier,
        address _badToken
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        vm.assume(_badIdentifier != 0 || _badToken != address(0));
        badIdentifier = _badIdentifier;
        badToken = _badToken;

        addErc1155OfferItem(inputs.tokenId, tokenAmount);
        addEthConsiderationItem(alice, 100);
        test(
            this
                .revertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration,
            Context(consideration, inputs, tokenAmount)
        );
        test(
            this
                .revertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function revertUnusedItemParametersAddressAndIdentifierSetOnNativeConsideration(
        Context memory context
    ) external stateless {
        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        considerationItems[0].identifierOrCriteria = badIdentifier;
        considerationItems[0].token = badToken;

        _configureOrderParameters(
            alice,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        _configureOrderComponents(context.consideration.getCounter(alice));

        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory _basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
                signature
            );

        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillBasicOrder{ value: 100 }(
            _basicOrderParameters
        );
    }

    function testRevertUnusedItemParametersIdentifierSetOnErc20Consideration(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount,
        uint256 _badIdentifier
    )
        public
        validateInputsWithAmount(Context(consideration, inputs, tokenAmount))
    {
        vm.assume(_badIdentifier != 0);
        badIdentifier = _badIdentifier;

        addErc721OfferItem(inputs.tokenId);
        addErc20ConsiderationItem(alice, 100);
        test(
            this.revertUnusedItemParametersIdentifierSetOnErc20Consideration,
            Context(consideration, inputs, tokenAmount)
        );
        test(
            this.revertUnusedItemParametersIdentifierSetOnErc20Consideration,
            Context(referenceConsideration, inputs, tokenAmount)
        );
    }

    function revertUnusedItemParametersIdentifierSetOnErc20Consideration(
        Context memory context
    ) external stateless {
        test721_1.mint(alice, context.args.tokenId);

        considerationItems[0].identifierOrCriteria = badIdentifier;

        _configureOrderParameters(
            alice,
            address(0),
            bytes32(0),
            globalSalt++,
            false
        );
        _configureOrderComponents(context.consideration.getCounter(alice));

        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory _basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ERC20_TO_ERC721_FULL_OPEN,
                signature
            );

        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        context.consideration.fulfillBasicOrder(_basicOrderParameters);
    }

    function prepareBasicOrder(uint256 tokenId)
        internal
        returns (
            Order memory order,
            BasicOrderParameters memory _basicOrderParameters
        )
    {
        (Order memory _order, , ) = _prepareOrder(tokenId, 1);
        order = _order;
        _basicOrderParameters = toBasicOrderParameters(
            _order,
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN
        );
    }

    function basicErc20To1155(Context memory context) external stateless {
        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 counter = context.consideration.getCounter(alice);
        baseOrderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder(basicOrderParameters);
        assertEq(
            context.tokenAmount,
            test1155_1.balanceOf(address(this), context.args.tokenId)
        );
    }

    function basicEthTo1155(Context memory context) external stateless {
        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 counter = context.consideration.getCounter(alice);
        baseOrderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder{
            value: context.args.paymentAmount
        }(basicOrderParameters);
        assertEq(
            context.tokenAmount,
            test1155_1.balanceOf(address(this), context.args.tokenId)
        );
    }

    function basicEthTo721(Context memory context) external stateless {
        test721_1.mint(alice, context.args.tokenId);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 counter = context.consideration.getCounter(alice);
        baseOrderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder{
            value: context.args.paymentAmount
        }(basicOrderParameters);
        assertEq(address(this), test721_1.ownerOf(context.args.tokenId));
    }

    function basicErc20To721(Context memory context) external stateless {
        test721_1.mint(alice, context.args.tokenId);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 counter = context.consideration.getCounter(alice);
        baseOrderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder(basicOrderParameters);
        assertEq(
            context.args.paymentAmount.add(uint128(MAX_INT)),
            token1.balanceOf(address(alice))
        );
        assertEq(address(this), test721_1.ownerOf(context.args.tokenId));
    }

    function _configureBasicOrderParametersEthTo721(
        FuzzInputsCommon memory args
    ) internal {
        basicOrderParameters.considerationToken = address(0);
        basicOrderParameters.considerationIdentifier = 0;
        basicOrderParameters.considerationAmount = args.paymentAmount;
        basicOrderParameters.offerer = payable(alice);
        basicOrderParameters.zone = args.zone;
        basicOrderParameters.offerToken = address(test721_1);
        basicOrderParameters.offerIdentifier = args.tokenId;
        basicOrderParameters.offerAmount = 1;
        basicOrderParameters.basicOrderType = BasicOrderType
            .ETH_TO_ERC721_FULL_OPEN;
        basicOrderParameters.startTime = block.timestamp;
        basicOrderParameters.endTime = block.timestamp + 100;
        basicOrderParameters.zoneHash = args.zoneHash;
        basicOrderParameters.salt = args.salt;
        basicOrderParameters.offererConduitKey = bytes32(0);
        basicOrderParameters.fulfillerConduitKey = bytes32(0);
        basicOrderParameters.totalOriginalAdditionalRecipients = 0;
        // additional recipients should always be empty
        // don't do signature;
    }

    function _configureBasicOrderParametersEthTo1155(
        FuzzInputsCommon memory args,
        uint128 amount
    ) internal {
        basicOrderParameters.considerationToken = address(0);
        basicOrderParameters.considerationIdentifier = 0;
        basicOrderParameters.considerationAmount = args.paymentAmount;
        basicOrderParameters.offerer = payable(alice);
        basicOrderParameters.zone = args.zone;
        basicOrderParameters.offerToken = address(test1155_1);
        basicOrderParameters.offerIdentifier = args.tokenId;
        basicOrderParameters.offerAmount = amount;
        basicOrderParameters.basicOrderType = BasicOrderType
            .ETH_TO_ERC1155_FULL_OPEN;
        basicOrderParameters.startTime = block.timestamp;
        basicOrderParameters.endTime = block.timestamp + 100;
        basicOrderParameters.zoneHash = args.zoneHash;
        basicOrderParameters.salt = args.salt;
        basicOrderParameters.offererConduitKey = bytes32(0);
        basicOrderParameters.fulfillerConduitKey = bytes32(0);
        basicOrderParameters.totalOriginalAdditionalRecipients = 0;
        // additional recipients should always be empty
        // don't do signature;
    }

    function _configureBasicOrderParametersErc20To1155(
        FuzzInputsCommon memory args,
        uint128 amount
    ) internal {
        _configureBasicOrderParametersEthTo1155(args, amount);
        basicOrderParameters.considerationToken = address(token1);
        basicOrderParameters.basicOrderType = BasicOrderType
            .ERC20_TO_ERC1155_FULL_OPEN;
    }

    function _configureBasicOrderParametersErc20To721(
        FuzzInputsCommon memory args
    ) internal {
        _configureBasicOrderParametersEthTo721(args);
        basicOrderParameters.considerationToken = address(token1);
        basicOrderParameters.basicOrderType = BasicOrderType
            .ERC20_TO_ERC721_FULL_OPEN;
    }

    function _configureOrderComponents(
        address zone,
        bytes32 zoneHash,
        uint256 salt,
        bytes32 conduitKey
    ) internal {
        baseOrderComponents.offerer = alice;
        baseOrderComponents.zone = zone;
        baseOrderComponents.offer = offerItems;
        baseOrderComponents.consideration = considerationItems;
        baseOrderComponents.orderType = OrderType.FULL_OPEN;
        baseOrderComponents.startTime = block.timestamp;
        baseOrderComponents.endTime = block.timestamp + 100;
        baseOrderComponents.zoneHash = zoneHash;
        baseOrderComponents.salt = salt;
        baseOrderComponents.conduitKey = conduitKey;
        // don't set counter
    }
}
