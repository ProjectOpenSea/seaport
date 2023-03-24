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

    function testCanVerify(uint256 seed) public {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(seed);
        CriteriaMetadata memory meta = test.generateCriteriaMetadata(prng);
        bytes32 hashedIdentifier = keccak256(
            abi.encode(meta.resolvedIdentifier)
        );
        assertTrue(
            test.MERKLE().verifyProof(meta.root, meta.proof, hashedIdentifier)
        );
    }
}
