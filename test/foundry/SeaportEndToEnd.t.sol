// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { Seaport } from "../../contracts/Seaport.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    SignatureVerificationErrors
} from "seaport-types/src/interfaces/SignatureVerificationErrors.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Fills orders through the Seaport contract itself. The rest of the suite
 *      deploys Consideration, whose EIP-712 domain is named "Consideration",
 *      so these are the only fills signed under the "Seaport" domain that
 *      Seaport.sol's name overrides produce.
 */
contract SeaportEndToEndTest is BaseOrderTest {
    ConsiderationInterface internal seaport;

    uint256 internal nextId = 9000;

    function setUp() public override {
        super.setUp();
        if (!coverage_or_debug) {
            seaport = ConsiderationInterface(
                deployCode(
                    "optimized-out/Seaport.sol/Seaport.json",
                    abi.encode(address(conduitController))
                )
            );
        } else {
            seaport = new Seaport(address(conduitController));
        }
        vm.label(address(seaport), "seaport");

        conduitController.updateChannel(
            address(conduit), address(seaport), true
        );

        address payable[2] memory accounts = [alice, bob];
        for (uint256 i; i < 2; ++i) {
            vm.startPrank(accounts[i]);
            token1.approve(address(seaport), type(uint256).max);
            test721_1.setApprovalForAll(address(seaport), true);
            test1155_1.setApprovalForAll(address(seaport), true);
            vm.stopPrank();
        }
    }

    /// @dev Seaport's domain separator is built from the name "Seaport", not
    ///      "Consideration", so a signature made for one does not verify on
    ///      the other.
    function test_domainSeparatorUsesSeaportName() public view {
        (, bytes32 domainSeparator,) = seaport.information();
        assertEq(domainSeparator, _seaportDomainSeparator());

        (, bytes32 considerationSeparator,) = consideration.information();
        assertTrue(domainSeparator != considerationSeparator);
    }

    /// @dev A standard fill: alice's ERC721 for 10 ether to her and 1 ether
    ///      to cal. A signature under the Consideration domain is rejected
    ///      first, then the "Seaport" one fills.
    function test_fulfillOrder() public {
        uint256 id = _mint721(alice);
        OrderParameters memory params = _params(
            _offer(ItemType.ERC721, address(test721_1), id, 1),
            _nativeConsideration()
        );
        bytes32 orderHash = _orderHash(params);

        Order memory order =
            Order(params, signOrder(consideration, alicePk, orderHash));
        vm.expectRevert(SignatureVerificationErrors.InvalidSigner.selector);
        vm.prank(bob);
        seaport.fulfillOrder{ value: 11 ether }(order, bytes32(0));

        order.signature = _signSeaport(alicePk, orderHash);
        uint256 aliceBalance = alice.balance;
        uint256 calBalance = cal.balance;
        vm.prank(bob);
        assertTrue(seaport.fulfillOrder{ value: 11 ether }(order, bytes32(0)));

        assertEq(test721_1.ownerOf(id), bob);
        assertEq(alice.balance, aliceBalance + 10 ether);
        assertEq(cal.balance, calBalance + 1 ether);
        _assertFilled(orderHash);
    }

    /// @dev The basic-order path, which derives the order hash in assembly:
    ///      alice's ERC721 for ERC20 to her and cal.
    function test_fulfillBasicOrder() public {
        uint256 id = _mint721(alice);
        ConsiderationItem[] memory cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1000, 1000, alice
        );
        cons[1] =
            ConsiderationItem(ItemType.ERC20, address(token1), 0, 50, 50, cal);
        OrderParameters memory params =
            _params(_offer(ItemType.ERC721, address(test721_1), id, 1), cons);
        bytes32 orderHash = _orderHash(params);
        Order memory order = Order(params, _signSeaport(alicePk, orderHash));

        uint256 aliceBalance = token1.balanceOf(alice);
        uint256 calBalance = token1.balanceOf(cal);
        uint256 bobBalance = token1.balanceOf(bob);
        vm.prank(bob);
        assertTrue(
            seaport.fulfillBasicOrder(
                toBasicOrderParameters(
                    order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
                )
            )
        );

        assertEq(test721_1.ownerOf(id), bob);
        assertEq(token1.balanceOf(alice), aliceBalance + 1000);
        assertEq(token1.balanceOf(cal), calBalance + 50);
        assertEq(token1.balanceOf(bob), bobBalance - 1050);
        _assertFilled(orderHash);
    }

    /// @dev An advanced fill through the conduit, which Seaport finds from
    ///      the controller's conduit code hash: alice's ERC1155 for ERC20,
    ///      with both sides moved by the conduit.
    function test_fulfillAdvancedOrderViaConduit() public {
        uint256 id = _newId();
        test1155_1.mint(alice, id, 10);
        OrderParameters memory params = _params(
            _offer(ItemType.ERC1155, address(test1155_1), id, 10),
            _erc20Consideration(alice, 500)
        );
        params.conduitKey = conduitKeyOne;
        bytes32 orderHash = _orderHash(params);

        uint256 aliceBalance = token1.balanceOf(alice);
        vm.prank(bob);
        assertTrue(
            seaport.fulfillAdvancedOrder(
                toAdvancedOrder(
                    Order(params, _signSeaport(alicePk, orderHash))
                ),
                new CriteriaResolver[](0),
                conduitKeyOne,
                address(0)
            )
        );

        assertEq(test1155_1.balanceOf(bob, id), 10);
        assertEq(token1.balanceOf(alice), aliceBalance + 500);
        _assertFilled(orderHash);
    }

    function _seaportDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Seaport"),
                keccak256("1.6"),
                block.chainid,
                address(seaport)
            )
        );
    }

    /// @dev Signs the EIP-712 digest under the expected "Seaport" domain,
    ///      built here rather than read back from Seaport.
    function _signSeaport(uint256 pk, bytes32 orderHash)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            pk,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901), _seaportDomainSeparator(), orderHash
                )
            )
        );
        return abi.encodePacked(r, s, v);
    }

    function _orderHash(OrderParameters memory params)
        internal
        view
        returns (bytes32)
    {
        return seaport.getOrderHash(
            toOrderComponents(params, seaport.getCounter(params.offerer))
        );
    }

    function _assertFilled(bytes32 orderHash) internal view {
        (bool isValidated, bool isCancelled, uint256 filled, uint256 size) =
            seaport.getOrderStatus(orderHash);
        assertTrue(isValidated);
        assertFalse(isCancelled);
        assertEq(filled, 1);
        assertEq(size, 1);
    }

    function _mint721(address to) internal returns (uint256 id) {
        id = _newId();
        test721_1.mint(to, id);
    }

    function _newId() internal returns (uint256) {
        return nextId++;
    }

    function _offer(
        ItemType itemType,
        address token,
        uint256 id,
        uint256 amount
    ) internal pure returns (OfferItem[] memory offer) {
        offer = new OfferItem[](1);
        offer[0] = OfferItem(itemType, token, id, amount, amount);
    }

    function _nativeConsideration()
        internal
        view
        returns (ConsiderationItem[] memory cons)
    {
        cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 10 ether, 10 ether, alice
        );
        cons[1] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 1 ether, 1 ether, cal
        );
    }

    function _erc20Consideration(address recipient, uint256 amount)
        internal
        view
        returns (ConsiderationItem[] memory cons)
    {
        cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            amount,
            amount,
            payable(recipient)
        );
    }

    function _params(OfferItem[] memory offer, ConsiderationItem[] memory cons)
        internal
        returns (OrderParameters memory)
    {
        return OrderParameters({
            offerer: alice,
            zone: address(0),
            offer: offer,
            consideration: cons,
            orderType: OrderType.FULL_OPEN,
            startTime: block.timestamp,
            endTime: block.timestamp + 100,
            zoneHash: bytes32(0),
            salt: globalSalt++,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: cons.length
        });
    }
}
