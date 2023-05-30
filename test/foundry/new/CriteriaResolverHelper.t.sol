// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { Test } from "forge-std/Test.sol";

// import {
//     AdvancedOrderLib,
//     ConsiderationItemLib,
//     OfferItemLib,
//     OrderParametersLib,
//     SeaportArrays
// } from "seaport-sol/src/SeaportSol.sol";

import { CriteriaResolverHelper } from "./helpers/CriteriaResolverHelper.sol";

contract CriteriaResolverHelperTest is Test {
    // using LibPRNG for LibPRNG.PRNG;
    // using OfferItemLib for OfferItem;
    // using OfferItemLib for OfferItem[];
    // using ConsiderationItemLib for ConsiderationItem;
    // using ConsiderationItemLib for ConsiderationItem[];
    // using OrderParametersLib for OrderParameters;
    // using AdvancedOrderLib for AdvancedOrder;
    // using AdvancedOrderLib for AdvancedOrder[];

    CriteriaResolverHelper test;

    function setUp() public {
        test = new CriteriaResolverHelper(100);
    }

    // function testCanVerify(uint256 seed) public {
    //     LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });
    //     uint256[] memory identifiers = test.generateIdentifiers(prng);
    //     uint256 criteria = test.generateCriteriaMetadata(prng, seed);

    //     uint256 resolvedIdentifier = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .resolvedIdentifier;
    //     bytes32[] memory proof = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .proof;
    //     bytes32 hashedIdentifier = keccak256(abi.encode(resolvedIdentifier));
    //     bytes32[] memory leaves = test.hashIdentifiersToLeaves(identifiers);
    //     bytes32 root = test.MERKLE().getRoot(leaves);
    //     assertTrue(test.MERKLE().verifyProof(root, proof, hashedIdentifier));
    // }

    // function testDeriveCriteriaResolvers(
    //     uint256 seed,
    //     uint256 desiredId
    // ) public {
    //     vm.assume(desiredId < type(uint256).max);

    //     LibPRNG.PRNG memory prng = LibPRNG.PRNG(seed);
    //     uint256 criteria = test.generateCriteriaMetadata(prng, desiredId);

    //     // Create the offer and consideration for the order
    //     OfferItem[] memory offer = SeaportArrays.OfferItems(
    //         OfferItemLib
    //             .empty()
    //             .withItemType(ItemType.ERC721_WITH_CRITERIA)
    //             .withStartAmount(1)
    //             .withEndAmount(1)
    //             .withToken(address(1234))
    //             .withIdentifierOrCriteria(criteria)
    //     );

    //     ConsiderationItem[] memory consideration = SeaportArrays
    //         .ConsiderationItems(
    //             ConsiderationItemLib
    //                 .empty()
    //                 .withItemType(ItemType.ERC20)
    //                 .withStartAmount(100)
    //                 .withEndAmount(100)
    //                 .withToken(address(1234))
    //                 .withIdentifierOrCriteria(0)
    //                 .withRecipient(address(this))
    //         );

    //     OrderParameters memory orderParameters = OrderParametersLib
    //         .empty()
    //         .withOffer(offer)
    //         .withConsideration(consideration);

    //     AdvancedOrder[] memory orders = SeaportArrays.AdvancedOrders(
    //         AdvancedOrderLib.empty().withParameters(orderParameters)
    //     );

    //     CriteriaResolver[] memory criteriaResolvers = test
    //         .deriveCriteriaResolvers(orders);

    //     assertEq(
    //         criteriaResolvers.length,
    //         1,
    //         "Invalid criteria resolvers length"
    //     );
    //     assertEq(
    //         criteriaResolvers[0].identifier,
    //         desiredId,
    //         "Criteria resolver should have desired id"
    //     );

    //     uint256[] memory identifiers = test.generateIdentifiers(prng);
    //     uint256 resolvedIdentifier = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .resolvedIdentifier;
    //     bytes32[] memory proof = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .proof;
    //     bytes32 hashedIdentifier = keccak256(abi.encode(resolvedIdentifier));
    //     bytes32[] memory leaves = test.hashIdentifiersToLeaves(identifiers);
    //     bytes32 root = test.MERKLE().getRoot(leaves);

    //     test.MERKLE().verifyProof(root, proof, hashedIdentifier);
    // }
}
