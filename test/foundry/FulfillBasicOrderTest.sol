// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { TestERC721 } from "../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";

import { TestERC20 } from "../../contracts/test/TestERC20.sol";

contract FulfillBasicOrderTest is BaseOrderTest {
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
        Consideration consideration;
        FuzzInputsCommon args;
        uint128 tokenAmount;
    }

    function testBasicEthTo721(FuzzInputsCommon memory inputs) public {
        _configureERC721OfferItem(inputs.tokenId);
        _configureEthConsiderationItem(inputs.paymentAmount);
        _configureBasicOrderParametersEthTo721(inputs);

        _testBasicEthTo721_new(Context(consideration, inputs, 0));
        _configureERC721OfferItem(inputs.tokenId);
        _configureEthConsiderationItem(inputs.paymentAmount);
        _testBasicEthTo721_new(Context(referenceConsideration, inputs, 0));
    }

    function testBasicErc20To721(FuzzInputsCommon memory inputs) public {
        _configureERC721OfferItem(inputs.tokenId);
        _configureErc20ConsiderationItem(inputs.paymentAmount);
        _configureBasicOrderParametersErc20To721(inputs);

        _testBasicErc20To721_new(Context(consideration, inputs, 0));
        _configureERC721OfferItem(inputs.tokenId);
        _configureErc20ConsiderationItem(inputs.paymentAmount);
        _testBasicErc20To721_new(Context(referenceConsideration, inputs, 0));
    }

    function testBasicEthTo1155(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount
    ) public {
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureEthConsiderationItem(inputs.paymentAmount);

        _configureBasicOrderParametersEthTo1155(inputs, tokenAmount);
        _testBasicEthTo1155_new(
            Context(referenceConsideration, inputs, tokenAmount)
        );
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureEthConsiderationItem(inputs.paymentAmount);
        _testBasicEthTo1155_new(Context(consideration, inputs, tokenAmount));
    }

    function testBasicErc20To1155(
        FuzzInputsCommon memory inputs,
        uint128 tokenAmount
    ) public {
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureErc20ConsiderationItem(inputs.paymentAmount);

        _configureBasicOrderParametersErc20To1155(inputs, tokenAmount);
        _testBasicErc20To1155_new(
            Context(referenceConsideration, inputs, tokenAmount)
        );
        _configureERC1155OfferItem(inputs.tokenId, tokenAmount);
        _configureErc20ConsiderationItem(inputs.paymentAmount);
        _testBasicErc20To1155_new(Context(consideration, inputs, tokenAmount));
    }

    function _testBasicErc20To1155_new(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.args.paymentAmount > 0);
        vm.assume(context.tokenAmount > 0);

        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 nonce = context.consideration.getNonce(alice);
        orderComponents.nonce = nonce;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder(basicOrderParameters);
    }

    function _testBasicEthTo1155_new(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.args.paymentAmount > 0);
        vm.assume(context.tokenAmount > 0);

        test1155_1.mint(alice, context.args.tokenId, context.tokenAmount);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 nonce = context.consideration.getNonce(alice);
        orderComponents.nonce = nonce;
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
    }

    function _testBasicEthTo721_new(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.args.paymentAmount > 0);

        test721_1.mint(alice, context.args.tokenId);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 nonce = context.consideration.getNonce(alice);
        orderComponents.nonce = nonce;
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
    }

    function _testBasicErc20To721_new(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.args.paymentAmount > 0);

        test721_1.mint(alice, context.args.tokenId);

        _configureOrderComponents(
            context.args.zone,
            context.args.zoneHash,
            context.args.salt,
            bytes32(0)
        );
        uint256 nonce = context.consideration.getNonce(alice);
        orderComponents.nonce = nonce;
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        basicOrderParameters.signature = signature;
        context.consideration.fulfillBasicOrder(basicOrderParameters);
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
        // don't set nonce
    }
}
