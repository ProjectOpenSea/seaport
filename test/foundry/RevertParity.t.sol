// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import {
    HugeRevertDataToken,
    NoRevertDataAuthorizeZone
} from "./utils/RevertParityMocks.sol";

import {
    ERC1155BatchRecipient
} from "../../contracts/test/ERC1155BatchRecipient.sol";

import {
    ExcessReturnDataRecipient
} from "../../contracts/test/ExcessReturnDataRecipient.sol";

import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";

import { TestZone } from "../../contracts/test/TestZone.sol";

import { Conduit } from "seaport-core/src/conduit/Conduit.sol";

import {
    ConduitInterface
} from "seaport-types/src/interfaces/ConduitInterface.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    TokenTransferrerErrors
} from "seaport-types/src/interfaces/TokenTransferrerErrors.sol";

import {
    ZoneInteractionErrors
} from "seaport-types/src/interfaces/ZoneInteractionErrors.sol";

import {
    ConduitBatch1155Transfer,
    ConduitItemType,
    ConduitTransfer
} from "seaport-types/src/conduit/lib/ConduitStructs.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Revert and edge paths in Seaport core that only the legacy Hardhat
 *      suite (test/revert.spec.ts, counter.spec.ts, advanced.spec.ts,
 *      conduit.spec.ts) exercised. Each case runs against the optimized and
 *      the reference build unless the Hardhat test was optimized-only. Where
 *      the reference build reverts differently, the test pins both payloads.
 */
contract RevertParityTest is BaseOrderTest {
    uint256 internal constant ETH_TOTAL = 12 ether;

    uint256 internal nextId = 1000;

    address payable internal feeRecipient = payable(makeAddr("feeRecipient"));

    function setUp() public override {
        super.setUp();

        // Let this contract call the conduits directly.
        conduitController.updateChannel(address(conduit), address(this), true);
        referenceConduitController.updateChannel(
            address(referenceConduit), address(this), true
        );
    }

    // -------------------------------------------------------------------------
    // Basic order native token handling (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts when no ether is supplied (basic)"
    function test_basicRevertsWhenNoEtherSupplied() public {
        _forEachSeaport(_basicRevertsWhenNoEtherSupplied);
    }

    function _basicRevertsWhenNoEtherSupplied(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal)));
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.InvalidMsgValue.selector, 0
            )
        );
        vm.prank(bob);
        c.fulfillBasicOrder(basic);

        // The same order fills once the payment is attached.
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL }(basic);
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev "Reverts when ether is supplied to a non-payable route (basic)"
    function test_basicRevertsWhenEtherSentToNonPayableRoute() public {
        _forEachSeaport(_basicRevertsWhenEtherSentToNonPayableRoute);
    }

    function _basicRevertsWhenEtherSentToNonPayableRoute(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        ConsiderationItem[] memory cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 10, 10, alice
        );
        cons[1] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1, 1, feeRecipient
        );
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 1), cons));
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.InvalidMsgValue.selector, 1
            )
        );
        vm.prank(bob);
        c.fulfillBasicOrder{ value: 1 }(basic);

        vm.prank(bob);
        c.fulfillBasicOrder(basic);
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev "Reverts when not enough ether is supplied (basic)": short for an
    ///      additional recipient, then short for the offerer's payment.
    function test_basicRevertsWhenNotEnoughEtherSupplied() public {
        _forEachSeaport(_basicRevertsWhenNotEnoughEtherSupplied);
    }

    function _basicRevertsWhenNotEnoughEtherSupplied(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal)));
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );

        // Additional recipients are paid first; 1 wei can't cover the first.
        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        vm.prank(bob);
        c.fulfillBasicOrder{ value: 1 }(basic);

        // Enough for both additional recipients, 1 wei short for the offerer.
        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL - 1 }(basic);

        uint256 aliceBalance = alice.balance;
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL }(basic);
        assertEq(test721_1.ownerOf(id), bob);
        assertEq(alice.balance, aliceBalance + 10 ether);
    }

    /// @dev "Reverts when marketplace is an ether recipient for basic orders".
    ///      The optimized build rejects the payment in receive() because the
    ///      basic-order guard does not accept native tokens; the reference
    ///      build reports the failed native transfer instead.
    function test_basicRevertsWhenSeaportIsEtherRecipient() public {
        _forEachSeaport(_basicRevertsWhenSeaportIsEtherRecipient);
    }

    function _basicRevertsWhenSeaportIsEtherRecipient(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        (Order memory order,) = _sign(
            c, alicePk, _params(_offer721(id, 1), _ethConsideration(address(c)))
        );
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );

        if (_isReference(c)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationEventsAndErrors.NativeTokenTransferGenericFailure
                        .selector,
                    address(c),
                    1 ether
                )
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationEventsAndErrors.InvalidMsgValue.selector,
                    1 ether
                )
            );
        }
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL }(basic);
    }

    /// @dev Ether sent straight to Seaport outside of a fulfillment hits
    ///      receive() with the guard clear and reverts InvalidMsgValue.
    function test_receiveRejectsDirectEther() public {
        _forEachSeaport(_receiveRejectsDirectEther);
    }

    function _receiveRejectsDirectEther(ConsiderationInterface c) internal {
        vm.prank(bob);
        (bool ok, bytes memory data) = address(c).call{ value: 1 }("");
        assertFalse(ok);
        assertEq(
            data,
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.InvalidMsgValue.selector, 1
            )
        );
    }

    // -------------------------------------------------------------------------
    // ERC721 amount > 1 (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts on attempts to transfer >1 ERC721 in single transfer
    ///      (basic)": BasicOrderFulfiller._transferIndividual721Or1155Item.
    function test_basicRevertsOnErc721AmountAboveOne() public {
        _forEachSeaport(_basicRevertsOnErc721AmountAboveOne);
    }

    function _basicRevertsOnErc721AmountAboveOne(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 2), _ethConsideration(cal)));
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenTransferrerErrors.InvalidERC721TransferAmount.selector, 2
            )
        );
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL }(basic);
    }

    /// @dev "Reverts on attempts to transfer >1 ERC721 in single transfer":
    ///      Executor._transferERC721 without a conduit.
    function test_standardRevertsOnErc721AmountAboveOne() public {
        _forEachSeaport(_standardRevertsOnErc721AmountAboveOne);
    }

    function _standardRevertsOnErc721AmountAboveOne(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 2), _ethConsideration(cal)));

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenTransferrerErrors.InvalidERC721TransferAmount.selector, 2
            )
        );
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(order, bytes32(0));
    }

    /// @dev "Reverts on attempts to transfer >1 ERC721 in single transfer via
    ///      conduit": the conduit rejects it and Seaport bubbles the error.
    function test_standardRevertsOnErc721AmountAboveOneViaConduit() public {
        _forEachSeaport(_standardRevertsOnErc721AmountAboveOneViaConduit);
    }

    function _standardRevertsOnErc721AmountAboveOneViaConduit(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        OrderParameters memory params =
            _params(_offer721(id, 2), _ethConsideration(cal));
        params.conduitKey = conduitKeyOne;
        (Order memory order,) = _sign(c, alicePk, params);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenTransferrerErrors.InvalidERC721TransferAmount.selector, 2
            )
        );
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(order, bytes32(0));
    }

    // -------------------------------------------------------------------------
    // Partial fills (revert.spec.ts, advanced.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts on partially filled order via basic fulfillment"
    function test_basicRevertsOnPartiallyFilledOrder() public {
        _forEachSeaport(_basicRevertsOnPartiallyFilledOrder);
    }

    function _basicRevertsOnPartiallyFilledOrder(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint1155(alice, 100);
        OrderParameters memory params =
            _params(_offer1155(id, 100), _ethConsideration(cal));
        params.orderType = OrderType.PARTIAL_OPEN;
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            AdvancedOrder(params, 1, 2, order.signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
        _assertStatus(c, orderHash, 1, 2);

        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ETH_TO_ERC1155_PARTIAL_OPEN
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.OrderPartiallyFilled.selector,
                orderHash
            )
        );
        vm.prank(bob);
        c.fulfillBasicOrder{ value: ETH_TOTAL }(basic);
    }

    /// @dev "Partial fills (standard, additional permutations)": fill 2/10,
    ///      then 1/10, then pass 1/1 to take the remaining 7/10.
    function test_partialFillOneOverOneTakesRemainder() public {
        _forEachSeaport(_partialFillOneOverOneTakesRemainder);
    }

    function _partialFillOneOverOneTakesRemainder(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint1155(alice, 100);
        OrderParameters memory params =
            _params(_offer1155(id, 100), _ethConsideration(cal));
        params.orderType = OrderType.PARTIAL_OPEN;
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);
        uint256 aliceBalance = alice.balance;

        _fillFraction(c, order, 2, 10);
        _assertStatus(c, orderHash, 2, 10);
        assertEq(test1155_1.balanceOf(bob, id), 20);

        _fillFraction(c, order, 1, 10);
        _assertStatus(c, orderHash, 3, 10);
        assertEq(test1155_1.balanceOf(bob, id), 30);

        _fillFraction(c, order, 1, 1);
        _assertStatus(c, orderHash, 10, 10);
        assertEq(test1155_1.balanceOf(bob, id), 100);
        assertEq(alice.balance, aliceBalance + 10 ether);
    }

    // -------------------------------------------------------------------------
    // validate() (counter.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Skip validation for contract order". Also checks that a second
    ///      validate() of an already validated order skips the signature
    ///      check and emits nothing.
    function test_validateSkipsContractOrder() public {
        _forEachSeaport(_validateSkipsContractOrder);
    }

    function _validateSkipsContractOrder(ConsiderationInterface c) internal {
        uint256 id = _mint721(alice);
        (Order memory order, bytes32 orderHash) =
            _sign(c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal)));

        OrderParameters memory contractParams =
            _params(_offer721(id, 1), _ethConsideration(cal));
        contractParams.orderType = OrderType.CONTRACT;

        Order[] memory orders = new Order[](2);
        orders[0] = order;
        orders[1] = Order(contractParams, "");

        vm.recordLogs();
        vm.prank(alice);
        assertTrue(c.validate(orders));
        bytes32[] memory validated = _validatedHashes(c);
        assertEq(validated.length, 1);
        assertEq(validated[0], orderHash);
        (bool isValidated,,,) = c.getOrderStatus(orderHash);
        assertTrue(isValidated);

        // Already validated: no signature needed and no second event.
        orders = new Order[](1);
        orders[0] = Order(order.parameters, "");
        vm.recordLogs();
        vm.prank(bob);
        assertTrue(c.validate(orders));
        assertEq(_validatedHashes(c).length, 0);
    }

    /// @dev "Reverts on validate when consideration array length doesn't
    ///      match totalOriginalConsiderationItems"
    function test_validateRevertsOnConsiderationLengthMismatch() public {
        _forEachSeaport(_validateRevertsOnConsiderationLengthMismatch);
    }

    function _validateRevertsOnConsiderationLengthMismatch(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        OrderParameters memory params =
            _params(_offer721(id, 1), _ethConsideration(cal));
        params.totalOriginalConsiderationItems = 2;
        (Order memory order,) = _sign(c, alicePk, params);

        Order[] memory orders = new Order[](1);
        orders[0] = order;
        vm.expectRevert(
            ConsiderationEventsAndErrors.ConsiderationLengthNotEqualToTotalOriginal
                .selector
        );
        vm.prank(alice);
        c.validate(orders);
    }

    // -------------------------------------------------------------------------
    // Match with an empty consideration aggregation (advanced.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "ERC1155 <=> ETH (match, offer aggregation skipped if no available
    ///      consideration items)". Two fulfillments name only an out-of-range
    ///      consideration item, so the aggregated amount is zero and
    ///      FulfillmentApplier returns before it reads the offer side, even
    ///      though one of them names an out-of-range offer order.
    function test_matchSkipsOfferAggregationWithoutConsideration() public {
        _forEachSeaport(_matchSkipsOfferAggregationWithoutConsideration);
    }

    function _matchSkipsOfferAggregationWithoutConsideration(ConsiderationInterface c)
        internal
    {
        (
            Order[] memory orders,
            bytes32[2] memory hashes,
            uint256[3] memory ids
        ) = _aggregationMatchOrders(c);

        Fulfillment[] memory fulfillments = new Fulfillment[](8);
        // Offer order index 5 is out of range, but never read.
        fulfillments[0] = _fulfillment(5, 5, 0, 5);
        fulfillments[1] = _fulfillment(0, 0, 1, 0);
        fulfillments[2] = _fulfillment(0, 0, 0, 5);
        fulfillments[3] = _fulfillment(0, 1, 1, 1);
        fulfillments[4] = _fulfillment(0, 2, 1, 2);
        fulfillments[5] = _fulfillment(1, 0, 0, 0);
        fulfillments[6] = _fulfillment(1, 0, 0, 1);
        fulfillments[7] = _fulfillment(1, 0, 0, 2);

        uint256 aliceBalance = alice.balance;
        uint256 feeBalance = feeRecipient.balance;
        Execution[] memory executions =
            c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);

        // Seaport returns an execution per fulfillment; the two empty ones
        // carry a zero amount and transfer nothing.
        assertEq(executions.length, 8);
        assertEq(executions[0].item.amount, 0);
        assertEq(executions[2].item.amount, 0);
        for (uint256 i; i < 3; ++i) {
            assertEq(test1155_1.balanceOf(bob, ids[i]), 5);
        }
        assertEq(alice.balance, aliceBalance + 10 ether);
        assertEq(feeRecipient.balance, feeBalance + 1 ether);
        _assertStatus(c, hashes[0], 1, 1);
        _assertStatus(c, hashes[1], 1, 1);
    }

    /// @dev Alice offers three ERC1155 items for the usual 12 ether; bob's
    ///      mirror order offers 12 ether for the three items.
    function _aggregationMatchOrders(ConsiderationInterface c)
        internal
        returns (
            Order[] memory orders,
            bytes32[2] memory hashes,
            uint256[3] memory ids
        )
    {
        ids = [_mint1155(alice, 5), _mint1155(alice, 5), _mint1155(alice, 5)];

        OfferItem[] memory offer = new OfferItem[](3);
        ConsiderationItem[] memory mirrorCons = new ConsiderationItem[](3);
        for (uint256 i; i < 3; ++i) {
            offer[i] = OfferItem(
                ItemType.ERC1155, address(test1155_1), ids[i], 5, 5
            );
            mirrorCons[i] = ConsiderationItem(
                ItemType.ERC1155, address(test1155_1), ids[i], 5, 5, bob
            );
        }

        OfferItem[] memory mirrorOffer = new OfferItem[](1);
        mirrorOffer[0] =
            OfferItem(ItemType.NATIVE, address(0), 0, ETH_TOTAL, ETH_TOTAL);
        OrderParameters memory mirrorParams = _params(mirrorOffer, mirrorCons);
        mirrorParams.offerer = bob;

        orders = new Order[](2);
        (orders[0], hashes[0]) =
            _sign(c, alicePk, _params(offer, _ethConsideration(cal)));
        (orders[1], hashes[1]) = _sign(c, bobPk, mirrorParams);
    }

    // -------------------------------------------------------------------------
    // Restricted orders whose zone reverts without data (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts on restricted order where isValidOrder reverts with no
    ///      data". The optimized build raises InvalidRestrictedOrder; the
    ///      reference build's high-level call bubbles the empty revert.
    function test_restrictedOrderZoneRevertsWithoutData() public {
        _forEachSeaport(_restrictedOrderZoneRevertsWithoutData);
    }

    function _restrictedOrderZoneRevertsWithoutData(ConsiderationInterface c)
        internal
    {
        TestZone zone = new TestZone();
        uint256 id = _mint721(alice);
        OrderParameters memory params =
            _params(_offer721(id, 1), _ethConsideration(cal));
        params.orderType = OrderType.FULL_RESTRICTED;
        params.zone = address(zone);
        // TestZone reverts with no data on zone hash 2 and empty extraData.
        params.zoneHash = bytes32(uint256(2));
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        _expectRestrictedNoDataRevert(c, orderHash);
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(order, bytes32(0));

        // TestZone also reverts with no data on 5 bytes of extraData.
        _expectRestrictedNoDataRevert(c, orderHash);
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            AdvancedOrder(params, 1, 1, order.signature, hex"0102030405"),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    /// @dev Same failure on the authorizeOrder call made while preparing a
    ///      match, which goes through ZoneInteraction's skip-capable helper
    ///      with revertOnInvalid set. Both builds raise InvalidRestrictedOrder.
    function test_matchRevertsWhenAuthorizeOrderRevertsWithoutData() public {
        _forEachSeaport(_matchRevertsWhenAuthorizeOrderRevertsWithoutData);
    }

    function _matchRevertsWhenAuthorizeOrderRevertsWithoutData(ConsiderationInterface c)
        internal
    {
        NoRevertDataAuthorizeZone zone = new NoRevertDataAuthorizeZone();
        uint256 id = _mint721(alice);

        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(ItemType.NATIVE, address(0), 0, 1, 1, alice);
        OrderParameters memory params = _params(_offer721(id, 1), cons);
        params.orderType = OrderType.FULL_RESTRICTED;
        params.zone = address(zone);
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        OfferItem[] memory mirrorOffer = new OfferItem[](1);
        mirrorOffer[0] = OfferItem(ItemType.NATIVE, address(0), 0, 1, 1);
        ConsiderationItem[] memory mirrorCons = new ConsiderationItem[](1);
        mirrorCons[0] = ConsiderationItem(
            ItemType.ERC721, address(test721_1), id, 1, 1, bob
        );
        OrderParameters memory mirrorParams = _params(mirrorOffer, mirrorCons);
        mirrorParams.offerer = bob;
        (Order memory mirror,) = _sign(c, bobPk, mirrorParams);

        Order[] memory orders = new Order[](2);
        orders[0] = order;
        orders[1] = mirror;
        Fulfillment[] memory fulfillments = new Fulfillment[](2);
        fulfillments[0] = _fulfillment(0, 0, 1, 0);
        fulfillments[1] = _fulfillment(1, 0, 0, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ZoneInteractionErrors.InvalidRestrictedOrder.selector, orderHash
            )
        );
        c.matchOrders{ value: 1 }(orders, fulfillments);
    }

    // -------------------------------------------------------------------------
    // TokenTransferrer failures through Seaport (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts when non-token account is supplied as the token": an
    ///      ERC20 consideration item whose token is Seaport itself, which has
    ///      no transferFrom and reverts with no data.
    function test_erc20NonTokenAccountReverts() public {
        _forEachSeaport(_erc20NonTokenAccountReverts);
    }

    function _erc20NonTokenAccountReverts(ConsiderationInterface c) internal {
        _erc20NonTokenAccount(c, bytes32(0));
    }

    /// @dev "Reverts when non-token account is supplied as the token fulfilled
    ///      via conduit"
    function test_erc20NonTokenAccountRevertsViaConduit() public {
        _forEachSeaport(_erc20NonTokenAccountRevertsViaConduit);
    }

    function _erc20NonTokenAccountRevertsViaConduit(ConsiderationInterface c)
        internal
    {
        _erc20NonTokenAccount(c, conduitKeyOne);
    }

    function _erc20NonTokenAccount(
        ConsiderationInterface c,
        bytes32 fulfillerConduitKey
    ) internal {
        uint256 id = _mint1155(alice, 10);
        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] =
            ConsiderationItem(ItemType.ERC20, address(c), 0, 10, 10, alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer1155(id, 10), cons));

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenTransferrerErrors.TokenTransferGenericFailure.selector,
                address(c),
                bob,
                alice,
                0,
                10
            )
        );
        vm.prank(bob);
        c.fulfillAdvancedOrder(
            toAdvancedOrder(order),
            new CriteriaResolver[](0),
            fulfillerConduitKey,
            address(0)
        );
    }

    /// @dev "Reverts when non-1155 account is supplied as the token". The
    ///      reference build makes a high-level call and bubbles the empty
    ///      revert.
    function test_erc1155NonTokenAccountReverts() public {
        _forEachSeaport(_erc1155NonTokenAccountReverts);
    }

    function _erc1155NonTokenAccountReverts(ConsiderationInterface c) internal {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC1155, address(c), 0, 3, 3);
        (Order memory order,) =
            _sign(c, alicePk, _params(offer, _ethConsideration(cal)));

        _expectGenericFailure(c, address(c), alice, bob, 0, 3);
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            toAdvancedOrder(order),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    /// @dev The ERC721 twin of the case above (no Hardhat test names it, but
    ///      revert.spec.ts's generic-failure group targets the same assembly).
    function test_erc721NonTokenAccountReverts() public {
        _forEachSeaport(_erc721NonTokenAccountReverts);
    }

    function _erc721NonTokenAccountReverts(ConsiderationInterface c) internal {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, address(c), 7, 1, 1);
        (Order memory order,) =
            _sign(c, alicePk, _params(offer, _ethConsideration(cal)));

        _expectGenericFailure(c, address(c), alice, bob, 7, 1);
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(order, bytes32(0));
    }

    /// @dev "Reverts when ERC20 tokens return falsey values (via conduit)".
    ///      The failed attempt leaves the order untouched and the same order
    ///      fills once the token behaves.
    function test_erc20FalseyReturnRevertsViaConduit() public {
        _forEachSeaport(_erc20FalseyReturnRevertsViaConduit);
    }

    function _erc20FalseyReturnRevertsViaConduit(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint1155(alice, 10);
        ConsiderationItem[] memory cons = new ConsiderationItem[](3);
        cons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1000, 1000, alice
        );
        cons[1] =
            ConsiderationItem(ItemType.ERC20, address(token1), 0, 10, 10, cal);
        cons[2] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 20, 20, feeRecipient
        );
        OrderParameters memory params = _params(_offer1155(id, 10), cons);
        params.conduitKey = conduitKeyOne;
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        token1.blockTransfer(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenTransferrerErrors.BadReturnValueFromERC20OnTransfer
                .selector,
                address(token1),
                bob,
                alice,
                1000
            )
        );
        vm.prank(bob);
        c.fulfillAdvancedOrder(
            toAdvancedOrder(order),
            new CriteriaResolver[](0),
            conduitKeyOne,
            address(0)
        );
        _assertStatus(c, orderHash, 0, 0);
        (bool isValidated,,,) = c.getOrderStatus(orderHash);
        assertFalse(isValidated);

        token1.blockTransfer(false);
        vm.prank(bob);
        c.fulfillAdvancedOrder(
            toAdvancedOrder(order),
            new CriteriaResolver[](0),
            conduitKeyOne,
            address(0)
        );
        _assertStatus(c, orderHash, 1, 1);
        assertEq(test1155_1.balanceOf(bob, id), 10);
    }

    // -------------------------------------------------------------------------
    // TokenTransferrer failures on the conduit (conduit.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "ERC1155 batch transfer reverts with revert data if it has
    ///      sufficient gas"
    function test_batch1155BubblesRevertData() public {
        TestERC1155 unapproved = new TestERC1155();
        uint256 id = _newId();
        unapproved.mint(alice, id, 1);
        ConduitBatch1155Transfer[] memory batch =
            _batch(address(unapproved), alice, bob, id, 1);

        Conduit[2] memory conduits = [conduit, referenceConduit];
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(
                abi.encodeWithSignature("Error(string)", "NOT_AUTHORIZED")
            );
            conduits[i].executeWithBatch1155(new ConduitTransfer[](0), batch);
        }
    }

    /// @dev "ERC1155 batch transfer reverts with generic error if it has
    ///      insufficient gas to copy revert data". Despite its name, that
    ///      Hardhat test points the batch at ExcessReturnDataRecipient, which
    ///      has no safeBatchTransferFrom and reverts with no data, so it
    ///      checks the no-data generic failure. The reference conduit bubbles
    ///      the empty revert. The insufficient-gas branch proper is
    ///      test_transfersWithUncopyableRevertDataUseGenericErrors.
    function test_batch1155NonTokenAccountReverts() public {
        ExcessReturnDataRecipient receiver = new ExcessReturnDataRecipient();
        ConduitBatch1155Transfer[] memory batch =
            _batch(address(receiver), alice, address(receiver), 1, 1);

        vm.expectRevert(_batchGenericFailure(batch[0]));
        conduit.executeWithBatch1155(new ConduitTransfer[](0), batch);

        vm.expectRevert(bytes(""));
        referenceConduit.executeWithBatch1155(new ConduitTransfer[](0), batch);
    }

    /// @dev A token that reverts with more data than the caller can afford to
    ///      copy. TokenTransferrer measures the copy cost against its
    ///      remaining gas and raises its generic error instead of running out
    ///      of gas. Optimized conduit only: the reference conduit always
    ///      copies the revert data.
    function test_transfersWithUncopyableRevertDataUseGenericErrors() public {
        HugeRevertDataToken token = new HugeRevertDataToken();
        address t = address(token);

        // Precondition: the token does return revert data (hundreds of KB at
        // this gas), so a generic error below comes from the gas check.
        (bool ok, bytes memory data) = t.call{ gas: 1_000_000 }("");
        assertFalse(ok);
        assertGt(data.length, 100_000);

        ConduitTransfer[] memory transfers = new ConduitTransfer[](1);
        transfers[0] =
            ConduitTransfer(ConduitItemType.ERC20, t, alice, bob, 0, 5);
        vm.expectRevert(_genericFailure(t, alice, bob, 0, 5));
        conduit.execute{ gas: 10_000_000 }(transfers);

        transfers[0] =
            ConduitTransfer(ConduitItemType.ERC721, t, alice, bob, 9, 1);
        vm.expectRevert(_genericFailure(t, alice, bob, 9, 1));
        conduit.execute{ gas: 10_000_000 }(transfers);

        transfers[0] =
            ConduitTransfer(ConduitItemType.ERC1155, t, alice, bob, 9, 4);
        vm.expectRevert(_genericFailure(t, alice, bob, 9, 4));
        conduit.execute{ gas: 10_000_000 }(transfers);

        ConduitBatch1155Transfer[] memory batch = _batch(t, alice, bob, 9, 4);
        vm.expectRevert(_batchGenericFailure(batch[0]));
        conduit.executeBatch1155{ gas: 10_000_000 }(batch);
    }

    /// @dev A batch whose ids and amounts lengths differ is rejected before
    ///      any call. Optimized conduit only: the reference conduit relies on
    ///      the ABI decoder and has no such check.
    function test_batch1155RevertsOnInvalidEncoding() public {
        uint256 id = _mint1155(alice, 2);
        ConduitBatch1155Transfer[] memory batch =
            _batch(address(test1155_1), alice, bob, id, 1);
        uint256[] memory ids = new uint256[](2);
        ids[0] = id;
        ids[1] = id;
        batch[0].ids = ids;

        vm.expectRevert(
            TokenTransferrerErrors.Invalid1155BatchTransferEncoding.selector
        );
        conduit.executeBatch1155(batch);
    }

    /// @dev "ERC1155 batch transfer sends no data": ERC1155BatchRecipient
    ///      reverts if the data argument is non-empty.
    function test_batch1155SendsNoData() public {
        ERC1155BatchRecipient receiver = new ERC1155BatchRecipient();
        Conduit[2] memory conduits = [conduit, referenceConduit];

        for (uint256 i; i < 2; ++i) {
            uint256[] memory ids = new uint256[](3);
            uint256[] memory amounts = new uint256[](3);
            for (uint256 j; j < 3; ++j) {
                ids[j] = _mint1155(alice, 4);
                amounts[j] = 2;
            }
            uint256[] memory reversedIds = new uint256[](2);
            uint256[] memory reversedAmounts = new uint256[](2);
            reversedIds[0] = ids[1];
            reversedIds[1] = ids[0];
            reversedAmounts[0] = 2;
            reversedAmounts[1] = 2;

            ConduitBatch1155Transfer[] memory batches =
                new ConduitBatch1155Transfer[](2);
            batches[0] = ConduitBatch1155Transfer(
                address(test1155_1), alice, address(receiver), ids, amounts
            );
            batches[1] = ConduitBatch1155Transfer(
                address(test1155_1),
                alice,
                address(receiver),
                reversedIds,
                reversedAmounts
            );

            assertEq(
                conduits[i].executeWithBatch1155(
                    new ConduitTransfer[](0), batches
                ),
                ConduitInterface.executeWithBatch1155.selector
            );
            assertEq(test1155_1.balanceOf(address(receiver), ids[0]), 4);
            assertEq(test1155_1.balanceOf(address(receiver), ids[1]), 4);
            assertEq(test1155_1.balanceOf(address(receiver), ids[2]), 2);
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _forEachSeaport(function(ConsiderationInterface) internal fn)
        internal
    {
        fn(consideration);
        fn(referenceConsideration);
    }

    function _isReference(ConsiderationInterface c)
        internal
        view
        returns (bool)
    {
        return address(c) == address(referenceConsideration);
    }

    function _newId() internal returns (uint256) {
        return nextId++;
    }

    function _mint721(address to) internal returns (uint256 id) {
        id = _newId();
        test721_1.mint(to, id);
    }

    function _mint1155(address to, uint256 amount)
        internal
        returns (uint256 id)
    {
        id = _newId();
        test1155_1.mint(to, id, amount);
    }

    function _offer721(uint256 id, uint256 amount)
        internal
        view
        returns (OfferItem[] memory offer)
    {
        offer = new OfferItem[](1);
        offer[0] =
            OfferItem(ItemType.ERC721, address(test721_1), id, amount, amount);
    }

    function _offer1155(uint256 id, uint256 amount)
        internal
        view
        returns (OfferItem[] memory offer)
    {
        offer = new OfferItem[](1);
        offer[0] = OfferItem(
            ItemType.ERC1155, address(test1155_1), id, amount, amount
        );
    }

    /// @dev 10 ether to the offerer and 1 ether each to two more recipients,
    ///      the shape most revert.spec.ts orders use (12 ether in total).
    function _ethConsideration(address secondRecipient)
        internal
        view
        returns (ConsiderationItem[] memory cons)
    {
        cons = new ConsiderationItem[](3);
        cons[0] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 10 ether, 10 ether, alice
        );
        cons[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            1 ether,
            1 ether,
            payable(secondRecipient)
        );
        cons[2] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 1 ether, 1 ether, feeRecipient
        );
    }

    /// @dev FULL_OPEN order from alice with no zone and no conduit.
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

    function _sign(
        ConsiderationInterface c,
        uint256 pk,
        OrderParameters memory params
    ) internal view returns (Order memory order, bytes32 orderHash) {
        orderHash = c.getOrderHash(
            toOrderComponents(params, c.getCounter(params.offerer))
        );
        order = Order(params, signOrder(c, pk, orderHash));
    }

    function _fillFraction(
        ConsiderationInterface c,
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) internal {
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            AdvancedOrder(
                order.parameters, numerator, denominator, order.signature, ""
            ),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );
    }

    function _assertStatus(
        ConsiderationInterface c,
        bytes32 orderHash,
        uint256 totalFilled,
        uint256 totalSize
    ) internal view {
        (,, uint256 filled, uint256 size) = c.getOrderStatus(orderHash);
        assertEq(filled, totalFilled);
        assertEq(size, totalSize);
    }

    function _fulfillment(
        uint256 offerOrder,
        uint256 offerItem,
        uint256 considerationOrder,
        uint256 considerationItem
    ) internal pure returns (Fulfillment memory f) {
        f.offerComponents = new FulfillmentComponent[](1);
        f.offerComponents[0] = FulfillmentComponent(offerOrder, offerItem);
        f.considerationComponents = new FulfillmentComponent[](1);
        f.considerationComponents[0] =
            FulfillmentComponent(considerationOrder, considerationItem);
    }

    /// @dev Order hashes from the OrderValidated events c emitted since the
    ///      last vm.recordLogs().
    function _validatedHashes(ConsiderationInterface c)
        internal
        view
        returns (bytes32[] memory hashes)
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        hashes = new bytes32[](logs.length);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(c)
                    && logs[i].topics[0]
                        == ConsiderationEventsAndErrors.OrderValidated.selector
            ) {
                (hashes[count++],) =
                    abi.decode(logs[i].data, (bytes32, OrderParameters));
            }
        }
        assembly {
            mstore(hashes, count)
        }
    }

    function _batch(
        address token,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) internal pure returns (ConduitBatch1155Transfer[] memory batch) {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = id;
        amounts[0] = amount;
        batch = new ConduitBatch1155Transfer[](1);
        batch[0] = ConduitBatch1155Transfer(token, from, to, ids, amounts);
    }

    function _genericFailure(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            TokenTransferrerErrors.TokenTransferGenericFailure.selector,
            token,
            from,
            to,
            identifier,
            amount
        );
    }

    /// @dev ERC1155BatchTransferGenericFailure exactly as the optimized
    ///      TokenTransferrer writes it. It rewrites the failed
    ///      safeBatchTransferFrom calldata in place, so the head keeps a sixth
    ///      word (the original call's data offset) and both array offsets sit
    ///      one word later than abi.encodeWithSelector would put them. The
    ///      payload still decodes to (token, from, to, ids, amounts).
    function _batchGenericFailure(ConduitBatch1155Transfer memory transfer)
        internal
        pure
        returns (bytes memory)
    {
        uint256 arrayWords = transfer.ids.length + 1;
        return abi.encodePacked(
            abi.encodeWithSelector(
                TokenTransferrerErrors.ERC1155BatchTransferGenericFailure
                .selector,
                transfer.token,
                transfer.from,
                transfer.to,
                uint256(0xc0),
                0xc0 + 0x20 * arrayWords,
                0xa0 + 0x40 * arrayWords
            ),
            transfer.ids.length,
            transfer.ids,
            transfer.amounts.length,
            transfer.amounts
        );
    }

    /// @dev The optimized build raises TokenTransferGenericFailure when an
    ///      ERC721 or ERC1155 call reverts with no data; the reference build
    ///      bubbles the empty revert from its high-level call.
    function _expectGenericFailure(
        ConsiderationInterface c,
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal {
        if (_isReference(c)) {
            vm.expectRevert(bytes(""));
        } else {
            vm.expectRevert(
                _genericFailure(token, from, to, identifier, amount)
            );
        }
    }

    function _expectRestrictedNoDataRevert(
        ConsiderationInterface c,
        bytes32 orderHash
    ) internal {
        if (_isReference(c)) {
            vm.expectRevert(bytes(""));
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ZoneInteractionErrors.InvalidRestrictedOrder.selector,
                    orderHash
                )
            );
        }
    }
}
