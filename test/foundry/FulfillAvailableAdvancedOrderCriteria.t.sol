// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { Merkle } from "murky/Merkle.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { CriteriaResolver, OfferItem, OrderComponents, AdvancedOrder, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
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

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
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
            try test721_1.mint(alice, context.args.identifiers[i]) {} catch (
                bytes memory
            ) {}
            // hash identifier and store to generate proof
            hashedIdentifiers[i] = keccak256(
                abi.encode(context.args.identifiers[i])
            );
        }

        bytes32 root = merkle.getRoot(hashedIdentifiers);

        addOfferItem721Criteria(address(test721_1), uint256(root));
        addEthConsiderationItem(alice, 1);
        _configureOrderParameters(alice, address(0), bytes32(0), 0, false);

        OrderComponents memory orderComponents = getOrderComponents(
            baseOrderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );
        advancedOrder = AdvancedOrder(baseOrderParameters, 1, 1, signature, "");
    }

    function addOfferItem721Criteria(address token, uint256 identifierHash)
        internal
    {
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

    function testFulfillAvailableAdvancedOrdersWithCriteria(
        FuzzArgs memory args
    ) public {
        test(
            this.fulfillAvailableAdvancedOrdersWithCriteria,
            Context(consideration, args)
        );
        test(
            this.fulfillAvailableAdvancedOrdersWithCriteria,
            Context(referenceConsideration, args)
        );
    }

    function fulfillAvailableAdvancedOrdersWithCriteria(Context memory context)
        external
        stateless
    {
        // pick a "random" index in the array of identifiers; use that identifier
        context.args.index = context.args.index % 8;
        uint256 identifier = context.args.identifiers[context.args.index];

        (
            bytes32[] memory hashedIdentifiers,
            AdvancedOrder memory advancedOrder
        ) = prepareCriteriaOfferOrder(context);

        // add advancedOrder to an AdvancedOrder array
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = advancedOrder;

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

        // add erc721 offer to offerComponentsArray
        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        resetOfferComponents();

        // add eth consideration to considerationComponentsArray
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        resetConsiderationComponents();

        context.consideration.fulfillAvailableAdvancedOrders{ value: 1 }(
            advancedOrders,
            resolvers,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            address(0),
            100
        );

        assertEq(address(this), test721_1.ownerOf(identifier));
    }
}
