// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import "contracts/conduit/ConduitController.sol";

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";

contract ConsiderationTest is BaseOrderTest {
    Consideration consider;
    address considerAddress;

    ConduitController conduitController;
    address conduitControllerAddress;

    address accountA;
    address accountB;
    address accountC;

    address test721Address;
    TestERC721 test721;

    address test1155Address;
    TestERC1155 test1155;

    function setUp() public override {
        _deployLegacyContracts();
        conduitControllerAddress = address(new ConduitController());
        conduitController = ConduitController(conduitControllerAddress);

        considerAddress = address(
            new Consideration(
                conduitControllerAddress,
                _wyvernProxyRegistry,
                _wyvernTokenTransferProxy,
                _wyvernDelegateProxyImplementation
            )
        );

        emit log_named_address("Deployed Consideration at", considerAddress);

        consider = Consideration(considerAddress);

        //deploy a test 721
        test721Address = address(new TestERC721());
        test721 = TestERC721(test721Address);

        //deploy a test 1155
        test1155Address = address(new TestERC1155());
        test1155 = TestERC1155(test1155Address);

        accountA = vm.addr(1);
        accountB = vm.addr(2);
        accountC = vm.addr(3);

        vm.prank(accountA);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountB);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountC);
        test721.setApprovalForAll(considerAddress, true);
        emit log("Accounts A B C have approved consider.");

        vm.label(accountA, "Account A");
    }

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
        vm.assume(_id > globalTokenId || _id == 0);

        emit log("Basic 721 Offer - Eth Consideration");

        test721.mint(accountA, _id);
        emit log_named_address("Minted test721 token to", accountA);

        OfferItem[] memory offer = new OfferItem[](1);
        emit log("offer item createde");

        offer[0] = OfferItem(ItemType.ERC721, test721Address, _id, 1, 1);
        emit log("offer0 set");

        ConsiderationItem[] memory considerationItem = new ConsiderationItem[](
            1
        );
        emit log("Consideration items made");

        considerationItem[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            _ethAmount,
            _ethAmount,
            payable(accountA)
        );

        emit log("getting nonce");
        // getNonce
        uint256 nonce = consider.getNonce(accountA);

        emit log("Getting order hash creation...");
        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            accountA,
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
        bytes32 orderHash = consider.getOrderHash(orderComponents);

        (bytes32 domainSeparator, ) = consider.information();

        //accountA is pk 1.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, orderHash)
            )
        );

        emit log("Creating Basic Order Params to fulfill...");

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(accountA),
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
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");

        // simple
        consider.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log_named_address(
            "Fulfilled Basic 721 Offer - Eth Consideration",
            accountA
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

        test1155.mint(accountA, _id, _tokenAmount);
        emit log_named_address("Minted test1155 token to", accountA);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            test1155Address,
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
            accountA
        );

        // getNonce
        uint256 nonce = consider.getNonce(accountA);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            accountA,
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
        bytes32 orderHash = consider.getOrderHash(orderComponents);
        bytes memory signature = signOrder(1, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(accountA),
            _zone,
            test1155Address,
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
        consider.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log_named_address(
            "Fulfilled Basic 1155 Offer - Eth Consideration",
            accountA
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

        test721.mint(accountA, _id);
        emit log_named_address("Minted test721 token to", accountA);

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
            payable(accountA)
        );

        // getNonce
        uint256 nonce = consider.getNonce(accountA);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            accountA,
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
        bytes32 orderHash = consider.getOrderHash(orderComponents);
        bytes memory signature = signOrder(1, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            _erc20Amount,
            payable(accountA),
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
        consider.fulfillBasicOrder(order);

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

        test1155.mint(accountA, _id, _tokenAmount);
        emit log_named_address("Minted test1155 token to", accountA);

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC1155,
            test1155Address,
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
            payable(accountA)
        );

        // getNonce
        uint256 nonce = consider.getNonce(accountA);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            accountA,
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

        bytes32 orderHash = consider.getOrderHash(orderComponents);
        bytes memory signature = signOrder(1, orderHash);

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(token1),
            0,
            _erc20Amount,
            payable(accountA),
            _zone,
            test1155Address,
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
        consider.fulfillBasicOrder(order);

        emit log("Fulfilled Basic 1155 Offer - ERC20 Consideration");
    }
}
