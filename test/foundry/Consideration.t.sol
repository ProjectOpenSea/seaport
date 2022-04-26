// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "contracts/lib/ConsiderationStructs.sol";
import "contracts/Consideration.sol";

import { DSTestPlusPlus } from "./utils/DSTestPlusPlus.sol";
import { TestERC721 } from "contracts/test/TestERC721.sol";
import { TestERC1155 } from "contracts/test/TestERC1155.sol";
import { TestERC20 } from "contracts/test/TestERC20.sol";

contract ConsiderationTest is DSTestPlusPlus {
    Consideration consider;
    address considerAddress;

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
        considerAddress = address(
            new Consideration(address(0), address(0), address(0))
        );
        consider = Consideration(considerAddress);

        //deploy a test 721
        test721Address = address(new TestERC721());
        test721 = TestERC721(test721Address);

        //deploy a test 1155
        test1155Address = address(new TestERC1155());
        test1155 = TestERC1155(test1155Address);

        //deploy a test erc20
        test20Address = address(new TestERC20());
        test20 = TestERC20(test20Address);

        accountA = vm.addr(1);
        accountB = vm.addr(2);
        accountC = vm.addr(3);

        vm.prank(accountA);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountB);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountC);
        test721.setApprovalForAll(considerAddress, true);
        emit log("Accounts A B C have approved consideration.");

        vm.prank(accountA);
        test1155.setApprovalForAll(considerAddress, true);

        vm.prank(accountA);
        test20.approve(considerAddress, 100);

        vm.label(accountA, "Account A");
    }

    //basic Order

    //eth to 721
    //accountA is offering their 721 for ETH
    function testListBasicETHto721(
        address _zone,
        uint256 _id,
        uint256 _ethAmount,
        bytes32 _zoneHash,
        uint256 _salt
    ) external {
        // fails on 0 since we calculate payable status based on msg.value; ie, we don't support 0 value orders
        vm.assume(_ethAmount > 0);

        test721.mint(accountA, _id);
        emit log("Account A airdropped an NFT.");

        // default caller ether amount is 2**96
        vm.deal(address(this), 2**256 - 1);
        emit log("Caller airdropped ETH.");

        emit log("Basic eth to 721 Order");

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, test721Address, _id, 1, 1);

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            _ethAmount,
            _ethAmount,
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
            address(0), // no conduit
            address(0), // no conduit
            0,
            new AdditionalRecipient[](0),
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");

        // simple
        consider.fulfillBasicOrder{ value: _ethAmount }(order);

        emit log("Fulfilled Consideration basic order signed by AccountA");
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

        test20.mint(address(this), 2**256 - 1);

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
        consider.fulfillBasicOrder{ value: _erc20Amount }(order);

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

        test1155.mint(accountA, _id, 100);
        emit log("Account A airdropped an 1155 NFT.");

        // default caller ether amount is 2**96
        vm.deal(address(this), 2**256 - 1);
        emit log("Caller airdropped ETH.");

        test20.mint(address(this), 2**256 - 1);

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
        consider.fulfillBasicOrder{ value: _erc20Amount }(order);

        emit log("Fulfilled Consideration basic order signed by AccountA");
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
}
