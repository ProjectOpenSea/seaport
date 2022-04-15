// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import "../../contracts/Consideration.sol";

import { DSTestPlus } from "src/test/utils/DSTestPlus.sol";
import "src/test/NFT721.sol";
import "src/test/CheatCodes.sol";

//use solmate tokens

contract ConsiderationTest is DSTestPlus {
    Consideration consider;
    address considerAddress;

    address accountA;
    address accountB;
    address accountC;

    address test721Address;
    NFT test721;

    function setUp() public {
        considerAddress = address(new Consideration(address(0), address(0)));
        consider = Consideration(considerAddress);

        //deploy a test 721
        test721Address = address(new NFT("Nifty", "NFT"));
        test721 = NFT(test721Address);

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
        test721.mintTo(accountA, _id);
        emit log("Account A airdropped an NFT.");

        vm.deal(address(this), _ethAmount);
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
            false,
            0,
            new AdditionalRecipient[](0),
            abi.encodePacked(r, s, v)
        );

        emit log(">>>>");

        // simple
        consider.fulfillBasicOrder{ value: _ethAmount }(order);

        //// to debug a bit
        // try consider.fulfillBasicOrder{value: _ethAmount}(order) {
        //         emit log("ok");
        //     } catch (bytes memory err) {
        //         if (keccak256(abi.encodeWithSignature("InvalidSigner()")) == keccak256(err)) {
        //             revert("bad signer");
        //         } else {
        //             if (err.length == 0) {
        //                 revert("no error data");
        //             } else {
        //                 revert("an error was returned");
        //             }
        //         }
        // }

        emit log("Fulfilled Consideration basic order signed by AccountA");
    }

    //eth to 1155
    //20 to 721
    //20 to 1155
    //721 to 20
    // 1155 to 20

    //match
    // function testMatchOrder721toEth() external {
    //     emit log("Basic Order, Match Order");
    //     address seller = accountA;
    //     vm.startPrank(seller);
    // }
}
