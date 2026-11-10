// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    FulfillmentComponent,
    OfferItem,
    OrderComponents,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    SeaportRouterInterface
} from "seaport-types/src/interfaces/SeaportRouterInterface.sol";

import {
    ReentrancyErrors
} from "seaport-types/src/interfaces/ReentrancyErrors.sol";

import {
    ZoneInteractionErrors
} from "seaport-types/src/interfaces/ZoneInteractionErrors.sol";

import { Consideration } from "seaport-core/src/lib/Consideration.sol";

import {
    ReferenceConsideration
} from "../../reference/ReferenceConsideration.sol";

import { SeaportRouter } from "../../contracts/helpers/SeaportRouter.sol";

import { Reenterer } from "../../contracts/test/Reenterer.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

/// @dev Ports test/router.spec.ts. The router is deployed against two Seaport
///      instances that stand in for v1.5 and v1.6, once with the optimized
///      build and once with the reference build.
contract SeaportRouterTest is BaseOrderTest {
    struct Context {
        ConsiderationInterface seaportA;
        ConsiderationInterface seaportB;
        SeaportRouterInterface router;
    }

    uint256 constant SELLER_AMOUNT = 10 ether;
    uint256 constant ZONE_AMOUNT = 1 ether;
    uint256 constant ORDER_VALUE = SELLER_AMOUNT + ZONE_AMOUNT;

    ConsiderationInterface consideration2;
    ConsiderationInterface referenceConsideration2;
    SeaportRouterInterface router;
    SeaportRouterInterface referenceRouter;

    address routerOwner;
    address seller;
    uint256 sellerPk;
    address buyer;
    address zoneRecipient;
    Reenterer reenterer;

    uint256 nextTokenId = 1;

    function setUp() public virtual override {
        super.setUp();

        routerOwner = makeAddr("routerOwner");
        (seller, sellerPk) = makeAddrAndKey("seller");
        buyer = makeAddr("buyer");
        zoneRecipient = makeAddr("zoneRecipient");
        reenterer = new Reenterer();

        vm.deal(buyer, 100 ether);
        vm.deal(address(reenterer), 100 ether);

        // Second Seaport for each build, sharing that build's conduit
        // controller so conduitKeyOne resolves on both.
        if (coverage_or_debug) {
            consideration2 = new Consideration(address(conduitController));
            referenceConsideration2 = new ReferenceConsideration(
                address(referenceConduitController)
            );
        } else {
            consideration2 = ConsiderationInterface(
                deployCode(
                    "optimized-out/Consideration.sol/Consideration.json",
                    abi.encode(address(conduitController))
                )
            );
            referenceConsideration2 = ConsiderationInterface(
                deployCode(
                    "reference-out/ReferenceConsideration.sol/ReferenceConsideration.json",
                    abi.encode(address(referenceConduitController))
                )
            );
        }
        conduitController.updateChannel(
            address(conduit), address(consideration2), true
        );
        referenceConduitController.updateChannel(
            address(referenceConduit), address(referenceConsideration2), true
        );

        router = _deployRouter(address(consideration), address(consideration2));
        referenceRouter = _deployRouter(
            address(referenceConsideration), address(referenceConsideration2)
        );

        vm.label(address(consideration2), "consideration2");
        vm.label(address(referenceConsideration2), "referenceConsideration2");
        vm.label(address(router), "router");
        vm.label(address(referenceRouter), "referenceRouter");
        vm.label(address(reenterer), "reenterer");
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function _contexts() internal view returns (Context[2] memory) {
        return [
            Context(consideration, consideration2, router),
            Context(
                referenceConsideration, referenceConsideration2, referenceRouter
            )
        ];
    }

    // "Should return the allowed Seaport contracts usable through the router"
    function testGetAllowedSeaportContracts() public view {
        Context[2] memory contexts = _contexts();
        for (uint256 i = 0; i < contexts.length; ++i) {
            Context memory context = contexts[i];
            assertTrue(
                address(context.seaportA) != address(context.seaportB),
                "seaport addresses must differ"
            );

            address[] memory allowed =
                context.router.getAllowedSeaportContracts();
            assertEq(allowed.length, 2);
            assertEq(allowed[0], address(context.seaportA));
            assertEq(allowed[1], address(context.seaportB));
        }
    }

    // "Should be able to fulfill orders through a single Seaport contract"
    function testFulfillThroughSingleSeaport() public {
        test(this.execFulfillThroughSingleSeaport, _contexts()[0]);
        test(this.execFulfillThroughSingleSeaport, _contexts()[1]);
    }

    function execFulfillThroughSingleSeaport(Context memory context)
        external
        stateless
    {
        uint256 nftId = _mintAndApprove(context);
        AdvancedOrder memory order = _createOrder(context.seaportA, nftId);

        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params =
            _params(_singleSeaport(context.seaportA), _singleOrder(order));
        // A zero recipient defaults to the caller.
        params.recipient = address(0);

        // A non-allowed contract is rejected before any call is made.
        params.seaportContracts[0] = address(test721_1);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaportRouterInterface.SeaportNotAllowed.selector,
                address(test721_1)
            )
        );
        context.router.fulfillAvailableAdvancedOrders{ value: ORDER_VALUE }(
            params
        );

        params.seaportContracts[0] = address(context.seaportA);

        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;
        uint256 zoneBefore = zoneRecipient.balance;

        vm.prank(buyer);
        (bool[][] memory availableOrders, Execution[][] memory executions) = context.router
        .fulfillAvailableAdvancedOrders{ value: ORDER_VALUE }(
            params
        );

        assertEq(test721_1.ownerOf(nftId), buyer);
        assertEq(availableOrders.length, 1);
        assertEq(availableOrders[0].length, 1);
        assertTrue(availableOrders[0][0]);
        assertEq(executions.length, 1);
        assertEq(executions[0].length, 3);
        assertEq(buyer.balance, buyerBefore - ORDER_VALUE);
        assertEq(seller.balance, sellerBefore + SELLER_AMOUNT);
        assertEq(zoneRecipient.balance, zoneBefore + ZONE_AMOUNT);
        assertEq(address(context.router).balance, 0);
    }

    // "Should be able to fulfill orders through multiple Seaport contracts"
    function testFulfillThroughMultipleSeaports() public {
        test(this.execFulfillThroughMultipleSeaports, _contexts()[0]);
        test(this.execFulfillThroughMultipleSeaports, _contexts()[1]);
    }

    function execFulfillThroughMultipleSeaports(Context memory context)
        external
        stateless
    {
        _fulfillThroughBothSeaports(context, bytes32(0));
    }

    // "Should be able to fulfill orders through multiple Seaport contracts
    // using conduit"
    function testFulfillThroughMultipleSeaportsWithConduit() public {
        test(this.execFulfillThroughMultipleSeaportsWithConduit, _contexts()[0]);
        test(this.execFulfillThroughMultipleSeaportsWithConduit, _contexts()[1]);
    }

    function execFulfillThroughMultipleSeaportsWithConduit(Context memory context)
        external
        stateless
    {
        _fulfillThroughBothSeaports(context, conduitKeyOne);
    }

    function _fulfillThroughBothSeaports(
        Context memory context,
        bytes32 fulfillerConduitKey
    ) internal {
        uint256 nftId = _mintAndApprove(context);
        uint256 nftId2 = _mintAndApprove(context);

        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params =
            _params(
                _bothSeaports(context),
                _twoOrders(
                    _createOrder(context.seaportA, nftId),
                    _createOrder(context.seaportB, nftId2)
                )
            );
        params.recipient = routerOwner;
        params.fulfillerConduitKey = fulfillerConduitKey;

        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;

        vm.prank(buyer);
        (bool[][] memory availableOrders,) = context.router
        .fulfillAvailableAdvancedOrders{ value: ORDER_VALUE * 2 }(
            params
        );

        assertEq(test721_1.ownerOf(nftId), routerOwner);
        assertEq(test721_1.ownerOf(nftId2), routerOwner);
        assertEq(availableOrders.length, 2);
        assertTrue(availableOrders[0][0]);
        assertTrue(availableOrders[1][0]);
        assertEq(buyer.balance, buyerBefore - ORDER_VALUE * 2);
        assertEq(seller.balance, sellerBefore + SELLER_AMOUNT * 2);
    }

    // "Should respect maximumFulfilled across multiple Seaport contracts"
    function testMaximumFulfilledAcrossSeaports() public {
        test(this.execMaximumFulfilledAcrossSeaports, _contexts()[0]);
        test(this.execMaximumFulfilledAcrossSeaports, _contexts()[1]);
    }

    function execMaximumFulfilledAcrossSeaports(Context memory context)
        external
        stateless
    {
        uint256 nftId = _mintAndApprove(context);
        uint256 nftId2 = _mintAndApprove(context);

        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params =
            _params(
                _bothSeaports(context),
                _twoOrders(
                    _createOrder(context.seaportA, nftId),
                    _createOrder(context.seaportB, nftId2)
                )
            );
        params.recipient = routerOwner;
        params.maximumFulfilled = 1;

        uint256 buyerBefore = buyer.balance;

        vm.prank(buyer);
        (bool[][] memory availableOrders,) = context.router
        .fulfillAvailableAdvancedOrders{ value: ORDER_VALUE * 2 }(
            params
        );

        // Only the first order is filled; the router stops before calling the
        // second Seaport and returns the unused ether.
        assertEq(test721_1.ownerOf(nftId), routerOwner);
        assertEq(test721_1.ownerOf(nftId2), seller);
        assertTrue(availableOrders[0][0]);
        assertEq(availableOrders[1].length, 0);
        assertEq(buyer.balance, buyerBefore - ORDER_VALUE);
    }

    // "Should process valid orders while skipping invalid orders"
    function testSkipsInvalidOrders() public {
        test(this.execSkipsInvalidOrders, _contexts()[0]);
        test(this.execSkipsInvalidOrders, _contexts()[1]);
    }

    function execSkipsInvalidOrders(Context memory context) external stateless {
        _fulfillFirstThenBoth(context);
    }

    // "Should revert on all errors except NoSpecifiedOrdersAvailable()"
    function testRevertsOnAllErrorsExceptNoSpecifiedOrdersAvailable() public {
        test(
            this.execRevertsOnAllErrorsExceptNoSpecifiedOrdersAvailable,
            _contexts()[0]
        );
        test(
            this.execRevertsOnAllErrorsExceptNoSpecifiedOrdersAvailable,
            _contexts()[1]
        );
    }

    function execRevertsOnAllErrorsExceptNoSpecifiedOrdersAvailable(Context memory context)
        external
        stateless
    {
        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params = _fulfillFirstThenBoth(context);

        // Both orders are now filled, so each Seaport reverts with
        // NoSpecifiedOrdersAvailable, the router swallows both, and then
        // reverts with its own copy of the error.
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaportRouterInterface.NoSpecifiedOrdersAvailable.selector
            )
        );
        context.router.fulfillAvailableAdvancedOrders{ value: ORDER_VALUE }(
            params
        );

        // Any other error bubbles up. A CONTRACT order whose offerer is an EOA
        // returns no data from generateOrder, which Seaport rejects.
        params.advancedOrderParams[0].advancedOrders[0].parameters.orderType =
        OrderType.CONTRACT;
        bytes32 contractOrderHash = bytes32(uint256(uint160(seller)) << 96)
            ^ bytes32(context.seaportA.getContractOffererNonce(seller));
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ZoneInteractionErrors.InvalidContractOrder.selector,
                contractOrderHash
            )
        );
        context.router.fulfillAvailableAdvancedOrders{ value: ORDER_VALUE }(
            params
        );
    }

    /// @dev Fills the first order alone, then submits both orders. The first
    ///      Seaport reverts with NoSpecifiedOrdersAvailable, which the router
    ///      skips, and the second order fills.
    function _fulfillFirstThenBoth(Context memory context)
        internal
        returns (SeaportRouterInterface
                    .FulfillAvailableAdvancedOrdersParams memory params)
    {
        uint256 nftId = _mintAndApprove(context);
        uint256 nftId2 = _mintAndApprove(context);

        AdvancedOrder memory order = _createOrder(context.seaportA, nftId);
        params = _params(
            _bothSeaports(context),
            _twoOrders(order, _createOrder(context.seaportB, nftId2))
        );
        params.recipient = buyer;

        uint256 buyerBefore = buyer.balance;

        vm.prank(buyer);
        context.router.fulfillAvailableAdvancedOrders{ value: ORDER_VALUE }(
            _params(_singleSeaport(context.seaportA), _singleOrder(order))
        );
        assertEq(test721_1.ownerOf(nftId), buyer);

        vm.prank(buyer);
        (bool[][] memory availableOrders,) = context.router
        .fulfillAvailableAdvancedOrders{ value: ORDER_VALUE * 2 }(
            params
        );

        assertEq(test721_1.ownerOf(nftId), buyer);
        assertEq(test721_1.ownerOf(nftId2), buyer);
        // The skipped Seaport leaves an empty entry.
        assertEq(availableOrders[0].length, 0);
        assertTrue(availableOrders[1][0]);
        // The ether sent for the skipped order came back: the buyer paid for
        // exactly two orders across both calls.
        assertEq(buyer.balance, buyerBefore - ORDER_VALUE * 2);
        assertEq(address(context.router).balance, 0);
    }

    // "Should revert if cannot return excess ether value"
    function testRevertsIfExcessEtherCannotBeReturned() public {
        test(this.execRevertsIfExcessEtherCannotBeReturned, _contexts()[0]);
        test(this.execRevertsIfExcessEtherCannotBeReturned, _contexts()[1]);
    }

    function execRevertsIfExcessEtherCannotBeReturned(Context memory context)
        external
        stateless
    {
        uint256 nftId = _mintAndApprove(context);
        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params =
            _params(
                _singleSeaport(context.seaportA),
                _singleOrder(_createOrder(context.seaportA, nftId))
            );
        params.recipient = buyer;

        // On receiving the refund, the reenterer calls TestERC721 with empty
        // calldata, which reverts without data.
        reenterer.prepare(address(test721_1), 0, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                SeaportRouterInterface.EtherReturnTransferFailed.selector,
                address(reenterer),
                ORDER_VALUE,
                ""
            )
        );
        reenterer.execute(
            address(context.router),
            ORDER_VALUE * 2,
            abi.encodeCall(
                SeaportRouterInterface.fulfillAvailableAdvancedOrders, (params)
            )
        );
    }

    // "Should not be able to reenter through receive()"
    function testCannotReenterThroughReceive() public {
        test(this.execCannotReenterThroughReceive, _contexts()[0]);
        test(this.execCannotReenterThroughReceive, _contexts()[1]);
    }

    function execCannotReenterThroughReceive(Context memory context)
        external
        stateless
    {
        uint256 nftId = _mintAndApprove(context);
        SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams memory
            params =
            _params(
                _singleSeaport(context.seaportA),
                _singleOrder(_createOrder(context.seaportA, nftId))
            );
        params.recipient = buyer;

        bytes memory callData = abi.encodeCall(
            SeaportRouterInterface.fulfillAvailableAdvancedOrders, (params)
        );

        // On receiving the refund, the reenterer calls back into the router.
        reenterer.prepare(address(context.router), 0, callData);

        vm.expectRevert(
            abi.encodeWithSelector(
                SeaportRouterInterface.EtherReturnTransferFailed.selector,
                address(reenterer),
                ORDER_VALUE,
                abi.encodeWithSelector(
                    ReentrancyErrors.NoReentrantCalls.selector
                )
            )
        );
        reenterer.execute(address(context.router), ORDER_VALUE * 2, callData);
    }

    // "Should not be able to receive ether from a non-Seaport address"
    function testReceiveOnlyFromAllowedSeaports() public {
        Context[2] memory contexts = _contexts();
        for (uint256 i = 0; i < contexts.length; ++i) {
            Context memory context = contexts[i];
            address router_ = address(context.router);
            vm.deal(routerOwner, 1);

            vm.prank(routerOwner);
            (bool success, bytes memory data) = router_.call{ value: 1 }("");
            assertFalse(success);
            assertEq(
                data,
                abi.encodeWithSelector(
                    SeaportRouterInterface.SeaportNotAllowed.selector,
                    routerOwner
                )
            );

            // Both allowed Seaports can send ether to the router.
            address[2] memory seaports =
                [address(context.seaportA), address(context.seaportB)];
            for (uint256 j = 0; j < seaports.length; ++j) {
                uint256 balanceBefore = router_.balance;
                vm.deal(seaports[j], 1);
                vm.prank(seaports[j]);
                (success,) = router_.call{ value: 1 }("");
                assertTrue(success);
                assertEq(router_.balance, balanceBefore + 1);
            }
        }
    }

    function _deployRouter(address seaportA, address seaportB)
        internal
        returns (SeaportRouterInterface)
    {
        if (coverage_or_debug) {
            return SeaportRouterInterface(
                payable(address(new SeaportRouter(seaportA, seaportB)))
            );
        }
        return SeaportRouterInterface(
            payable(deployCode(
                    "optimized-out/SeaportRouter.sol/SeaportRouter.json",
                    abi.encode(seaportA, seaportB)
                ))
        );
    }

    function _mintAndApprove(Context memory context)
        internal
        returns (uint256 nftId)
    {
        nftId = nextTokenId++;
        test721_1.mint(seller, nftId);
        vm.startPrank(seller);
        test721_1.setApprovalForAll(address(context.seaportA), true);
        test721_1.setApprovalForAll(address(context.seaportB), true);
        vm.stopPrank();
    }

    /// @dev A FULL_OPEN order offering one ERC721 for 10 ETH to the seller and
    ///      1 ETH to the zone recipient, signed for the given Seaport.
    function _createOrder(ConsiderationInterface seaport, uint256 nftId)
        internal
        view
        returns (AdvancedOrder memory)
    {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, address(test721_1), nftId, 1, 1);

        ConsiderationItem[] memory consideration_ = new ConsiderationItem[](2);
        consideration_[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            SELLER_AMOUNT,
            SELLER_AMOUNT,
            payable(seller)
        );
        consideration_[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            ZONE_AMOUNT,
            ZONE_AMOUNT,
            payable(zoneRecipient)
        );

        OrderParameters memory parameters = OrderParameters({
            offerer: seller,
            zone: zoneRecipient,
            offer: offer,
            consideration: consideration_,
            orderType: OrderType.FULL_OPEN,
            startTime: vm.getBlockTimestamp(),
            endTime: vm.getBlockTimestamp() + 1 days,
            zoneHash: bytes32(0),
            salt: nftId,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: 2
        });

        OrderComponents memory components = OrderComponents({
            offerer: parameters.offerer,
            zone: parameters.zone,
            offer: parameters.offer,
            consideration: parameters.consideration,
            orderType: parameters.orderType,
            startTime: parameters.startTime,
            endTime: parameters.endTime,
            zoneHash: parameters.zoneHash,
            salt: parameters.salt,
            conduitKey: parameters.conduitKey,
            counter: seaport.getCounter(seller)
        });

        return AdvancedOrder({
            parameters: parameters,
            numerator: 1,
            denominator: 1,
            signature: signOrder(
                seaport, sellerPk, seaport.getOrderHash(components)
            ),
            extraData: ""
        });
    }

    function _params(
        address[] memory seaportContracts,
        AdvancedOrder[][] memory orders
    )
        internal
        pure
        returns (SeaportRouterInterface
                    .FulfillAvailableAdvancedOrdersParams memory params)
    {
        // One offer item and two consideration items, each fulfilled alone.
        FulfillmentComponent[][] memory offerFulfillments =
            new FulfillmentComponent[][](1);
        offerFulfillments[0] = new FulfillmentComponent[](1);
        offerFulfillments[0][0] = FulfillmentComponent(0, 0);

        FulfillmentComponent[][] memory considerationFulfillments =
            new FulfillmentComponent[][](2);
        considerationFulfillments[0] = new FulfillmentComponent[](1);
        considerationFulfillments[0][0] = FulfillmentComponent(0, 0);
        considerationFulfillments[1] = new FulfillmentComponent[](1);
        considerationFulfillments[1][0] = FulfillmentComponent(0, 1);

        SeaportRouterInterface.AdvancedOrderParams[] memory orderParams =
            new SeaportRouterInterface.AdvancedOrderParams[](orders.length);
        for (uint256 i = 0; i < orders.length; ++i) {
            orderParams[i] = SeaportRouterInterface.AdvancedOrderParams({
                advancedOrders: orders[i],
                criteriaResolvers: new CriteriaResolver[](0),
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                etherValue: ORDER_VALUE
            });
        }

        params = SeaportRouterInterface.FulfillAvailableAdvancedOrdersParams({
            seaportContracts: seaportContracts,
            advancedOrderParams: orderParams,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0),
            maximumFulfilled: 100
        });
    }

    function _singleSeaport(ConsiderationInterface seaport)
        internal
        pure
        returns (address[] memory seaports)
    {
        seaports = new address[](1);
        seaports[0] = address(seaport);
    }

    function _bothSeaports(Context memory context)
        internal
        pure
        returns (address[] memory seaports)
    {
        seaports = new address[](2);
        seaports[0] = address(context.seaportA);
        seaports[1] = address(context.seaportB);
    }

    function _singleOrder(AdvancedOrder memory order)
        internal
        pure
        returns (AdvancedOrder[][] memory orders)
    {
        orders = new AdvancedOrder[][](1);
        orders[0] = new AdvancedOrder[](1);
        orders[0][0] = order;
    }

    function _twoOrders(AdvancedOrder memory order, AdvancedOrder memory order2)
        internal
        pure
        returns (AdvancedOrder[][] memory orders)
    {
        orders = new AdvancedOrder[][](2);
        orders[0] = new AdvancedOrder[](1);
        orders[0][0] = order;
        orders[1] = new AdvancedOrder[](1);
        orders[1][0] = order2;
    }
}
