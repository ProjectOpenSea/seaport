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
    struct TestBasicOrder {
        address zone;
        uint256 tokenId;
        uint128 paymentAmount;
        bytes32 zoneHash;
        uint256 salt;
    }

    struct TestBasicOrder1155 {
        address zone;
        uint256 tokenId;
        uint256 tokenAmount;
        uint128 paymentAmount;
        bytes32 zoneHash;
        uint256 salt;
    }

    function testBasicSingleERC721(TestBasicOrder memory testBasicOrder)
        public
    {
        _testListBasicEthTo721(consideration, testBasicOrder);
        _testListBasicEthTo721(referenceConsideration, testBasicOrder);
    }

    function testListBasicEthTo1155(TestBasicOrder1155 memory testBasicOrder)
        public
    {
        _testListBasicEthTo1155(consideration, testBasicOrder);
        _testListBasicEthTo1155(referenceConsideration, testBasicOrder);
    }

    function testListBasic20to721(TestBasicOrder memory testBasicOrder) public {
        _testListBasic20to721(consideration, testBasicOrder);
        _testListBasic20to721(referenceConsideration, testBasicOrder);
    }

    function testListBasic20to1155(TestBasicOrder1155 memory testBasicOrder)
        public
    {
        _testListBasic20to1155(consideration, testBasicOrder);
        _testListBasic20to1155(referenceConsideration, testBasicOrder);
    }

    function _testListBasicEthTo721(
        Consideration _consideration,
        TestBasicOrder memory testBasicOrder
    ) internal resetTokenBalancesBetweenRuns {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(testBasicOrder.paymentAmount > 0);
        // don't try to mint IDs that already exist
        vm.assume(
            testBasicOrder.tokenId > globalTokenId ||
                testBasicOrder.tokenId == 0
        );

        emit log("Basic 721 Offer - Eth Consideration");

        test721_1.mint(alice, testBasicOrder.tokenId);
        emit log_named_address("Minted test721_1 token to", alice);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(
            ItemType.ERC721,
            address(test721_1),
            testBasicOrder.tokenId,
            1,
            1
        );

        ConsiderationItem[] memory considerationItem = new ConsiderationItem[](
            1
        );
        considerationItem[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            testBasicOrder.paymentAmount,
            testBasicOrder.paymentAmount,
            payable(alice)
        );

        // getNonce
        uint256 nonce = _consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testBasicOrder.zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            nonce
        );
        bytes32 orderHash = _consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(_consideration, alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            testBasicOrder.paymentAmount,
            payable(alice),
            testBasicOrder.zone,
            address(test721_1),
            testBasicOrder.tokenId,
            1,
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        _consideration.fulfillBasicOrder{ value: testBasicOrder.paymentAmount }(
            order
        );

        emit log_named_address(
            "Fulfilled Basic 721 Offer - Eth Consideration",
            alice
        );
    }

    function _testListBasicEthTo1155(
        Consideration _consideration,
        TestBasicOrder1155 memory testBasicOrder
    ) internal resetTokenBalancesBetweenRuns {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(testBasicOrder.paymentAmount > 0);
        vm.assume(
            testBasicOrder.tokenId > globalTokenId ||
                testBasicOrder.tokenId == 0
        );
        vm.assume(testBasicOrder.tokenAmount > 0);

        emit log("Basic 1155 Offer - Eth Consideration");

        test1155_1.mint(
            alice,
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount
        );
        emit log_named_address("Minted test1155_1 token to", alice);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount,
            testBasicOrder.tokenAmount
        );

        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            testBasicOrder.paymentAmount,
            testBasicOrder.paymentAmount,
            alice
        );

        // getNonce
        uint256 nonce = _consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testBasicOrder.zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            nonce
        );
        bytes32 orderHash = _consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(_consideration, alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            testBasicOrder.paymentAmount,
            payable(alice),
            testBasicOrder.zone,
            address(test1155_1),
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount,
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        _consideration.fulfillBasicOrder{ value: testBasicOrder.paymentAmount }(
            order
        );

        emit log_named_address(
            "Fulfilled Basic 1155 Offer - Eth Consideration",
            alice
        );
    }

    function _testListBasic20to721(
        Consideration _consideration,
        TestBasicOrder memory testBasicOrder
    ) internal resetTokenBalancesBetweenRuns {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(testBasicOrder.paymentAmount > 0);
        // vm.assume(testBasicOrder.paymentAmount < 100); //TODO change this so we can test big numbers.
        vm.assume(
            testBasicOrder.tokenId > globalTokenId ||
                testBasicOrder.tokenId == 0
        );
        emit log("Basic 721 Offer - ERC20 Consideration");

        test721_1.mint(alice, testBasicOrder.tokenId);
        emit log_named_address("Minted test721_1 token to", alice);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
            testBasicOrder.tokenId,
            1,
            1
        );

        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            testBasicOrder.paymentAmount,
            testBasicOrder.paymentAmount,
            payable(alice)
        );

        // getNonce
        uint256 nonce = _consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testBasicOrder.zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            nonce
        );
        bytes32 orderHash = _consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(_consideration, alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            testBasicOrder.paymentAmount,
            payable(alice),
            testBasicOrder.zone,
            address(address(test721_1)),
            testBasicOrder.tokenId,
            1,
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        _consideration.fulfillBasicOrder(order);

        emit log("Fulfilled Basic 721 Offer - ERC20 Consideration");
    }

    function _testListBasic20to1155(
        Consideration _consideration,
        TestBasicOrder1155 memory testBasicOrder
    ) internal resetTokenBalancesBetweenRuns {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(testBasicOrder.paymentAmount > 0);
        vm.assume(
            testBasicOrder.tokenId > globalTokenId ||
                testBasicOrder.tokenId == 0
        );
        vm.assume(testBasicOrder.tokenAmount > 0);

        emit log("Basic 1155 Offer - ERC20 Consideration");

        test1155_1.mint(
            alice,
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount
        );
        emit log_named_address("Minted test1155_1 token to", alice);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount,
            testBasicOrder.tokenAmount
        );
        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            testBasicOrder.paymentAmount,
            testBasicOrder.paymentAmount,
            payable(alice)
        );

        // getNonce
        uint256 nonce = _consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testBasicOrder.zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            nonce
        );

        bytes32 orderHash = _consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(_consideration, alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            testBasicOrder.paymentAmount,
            payable(alice),
            testBasicOrder.zone,
            address(test1155_1),
            testBasicOrder.tokenId,
            testBasicOrder.tokenAmount,
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            testBasicOrder.zoneHash,
            testBasicOrder.salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        _consideration.fulfillBasicOrder(order);

        emit log_named_address(
            "Fulfilled Basic 721 Offer - Eth Consideration",
            alice
        );
    }
}
