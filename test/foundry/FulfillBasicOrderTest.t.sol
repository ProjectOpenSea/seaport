// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity >=0.8.13;

import { OneWord } from "../../contracts/lib/ConsiderationConstants.sol";
import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient, Order } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { LowLevelHelpers } from "../../contracts/lib/LowLevelHelpers.sol";

import { TestERC721 } from "../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";

import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

import { OrderParameters } from "./utils/reentrancy/ReentrantStructs.sol";

contract FulfillBasicOrderTest is BaseOrderTest, LowLevelHelpers {
    using ArithmeticUtil for uint128;

    BasicOrderParameters basicOrderParameters;
    OrderComponents orderComponents;

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
        _configureERC721OfferItem(inputs.tokenId);
        _configureEthConsiderationItem(alice, inputs.paymentAmount);
        _configureBasicOrderParametersEthTo721(inputs);

        test(this.basicEthTo721, Context(consideration, inputs, 0));
        test(this.basicEthTo721, Context(referenceConsideration, inputs, 0));
    }

    function testBasicErc20To721(FuzzInputsCommon memory inputs)
        public
        validateInputs(Context(consideration, inputs, 0))
    {
        _configureERC721OfferItem(inputs.tokenId);
        _configureErc20ConsiderationItem(alice, inputs.paymentAmount);
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
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureEthConsiderationItem(alice, inputs.paymentAmount);
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
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureErc20ConsiderationItem(alice, inputs.paymentAmount);
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
        uint256 amountToSubtractFromTotalRecipients,
        AdditionalRecipient[] memory additionalRecipients
    ) public {
        vm.assume(additionalRecipients.length <= 200);
        vm.assume(
            amountToSubtractFromTotalRecipients <= additionalRecipients.length
        );
        bool overwriteTotalRecipientsLength = amountToSubtractFromTotalRecipients >
                0;

        // Create basic order
        (
            Order memory myOrder,
            BasicOrderParameters memory _basicOrderParameters
        ) = prepareBasicOrderAndOrderParameters(1);

        // Add additional recipients
        _basicOrderParameters.additionalRecipients = additionalRecipients;
        for (
            uint256 i = 0;
            i < _basicOrderParameters.additionalRecipients.length;
            i++
        ) {
            _basicOrderParameters.additionalRecipients[i].amount = 1;
        }

        // Validate the order.
        Order[] memory myOrders = new Order[](1);
        myOrders[0] = myOrder;
        consideration.validate(myOrders);

        // Get the calldata that will be passed into fulfillBasicOrder.
        bytes4 fulfillBasicOrderSignature = consideration
            .fulfillBasicOrder
            .selector;
        bytes memory fulfillBasicOrderCalldata = abi.encodeWithSelector(
            fulfillBasicOrderSignature,
            _basicOrderParameters
        );

        if (overwriteTotalRecipientsLength) {
            // Get the additional recipients length from the calldata and
            // store the length - amountToSubtractFromTotalRecipients in the calldata
            // so that the length value does _not_ accurately represent the actual
            // total recipients length.
            assembly {
                let additionalRecipientsLengthOffset := add(
                    fulfillBasicOrderCalldata,
                    0x264
                )
                let additionalRecipientsLength := mload(
                    additionalRecipientsLengthOffset
                )
                mstore(
                    additionalRecipientsLengthOffset,
                    sub(
                        additionalRecipientsLength,
                        amountToSubtractFromTotalRecipients
                    )
                )
            }
        }

        address considerationAddress = address(consideration);
        uint256 calldataLength = fulfillBasicOrderCalldata.length;
        bool success;

        assembly {
            // Call fulfillBasicOrders
            success := call(
                gas(),
                considerationAddress,
                0,
                // The fn signature and calldata starts after the
                // first OneWord bytes, as those initial bytes just
                // contain the length of fulfillBasicOrderCalldata
                add(fulfillBasicOrderCalldata, OneWord),
                calldataLength,
                // Store output at empty storage location,
                // identified using "free memory pointer".
                mload(0x40),
                OneWord
            )
        }

        // If overwriteTotalRecipientsLength is True, the call should
        // have failed (success should be False) and if overwriteTotalRecipientsLength is False,
        // the call should have succeeded (success should be True).
        assertEq(!overwriteTotalRecipientsLength, success);

        if (overwriteTotalRecipientsLength) {
            // Expect a revert if the additional recipients length is too small (e.g. 1 was subtracted).
            vm.expectRevert();
        }

        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            revert();
        }
    }

    function prepareBasicOrderAndOrderParameters(uint256 tokenId)
        internal
        returns (
            Order memory _order,
            BasicOrderParameters memory _basicOrderParameters
        )
    {
        test1155_1.mint(address(this), tokenId, 10);

        _configureERC1155OfferItem(tokenId, 10);
        _configureErc20ConsiderationItem(alice, 10);
        uint256 nonce = consideration.getCounter(address(this));

        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
        );

        bytes32 orderHash = consideration.getOrderHash(_orderComponents);

        bytes memory _signature = signOrder(consideration, alicePk, orderHash);
        _order = Order(_orderParameters, _signature);
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
        orderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
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
        orderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
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
        orderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
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
        orderComponents.counter = counter;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
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
        orderComponents.offerer = alice;
        orderComponents.zone = zone;
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 100;
        orderComponents.zoneHash = zoneHash;
        orderComponents.salt = salt;
        orderComponents.conduitKey = conduitKey;
        // don't set counter
    }
}
