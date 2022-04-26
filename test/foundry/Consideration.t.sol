// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "contracts/lib/ConsiderationStructs.sol";
import { Consideration, OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "contracts/Consideration.sol";
import { DSTestPlusPlus } from "./utils/DSTestPlusPlus.sol";
import { TestERC721 } from "contracts/test/TestERC721.sol";
import { TestERC1155 } from "contracts/test/TestERC1155.sol";
import { TestERC20 } from "contracts/test/TestERC20.sol";
import { ERC721Recipient } from "./utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "./utils/ERC1155Recipient.sol";

contract ConsiderationTest is
    DSTestPlusPlus,
    ERC721Recipient,
    ERC1155Recipient
{
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

    address test20Address;
    TestERC20 test20;

    function setUp() public {
        conduitControllerAddress = address(new ConduitController());
        conduitController = ConduitController(conduitControllerAddress);

        considerAddress = address(new Consideration(conduitControllerAddress));
        consider = Consideration(considerAddress);

        //deploy a test 721
        test721Address = address(new TestERC721());
        test721 = TestERC721(test721Address);

        accountA = vm.addr(1);
        accountB = vm.addr(2);
        accountC = vm.addr(3);

        vm.prank(accountA);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountB);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountC);
        test721.setApprovalForAll(considerAddress, true);

        //deploy a test 1155
        test1155Address = address(new TestERC1155());
        test1155 = TestERC1155(test1155Address);

        //deploy a test erc20
        test20Address = address(new TestERC20());
        test20 = TestERC20(test20Address);

        emit log("Accounts A B C have approved consideration.");

        vm.label(accountA, "Account A");
    }

    // Helpers
    function signOrder(bytes32 _orderHash)
        external
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        return
            vm.sign(
                1,
                keccak256(
                    abi.encodePacked(
                        bytes2(0x1901),
                        consider.DOMAIN_SEPARATOR(),
                        _orderHash
                    )
                )
            );
    }

    function genConsiderationItem(
        ItemType _itemType,
        address _token,
        uint256 _identifierOrCriteria,
        uint256 _startAmount,
        uint256 _endAmount,
        address payable _recipient
    ) external pure returns (ConsiderationItem memory) {
        ConsiderationItem memory consideration = ConsiderationItem(
            _itemType,
            _token,
            _identifierOrCriteria,
            _startAmount,
            _endAmount,
            _recipient
        );

        return consideration;
    }

    //basic Order

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
        vm.assume(_id > globalTokenId || _id == 0);

        emit log("Basic 721 Offer - Eth Consideration");

        test721_1.mint(alice, _id);
        emit log_named_address("Minted test721_1 token to", alice);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, address(test721_1), _id, 1, 1);

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
        bytes32 orderHash = consider.getOrderHash(orderComponents);

        (, bytes32 domainSeparator, ) = consider.information();

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(alice),
            _zone,
            address(test721_1),
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

        OfferItem[] memory offer = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
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
            address(address(test721_1)),
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

        emit log_named_address(
            "Fulfilled Basic 721 Offer - Eth Consideration",
            alice
        );
    }

    //TODO: add _amount param and test with varying number of 1155s
    function testListBasicETHto1155(
        address _zone,
        uint256 _id,
        uint256 _ethAmount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_ethAmount > 0);
        vm.assume(_id > 0);

        test1155.mint(accountA, _id, 1);
        emit log("Account A airdropped an 1155 NFT.");
        vm.prank(accountA);
        test1155.setApprovalForAll(considerAddress, true);
        emit log("Account A approved consideration for their 1155 NFT.");

        // default caller ether amount is 2**96
        vm.deal(address(this), 2**256 - 1);
        emit log("Caller airdropped ETH.");

        emit log("Basic eth to 1155 Order");

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC1155, test1155Address, _id, 1, 1);

        emit log("Offer item 1155 created.");

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0), // eth order, should be 0
            0,
            _ethAmount,
            _ethAmount,
            payable(accountA)
        );

        emit log("consideration item native created");

        // getNonce
        uint256 nonce = consider.getNonce(accountA);

        // getOrderHash
        OrderComponents memory orderComponents = OrderComponents(
            accountA,
            _zone,
            offer,
            consideration,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            address(0), // no conduit
            nonce
        );
        bytes32 orderHash = consider.getOrderHash(orderComponents);

        emit log("order components made and hashed.");

        //accountA is pk 1.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    consider.DOMAIN_SEPARATOR(),
                    orderHash
                )
            )
        );

        emit log("order signed by account A");

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            address(0),
            0,
            _ethAmount,
            payable(accountA),
            _zone,
            test1155Address,
            _id,
            1,
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            address(0), // no conduit
            address(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");
        emit log_uint(test1155.balanceOf(accountA, _id)); // tokens owned by accountA

        // simple
        consider.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log(
            "Fulfilled Consideration basic order eth to 1155 signed by AccountA"
        );
    }

    function testListBasic20to721(
        address _zone,
        uint256 _id,
        uint256 _erc20Amount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_erc20Amount > 0);
        vm.assume(_erc20Amount < 100); //TODO change this so we can test big numbers.

        test721.mint(accountA, _id);
        emit log("Account A airdropped an NFT.");

        // default caller ether amount is 2**96
        vm.deal(address(this), 2**256 - 1);
        emit log("Caller airdropped ETH.");

        test20.mint(address(this), 100);
        test20.approve(considerAddress, 2**256 - 1);

        emit log("Basic erc20 to 721 Order");

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, test721Address, _id, 1, 1);

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem(
            ItemType.ERC20,
            test20Address,
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
            consideration,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            address(0), // no conduit
            nonce
        );
        bytes32 orderHash = consider.getOrderHash(orderComponents);

        //accountA is pk 1.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    consider.DOMAIN_SEPARATOR(),
                    orderHash
                )
            )
        );

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            test20Address,
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
            address(0), // no conduit
            address(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");

        // simple
        consider.fulfillBasicOrder(order);

        emit log("Fulfilled Consideration basic order signed by AccountA");
    }

    function testListBasic20to1155(
        address _zone,
        uint256 _id,
        uint256 _erc20Amount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_erc20Amount > 0);
        vm.assume(_erc20Amount < 100); //TODO change this so we can test big numbers.

        test20.approve(considerAddress, 2**256 - 1);

        test1155.mint(accountA, _id, 100);
        emit log("Account A airdropped an 1155 NFT.");

        vm.prank(accountA);
        test1155.setApprovalForAll(considerAddress, true);
        emit log("Account A approved test1155 for consider.");

        // default caller ether amount is 2**96
        vm.deal(address(this), 2**256 - 1);
        emit log("Caller airdropped ETH.");

        test20.mint(address(this), 100);

        emit log("Basic erc20 to 1155 Order");

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC1155, test1155Address, _id, 1, 1);

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem(
            ItemType.ERC20,
            test20Address,
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
            consideration,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            address(0), // no conduit
            nonce
        );
        bytes32 orderHash = consider.getOrderHash(orderComponents);

        //accountA is pk 1.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            1,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    consider.DOMAIN_SEPARATOR(),
                    orderHash
                )
            )
        );

        // fulfill
        BasicOrderParameters memory order = BasicOrderParameters(
            test20Address,
            0,
            _erc20Amount,
            payable(accountA),
            _zone,
            test1155Address,
            _id,
            1,
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN,
            block.timestamp,
            block.timestamp + 5000,
            _zoneHash,
            _salt,
            address(0), // no conduit
            address(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");

        // simple
        consider.fulfillBasicOrder(order);

        emit log("Fulfilled Consideration basic order signed by AccountA");
    }
}
