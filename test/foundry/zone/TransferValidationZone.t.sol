// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Merkle } from "murky/Merkle.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import {
    TestTransferValidationZoneOfferer
} from "../../../contracts/test/TestTransferValidationZoneOfferer.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    ItemType,
    OrderType,
    Side
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev The "Zone - Transfer Validation" block of zone.spec.ts. The zone's
 *      validateOrder checks that every consideration recipient and the
 *      fulfiller already hold the order's items and that Seaport holds no
 *      native tokens, so each fill also shows that Seaport calls the zone
 *      only after it has made every transfer. The fulfiller and the
 *      consideration recipients are fresh accounts with no tokens, so a check
 *      made before the transfers would fail. Each case runs against the
 *      optimized and the reference build.
 */
contract TransferValidationZoneTest is BaseOrderTest {
    Merkle internal merkle = new Merkle();

    uint256 internal nextId = 7000;

    /// @dev "Fulfills an order with a transfer validation zone"
    function test_fulfillOrder() public {
        _forEachSeaport(_fulfillOrder);
    }

    function _fulfillOrder(ConsiderationInterface c) internal {
        (TestTransferValidationZoneOfferer zone, address buyer) = _setUpFill();
        uint256 id = _mint721(alice);
        (Order memory order,) = _sign(
            c,
            _params(
                _offer(ItemType.ERC721, address(test721_1), id, 1),
                address(zone),
                OrderType.FULL_RESTRICTED
            )
        );

        vm.prank(buyer);
        c.fulfillOrder{ value: 11 ether }(order, bytes32(0));

        assertEq(test721_1.ownerOf(id), buyer);
        _assertRecipientsPaid(order.parameters.consideration, 1);
        assertEq(zone.callCount(), 1);
    }

    /// @dev "Fulfills an advanced order with criteria with the transfer
    ///      validation zone": the zone sees the resolved identifier.
    function test_fulfillAdvancedOrderWithCriteria() public {
        _forEachSeaport(_fulfillAdvancedOrderWithCriteria);
    }

    function _fulfillAdvancedOrderWithCriteria(ConsiderationInterface c)
        internal
    {
        (TestTransferValidationZoneOfferer zone, address buyer) = _setUpFill();
        uint256 id = _mint721(alice);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encode(id));
        leaves[1] = keccak256(abi.encode(id + 1000));

        (Order memory order,) = _sign(
            c,
            _params(
                _offer(
                    ItemType.ERC721_WITH_CRITERIA,
                    address(test721_1),
                    uint256(merkle.getRoot(leaves)),
                    1
                ),
                address(zone),
                OrderType.FULL_RESTRICTED
            )
        );
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] =
            CriteriaResolver(0, Side.OFFER, 0, id, merkle.getProof(leaves, 0));

        vm.prank(buyer);
        c.fulfillAdvancedOrder{ value: 11 ether }(
            toAdvancedOrder(order), resolvers, bytes32(0), address(0)
        );

        assertEq(test721_1.ownerOf(id), buyer);
        _assertRecipientsPaid(order.parameters.consideration, 1);
        assertEq(zone.callCount(), 1);
    }

    /// @dev "Fulfills a PARTIAL_RESTRICTED order with the caller being the
    ///      offerer through the transfer validation zone". Despite its name,
    ///      the Hardhat test filled from the buyer, as this one does.
    function test_fulfillPartialRestrictedOrder() public {
        _forEachSeaport(_fulfillPartialRestrictedOrder);
    }

    function _fulfillPartialRestrictedOrder(ConsiderationInterface c) internal {
        (TestTransferValidationZoneOfferer zone, address buyer) = _setUpFill();
        uint256 id = _mint721(alice);
        (Order memory order, bytes32 orderHash) = _sign(
            c,
            _params(
                _offer(ItemType.ERC721, address(test721_1), id, 1),
                address(zone),
                OrderType.PARTIAL_RESTRICTED
            )
        );

        vm.prank(buyer);
        c.fulfillAdvancedOrder{ value: 11 ether }(
            toAdvancedOrder(order),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );

        assertEq(test721_1.ownerOf(id), buyer);
        _assertRecipientsPaid(order.parameters.consideration, 1);
        assertEq(zone.callCount(), 1);
        (,, uint256 filled, uint256 size) = c.getOrderStatus(orderHash);
        assertEq(filled, 1);
        assertEq(size, 1);
    }

    /// @dev "Reverts on fulfill and aggregate multiple orders (ERC-1155) via
    ///      fulfillAvailableAdvancedOrders (via conduit) with balance checking
    ///      on validation zone (1.2 Issue - resolved in 1.3)". Two orders
    ///      each offer 5 of one ERC1155 and aggregate into a single transfer
    ///      of 10. Seaport 1.2 validated the restricted order before that
    ///      transfer, so the zone saw a fulfiller with no tokens and reverted.
    ///      From 1.3 on, the zone runs after it and the fill succeeds.
    function test_fulfillAvailableAggregatesBeforeValidation() public {
        _forEachSeaport(_fulfillAvailableAggregatesBeforeValidation);
    }

    function _fulfillAvailableAggregatesBeforeValidation(ConsiderationInterface c)
        internal
    {
        (TestTransferValidationZoneOfferer zone, address buyer) = _setUpFill();
        uint256 id = _newId();
        test1155_1.mint(alice, id, 10);

        OrderParameters memory restricted = _params(
            _offer(ItemType.ERC1155, address(test1155_1), id, 5),
            address(zone),
            OrderType.FULL_RESTRICTED
        );
        restricted.conduitKey = conduitKeyOne;
        OrderParameters memory open = _params(
            _offer(ItemType.ERC1155, address(test1155_1), id, 5),
            makeAddr("notAZone"),
            OrderType.FULL_OPEN
        );
        open.conduitKey = conduitKeyOne;
        // Same recipients for both orders, so each item aggregates.
        open.consideration = restricted.consideration;

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        (Order memory order,) = _sign(c, restricted);
        orders[0] = toAdvancedOrder(order);
        (order,) = _sign(c, open);
        orders[1] = toAdvancedOrder(order);

        FulfillmentComponent[][] memory offerComponents =
            new FulfillmentComponent[][](1);
        offerComponents[0] = _pair(0);
        FulfillmentComponent[][] memory considerationComponents =
            new FulfillmentComponent[][](2);
        considerationComponents[0] = _pair(0);
        considerationComponents[1] = _pair(1);

        assertEq(test1155_1.balanceOf(buyer, id), 0);
        vm.prank(buyer);
        (bool[] memory available,) = c.fulfillAvailableAdvancedOrders{
            value: 22 ether
        }(
            orders,
            new CriteriaResolver[](0),
            offerComponents,
            considerationComponents,
            bytes32(0),
            address(0),
            2
        );

        assertTrue(available[0]);
        assertTrue(available[1]);
        assertEq(test1155_1.balanceOf(buyer, id), 10);
        _assertRecipientsPaid(restricted.consideration, 2);
        assertEq(zone.callCount(), 1);
    }

    function _forEachSeaport(function(ConsiderationInterface) internal fn)
        internal
    {
        fn(consideration);
        fn(referenceConsideration);
    }

    /// @dev A new zone (expecting offer items to reach the fulfiller), a
    ///      fresh fulfiller with ether, and fresh consideration recipients.
    function _setUpFill()
        internal
        returns (TestTransferValidationZoneOfferer zone, address buyer)
    {
        zone = new TestTransferValidationZoneOfferer(address(0));
        buyer = makeAddr(string.concat("buyer", vm.toString(nextId)));
        vm.deal(buyer, 100 ether);
    }

    function _assertRecipientsPaid(
        ConsiderationItem[] memory cons,
        uint256 fills
    ) internal view {
        for (uint256 i; i < cons.length; ++i) {
            assertEq(cons[i].recipient.balance, cons[i].endAmount * fills);
        }
    }

    function _pair(uint256 itemIndex)
        internal
        pure
        returns (FulfillmentComponent[] memory components)
    {
        components = new FulfillmentComponent[](2);
        components[0] = FulfillmentComponent(0, itemIndex);
        components[1] = FulfillmentComponent(1, itemIndex);
    }

    function _newId() internal returns (uint256) {
        return nextId++;
    }

    function _mint721(address to) internal returns (uint256 id) {
        id = _newId();
        test721_1.mint(to, id);
    }

    function _offer(
        ItemType itemType,
        address token,
        uint256 identifierOrCriteria,
        uint256 amount
    ) internal pure returns (OfferItem[] memory offer) {
        offer = new OfferItem[](1);
        offer[0] =
            OfferItem(itemType, token, identifierOrCriteria, amount, amount);
    }

    /// @dev Alice's order paying 10 ether to a fresh seller account and 1
    ///      ether to a fresh fee account.
    function _params(
        OfferItem[] memory offer,
        address zone,
        OrderType orderType
    ) internal returns (OrderParameters memory) {
        string memory suffix = vm.toString(nextId++);
        ConsiderationItem[] memory cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            10 ether,
            10 ether,
            payable(makeAddr(string.concat("seller", suffix)))
        );
        cons[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            1 ether,
            1 ether,
            payable(makeAddr(string.concat("fee", suffix)))
        );
        return OrderParameters({
            offerer: alice,
            zone: zone,
            offer: offer,
            consideration: cons,
            orderType: orderType,
            startTime: block.timestamp,
            endTime: block.timestamp + 100,
            zoneHash: bytes32(0),
            salt: globalSalt++,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: cons.length
        });
    }

    function _sign(ConsiderationInterface c, OrderParameters memory params)
        internal
        view
        returns (Order memory order, bytes32 orderHash)
    {
        orderHash = c.getOrderHash(
            toOrderComponents(params, c.getCounter(params.offerer))
        );
        order = Order(params, signOrder(c, alicePk, orderHash));
    }
}
