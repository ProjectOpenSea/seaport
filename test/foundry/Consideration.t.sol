// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "contracts/lib/ConsiderationStructs.sol";
import "contracts/Consideration.sol";
import "contracts/conduit/ConduitController.sol";

import { DSTestPlusPlus } from "./utils/DSTestPlusPlus.sol";
import { TestERC721 } from "contracts/test/TestERC721.sol";

contract ConsiderationTest is DSTestPlusPlus {
    Consideration consider;
    address considerAddress;

    ConduitController conduitController;
    address conduitControllerAddress;

    address accountA;
    address accountB;
    address accountC;

    address test721Address;
    TestERC721 test721;

    function setUp() public {
        conduitControllerAddress = address(new ConduitController());
        conduitController = ConduitController(conduitControllerAddress);

        considerAddress = address(
            new Consideration(
                conduitControllerAddress,
                address(0),
                address(0),
                address(0)
            )
        );
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
        emit log("Accounts A B C have approved consideration.");

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

        emit log("Basic Order");

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

        emit log("Fulfilled Consideration basic order signed by AccountA");
    }
}
