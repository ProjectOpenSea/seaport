// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { Merkle } from "murky/Merkle.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import { LibSort } from "solady/src/utils/LibSort.sol";

struct CriteriaMetadata {
    uint256 resolvedIdentifier;
    bytes32 root;
    bytes32[] proof;
}

contract CriteriaResolverHelper {
    using LibPRNG for LibPRNG.PRNG;

    uint256 immutable MAX_LEAVES;
    Merkle public immutable MERKLE;

    constructor(uint256 maxLeaves) {
        MAX_LEAVES = maxLeaves;
        MERKLE = new Merkle();
    }

    /**
     * @notice Generates a random number of random token identifiers to use as
     *         leaves in a Merkle tree, then hashes them to leaves, and finally
     *         generates a Merkle root and proof for a randomly selected leaf
     * @param prng PRNG to use to generate the criteria metadata
     */
    function generateCriteriaMetadata(
        LibPRNG.PRNG memory prng
    ) public view returns (CriteriaMetadata memory criteria) {
        uint256[] memory identifiers = generateIdentifiers(prng);

        uint256 selectedIdentifierIndex = prng.next() % identifiers.length;
        uint256 selectedIdentifier = identifiers[selectedIdentifierIndex];
        bytes32[] memory leaves = hashIdentifiersToLeaves(identifiers);
        // TODO: Base Murky impl is very memory-inefficient (O(n^2))
        bytes32 root = MERKLE.getRoot(leaves);
        bytes32[] memory proof = MERKLE.getProof(
            leaves,
            selectedIdentifierIndex
        );
        criteria = CriteriaMetadata({
            resolvedIdentifier: selectedIdentifier,
            root: root,
            proof: proof
        });
    }

    /**
     * @notice Generates a random number of random token identifiers to use as
     *         leaves in a Merkle tree
     * @param prng PRNG to use to generate the identifiers
     */
    function generateIdentifiers(
        LibPRNG.PRNG memory prng
    ) public view returns (uint256[] memory identifiers) {
        uint256 numIdentifiers = (prng.next() % MAX_LEAVES);
        if (numIdentifiers <= 1) {
            numIdentifiers = 2;
        }
        identifiers = new uint256[](numIdentifiers);
        for (uint256 i = 0; i < numIdentifiers; ) {
            identifiers[i] = prng.next();
            unchecked {
                ++i;
            }
        }
        bool shouldSort = prng.next() % 2 == 1;
        if (shouldSort) {
            LibSort.sort(identifiers);
        }
    }

    /**
     * @notice Hashes an array of identifiers in-place to use as leaves in a
     *         Merkle tree
     * @param identifiers Identifiers to hash
     */
    function hashIdentifiersToLeaves(
        uint256[] memory identifiers
    ) internal pure returns (bytes32[] memory leaves) {
        assembly {
            leaves := identifiers
        }
        for (uint256 i = 0; i < identifiers.length; ) {
            bytes32 identifier = leaves[i];
            assembly {
                mstore(0x0, identifier)
                identifier := keccak256(0x0, 0x20)
            }
            leaves[i] = identifier;
            unchecked {
                ++i;
            }
        }
    }
}
