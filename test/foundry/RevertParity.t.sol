// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { Merkle } from "murky/Merkle.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import {
    HugeRevertDataToken,
    NoRevertDataAuthorizeZone,
    RevertingEIP1271Wallet
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
    AmountDerivationErrors
} from "seaport-types/src/interfaces/AmountDerivationErrors.sol";

import {
    ConduitControllerInterface
} from "seaport-types/src/interfaces/ConduitControllerInterface.sol";

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
    CriteriaResolutionErrors
} from "seaport-types/src/interfaces/CriteriaResolutionErrors.sol";

import {
    FulfillmentApplicationErrors
} from "seaport-types/src/interfaces/FulfillmentApplicationErrors.sol";

import {
    SignatureVerificationErrors
} from "seaport-types/src/interfaces/SignatureVerificationErrors.sol";

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
    OrderType,
    Side
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
    OrderComponents,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Revert and edge paths in Seaport core that only the legacy Hardhat
 *      suite (test/revert.spec.ts, counter.spec.ts, advanced.spec.ts,
 *      conduit.spec.ts) exercised. Each case runs against the optimized and
 *      the reference build unless the Hardhat test was optimized-only. Where
 *      the reference build reverts differently, the test pins both payloads.
 *      It also pins, on both builds, errors that otherwise only the fuzz
 *      engine reaches, since the engine skips the revert-reason check on the
 *      reference build.
 */
contract RevertParityTest is BaseOrderTest {
    uint256 internal constant ETH_TOTAL = 12 ether;

    uint256 internal nextId = 1000;

    Merkle internal merkle = new Merkle();

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
    // InvalidFulfillmentComponentData during aggregation (revert.spec.ts)
    // -------------------------------------------------------------------------

    // revert.spec.ts aggregated two items that differ in one field, or named
    // an order index past the end of the orders array, on matchOrders and
    // fulfillAvailable(Advanced)Orders. Each case below builds two orders from
    // alice that offer the same ERC1155 for the same three native payments,
    // changes one field on the second order, and aggregates the first order's
    // item with the second's. Every case runs on all three entry points, then
    // runs again unchanged to show the same orders and fulfillments fill.

    enum AggregationField {
        NONE,
        OFFERER,
        CONDUIT_KEY,
        OFFER_ITEM_TYPE,
        OFFER_TOKEN,
        OFFER_IDENTIFIER,
        RECIPIENT,
        CONSIDERATION_ITEM_TYPE,
        CONSIDERATION_TOKEN,
        CONSIDERATION_IDENTIFIER
    }

    enum AggregationEntry {
        MATCH,
        AVAILABLE,
        AVAILABLE_ADVANCED
    }

    /// @dev Where an out-of-range order index goes: the first or a later
    ///      component of the offer or the first consideration group.
    enum OutOfRange {
        NONE,
        OFFER_FIRST,
        OFFER_LATER,
        CONSIDERATION_FIRST,
        CONSIDERATION_LATER
    }

    /// @dev "Reverts on invalid matching offerer (branch coverage 2)"
    function test_aggregationRejectsMismatchedOfferer() public {
        _forEachSeaport(_aggregationRejectsMismatchedOfferer);
    }

    function _aggregationRejectsMismatchedOfferer(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.OFFERER, OutOfRange.NONE);
    }

    /// @dev "Reverts on invalid matching conduit key (branch coverage 3)"
    function test_aggregationRejectsMismatchedConduitKey() public {
        _forEachSeaport(_aggregationRejectsMismatchedConduitKey);
    }

    function _aggregationRejectsMismatchedConduitKey(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.CONDUIT_KEY, OutOfRange.NONE);
    }

    /// @dev "Reverts on invalid matching itemType (branch coverage 4)" and
    ///      "Reverts on fulfillAvailableAdvancedOrders with mismatched offer
    ///      components"
    function test_aggregationRejectsMismatchedOfferItemType() public {
        _forEachSeaport(_aggregationRejectsMismatchedOfferItemType);
    }

    function _aggregationRejectsMismatchedOfferItemType(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.OFFER_ITEM_TYPE, OutOfRange.NONE);
    }

    /// @dev "Reverts on invalid matching token" (offer side)
    function test_aggregationRejectsMismatchedOfferToken() public {
        _forEachSeaport(_aggregationRejectsMismatchedOfferToken);
    }

    function _aggregationRejectsMismatchedOfferToken(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.OFFER_TOKEN, OutOfRange.NONE);
    }

    /// @dev "Reverts on mismatched offer components" and its "(branch coverage
    ///      1)" twin: two ERC721s with different identifiers.
    function test_aggregationRejectsMismatchedOfferIdentifier() public {
        _forEachSeaport(_aggregationRejectsMismatchedOfferIdentifier);
    }

    function _aggregationRejectsMismatchedOfferIdentifier(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.OFFER_IDENTIFIER, OutOfRange.NONE);
    }

    /// @dev "Reverts on invalid matching recipient"
    function test_aggregationRejectsMismatchedRecipient() public {
        _forEachSeaport(_aggregationRejectsMismatchedRecipient);
    }

    function _aggregationRejectsMismatchedRecipient(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.RECIPIENT, OutOfRange.NONE);
    }

    /// @dev "Reverts on invalid matching itemType" (consideration side) and
    ///      "Reverts on fulfillAvailableAdvancedOrders with mismatched
    ///      consideration components"
    function test_aggregationRejectsMismatchedConsiderationItemType() public {
        _forEachSeaport(_aggregationRejectsMismatchedConsiderationItemType);
    }

    function _aggregationRejectsMismatchedConsiderationItemType(ConsiderationInterface c)
        internal
    {
        _checkAggregation(
            c, AggregationField.CONSIDERATION_ITEM_TYPE, OutOfRange.NONE
        );
    }

    /// @dev "Reverts on invalid matching token" (consideration side)
    function test_aggregationRejectsMismatchedConsiderationToken() public {
        _forEachSeaport(_aggregationRejectsMismatchedConsiderationToken);
    }

    function _aggregationRejectsMismatchedConsiderationToken(ConsiderationInterface c)
        internal
    {
        _checkAggregation(
            c, AggregationField.CONSIDERATION_TOKEN, OutOfRange.NONE
        );
    }

    /// @dev "Reverts on invalid matching identifier" and "Reverts on mismatched
    ///      consideration components"
    function test_aggregationRejectsMismatchedConsiderationIdentifier() public {
        _forEachSeaport(_aggregationRejectsMismatchedConsiderationIdentifier);
    }

    function _aggregationRejectsMismatchedConsiderationIdentifier(ConsiderationInterface c)
        internal
    {
        _checkAggregation(
            c, AggregationField.CONSIDERATION_IDENTIFIER, OutOfRange.NONE
        );
    }

    /// @dev "Reverts on fulfillment component with out-of-range initial order
    ///      on fulfillAvailableOrders" and "... with out-of-range initial offer
    ///      order" (fulfillAvailableAdvancedOrders)
    function test_aggregationRejectsOutOfRangeFirstOfferOrder() public {
        _forEachSeaport(_aggregationRejectsOutOfRangeFirstOfferOrder);
    }

    function _aggregationRejectsOutOfRangeFirstOfferOrder(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.NONE, OutOfRange.OFFER_FIRST);
    }

    /// @dev "Reverts on fulfillment component with out-of-range order" (match)
    ///      and "... with out-of-range offer order" (fulfillAvailableAdvanced)
    function test_aggregationRejectsOutOfRangeLaterOfferOrder() public {
        _forEachSeaport(_aggregationRejectsOutOfRangeLaterOfferOrder);
    }

    function _aggregationRejectsOutOfRangeLaterOfferOrder(ConsiderationInterface c)
        internal
    {
        _checkAggregation(c, AggregationField.NONE, OutOfRange.OFFER_LATER);
    }

    /// @dev "Reverts on fulfillAvailableAdvancedOrders with out-of-range
    ///      consideration order", first component.
    function test_aggregationRejectsOutOfRangeFirstConsiderationOrder() public {
        _forEachSeaport(_aggregationRejectsOutOfRangeFirstConsiderationOrder);
    }

    function _aggregationRejectsOutOfRangeFirstConsiderationOrder(ConsiderationInterface c)
        internal
    {
        _checkAggregation(
            c, AggregationField.NONE, OutOfRange.CONSIDERATION_FIRST
        );
    }

    /// @dev "Reverts on fulfillAvailableAdvancedOrders with out-of-range
    ///      consideration order", later component.
    function test_aggregationRejectsOutOfRangeLaterConsiderationOrder() public {
        _forEachSeaport(_aggregationRejectsOutOfRangeLaterConsiderationOrder);
    }

    function _aggregationRejectsOutOfRangeLaterConsiderationOrder(ConsiderationInterface c)
        internal
    {
        _checkAggregation(
            c, AggregationField.NONE, OutOfRange.CONSIDERATION_LATER
        );
    }

    /// @dev Runs one broken aggregation on every entry point and expects
    ///      InvalidFulfillmentComponentData, then fills fresh, unbroken orders
    ///      through the same entry point.
    function _checkAggregation(
        ConsiderationInterface c,
        AggregationField field,
        OutOfRange outOfRange
    ) internal {
        for (uint256 i; i < 3; ++i) {
            AggregationEntry entry = AggregationEntry(i);

            (
                Order[] memory orders,
                FulfillmentComponent[][] memory offerGroups,
                FulfillmentComponent[][] memory considerationGroups,
            ) = _buildAggregation(c, entry, field, outOfRange);
            vm.expectRevert(
                FulfillmentApplicationErrors.InvalidFulfillmentComponentData
                    .selector
            );
            _executeAggregation(
                c, entry, orders, offerGroups, considerationGroups
            );

            uint256 id;
            (orders, offerGroups, considerationGroups, id) = _buildAggregation(
                c, entry, AggregationField.NONE, OutOfRange.NONE
            );
            uint256 aliceBalance = alice.balance;
            _executeAggregation(
                c, entry, orders, offerGroups, considerationGroups
            );
            assertEq(alice.balance, aliceBalance + 20 ether);
            assertEq(test1155_1.balanceOf(bob, id), 10);
        }
    }

    /// @dev Two orders from alice, each offering 5 of one ERC1155 for 10
    ///      ether to alice, 1 to cal and 1 to feeRecipient, with `field`
    ///      changed on the second. Offer items of both orders aggregate into
    ///      one transfer to bob, and each consideration item aggregates with
    ///      its twin. Match adds a third order from bob that offers 24 ether
    ///      for the 10 tokens. Also returns the ERC1155 id.
    function _buildAggregation(
        ConsiderationInterface c,
        AggregationEntry entry,
        AggregationField field,
        OutOfRange outOfRange
    )
        internal
        returns (
            Order[] memory orders,
            FulfillmentComponent[][] memory offerGroups,
            FulfillmentComponent[][] memory considerationGroups,
            uint256 id
        )
    {
        id = _mint1155(alice, 10);
        orders = new Order[](entry == AggregationEntry.MATCH ? 3 : 2);
        (orders[0],) = _sign(
            c, alicePk, _params(_offer1155(id, 5), _ethConsideration(cal))
        );
        orders[1] = _aggregationTwin(c, id, field);
        if (entry == AggregationEntry.MATCH) {
            orders[2] = _aggregationMirror(c, id);
        }

        offerGroups = new FulfillmentComponent[][](1);
        offerGroups[0] = _components(_component(0, 0), _component(1, 0));
        considerationGroups = new FulfillmentComponent[][](3);
        for (uint256 i; i < 3; ++i) {
            considerationGroups[i] =
                _components(_component(0, i), _component(1, i));
        }

        // Order index 5 is past the end of every orders array used here.
        if (outOfRange == OutOfRange.OFFER_FIRST) {
            offerGroups[0][0].orderIndex = 5;
        } else if (outOfRange == OutOfRange.OFFER_LATER) {
            offerGroups[0][1].orderIndex = 5;
        } else if (outOfRange == OutOfRange.CONSIDERATION_FIRST) {
            considerationGroups[0][0].orderIndex = 5;
        } else if (outOfRange == OutOfRange.CONSIDERATION_LATER) {
            considerationGroups[0][1].orderIndex = 5;
        }
    }

    /// @dev Match pairs the offer group with bob's consideration item and
    ///      bob's 24 ether with each consideration group. The
    ///      fulfillAvailable entry points take the groups as they are, with
    ///      bob as the fulfiller.
    function _executeAggregation(
        ConsiderationInterface c,
        AggregationEntry entry,
        Order[] memory orders,
        FulfillmentComponent[][] memory offerGroups,
        FulfillmentComponent[][] memory considerationGroups
    ) internal {
        if (entry == AggregationEntry.MATCH) {
            Fulfillment[] memory fulfillments = new Fulfillment[](4);
            fulfillments[0] =
                Fulfillment(offerGroups[0], _components(_component(2, 0)));
            for (uint256 i; i < 3; ++i) {
                fulfillments[i + 1] = Fulfillment(
                    _components(_component(2, 0)), considerationGroups[i]
                );
            }
            c.matchOrders{ value: 2 * ETH_TOTAL }(orders, fulfillments);
        } else if (entry == AggregationEntry.AVAILABLE) {
            vm.prank(bob);
            c.fulfillAvailableOrders{ value: 2 * ETH_TOTAL }(
                orders, offerGroups, considerationGroups, bytes32(0), 2
            );
        } else {
            AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
            advancedOrders[0] = toAdvancedOrder(orders[0]);
            advancedOrders[1] = toAdvancedOrder(orders[1]);
            vm.prank(bob);
            c.fulfillAvailableAdvancedOrders{ value: 2 * ETH_TOTAL }(
                advancedOrders,
                new CriteriaResolver[](0),
                offerGroups,
                considerationGroups,
                bytes32(0),
                bob,
                2
            );
        }
    }

    /// @dev The second aggregation order: alice's first order with one field
    ///      changed, signed by its offerer.
    function _aggregationTwin(
        ConsiderationInterface c,
        uint256 id,
        AggregationField field
    ) internal returns (Order memory order) {
        OrderParameters memory params = _params(
            _offer1155(id, 5), _ethConsideration(cal)
        );
        OfferItem memory offerItem = params.offer[0];
        ConsiderationItem memory considerationItem = params.consideration[0];
        uint256 pk = alicePk;

        if (field == AggregationField.OFFERER) {
            params.offerer = cal;
            pk = calPk;
        } else if (field == AggregationField.CONDUIT_KEY) {
            params.conduitKey = conduitKeyOne;
        } else if (field == AggregationField.OFFER_ITEM_TYPE) {
            offerItem.itemType = ItemType.ERC20;
        } else if (field == AggregationField.OFFER_TOKEN) {
            offerItem.token = address(test1155_2);
        } else if (field == AggregationField.OFFER_IDENTIFIER) {
            offerItem.identifierOrCriteria = id + 1;
        } else if (field == AggregationField.RECIPIENT) {
            considerationItem.recipient = payable(cal);
        } else if (field == AggregationField.CONSIDERATION_ITEM_TYPE) {
            considerationItem.itemType = ItemType.ERC20;
        } else if (field == AggregationField.CONSIDERATION_TOKEN) {
            considerationItem.token = address(token1);
        } else if (field == AggregationField.CONSIDERATION_IDENTIFIER) {
            considerationItem.identifierOrCriteria = 1;
        }

        (order,) = _sign(c, pk, params);
    }

    /// @dev Bob's side of the aggregation match: 24 ether for 10 of `id`.
    function _aggregationMirror(ConsiderationInterface c, uint256 id)
        internal
        returns (Order memory order)
    {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(
            ItemType.NATIVE, address(0), 0, 2 * ETH_TOTAL, 2 * ETH_TOTAL
        );
        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC1155, address(test1155_1), id, 10, 10, bob
        );
        OrderParameters memory params = _params(offer, cons);
        params.offerer = bob;
        (order,) = _sign(c, bobPk, params);
    }

    function _component(uint256 orderIndex, uint256 itemIndex)
        internal
        pure
        returns (FulfillmentComponent memory)
    {
        return FulfillmentComponent(orderIndex, itemIndex);
    }

    function _components(FulfillmentComponent memory a)
        internal
        pure
        returns (FulfillmentComponent[] memory components)
    {
        components = new FulfillmentComponent[](1);
        components[0] = a;
    }

    function _components(
        FulfillmentComponent memory a,
        FulfillmentComponent memory b
    ) internal pure returns (FulfillmentComponent[] memory components) {
        components = new FulfillmentComponent[](2);
        components[0] = a;
        components[1] = b;
    }

    // -------------------------------------------------------------------------
    // Conduit access and item checks (conduit.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts when attempting to execute transfers on a conduit when
    ///      not called from a channel" and its executeWithBatch1155 and
    ///      executeBatch1155 twins. Bob never had a channel. This contract
    ///      has one (setUp), so the same calls succeed until the channel is
    ///      closed, and then revert with this contract as the closed channel.
    function test_conduitRejectsCallerWithoutOpenChannel() public {
        Conduit[2] memory conduits = [conduit, referenceConduit];
        ConduitControllerInterface[2] memory controllers =
            [conduitController, referenceConduitController];

        for (uint256 i; i < 2; ++i) {
            Conduit target = conduits[i];

            _expectChannelClosed(bob);
            vm.prank(bob);
            target.execute(new ConduitTransfer[](0));

            _expectChannelClosed(bob);
            vm.prank(bob);
            target.executeWithBatch1155(
                new ConduitTransfer[](0), new ConduitBatch1155Transfer[](0)
            );

            _expectChannelClosed(bob);
            vm.prank(bob);
            target.executeBatch1155(new ConduitBatch1155Transfer[](0));

            // Open channel: the same empty calls go through.
            assertEq(
                target.execute(new ConduitTransfer[](0)),
                ConduitInterface.execute.selector
            );
            assertEq(
                target.executeWithBatch1155(
                    new ConduitTransfer[](0), new ConduitBatch1155Transfer[](0)
                ),
                ConduitInterface.executeWithBatch1155.selector
            );
            assertEq(
                target.executeBatch1155(new ConduitBatch1155Transfer[](0)),
                ConduitInterface.executeBatch1155.selector
            );

            // Closed channel.
            controllers[i].updateChannel(address(target), address(this), false);

            _expectChannelClosed(address(this));
            target.execute(new ConduitTransfer[](0));

            _expectChannelClosed(address(this));
            target.executeWithBatch1155(
                new ConduitTransfer[](0), new ConduitBatch1155Transfer[](0)
            );

            _expectChannelClosed(address(this));
            target.executeBatch1155(new ConduitBatch1155Transfer[](0));
        }
    }

    /// @dev "Reverts on an attempt to move an unsupported item": a native
    ///      item has no conduit transfer path. Checked on execute as well as
    ///      on executeWithBatch1155, which the Hardhat test used.
    function test_conduitRejectsNativeItem() public {
        Conduit[2] memory conduits = [conduit, referenceConduit];
        ConduitTransfer[] memory transfers = new ConduitTransfer[](1);
        transfers[0] = ConduitTransfer(
            ConduitItemType.NATIVE, address(0), address(this), alice, 0, 1
        );

        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(ConduitInterface.InvalidItemType.selector);
            conduits[i].executeWithBatch1155(
                transfers, new ConduitBatch1155Transfer[](0)
            );

            vm.expectRevert(ConduitInterface.InvalidItemType.selector);
            conduits[i].execute(transfers);
        }
    }

    /// @dev "Reverts on calls to batch transfer 1155 items with no contract on
    ///      a conduit": executeWithBatch1155 with a token account that has no
    ///      code. The same batch on a real token goes through.
    function test_conduitBatchWithTransfersRejectsTokenWithoutCode() public {
        Conduit[2] memory conduits = [conduit, referenceConduit];
        address noCode = makeAddr("noCode");

        for (uint256 i; i < 2; ++i) {
            uint256 id = _mint1155(alice, 4);
            ConduitBatch1155Transfer[] memory batch =
                _batch(noCode, alice, bob, id, 4);

            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenTransferrerErrors.NoContract.selector, noCode
                )
            );
            conduits[i].executeWithBatch1155(new ConduitTransfer[](0), batch);

            batch[0].token = address(test1155_1);
            conduits[i].executeWithBatch1155(new ConduitTransfer[](0), batch);
            assertEq(test1155_1.balanceOf(bob, id), 4);
        }
    }

    function _expectChannelClosed(address channel) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitInterface.ChannelClosed.selector, channel
            )
        );
    }

    // -------------------------------------------------------------------------
    // Basic order calldata encoding (revert.spec.ts "Basic Order Calldata")
    // -------------------------------------------------------------------------

    // Calldata offsets of fulfillBasicOrder's three head pointers: the struct
    // offset, then the additionalRecipients and signature offsets inside the
    // struct head (fields 16 and 17, after the 4-byte selector and the struct
    // offset word).
    uint256 internal constant BASIC_PARAMETERS_OFFSET_PTR = 0x04;
    uint256 internal constant BASIC_RECIPIENTS_OFFSET_PTR = 0x224;
    uint256 internal constant BASIC_SIGNATURE_OFFSET_PTR = 0x244;

    /// @dev "Reverts if BasicOrderParameters has non-default offset"
    function test_basicRejectsNonDefaultParametersOffset() public {
        _forEachSeaport(_basicRejectsNonDefaultParametersOffset);
    }

    function _basicRejectsNonDefaultParametersOffset(ConsiderationInterface c)
        internal
    {
        _checkBasicOffset(c, BASIC_PARAMETERS_OFFSET_PTR, 0x20);
    }

    /// @dev "Reverts if additionalRecipients has non-default offset"
    function test_basicRejectsNonDefaultRecipientsOffset() public {
        _forEachSeaport(_basicRejectsNonDefaultRecipientsOffset);
    }

    function _basicRejectsNonDefaultRecipientsOffset(ConsiderationInterface c)
        internal
    {
        _checkBasicOffset(c, BASIC_RECIPIENTS_OFFSET_PTR, 0x240);
    }

    /// @dev "Reverts if signature has non-default offset". The Hardhat test of
    ///      that name bumped the additionalRecipients offset a second time;
    ///      this one moves the signature offset. Two additional recipients
    ///      put the default at 0x260 + 2 * 0x40.
    function test_basicRejectsNonDefaultSignatureOffset() public {
        _forEachSeaport(_basicRejectsNonDefaultSignatureOffset);
    }

    function _basicRejectsNonDefaultSignatureOffset(ConsiderationInterface c)
        internal
    {
        _checkBasicOffset(c, BASIC_SIGNATURE_OFFSET_PTR, 0x2e0);
    }

    /// @dev Adds one to the head word at `ptr` of an otherwise valid
    ///      fulfillBasicOrder call and expects InvalidBasicOrderParameterEncoding,
    ///      then sends the untouched calldata and expects the fill.
    function _checkBasicOffset(
        ConsiderationInterface c,
        uint256 ptr,
        uint256 defaultOffset
    ) internal {
        uint256 id = _mint721(alice);
        (Order memory order,) =
            _sign(c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal)));
        bytes memory data = abi.encodeCall(
            ConsiderationInterface.fulfillBasicOrder,
            (toBasicOrderParameters(
                    order, BasicOrderType.ETH_TO_ERC721_FULL_OPEN
                ))
        );
        assertEq(_word(data, ptr), defaultOffset);

        bytes memory badData = bytes.concat(data);
        _setWord(badData, ptr, defaultOffset + 1);

        vm.prank(bob);
        (bool ok, bytes memory ret) =
            address(c).call{ value: ETH_TOTAL }(badData);
        assertFalse(ok);
        if (_isReference(c) && ptr == BASIC_PARAMETERS_OFFSET_PTR) {
            // The reference build checks the order's time window before the
            // offsets, through the ABI-decoded struct, which now starts one
            // byte late. startTime and endTime (fields 9 and 10) read as
            // words straddling their neighbours, and the window is invalid.
            uint256 head = 4 + defaultOffset + 1;
            assertEq(
                ret,
                abi.encodeWithSelector(
                    ConsiderationEventsAndErrors.InvalidTime.selector,
                    _word(badData, head + 9 * 0x20),
                    _word(badData, head + 10 * 0x20)
                )
            );
        } else {
            assertEq(
                ret,
                abi.encodeWithSelector(
                    ConsiderationEventsAndErrors.InvalidBasicOrderParameterEncoding
                        .selector
                )
            );
        }

        vm.prank(bob);
        (ok,) = address(c).call{ value: ETH_TOTAL }(data);
        assertTrue(ok);
        assertEq(test721_1.ownerOf(id), bob);
    }

    function _word(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint256 value)
    {
        assembly {
            value := mload(add(add(data, 0x20), offset))
        }
    }

    function _setWord(bytes memory data, uint256 offset, uint256 value)
        internal
        pure
    {
        assembly {
            mstore(add(add(data, 0x20), offset), value)
        }
    }

    // -------------------------------------------------------------------------
    // ERC-1271 revert reasons (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts on invalid 1271 signature": the wallet rejects a
    ///      signature from someone other than its owner with
    ///      revert("BAD SIGNER"), and fulfillBasicOrder passes that reason up
    ///      unchanged. The owner's signature on the same order fills.
    function test_basicBubblesEip1271RevertReason() public {
        _forEachSeaport(_basicBubblesEip1271RevertReason);
    }

    function _basicBubblesEip1271RevertReason(ConsiderationInterface c)
        internal
    {
        RevertingEIP1271Wallet wallet = new RevertingEIP1271Wallet(alice);
        wallet.approve(address(test721_1), address(c));
        uint256 id = _newId();
        test721_1.mint(address(wallet), id);

        ConsiderationItem[] memory cons = new ConsiderationItem[](3);
        cons[0] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            1000,
            1000,
            payable(address(wallet))
        );
        cons[1] =
            ConsiderationItem(ItemType.ERC20, address(token1), 0, 40, 40, cal);
        cons[2] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 40, 40, feeRecipient
        );
        OrderParameters memory params = _params(_offer721(id, 1), cons);
        params.offerer = address(wallet);

        // Cal is not the wallet's owner.
        (Order memory order,) = _sign(c, calPk, params);
        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );
        vm.expectRevert(bytes("BAD SIGNER"));
        vm.prank(bob);
        c.fulfillBasicOrder(basic);

        (order,) = _sign(c, alicePk, params);
        basic = toBasicOrderParameters(
            order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );
        uint256 walletBalance = token1.balanceOf(address(wallet));
        vm.prank(bob);
        c.fulfillBasicOrder(basic);
        assertEq(test721_1.ownerOf(id), bob);
        assertEq(token1.balanceOf(address(wallet)), walletBalance + 1000);
    }

    // -------------------------------------------------------------------------
    // Conduit failures without revert data (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts when 1155 token transfer reverts (via conduit,
    ///      returndata)". The ERC1155 recipient reverts with as much data as
    ///      its gas can pay for. The failure eats the gas left down the call
    ///      chain, so the conduit runs out of gas before it can return an
    ///      error of its own and its call fails with no data. Seaport then
    ///      raises InvalidCallToConduit. The Hardhat test picked a gas limit
    ///      just above an estimate; the result is the same at 1M and at 5M
    ///      gas here. Optimized only, like the Hardhat test: the reference
    ///      build calls the conduit with a high-level call and has no
    ///      InvalidCallToConduit path.
    function test_conduitFailureWithoutDataRaisesInvalidCallToConduit() public {
        ExcessReturnDataRecipient receiver = new ExcessReturnDataRecipient();
        uint256 id = _mint1155(bob, 10);

        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC1155,
            address(test1155_1),
            id,
            10,
            10,
            payable(address(receiver))
        );
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC20, address(token1), 0, 100, 100);
        OrderParameters memory params = _params(offer, cons);
        params.conduitKey = conduitKeyOne;
        (Order memory order,) = _sign(consideration, alicePk, params);
        bytes memory data = abi.encodeCall(
            ConsiderationInterface.fulfillAdvancedOrder,
            (
                toAdvancedOrder(order),
                new CriteriaResolver[](0),
                conduitKeyOne,
                address(0)
            )
        );

        receiver.setRevertDataSize(1);

        bytes memory expected = abi.encodeWithSelector(
            ConsiderationEventsAndErrors.InvalidCallToConduit.selector,
            address(conduit)
        );
        uint256[2] memory gasLimits = [uint256(1_000_000), 5_000_000];
        bool ok;
        bytes memory ret;
        for (uint256 i; i < 2; ++i) {
            vm.prank(bob);
            (ok, ret) = address(consideration).call{ gas: gasLimits[i] }(data);
            assertFalse(ok);
            assertEq(ret, expected);
        }

        // The same order fills once the recipient accepts the tokens.
        receiver.setRevertDataSize(0);
        vm.prank(bob);
        (ok,) = address(consideration).call(data);
        assertTrue(ok);
        assertEq(test1155_1.balanceOf(address(receiver), id), 10);
    }

    // -------------------------------------------------------------------------
    // Restricted match with an EOA zone (revert.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Reverts on invalid submitter when required by order": a
    ///      FULL_RESTRICTED order whose zone is an account with no code. A
    ///      match from anyone else fails the zone check; the optimized build
    ///      raises InvalidRestrictedOrder, while the reference build's
    ///      high-level call to an account with no code reverts with no data.
    ///      The zone itself can submit the same match.
    function test_matchRejectsSubmitterOtherThanEoaZone() public {
        _forEachSeaport(_matchRejectsSubmitterOtherThanEoaZone);
    }

    function _matchRejectsSubmitterOtherThanEoaZone(ConsiderationInterface c)
        internal
    {
        address zone = makeAddr("eoaZone");
        vm.deal(zone, ETH_TOTAL);
        uint256 id = _mint721(alice);

        OrderParameters memory params =
            _params(_offer721(id, 1), _ethConsideration(cal));
        params.orderType = OrderType.FULL_RESTRICTED;
        params.zone = zone;
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        OfferItem[] memory mirrorOffer = new OfferItem[](1);
        mirrorOffer[0] =
            OfferItem(ItemType.NATIVE, address(0), 0, ETH_TOTAL, ETH_TOTAL);
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
        Fulfillment[] memory fulfillments = new Fulfillment[](4);
        fulfillments[0] = _fulfillment(0, 0, 1, 0);
        fulfillments[1] = _fulfillment(1, 0, 0, 0);
        fulfillments[2] = _fulfillment(1, 0, 0, 1);
        fulfillments[3] = _fulfillment(1, 0, 0, 2);

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
        vm.prank(cal);
        c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);

        uint256 aliceBalance = alice.balance;
        vm.prank(zone);
        c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);
        assertEq(test721_1.ownerOf(id), bob);
        assertEq(alice.balance, aliceBalance + 10 ether);
        _assertStatus(c, orderHash, 1, 1);
    }

    // -------------------------------------------------------------------------
    // incrementCounter (counter.spec.ts)
    // -------------------------------------------------------------------------

    /// @dev "Can increment the counter": the new counter is the old one plus
    ///      the upper half of the previous block hash, CounterIncremented
    ///      reports it, an order signed under the old counter no longer
    ///      verifies, and the same order signed under the new counter fills.
    function test_incrementCounterInvalidatesOldSignatures() public {
        _forEachSeaport(_incrementCounterInvalidatesOldSignatures);
    }

    function _incrementCounterInvalidatesOldSignatures(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        OrderParameters memory params =
            _params(_offer721(id, 1), _ethConsideration(cal));
        (Order memory order,) = _sign(c, alicePk, params);
        uint256 oldCounter = c.getCounter(alice);

        bytes32 previousBlockHash = keccak256(abi.encode("previous block", c));
        vm.setBlockhash(block.number - 1, previousBlockHash);
        uint256 newCounter = oldCounter + (uint256(previousBlockHash) >> 128);
        assertGt(newCounter, oldCounter);

        vm.expectEmit(address(c));
        emit ConsiderationEventsAndErrors.CounterIncremented(newCounter, alice);
        vm.prank(alice);
        assertEq(c.incrementCounter(), newCounter);
        assertEq(c.getCounter(alice), newCounter);

        vm.expectRevert(SignatureVerificationErrors.InvalidSigner.selector);
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(order, bytes32(0));

        // Same parameters, signed again under the new counter.
        (Order memory resigned, bytes32 orderHash) = _sign(c, alicePk, params);
        uint256 aliceBalance = alice.balance;
        vm.prank(bob);
        c.fulfillOrder{ value: ETH_TOTAL }(resigned, bytes32(0));
        assertEq(test721_1.ownerOf(id), bob);
        assertEq(alice.balance, aliceBalance + 10 ether);
        _assertStatus(c, orderHash, 1, 1);
    }

    // -------------------------------------------------------------------------
    // Errors otherwise checked only by the fuzz engine
    // -------------------------------------------------------------------------

    // FuzzEngine skips the revert-reason comparison on the reference build,
    // so these errors had no exact-payload check there. Each case below pins
    // the payload on both builds.

    /// @dev Criteria resolver errors on an offer-side criteria item:
    ///      OrderCriteriaResolverOutOfRange, OfferCriteriaResolverOutOfRange,
    ///      UnresolvedOfferCriteria, InvalidProof and CriteriaNotEnabledForItem.
    ///      The correct resolver then fills the order.
    function test_offerCriteriaResolverErrors() public {
        _forEachSeaport(_offerCriteriaResolverErrors);
    }

    function _offerCriteriaResolverErrors(ConsiderationInterface c) internal {
        uint256 id = _mint721(alice);
        (bytes32 root, bytes32[] memory proof) = _criteria(id);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(
            ItemType.ERC721_WITH_CRITERIA,
            address(test721_1),
            uint256(root),
            1,
            1
        );
        (Order memory order,) =
            _sign(c, alicePk, _params(offer, _ethConsideration(cal)));
        AdvancedOrder memory advanced = toAdvancedOrder(order);

        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(1, Side.OFFER, 0, id, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.OrderCriteriaResolverOutOfRange
                .selector,
                Side.OFFER
            )
        );
        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(0, Side.OFFER, 1, id, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.OfferCriteriaResolverOutOfRange
                .selector
            )
        );
        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(0, Side.OFFER, 0, id + 1, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.InvalidProof.selector
            )
        );
        // A resolver for the (non-criteria) native consideration item.
        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(0, Side.CONSIDERATION, 0, id, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.CriteriaNotEnabledForItem.selector
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CriteriaResolutionErrors.UnresolvedOfferCriteria.selector, 0, 0
            )
        );
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            advanced, new CriteriaResolver[](0), bytes32(0), address(0)
        );

        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] = CriteriaResolver(0, Side.OFFER, 0, id, proof);
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            advanced, resolvers, bytes32(0), address(0)
        );
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev The consideration-side twins: OrderCriteriaResolverOutOfRange,
    ///      ConsiderationCriteriaResolverOutOfRange and
    ///      UnresolvedConsiderationCriteria. Bob supplies the ERC721.
    function test_considerationCriteriaResolverErrors() public {
        _forEachSeaport(_considerationCriteriaResolverErrors);
    }

    function _considerationCriteriaResolverErrors(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(bob);
        (bytes32 root, bytes32[] memory proof) = _criteria(id);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC20, address(token1), 0, 100, 100);
        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC721_WITH_CRITERIA,
            address(test721_1),
            uint256(root),
            1,
            1,
            alice
        );
        (Order memory order,) = _sign(c, alicePk, _params(offer, cons));
        AdvancedOrder memory advanced = toAdvancedOrder(order);

        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(1, Side.CONSIDERATION, 0, id, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.OrderCriteriaResolverOutOfRange
                .selector,
                Side.CONSIDERATION
            )
        );
        _expectCriteriaRevert(
            c,
            advanced,
            CriteriaResolver(0, Side.CONSIDERATION, 1, id, proof),
            abi.encodeWithSelector(
                CriteriaResolutionErrors.ConsiderationCriteriaResolverOutOfRange
                    .selector
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CriteriaResolutionErrors.UnresolvedConsiderationCriteria
                .selector,
                0,
                0
            )
        );
        vm.prank(bob);
        c.fulfillAdvancedOrder(
            advanced, new CriteriaResolver[](0), bytes32(0), address(0)
        );

        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] = CriteriaResolver(0, Side.CONSIDERATION, 0, id, proof);
        vm.prank(bob);
        c.fulfillAdvancedOrder(advanced, resolvers, bytes32(0), address(0));
        assertEq(test721_1.ownerOf(id), alice);
    }

    /// @dev ConsiderationNotMet: a match that leaves alice's third
    ///      consideration item (1 ether to feeRecipient) unpaid. With that
    ///      fulfillment added, the match goes through.
    function test_matchRevertsWhenConsiderationNotMet() public {
        _forEachSeaport(_matchRevertsWhenConsiderationNotMet);
    }

    function _matchRevertsWhenConsiderationNotMet(ConsiderationInterface c)
        internal
    {
        (Order[] memory orders, uint256 id) = _simpleMatchOrders(c);
        Fulfillment[] memory fulfillments = _simpleMatchFulfillments();
        Fulfillment[] memory short = new Fulfillment[](3);
        for (uint256 i; i < 3; ++i) {
            short[i] = fulfillments[i];
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.ConsiderationNotMet.selector,
                0,
                2,
                1 ether
            )
        );
        c.matchOrders{ value: ETH_TOTAL }(orders, short);

        c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev OfferAndConsiderationRequiredOnFulfillment: a match fulfillment
    ///      with no offer components, one with no consideration components,
    ///      and one with neither.
    function test_matchRequiresOfferAndConsiderationComponents() public {
        _forEachSeaport(_matchRequiresOfferAndConsiderationComponents);
    }

    function _matchRequiresOfferAndConsiderationComponents(ConsiderationInterface c)
        internal
    {
        (Order[] memory orders, uint256 id) = _simpleMatchOrders(c);

        // Empty offer side, empty consideration side, then both.
        for (uint256 i; i < 3; ++i) {
            Fulfillment[] memory fulfillments = _simpleMatchFulfillments();
            if (i != 1) {
                fulfillments[1].offerComponents = new FulfillmentComponent[](0);
            }
            if (i != 0) {
                fulfillments[1].considerationComponents =
                    new FulfillmentComponent[](0);
            }
            vm.expectRevert(
                FulfillmentApplicationErrors.OfferAndConsiderationRequiredOnFulfillment
                    .selector
            );
            c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);
        }

        c.matchOrders{ value: ETH_TOTAL }(orders, _simpleMatchFulfillments());
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev MismatchedFulfillmentOfferAndConsiderationComponents: a match
    ///      fulfillment whose offer and consideration items differ: alice's
    ///      ERC721 against her own native payment as fulfillment 0, then
    ///      against the fee payment as fulfillment 2, after the first two
    ///      payments. The error carries the fulfillment index.
    function test_matchRejectsMismatchedOfferAndConsideration() public {
        _forEachSeaport(_matchRejectsMismatchedOfferAndConsideration);
    }

    function _matchRejectsMismatchedOfferAndConsideration(ConsiderationInterface c)
        internal
    {
        (Order[] memory orders, uint256 id) = _simpleMatchOrders(c);

        Fulfillment[] memory fulfillments = _simpleMatchFulfillments();
        fulfillments[0] = _fulfillment(0, 0, 0, 0);
        _expectMismatchedComponents(0);
        c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);

        // Pay alice first, then pair her ERC721 with the fee payment.
        fulfillments = new Fulfillment[](4);
        fulfillments[0] = _fulfillment(1, 0, 0, 0);
        fulfillments[1] = _fulfillment(1, 0, 0, 1);
        fulfillments[2] = _fulfillment(0, 0, 0, 2);
        fulfillments[3] = _fulfillment(0, 0, 1, 0);
        _expectMismatchedComponents(2);
        c.matchOrders{ value: ETH_TOTAL }(orders, fulfillments);

        c.matchOrders{ value: ETH_TOTAL }(orders, _simpleMatchFulfillments());
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev MissingFulfillmentComponentOnAggregation: fulfillAvailableOrders
    ///      with an empty offer group, then an empty consideration group.
    function test_fulfillAvailableRejectsEmptyComponentGroup() public {
        _forEachSeaport(_fulfillAvailableRejectsEmptyComponentGroup);
    }

    function _fulfillAvailableRejectsEmptyComponentGroup(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        Order[] memory orders = new Order[](1);
        (orders[0],) = _sign(
            c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal))
        );

        FulfillmentComponent[][] memory offerGroups;
        FulfillmentComponent[][] memory considerationGroups;
        for (uint256 side; side < 2; ++side) {
            (offerGroups, considerationGroups) = _singleOrderGroups();
            if (side == 0) {
                offerGroups[0] = new FulfillmentComponent[](0);
            } else {
                considerationGroups[1] = new FulfillmentComponent[](0);
            }
            vm.expectRevert(
                abi.encodeWithSelector(
                    FulfillmentApplicationErrors.MissingFulfillmentComponentOnAggregation
                        .selector,
                    Side(side)
                )
            );
            vm.prank(bob);
            c.fulfillAvailableOrders{ value: ETH_TOTAL }(
                orders, offerGroups, considerationGroups, bytes32(0), 1
            );
        }

        (offerGroups, considerationGroups) = _singleOrderGroups();
        vm.prank(bob);
        c.fulfillAvailableOrders{ value: ETH_TOTAL }(
            orders, offerGroups, considerationGroups, bytes32(0), 1
        );
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev NoSpecifiedOrdersAvailable: every order passed to
    ///      fulfillAvailableOrders is cancelled. A fresh order fills.
    function test_fulfillAvailableRevertsWhenNoOrderAvailable() public {
        _forEachSeaport(_fulfillAvailableRevertsWhenNoOrderAvailable);
    }

    function _fulfillAvailableRevertsWhenNoOrderAvailable(ConsiderationInterface c)
        internal
    {
        uint256 id = _mint721(alice);
        OrderParameters memory params =
            _params(_offer721(id, 1), _ethConsideration(cal));
        Order[] memory orders = new Order[](1);
        (orders[0],) = _sign(c, alicePk, params);

        OrderComponents[] memory toCancel = new OrderComponents[](1);
        toCancel[0] = toOrderComponents(params, c.getCounter(alice));
        vm.prank(alice);
        assertTrue(c.cancel(toCancel));

        (
            FulfillmentComponent[][] memory offerGroups,
            FulfillmentComponent[][] memory considerationGroups
        ) = _singleOrderGroups();
        vm.expectRevert(
            ConsiderationEventsAndErrors.NoSpecifiedOrdersAvailable.selector
        );
        vm.prank(bob);
        c.fulfillAvailableOrders{ value: ETH_TOTAL }(
            orders, offerGroups, considerationGroups, bytes32(0), 1
        );

        (orders[0],) = _sign(
            c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal))
        );
        vm.prank(bob);
        c.fulfillAvailableOrders{ value: ETH_TOTAL }(
            orders, offerGroups, considerationGroups, bytes32(0), 1
        );
        assertEq(test721_1.ownerOf(id), bob);
    }

    /// @dev PartialFillsNotEnabledForOrder: half of a FULL_OPEN order.
    ///      InexactFraction: a third of a PARTIAL_OPEN order for 10 ERC1155
    ///      tokens. Half of the partial order fills.
    function test_partialFillErrors() public {
        _forEachSeaport(_partialFillErrors);
    }

    function _partialFillErrors(ConsiderationInterface c) internal {
        uint256 id = _mint1155(alice, 10);
        OrderParameters memory params =
            _params(_offer1155(id, 10), _ethConsideration(cal));
        (Order memory order, bytes32 orderHash) = _sign(c, alicePk, params);

        vm.expectRevert(
            ConsiderationEventsAndErrors.PartialFillsNotEnabledForOrder.selector
        );
        _fillFraction(c, order, 1, 2);

        params = _params(_offer1155(id, 10), _ethConsideration(cal));
        params.orderType = OrderType.PARTIAL_OPEN;
        (order, orderHash) = _sign(c, alicePk, params);

        vm.expectRevert(AmountDerivationErrors.InexactFraction.selector);
        _fillFraction(c, order, 1, 3);

        _fillFraction(c, order, 1, 2);
        _assertStatus(c, orderHash, 1, 2);
        assertEq(test1155_1.balanceOf(bob, id), 5);
    }

    /// @dev Alice's ERC721 for the usual 12 ether, and bob's order offering
    ///      12 ether for it.
    function _simpleMatchOrders(ConsiderationInterface c)
        internal
        returns (Order[] memory orders, uint256 id)
    {
        id = _mint721(alice);
        OfferItem[] memory mirrorOffer = new OfferItem[](1);
        mirrorOffer[0] =
            OfferItem(ItemType.NATIVE, address(0), 0, ETH_TOTAL, ETH_TOTAL);
        ConsiderationItem[] memory mirrorCons = new ConsiderationItem[](1);
        mirrorCons[0] = ConsiderationItem(
            ItemType.ERC721, address(test721_1), id, 1, 1, bob
        );
        OrderParameters memory mirrorParams = _params(mirrorOffer, mirrorCons);
        mirrorParams.offerer = bob;

        orders = new Order[](2);
        (orders[0],) = _sign(
            c, alicePk, _params(_offer721(id, 1), _ethConsideration(cal))
        );
        (orders[1],) = _sign(c, bobPk, mirrorParams);
    }

    function _simpleMatchFulfillments()
        internal
        pure
        returns (Fulfillment[] memory fulfillments)
    {
        fulfillments = new Fulfillment[](4);
        fulfillments[0] = _fulfillment(0, 0, 1, 0);
        fulfillments[1] = _fulfillment(1, 0, 0, 0);
        fulfillments[2] = _fulfillment(1, 0, 0, 1);
        fulfillments[3] = _fulfillment(1, 0, 0, 2);
    }

    /// @dev Fulfillment groups for one order with one offer item and three
    ///      consideration items.
    function _singleOrderGroups()
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offerGroups,
            FulfillmentComponent[][] memory considerationGroups
        )
    {
        offerGroups = new FulfillmentComponent[][](1);
        offerGroups[0] = _components(_component(0, 0));
        considerationGroups = new FulfillmentComponent[][](3);
        for (uint256 i; i < 3; ++i) {
            considerationGroups[i] = _components(_component(0, i));
        }
    }

    /// @dev Root and proof for `id` in a two-leaf tree.
    function _criteria(uint256 id)
        internal
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encode(id));
        leaves[1] = keccak256(abi.encode(id + 1_000_000));
        root = merkle.getRoot(leaves);
        proof = merkle.getProof(leaves, 0);
    }

    function _expectCriteriaRevert(
        ConsiderationInterface c,
        AdvancedOrder memory advanced,
        CriteriaResolver memory resolver,
        bytes memory expected
    ) internal {
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] = resolver;
        vm.expectRevert(expected);
        vm.prank(bob);
        c.fulfillAdvancedOrder{ value: ETH_TOTAL }(
            advanced, resolvers, bytes32(0), address(0)
        );
    }

    function _expectMismatchedComponents(uint256 fulfillmentIndex) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                FulfillmentApplicationErrors.MismatchedFulfillmentOfferAndConsiderationComponents
                    .selector,
                fulfillmentIndex
            )
        );
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
