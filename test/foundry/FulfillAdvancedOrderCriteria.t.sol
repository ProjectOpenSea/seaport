// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { Merkle } from "murky/Merkle.sol";
import { ConsiderationInterface } from
    "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    CriteriaResolver,
    OfferItem,
    OrderComponents,
    AdvancedOrder
} from "../../contracts/lib/ConsiderationStructs.sol";
import { ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";

contract FulfillAdvancedOrderCriteria is BaseOrderTest {
    Merkle merkle = new Merkle();
    FuzzArgs empty;

    struct FuzzArgs {
        uint256[8] identifiers;
        uint8 index;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzArgs args;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testFulfillAdvancedOrderWithCriteria(FuzzArgs memory args)
        public
    {
        test(
            this.fulfillAdvancedOrderWithCriteria, Context(consideration, args)
        );
        test(
            this.fulfillAdvancedOrderWithCriteria,
            Context(referenceConsideration, args)
        );
    }

    function testFulfillAdvancedOrderWithCriteriaPreimage(FuzzArgs memory args)
        public
    {
        test(
            this.fulfillAdvancedOrderWithCriteriaPreimage,
            Context(consideration, args)
        );
        test(
            this.fulfillAdvancedOrderWithCriteriaPreimage,
            Context(referenceConsideration, args)
        );
    }

    function prepareCriteriaOfferOrder(Context memory context)
        internal
        returns (
            bytes32[] memory hashedIdentifiers,
            AdvancedOrder memory advancedOrder
        )
    {
        // create a new array to store bytes32 hashes of identifiers
        hashedIdentifiers = new bytes32[](context.args.identifiers.length);
        for (uint256 i = 0; i < context.args.identifiers.length; i++) {
            // try to mint each identifier; fuzzer may include duplicates
            try test721_1.mint(alice, context.args.identifiers[i]) { }
                catch (bytes memory) { }
            // hash identifier and store to generate proof
            hashedIdentifiers[i] =
                keccak256(abi.encode(context.args.identifiers[i]));
        }

        bytes32 root = merkle.getRoot(hashedIdentifiers);

        addOfferItem721Criteria(address(test721_1), uint256(root));
        addEthConsiderationItem(alice, 1);
        _configureOrderParameters(alice, address(0), bytes32(0), 0, false);

        OrderComponents memory orderComponents = getOrderComponents(
            baseOrderParameters, context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );
        advancedOrder = AdvancedOrder(baseOrderParameters, 1, 1, signature, "");
    }

    function fulfillAdvancedOrderWithCriteria(Context memory context)
        external
        stateless
    {
        // pick a "random" index in the array of identifiers; use that
        // identifier
        context.args.index = context.args.index % 8;
        uint256 identifier = context.args.identifiers[context.args.index];

        (bytes32[] memory hashedIdentifiers, AdvancedOrder memory advancedOrder)
        = prepareCriteriaOfferOrder(context);
        // create resolver for identifier including proof for token at index
        CriteriaResolver memory resolver = CriteriaResolver(
            0,
            Side.OFFER,
            0,
            identifier,
            merkle.getProof(hashedIdentifiers, context.args.index)
        );
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] = resolver;

        context.consideration.fulfillAdvancedOrder{value: 1}(
            advancedOrder, resolvers, bytes32(0), address(0)
        );

        assertEq(address(this), test721_1.ownerOf(identifier));
    }

    function fulfillAdvancedOrderWithCriteriaPreimage(Context memory context)
        external
        stateless
    {
        context.args.index = context.args.index % 8;
        (bytes32[] memory hashedIdentifiers, AdvancedOrder memory advancedOrder)
        = prepareCriteriaOfferOrder(context);

        // grab a random proof
        bytes32[] memory proof =
            merkle.getProof(hashedIdentifiers, context.args.index);
        // copy all but the first element of the proof to a new array
        bytes32[] memory truncatedProof = new bytes32[](proof.length - 1);
        for (uint256 i = 0; i < truncatedProof.length - 1; i++) {
            truncatedProof[i] = proof[i + 1];
        }
        // use the first element as a new token identifier
        uint256 preimageIdentifier = uint256(proof[0]);
        // try to mint preimageIdentifier; there's a chance it's already minted
        try test721_1.mint(alice, preimageIdentifier) { }
            catch (bytes memory) { }

        // create criteria resolver including first hash as identifier
        CriteriaResolver memory resolver = CriteriaResolver(
            0, Side.OFFER, 0, preimageIdentifier, truncatedProof
        );
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](1);
        resolvers[0] = resolver;

        vm.expectRevert(abi.encodeWithSignature("InvalidProof()"));
        context.consideration.fulfillAdvancedOrder{value: 1}(
            advancedOrder, resolvers, bytes32(0), address(0)
        );
    }

    function addOfferItem721Criteria(
        address token,
        uint256 identifierHash
    ) internal {
        addOfferItem721Criteria(token, identifierHash, 1, 1);
    }

    function addOfferItem721Criteria(
        address token,
        uint256 identifierHash,
        uint256 amount
    ) internal {
        addOfferItem721Criteria(token, identifierHash, amount, amount);
    }

    function addOfferItem721Criteria(
        address token,
        uint256 identifierHash,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        offerItems.push(
            OfferItem(
                ItemType.ERC721_WITH_CRITERIA,
                token,
                identifierHash,
                startAmount,
                endAmount
            )
        );
    }
}
