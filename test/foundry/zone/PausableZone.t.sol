// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import {
    ItemType,
    OrderType,
    Side
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    Schema,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    SeaportInterface
} from "seaport-types/src/interfaces/SeaportInterface.sol";

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

import { PausableZone } from "../../../contracts/zones/PausableZone.sol";

import {
    PausableZoneController
} from "../../../contracts/zones/PausableZoneController.sol";

import {
    PausableZoneEventsAndErrors
} from "../../../contracts/zones/interfaces/PausableZoneEventsAndErrors.sol";

import {
    PausableZoneInterface
} from "../../../contracts/zones/interfaces/PausableZoneInterface.sol";

import { TestZone } from "../../../contracts/test/TestZone.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

/// @dev Ports the "Zone - PausableZone" block of test/zone.spec.ts, plus
///      PausableZone's getSeaportMetadata and supportsInterface. Tests that
///      touch Seaport run against both the optimized and reference builds.
contract PausableZoneTest is
    BaseOrderTest,
    ConsiderationEventsAndErrors,
    PausableZoneEventsAndErrors
{
    struct Context {
        ConsiderationInterface seaport;
    }

    uint256 constant SELLER_AMOUNT = 10 ether;
    uint256 constant FEE_AMOUNT = 1 ether;
    uint256 constant ORDER_VALUE = SELLER_AMOUNT + FEE_AMOUNT;

    PausableZoneController controller;

    address owner;
    uint256 ownerPk;
    address seller;
    uint256 sellerPk;
    address buyer;
    uint256 buyerPk;

    uint256 nextTokenId = 1;
    uint256 nextSalt = 1;

    function setUp() public virtual override {
        super.setUp();

        (owner, ownerPk) = makeAddrAndKey("owner");
        (seller, sellerPk) = makeAddrAndKey("seller");
        (buyer, buyerPk) = makeAddrAndKey("buyer");
        allocateTokensAndApprovals(owner, 1000 ether);
        allocateTokensAndApprovals(seller, 1000 ether);
        allocateTokensAndApprovals(buyer, 1000 ether);

        if (coverage_or_debug) {
            controller = new PausableZoneController(owner);
        } else {
            controller = PausableZoneController(
                deployCode(
                    "optimized-out/PausableZoneController.sol/PausableZoneController.json",
                    abi.encode(owner)
                )
            );
        }
        vm.label(address(controller), "pausableZoneController");
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    // "Fulfills an order with a pausable zone"
    function testFulfillOrderWithPausableZone() public {
        test(this.execFulfillOrderWithPausableZone, Context(consideration));
        test(
            this.execFulfillOrderWithPausableZone,
            Context(referenceConsideration)
        );
    }

    function execFulfillOrderWithPausableZone(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        uint256 nftId = _mint(seller);

        (Order memory order, bytes32 orderHash,) = _createOrder(
            context.seaport,
            sellerPk,
            zone,
            _offer721(nftId),
            _ethConsideration(),
            OrderType.FULL_RESTRICTED
        );

        _expectOrderFulfilled(context.seaport, orderHash, zone, nftId);
        _withBalanceChecks(context, order, nftId);
    }

    // "Fulfills an advanced order with criteria with a pausable zone"
    function testFulfillAdvancedOrderWithCriteriaWithPausableZone() public {
        test(
            this.execFulfillAdvancedOrderWithCriteriaWithPausableZone,
            Context(consideration)
        );
        test(
            this.execFulfillAdvancedOrderWithCriteriaWithPausableZone,
            Context(referenceConsideration)
        );
    }

    function execFulfillAdvancedOrderWithCriteriaWithPausableZone(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        uint256 nftId = _mint(seller);

        // A one-leaf tree: the root is the hashed identifier and the proof is
        // empty.
        uint256 root = uint256(keccak256(abi.encode(nftId)));
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(
            ItemType.ERC721_WITH_CRITERIA, address(test721_1), root, 1, 1
        );

        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] =
            CriteriaResolver(0, Side.OFFER, 0, nftId, new bytes32[](0));

        (Order memory order, bytes32 orderHash,) = _createOrder(
            context.seaport,
            sellerPk,
            zone,
            offer,
            _ethConsideration(),
            OrderType.FULL_RESTRICTED
        );

        // The event reports the resolved ERC721 item.
        _expectOrderFulfilled(context.seaport, orderHash, zone, nftId);

        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;
        uint256 feeBefore = owner.balance;

        vm.prank(buyer);
        assertTrue(
            context.seaport.fulfillAdvancedOrder{ value: ORDER_VALUE }(
                toAdvancedOrder(order), resolvers, bytes32(0), address(0)
            )
        );

        _assertSettled(nftId, buyerBefore, sellerBefore, feeBefore);
    }

    // "Fulfills a PARTIAL_RESTRICTED order with the caller being the offerer"
    // (despite the name, the buyer fulfills it; the zone authorizes it)
    function testFulfillPartialRestrictedOrderWithPausableZone() public {
        test(
            this.execFulfillPartialRestrictedOrderWithPausableZone,
            Context(consideration)
        );
        test(
            this.execFulfillPartialRestrictedOrderWithPausableZone,
            Context(referenceConsideration)
        );
    }

    function execFulfillPartialRestrictedOrderWithPausableZone(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        uint256 nftId = _mint(seller);

        (Order memory order, bytes32 orderHash,) = _createOrder(
            context.seaport,
            sellerPk,
            zone,
            _offer721(nftId),
            _ethConsideration(),
            OrderType.PARTIAL_RESTRICTED
        );

        _expectOrderFulfilled(context.seaport, orderHash, zone, nftId);

        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;
        uint256 feeBefore = owner.balance;

        vm.prank(buyer);
        assertTrue(
            context.seaport.fulfillAdvancedOrder{ value: ORDER_VALUE }(
                toAdvancedOrder(order),
                new CriteriaResolver[](0),
                bytes32(0),
                address(0)
            )
        );

        _assertSettled(nftId, buyerBefore, sellerBefore, feeBefore);
    }

    // "Fulfills an order with executeMatchOrders"
    function testExecuteMatchOrders() public {
        test(this.execExecuteMatchOrders, Context(consideration));
        test(this.execExecuteMatchOrders, Context(referenceConsideration));
    }

    function execExecuteMatchOrders(Context memory context) external stateless {
        address zone = _createZone();
        (
            Order[] memory orders,
            bytes32[3] memory orderHashes,
            uint256[3] memory nftIds
        ) = _createRingOrders(context.seaport, zone);
        Fulfillment[] memory ringFulfillments = _ringFulfillments();

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.executeMatchOrders(
            zone,
            SeaportInterface(address(context.seaport)),
            orders,
            ringFulfillments
        );

        vm.recordLogs();
        vm.prank(owner);
        Execution[] memory executions = controller.executeMatchOrders(
            zone,
            SeaportInterface(address(context.seaport)),
            orders,
            ringFulfillments
        );

        assertEq(executions.length, ringFulfillments.length);
        _assertOrderFulfilledHashes(context.seaport, orderHashes);
        _assertRingSettled(nftIds);
    }

    // "Fulfills an order with executeMatchAdvancedOrders"
    function testExecuteMatchAdvancedOrders() public {
        test(this.execExecuteMatchAdvancedOrders, Context(consideration));
        test(
            this.execExecuteMatchAdvancedOrders, Context(referenceConsideration)
        );
    }

    function execExecuteMatchAdvancedOrders(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        (
            Order[] memory orders,
            bytes32[3] memory orderHashes,
            uint256[3] memory nftIds
        ) = _createRingOrders(context.seaport, zone);
        Fulfillment[] memory ringFulfillments = _ringFulfillments();

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](3);
        for (uint256 i = 0; i < 3; ++i) {
            advancedOrders[i] = toAdvancedOrder(orders[i]);
        }

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.executeMatchAdvancedOrders(
            zone,
            SeaportInterface(address(context.seaport)),
            advancedOrders,
            new CriteriaResolver[](0),
            ringFulfillments
        );

        vm.recordLogs();
        vm.prank(owner);
        Execution[] memory executions = controller.executeMatchAdvancedOrders(
            zone,
            SeaportInterface(address(context.seaport)),
            advancedOrders,
            new CriteriaResolver[](0),
            ringFulfillments
        );

        assertEq(executions.length, ringFulfillments.length);
        _assertOrderFulfilledHashes(context.seaport, orderHashes);
        _assertRingSettled(nftIds);
    }

    // "Only the deployer owner can create a zone"
    function testOnlyOwnerCanCreateZone() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.createZone(bytes32(nextSalt));

        address zone = _createZone();
        assertFalse(PausableZone(zone).isPaused());
        assertEq(PausableZone(zone).operator(), address(0));
    }

    // "Assign pauser"
    function testAssignPauser() public {
        address zone = _createZone();

        // Before being assigned, the buyer can pause neither through the
        // controller nor directly.
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(InvalidPauser.selector));
        controller.pause(zone);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(InvalidController.selector));
        PausableZone(zone).pause();

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.assignPauser(seller);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(PauserCanNotBeSetAsZero.selector)
        );
        controller.assignPauser(address(0));

        vm.expectEmit(address(controller));
        emit PauserUpdated(buyer);
        vm.prank(owner);
        controller.assignPauser(buyer);
        assertEq(controller.pauser(), buyer);

        // Now the pauser can pause the zone through the controller.
        vm.recordLogs();
        vm.prank(buyer);
        assertTrue(controller.pause(zone));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, zone);
        assertEq(logs[0].topics[0], Paused.selector);
        assertTrue(PausableZone(zone).isPaused());
    }

    // "Revert on deploying a zone with the same salt"
    function testRevertCreateZoneWithSameSalt() public {
        bytes32 salt = bytes32(nextSalt);
        address zone = _createZone();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ZoneAlreadyExists.selector, zone)
        );
        controller.createZone(salt);
    }

    // "Revert on an order with a pausable zone if zone has been paused"
    function testRevertFulfillWhenZonePaused() public {
        test(this.execRevertFulfillWhenZonePaused, Context(consideration));
        test(
            this.execRevertFulfillWhenZonePaused,
            Context(referenceConsideration)
        );
    }

    function execRevertFulfillWhenZonePaused(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        uint256 nftId = _mint(seller);

        (Order memory order,,) = _createOrder(
            context.seaport,
            sellerPk,
            zone,
            _offer721(nftId),
            _ethConsideration(),
            OrderType.FULL_RESTRICTED
        );

        // The owner can pause without being assigned as pauser.
        vm.recordLogs();
        vm.prank(owner);
        assertTrue(controller.pause(zone));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, zone);
        assertEq(logs[0].topics[0], Paused.selector);

        // Both builds bubble the zone's revert reason. The Hardhat suite only
        // checked for a bare revert on the reference build.
        vm.expectRevert(abi.encodeWithSelector(ZoneIsPaused.selector));
        vm.prank(buyer);
        context.seaport.fulfillOrder{ value: ORDER_VALUE }(order, bytes32(0));
    }

    // "Reverts if non-owner tries to self destruct the zone"
    // (the controller has no self destruct; this checks pause)
    function testRevertNonPauserCannotPause() public {
        address zone = _createZone();

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(InvalidPauser.selector));
        controller.pause(zone);
    }

    // "Zone can cancel restricted orders"
    function testControllerCanCancelRestrictedOrders() public {
        test(
            this.execControllerCanCancelRestrictedOrders, Context(consideration)
        );
        test(
            this.execControllerCanCancelRestrictedOrders,
            Context(referenceConsideration)
        );
    }

    function execControllerCanCancelRestrictedOrders(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        (OrderComponents[] memory components, bytes32 orderHash) =
            _restrictedOrderComponents(context.seaport, zone);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.cancelOrders(
            zone, SeaportInterface(address(context.seaport)), components
        );

        vm.expectEmit(address(context.seaport));
        emit OrderCancelled(orderHash, seller, zone);
        vm.prank(owner);
        controller.cancelOrders(
            zone, SeaportInterface(address(context.seaport)), components
        );

        (, bool isCancelled,,) = context.seaport.getOrderStatus(orderHash);
        assertTrue(isCancelled);
    }

    // "Operator of zone can cancel restricted orders"
    function testOperatorCanCancelRestrictedOrders() public {
        test(this.execOperatorCanCancelRestrictedOrders, Context(consideration));
        test(
            this.execOperatorCanCancelRestrictedOrders,
            Context(referenceConsideration)
        );
    }

    function execOperatorCanCancelRestrictedOrders(Context memory context)
        external
        stateless
    {
        address zone = _createZone();
        (OrderComponents[] memory components, bytes32 orderHash) =
            _restrictedOrderComponents(context.seaport, zone);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(InvalidOperator.selector));
        PausableZone(zone)
            .cancelOrders(
                SeaportInterface(address(context.seaport)), components
            );

        vm.expectEmit(zone);
        emit OperatorUpdated(seller);
        vm.prank(owner);
        controller.assignOperator(zone, seller);
        assertEq(PausableZone(zone).operator(), seller);

        vm.expectEmit(address(context.seaport));
        emit OrderCancelled(orderHash, seller, zone);
        vm.prank(seller);
        assertTrue(
            PausableZone(zone)
                .cancelOrders(
                    SeaportInterface(address(context.seaport)), components
                )
        );
        (, bool isCancelled,,) = context.seaport.getOrderStatus(orderHash);
        assertTrue(isCancelled);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(PauserCanNotBeSetAsZero.selector)
        );
        controller.assignOperator(zone, address(0));
    }

    // "Reverts trying to assign operator as non-deployer"
    function testRevertAssignOperatorAsNonOwner() public {
        address zone = _createZone();

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.assignOperator(zone, seller);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(InvalidController.selector));
        PausableZone(zone).assignOperator(seller);
    }

    // "Reverts if non-Zone tries to cancel restricted orders"
    function testRevertNonZoneCannotCancelRestrictedOrders() public {
        test(
            this.execRevertNonZoneCannotCancelRestrictedOrders,
            Context(consideration)
        );
        test(
            this.execRevertNonZoneCannotCancelRestrictedOrders,
            Context(referenceConsideration)
        );
    }

    function execRevertNonZoneCannotCancelRestrictedOrders(Context memory context)
        external
        stateless
    {
        _createZone();
        address stubZone = address(new TestZone());
        (OrderComponents[] memory components,) =
            _restrictedOrderComponents(context.seaport, stubZone);

        // The buyer is neither the offerer nor the zone.
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CannotCancelOrder.selector));
        context.seaport.cancel(components);
    }

    // "Reverts if non-owner tries to use the zone to cancel restricted orders"
    function testRevertNonOwnerCannotCancelThroughController() public {
        address zone = _createZone();
        address stubZone = address(new TestZone());
        (OrderComponents[] memory components,) =
            _restrictedOrderComponents(consideration, stubZone);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.cancelOrders(
            zone, SeaportInterface(address(consideration)), components
        );
    }

    // "Lets the Zone Deployer owner transfer ownership via a two-stage process"
    function testTwoStepOwnershipTransfer() public {
        _createZone();

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.transferOwnership(buyer);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OwnerCanNotBeSetAsZero.selector));
        controller.transferOwnership(address(0));

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(CallerIsNotOwner.selector));
        controller.cancelOwnershipTransfer();

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotPotentialOwner.selector)
        );
        controller.acceptOwnership();

        vm.expectEmit(address(controller));
        emit PotentialOwnerUpdated(buyer);
        vm.prank(owner);
        controller.transferOwnership(buyer);
        assertEq(controller.potentialOwner(), buyer);

        vm.expectEmit(address(controller));
        emit PotentialOwnerUpdated(address(0));
        vm.prank(owner);
        controller.cancelOwnershipTransfer();
        assertEq(controller.potentialOwner(), address(0));

        vm.prank(owner);
        controller.transferOwnership(buyer);

        vm.expectEmit(address(controller));
        emit PotentialOwnerUpdated(address(0));
        vm.expectEmit(address(controller));
        emit OwnershipTransferred(owner, buyer);
        vm.prank(buyer);
        controller.acceptOwnership();

        assertEq(controller.owner(), buyer);
        assertEq(controller.potentialOwner(), address(0));
    }

    function testGetSeaportMetadata() public {
        PausableZone zone = PausableZone(_createZone());

        (string memory name, Schema[] memory schemas) =
            zone.getSeaportMetadata();

        assertEq(name, "PausableZone");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 3003);
        assertEq(schemas[0].metadata.length, 0);
    }

    function testSupportsInterface() public {
        PausableZone zone = PausableZone(_createZone());

        bytes4 zoneInterfaceId = ZoneInterface.authorizeOrder.selector
            ^ ZoneInterface.validateOrder.selector
            ^ ZoneInterface.getSeaportMetadata.selector
            ^ ZoneInterface.supportsInterface.selector;
        assertEq(type(ZoneInterface).interfaceId, zoneInterfaceId);

        assertTrue(zone.supportsInterface(zoneInterfaceId));
        // ERC-165 itself.
        assertTrue(zone.supportsInterface(0x01ffc9a7));

        // The zone does not advertise its own admin interface.
        assertFalse(
            zone.supportsInterface(type(PausableZoneInterface).interfaceId)
        );
        assertFalse(zone.supportsInterface(0xffffffff));
        assertFalse(zone.supportsInterface(0x00000000));
    }

    /// @dev Creates a zone as the owner and checks the zone emits Unpaused and
    ///      then the controller emits ZoneCreated, with no other logs.
    function _createZone() internal returns (address zone) {
        bytes32 salt = bytes32(nextSalt++);
        address expected = vm.computeCreate2Address(
            salt, controller.zoneCreationCode(), address(controller)
        );

        vm.recordLogs();
        vm.prank(owner);
        zone = controller.createZone(salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(zone, expected);
        assertEq(logs.length, 2);
        assertEq(logs[0].emitter, zone);
        assertEq(logs[0].topics[0], Unpaused.selector);
        assertEq(logs[1].emitter, address(controller));
        assertEq(logs[1].topics[0], ZoneCreated.selector);
        (address createdZone, bytes32 createdSalt) =
            abi.decode(logs[1].data, (address, bytes32));
        assertEq(createdZone, zone);
        assertEq(createdSalt, salt);
    }

    function _mint(address to) internal returns (uint256 nftId) {
        nftId = nextTokenId++;
        test721_1.mint(to, nftId);
    }

    function _offer721(uint256 nftId)
        internal
        view
        returns (OfferItem[] memory offer)
    {
        offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, address(test721_1), nftId, 1, 1);
    }

    function _consider721(uint256 nftId, address recipient)
        internal
        view
        returns (ConsiderationItem[] memory items)
    {
        items = new ConsiderationItem[](1);
        items[0] = ConsiderationItem(
            ItemType.ERC721, address(test721_1), nftId, 1, 1, payable(recipient)
        );
    }

    /// @dev 10 ETH to the seller and 1 ETH to the owner.
    function _ethConsideration()
        internal
        view
        returns (ConsiderationItem[] memory items)
    {
        items = new ConsiderationItem[](2);
        items[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            SELLER_AMOUNT,
            SELLER_AMOUNT,
            payable(seller)
        );
        items[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            FEE_AMOUNT,
            FEE_AMOUNT,
            payable(owner)
        );
    }

    function _createOrder(
        ConsiderationInterface seaport,
        uint256 offererPk,
        address zone,
        OfferItem[] memory offer,
        ConsiderationItem[] memory consideration_,
        OrderType orderType
    )
        internal
        returns (
            Order memory order,
            bytes32 orderHash,
            OrderComponents memory components
        )
    {
        address offerer = vm.addr(offererPk);
        components = OrderComponents({
            offerer: offerer,
            zone: zone,
            offer: offer,
            consideration: consideration_,
            orderType: orderType,
            startTime: vm.getBlockTimestamp(),
            endTime: vm.getBlockTimestamp() + 1 days,
            zoneHash: bytes32(0),
            salt: globalSalt++,
            conduitKey: bytes32(0),
            counter: seaport.getCounter(offerer)
        });
        orderHash = seaport.getOrderHash(components);

        order = Order({
            parameters: OrderParameters({
                offerer: offerer,
                zone: zone,
                offer: offer,
                consideration: consideration_,
                orderType: orderType,
                startTime: components.startTime,
                endTime: components.endTime,
                zoneHash: bytes32(0),
                salt: components.salt,
                conduitKey: bytes32(0),
                totalOriginalConsiderationItems: consideration_.length
            }),
            signature: signOrder(seaport, offererPk, orderHash)
        });
    }

    function _restrictedOrderComponents(
        ConsiderationInterface seaport,
        address zone
    )
        internal
        returns (OrderComponents[] memory components, bytes32 orderHash)
    {
        components = new OrderComponents[](1);
        (, orderHash, components[0]) = _createOrder(
            seaport,
            sellerPk,
            zone,
            _offer721(_mint(seller)),
            _ethConsideration(),
            OrderType.FULL_RESTRICTED
        );
    }

    function _expectOrderFulfilled(
        ConsiderationInterface seaport,
        bytes32 orderHash,
        address zone,
        uint256 nftId
    ) internal {
        SpentItem[] memory spent = new SpentItem[](1);
        spent[0] = SpentItem(ItemType.ERC721, address(test721_1), nftId, 1);

        ReceivedItem[] memory received = new ReceivedItem[](2);
        received[0] = ReceivedItem(
            ItemType.NATIVE, address(0), 0, SELLER_AMOUNT, payable(seller)
        );
        received[1] = ReceivedItem(
            ItemType.NATIVE, address(0), 0, FEE_AMOUNT, payable(owner)
        );

        vm.expectEmit(address(seaport));
        emit OrderFulfilled(orderHash, seller, zone, buyer, spent, received);
    }

    function _withBalanceChecks(
        Context memory context,
        Order memory order,
        uint256 nftId
    ) internal {
        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;
        uint256 feeBefore = owner.balance;

        vm.prank(buyer);
        assertTrue(
            context.seaport.fulfillOrder{ value: ORDER_VALUE }(
                order, bytes32(0)
            )
        );

        _assertSettled(nftId, buyerBefore, sellerBefore, feeBefore);
    }

    function _assertSettled(
        uint256 nftId,
        uint256 buyerBefore,
        uint256 sellerBefore,
        uint256 feeBefore
    ) internal view {
        assertEq(test721_1.ownerOf(nftId), buyer);
        assertEq(buyer.balance, buyerBefore - ORDER_VALUE);
        assertEq(seller.balance, sellerBefore + SELLER_AMOUNT);
        assertEq(owner.balance, feeBefore + FEE_AMOUNT);
    }

    /// @dev Three FULL_RESTRICTED orders in a ring: the seller offers NFT 0 for
    ///      NFT 1, the buyer offers NFT 1 for NFT 2, and the owner offers NFT 2
    ///      for NFT 0.
    function _createRingOrders(ConsiderationInterface seaport, address zone)
        internal
        returns (
            Order[] memory orders,
            bytes32[3] memory orderHashes,
            uint256[3] memory nftIds
        )
    {
        nftIds = [_mint(seller), _mint(buyer), _mint(owner)];
        uint256[3] memory pks = [sellerPk, buyerPk, ownerPk];
        address[3] memory offerers = [seller, buyer, owner];

        orders = new Order[](3);
        for (uint256 i = 0; i < 3; ++i) {
            (orders[i], orderHashes[i],) = _createOrder(
                seaport,
                pks[i],
                zone,
                _offer721(nftIds[i]),
                _consider721(nftIds[(i + 1) % 3], offerers[i]),
                OrderType.FULL_RESTRICTED
            );
        }
    }

    function _assertRingSettled(uint256[3] memory nftIds) internal view {
        assertEq(test721_1.ownerOf(nftIds[0]), owner);
        assertEq(test721_1.ownerOf(nftIds[1]), seller);
        assertEq(test721_1.ownerOf(nftIds[2]), buyer);
    }

    /// @dev Each order's offer item fills the previous order's consideration.
    function _ringFulfillments()
        internal
        pure
        returns (Fulfillment[] memory ring)
    {
        uint256[2][3] memory pairs =
            [[uint256(1), 0], [uint256(0), 2], [uint256(2), 1]];
        ring = new Fulfillment[](3);
        for (uint256 i = 0; i < 3; ++i) {
            FulfillmentComponent[] memory offerSide =
                new FulfillmentComponent[](1);
            offerSide[0] = FulfillmentComponent(pairs[i][0], 0);
            FulfillmentComponent[] memory considerationSide =
                new FulfillmentComponent[](1);
            considerationSide[0] = FulfillmentComponent(pairs[i][1], 0);
            ring[i] = Fulfillment(offerSide, considerationSide);
        }
    }

    function _assertOrderFulfilledHashes(
        ConsiderationInterface seaport,
        bytes32[3] memory orderHashes
    ) internal view {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(seaport)
                    && logs[i].topics[0] == OrderFulfilled.selector
            ) {
                assertLt(found, 3, "too many OrderFulfilled events");
                assertEq(bytes32(logs[i].data), orderHashes[found]);
                ++found;
            }
        }
        assertEq(found, 3);
    }
}
