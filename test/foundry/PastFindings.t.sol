// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdError } from "forge-std/StdError.sol";

import { Merkle } from "murky/Merkle.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

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
    TokenTransferrerErrors
} from "seaport-types/src/interfaces/TokenTransferrerErrors.sol";

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
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Reproductions of past Seaport vulnerabilities, ported from the Hardhat
 *      specs that lived in test/findings/. Each test builds the original attack and
 *      checks that it now fails, and where the attack needs an otherwise
 *      valid order, also checks that the honest fill still works so the
 *      revert can't come from a broken setup.
 */
contract PastFindingsTest is BaseOrderTest {
    Merkle internal merkle = new Merkle();

    uint256 internal nextId = 5000;

    // -------------------------------------------------------------------------
    // AdditionalRecipientsOffByOne.spec.ts
    // -------------------------------------------------------------------------

    // Calldata offsets of fulfillBasicOrder with an empty additionalRecipients
    // array and standard ABI encoding: 4-byte selector, the struct offset,
    // then 18 head words, so the array length sits at 0x264 and the signature
    // length and data follow it.
    uint256 internal constant ADDITIONAL_RECIPIENTS_LENGTH_PTR = 0x264;
    uint256 internal constant SIGNATURE_LENGTH_PTR = 0x284;
    uint256 internal constant SIGNATURE_DATA_PTR = 0x2a4;

    /**
     * @dev Alice lists an NFT for 1000 tokens to her plus 100 to cal. Bob
     *      validates the order, then fulfills it with no additional
     *      recipients and a signature whose length word and first data word
     *      read as the missing recipient (100 tokens to cal). An off-by-one
     *      read past the empty array once let the order hash match while cal
     *      was never paid. The fix requires every original additional
     *      recipient to be supplied.
     */
    function test_additionalRecipientsOffByOne() public {
        uint256 id = _newId();
        test721_1.mint(alice, id);

        ConsiderationItem[] memory cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1000, 1000, alice
        );
        cons[1] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 100, 100, cal
        );

        (Order memory order,) = _sign(
            consideration,
            alicePk,
            _params(
                alice,
                _offer(ItemType.ERC721, address(test721_1), id, 1),
                cons,
                OrderType.FULL_OPEN
            )
        );

        // Bob validates the order, so the fill below skips the signature.
        Order[] memory toValidate = new Order[](1);
        toValidate[0] = order;
        vm.prank(bob);
        assertTrue(consideration.validate(toValidate));

        BasicOrderParameters memory basic = toBasicOrderParameters(
            order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );
        assertEq(basic.totalOriginalAdditionalRecipients, 1);

        // Malicious version: drop the additional recipient, then shape the
        // signature so the words right after the empty array read as
        // (amount = 100, recipient = cal).
        BasicOrderParameters memory scuffed = toBasicOrderParameters(
            order, BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );
        delete scuffed.additionalRecipients;
        scuffed.signature = new bytes(128);
        bytes memory data = abi.encodeCall(
            ConsiderationInterface.fulfillBasicOrder, (scuffed)
        );
        assertEq(_word(data, ADDITIONAL_RECIPIENTS_LENGTH_PTR), 0);
        assertEq(_word(data, SIGNATURE_LENGTH_PTR), 128);
        _setWord(data, SIGNATURE_LENGTH_PTR, 100);
        _setWord(data, SIGNATURE_DATA_PTR, uint256(uint160(address(cal))));

        uint256 calBefore = token1.balanceOf(cal);

        vm.prank(bob);
        (bool ok, bytes memory ret) = address(consideration).call(data);
        assertFalse(ok, "malicious basic order fill succeeded");
        assertEq(
            ret,
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.MissingOriginalConsiderationItems
                .selector
            )
        );
        assertEq(test721_1.ownerOf(id), alice);

        // The honest fill pays cal.
        vm.prank(bob);
        assertTrue(consideration.fulfillBasicOrder(basic));
        assertEq(test721_1.ownerOf(id), bob);
        assertEq(token1.balanceOf(cal) - calBefore, 100);
    }

    // -------------------------------------------------------------------------
    // CriteriaResolverUnhashedLeaves.spec.ts
    // -------------------------------------------------------------------------

    /**
     * @dev Alice offers 1000 tokens for any of ten NFTs in a Merkle tree. Cal,
     *      who controls the collection, mints a token whose ID is the root and
     *      fills with that ID and an empty proof. Seaport once compared the
     *      unhashed leaf to the root, so this passed. Leaves are now hashed
     *      before the proof is checked.
     */
    function test_criteriaResolverUnhashedLeaves() public {
        _forEachSeaport(_criteriaResolverUnhashedLeaves);
    }

    function _criteriaResolverUnhashedLeaves(ConsiderationInterface c)
        internal
    {
        bytes32[] memory leaves = new bytes32[](10);
        uint256 firstId = nextId;
        for (uint256 i = 0; i < 10; ++i) {
            uint256 id = _newId();
            test721_1.mint(bob, id);
            leaves[i] = keccak256(abi.encode(id));
        }
        bytes32 root = merkle.getRoot(leaves);

        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC721_WITH_CRITERIA,
            address(test721_1),
            uint256(root),
            1,
            1,
            alice
        );
        (Order memory order,) = _sign(
            c,
            alicePk,
            _params(
                alice,
                _offer(ItemType.ERC20, address(token1), 0, 1000),
                cons,
                OrderType.PARTIAL_OPEN
            )
        );
        AdvancedOrder memory advanced =
            AdvancedOrder(order.parameters, 1, 1, order.signature, "");

        // Cal mints an NFT whose ID is the root, outside Alice's set.
        test721_1.mint(cal, uint256(root));

        uint256 aliceBefore = token1.balanceOf(alice);

        vm.expectRevert(CriteriaResolutionErrors.InvalidProof.selector);
        vm.prank(cal);
        c.fulfillAdvancedOrder(
            advanced,
            _resolver(uint256(root), new bytes32[](0)),
            bytes32(0),
            cal
        );
        assertEq(test721_1.ownerOf(uint256(root)), cal);

        // A token from the set with a real proof still fills the order.
        uint256 index = 3;
        bytes32[] memory proof = merkle.getProof(leaves, index);
        vm.prank(bob);
        c.fulfillAdvancedOrder(
            advanced, _resolver(firstId + index, proof), bytes32(0), bob
        );
        assertEq(test721_1.ownerOf(firstId + index), alice);
        assertEq(aliceBefore - token1.balanceOf(alice), 1000);
    }

    // -------------------------------------------------------------------------
    // FulfillmentOverflowWithMissingItems.spec.ts
    // -------------------------------------------------------------------------

    /**
     * @dev Alice lists an NFT for 1000 tokens. Bob matches it with his own
     *      order that offers 1 token and lists two extra token consideration
     *      items to Alice: one for 0 and one for 2^256 - 999. Aggregating
     *      those with Alice's 1000 once wrapped to 1, so Bob paid 1 token for
     *      the NFT. The fulfillment applier now checks for overflow.
     */
    function test_fulfillmentOverflowWithMissingItems() public {
        _forEachSeaport(_fulfillmentOverflowWithMissingItems);
    }

    function _fulfillmentOverflowWithMissingItems(ConsiderationInterface c)
        internal
    {
        uint256 id = _newId();
        test721_1.mint(alice, id);

        ConsiderationItem[] memory aliceCons = new ConsiderationItem[](1);
        aliceCons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1000, 1000, alice
        );
        (Order memory aliceOrder,) = _sign(
            c,
            alicePk,
            _params(
                alice,
                _offer(ItemType.ERC721, address(test721_1), id, 1),
                aliceCons,
                OrderType.FULL_OPEN
            )
        );

        ConsiderationItem[] memory bobCons = new ConsiderationItem[](3);
        bobCons[0] = ConsiderationItem(
            ItemType.ERC721, address(test721_1), id, 1, 1, bob
        );
        bobCons[1] =
            ConsiderationItem(ItemType.ERC20, address(token1), 0, 0, 0, alice);
        bobCons[2] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            type(uint256).max - 998,
            type(uint256).max - 998,
            alice
        );
        (Order memory bobOrder,) = _sign(
            c,
            bobPk,
            _params(
                bob,
                _offer(ItemType.ERC20, address(token1), 0, 1),
                bobCons,
                OrderType.PARTIAL_OPEN
            )
        );

        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = AdvancedOrder(
            aliceOrder.parameters, 1, 1, aliceOrder.signature, ""
        );
        orders[1] =
            AdvancedOrder(bobOrder.parameters, 1, 1, bobOrder.signature, "");

        // Alice's NFT to Bob; Bob's 1 token against Alice's 1000 and both of
        // his extra items.
        Fulfillment[] memory fulfillments = new Fulfillment[](2);
        fulfillments[0] = Fulfillment(_components(0, 0), _components(1, 0));
        FulfillmentComponent[] memory considerationComponents =
            new FulfillmentComponent[](3);
        considerationComponents[0] = FulfillmentComponent(0, 0);
        considerationComponents[1] = FulfillmentComponent(1, 1);
        considerationComponents[2] = FulfillmentComponent(1, 2);
        fulfillments[1] =
            Fulfillment(_components(1, 0), considerationComponents);

        // The optimized build sums the items and panics on the overflow. The
        // reference build rejects the zero-amount item before summing.
        if (_isReference(c)) {
            vm.expectRevert(TokenTransferrerErrors.MissingItemAmount.selector);
        } else {
            vm.expectRevert(stdError.arithmeticError);
        }
        vm.prank(bob);
        c.matchAdvancedOrders(
            orders, new CriteriaResolver[](0), fulfillments, address(0)
        );
        assertEq(test721_1.ownerOf(id), alice);
    }

    // -------------------------------------------------------------------------
    // PartialFillFractionOverflow.spec.ts
    // -------------------------------------------------------------------------

    /**
     * @dev Alice sells two ERC1155 tokens for 1000 in a partially fillable
     *      order. Bob fills half. Cal then fills 2^118 / 2^119, which once
     *      overflowed the stored fraction and reset the order to 0% filled,
     *      so Cal could keep filling it and drain all ten of Alice's tokens.
     *      The fill now completes the order and no further fill succeeds.
     */
    function test_partialFillFractionOverflow() public {
        _forEachSeaport(_partialFillFractionOverflow);
    }

    function _partialFillFractionOverflow(ConsiderationInterface c) internal {
        uint256 id = _newId();
        test1155_1.mint(alice, id, 10);

        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem(
            ItemType.ERC20, address(token1), 0, 1000, 1000, alice
        );
        (Order memory order, bytes32 orderHash) = _sign(
            c,
            alicePk,
            _params(
                alice,
                _offer(ItemType.ERC1155, address(test1155_1), id, 2),
                cons,
                OrderType.PARTIAL_OPEN
            )
        );

        Order[] memory toValidate = new Order[](1);
        toValidate[0] = order;
        vm.prank(bob);
        assertTrue(c.validate(toValidate));

        uint256 aliceBefore = token1.balanceOf(alice);

        // Bob fills half.
        _fill(c, order, bob, 1, 2);
        assertEq(test1155_1.balanceOf(bob, id), 1);
        assertEq(token1.balanceOf(alice) - aliceBefore, 500);

        // Cal fills with the fraction that used to overflow.
        _fill(c, order, cal, 2 ** 118, 2 ** 119);
        assertEq(test1155_1.balanceOf(cal, id), 1);
        assertEq(test1155_1.balanceOf(alice, id), 8);
        assertEq(token1.balanceOf(alice) - aliceBefore, 1000);

        (bool isValidated, bool isCancelled, uint256 filled, uint256 size) =
            c.getOrderStatus(orderHash);
        assertTrue(isValidated);
        assertFalse(isCancelled);
        assertEq(filled, 2);
        assertEq(size, 2);

        // The order is filled, so neither fraction fills it again.
        AdvancedOrder memory again =
            AdvancedOrder(order.parameters, 1, 2, order.signature, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.OrderAlreadyFilled.selector,
                orderHash
            )
        );
        vm.prank(cal);
        c.fulfillAdvancedOrder(
            again, new CriteriaResolver[](0), bytes32(0), cal
        );

        again.numerator = 2 ** 118;
        again.denominator = 2 ** 119;
        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.OrderAlreadyFilled.selector,
                orderHash
            )
        );
        vm.prank(cal);
        c.fulfillAdvancedOrder(
            again, new CriteriaResolver[](0), bytes32(0), cal
        );

        assertEq(test1155_1.balanceOf(alice, id), 8);
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

    function _offer(
        ItemType itemType,
        address token,
        uint256 id,
        uint256 amount
    ) internal pure returns (OfferItem[] memory offer) {
        offer = new OfferItem[](1);
        offer[0] = OfferItem(itemType, token, id, amount, amount);
    }

    function _params(
        address offerer,
        OfferItem[] memory offer,
        ConsiderationItem[] memory cons,
        OrderType orderType
    ) internal returns (OrderParameters memory) {
        return OrderParameters({
            offerer: offerer,
            zone: address(0),
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

    function _fill(
        ConsiderationInterface c,
        Order memory order,
        address fulfiller,
        uint120 numerator,
        uint120 denominator
    ) internal {
        vm.prank(fulfiller);
        c.fulfillAdvancedOrder(
            AdvancedOrder(
                order.parameters, numerator, denominator, order.signature, ""
            ),
            new CriteriaResolver[](0),
            bytes32(0),
            fulfiller
        );
    }

    function _resolver(uint256 identifier, bytes32[] memory proof)
        internal
        pure
        returns (CriteriaResolver[] memory resolvers)
    {
        resolvers = new CriteriaResolver[](1);
        resolvers[0] =
            CriteriaResolver(0, Side.CONSIDERATION, 0, identifier, proof);
    }

    function _components(uint256 orderIndex, uint256 itemIndex)
        internal
        pure
        returns (FulfillmentComponent[] memory components)
    {
        components = new FulfillmentComponent[](1);
        components[0] = FulfillmentComponent(orderIndex, itemIndex);
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
}
