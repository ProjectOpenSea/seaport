// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import "contracts/conduit/ConduitController.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";

contract ConsiderationTest is BaseOrderTest {
    //eth to 721
    // alice is offering their 721 for ETH
    function testListBasicETHto721(
        address _zone,
        uint256 _id,
        uint128 _ethAmount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_ethAmount > 0);
        // don't try to mint IDs that already exist
        vm.assume(_id > globalTokenId);

        emit log("Basic 721 Offer - Eth Consideration");

        test721.mint(alice, _id);
        emit log_named_address("Minted test721 token to", alice);

        ConduitController conduitController;
        address conduitControllerAddress;

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, test721Address, _id, 1, 1);

        ConsiderationItem[] memory considerationItem = new ConsiderationItem[](
            1
        );
        considerationItem[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            _ethAmount,
            _ethAmount,
            payable(alice)
        );
        emit log("getting nonce");
        // getNonce
        uint256 nonce = consideration.getNonce(alice);

        emit log("setting up order comps");
        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            nonce
        );

        emit log("created order comps");

        bytes32 orderHash = consideration.getOrderHash(orderComponents);
        emit log("signing...");
        bytes memory signature = signOrder(alicePk, orderHash);

        emit log("creating Order params");
        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(alice),
            _zone,
            test721Address,
            _id,
            1,
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        consideration.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log_named_address(
            "Fulfilled Basic 721 Offer - Eth Consideration",
            alice
        );
    }

    //TODO: add _amount param and test with varying number of 1155s
    function testListBasicETHto1155(
        address _zone,
        uint256 _id,
        uint128 _tokenAmount,
        uint128 _ethAmount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_ethAmount > 0);
        vm.assume(_id > globalTokenId || _id == 0);
        vm.assume(_tokenAmount > 0);

        emit log("Basic 1155 Offer - Eth Consideration");

        test1155_1.mint(alice, _id, _tokenAmount);
        emit log_named_address("Minted test1155_1 token to", alice);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            _id,
            _tokenAmount,
            _tokenAmount
        );

        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            _ethAmount,
            _ethAmount,
            alice
        );

        // getNonce
        uint256 nonce = consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            nonce
        );
        bytes32 orderHash = consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(alice),
            _zone,
            address(test1155_1),
            _id,
            _tokenAmount,
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        consideration.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log_named_address(
            "Fulfilled Basic 1155 Offer - Eth Consideration",
            alice
        );
    }

    function testListBasic20to721(
        address _zone,
        uint256 _id,
        uint128 _erc20Amount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_erc20Amount > 0);
        // vm.assume(_erc20Amount < 100); //TODO change this so we can test big numbers.
        vm.assume(_id > globalTokenId || _id == 0);
        emit log("Basic 721 Offer - ERC20 Consideration");

        test721_1.mint(alice, _id);
        emit log_named_address("Minted test721_1 token to", alice);

        emit log("test 721 minted success");

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC721,
            test721Address,
            _id,
            1,
            1
        );

        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            _erc20Amount,
            _erc20Amount,
            payable(alice)
        );

        // getNonce
        uint256 nonce = consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            nonce
        );
        bytes32 orderHash = consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            _erc20Amount,
            payable(alice),
            _zone,
            test721Address,
            _id,
            1,
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        consideration.fulfillBasicOrder(order);

        emit log("Fulfilled Basic 721 Offer - ERC20 Consideration");
    }

    function testListBasic20to1155(
        address _zone,
        uint256 _id,
        uint128 _tokenAmount,
        uint128 _erc20Amount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_erc20Amount > 0);
        vm.assume(_id > globalTokenId || _id == 0);
        vm.assume(_tokenAmount > 0);

        emit log("Basic 1155 Offer - ERC20 Consideration");

        test1155_1.mint(alice, _id, _tokenAmount);
        emit log_named_address("Minted test1155_1 token to", alice);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            _id,
            _tokenAmount,
            _tokenAmount
        );
        ConsiderationItem[] memory considerationItem = singleConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            _erc20Amount,
            _erc20Amount,
            payable(alice)
        );

        // getNonce
        uint256 nonce = consideration.getNonce(alice);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offer,
            considerationItem,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            nonce
        );

        bytes32 orderHash = consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(alicePk, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            _erc20Amount,
            payable(alice),
            _zone,
            address(test1155_1),
            _id,
            _tokenAmount,
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            bytes32(0), // no conduit
            bytes32(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            signature
        );

        emit log(">>>>");

        // simple
        consideration.fulfillBasicOrder(order);

        emit log("Fulfilled Basic 1155 Offer - ERC20 Consideration");
    }
}
