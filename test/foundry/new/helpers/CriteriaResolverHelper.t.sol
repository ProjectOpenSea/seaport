// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    CriteriaResolverHelper,
    CriteriaMetadata
} from "./CriteriaResolverHelper.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

contract CriteriaResolverHelperTest is Test {
    CriteriaResolverHelper test;

    function setUp() public {
        test = new CriteriaResolverHelper(100);
    }

    // function testCanVerify(uint256 seed) public {
    //     LibPRNG.PRNG memory prng = LibPRNG.PRNG(seed);
    //     uint256 criteria = test.generateCriteriaMetadata(prng);
    //     uint256 resolvedIdentifier = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .resolvedIdentifier;
    //     bytes32[] memory proof = test
    //         .resolvableIdentifierForGivenCriteria(criteria)
    //         .proof;
    //     bytes32 hashedIdentifier = keccak256(abi.encode(resolvedIdentifier));
    //     assertTrue(
    //         test.MERKLE().verifyProof(meta.root, meta.proof, hashedIdentifier)
    //     );
    // }
}