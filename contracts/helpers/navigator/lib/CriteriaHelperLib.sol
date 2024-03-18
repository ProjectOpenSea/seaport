// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MerkleLib } from "./MerkleLib.sol";

error TokenIdNotFound();

struct HashAndIntTuple {
    uint256 num;
    bytes32 hash;
}

/**
 * @notice Helper library for calculating criteria resolver Merkle roots and
 *         proofs from integer token ids.
 */
library CriteriaHelperLib {
    error CannotDeriveRootForSingleTokenId();
    error CannotDeriveProofForSingleTokenId();

    /**
     * @notice Calculate the Merkle root of a criteria tree containing the given
     *         integer token ids.
     */
    function criteriaRoot(
        uint256[] memory tokenIds
    ) internal pure returns (bytes32) {
        if (tokenIds.length == 0) {
            return bytes32(0);
        } else if (tokenIds.length == 1) {
            revert CannotDeriveRootForSingleTokenId();
        } else {
            return
                MerkleLib.getRoot(
                    toSortedHashes(tokenIds),
                    MerkleLib.merkleHash
                );
        }
    }

    /**
     * @notice Calculate the Merkle proof that the given token id is a member of
     *         the criteria tree containing the provided tokenIds.
     */
    function criteriaProof(
        uint256[] memory tokenIds,
        uint256 id
    ) internal pure returns (bytes32[] memory) {
        if (tokenIds.length == 0) {
            return new bytes32[](0);
        } else if (tokenIds.length == 1) {
            revert CannotDeriveProofForSingleTokenId();
        } else {
            bytes32 idHash = keccak256(abi.encode(id));
            uint256 idx;
            bool found;
            bytes32[] memory idHashes = toSortedHashes(tokenIds);
            for (; idx < idHashes.length; idx++) {
                if (idHashes[idx] == idHash) {
                    found = true;
                    break;
                }
            }
            if (!found) revert TokenIdNotFound();
            return MerkleLib.getProof(idHashes, idx, MerkleLib.merkleHash);
        }
    }

    /**
     * @notice Sort an array of integer token ids by their hashed values.
     */
    function sortByHash(
        uint256[] memory tokenIds
    ) internal pure returns (uint256[] memory sortedIds) {
        // Instantiate a new array of HashAndIntTuple structs.
        HashAndIntTuple[] memory toSort = new HashAndIntTuple[](
            tokenIds.length
        );

        // Populate the array of HashAndIntTuple structs.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            toSort[i] = HashAndIntTuple(
                tokenIds[i],
                keccak256(abi.encode(tokenIds[i]))
            );
        }

        // Sort the array of HashAndIntTuple structs.
        _quickSort(toSort, 0, int256(toSort.length - 1));

        // Populate the sortedIds array with the sorted token ids.
        sortedIds = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            sortedIds[i] = toSort[i].num;
        }
    }

    /**
     * @notice Convert an array of integer token ids to a sorted array of
     *         their hashed values.
     */
    function toSortedHashes(
        uint256[] memory tokenIds
    ) internal pure returns (bytes32[] memory hashes) {
        // Instantiate a new array of hashes.
        hashes = new bytes32[](tokenIds.length);

        // Sort the token ids by their hashes.
        uint256[] memory ids = sortByHash(tokenIds);

        // Hash each token id and store it in the hashes array.
        for (uint256 i; i < ids.length; ++i) {
            hashes[i] = keccak256(abi.encode(ids[i]));
        }
    }

    /**
     *  @dev This function performs the quick sort algorithm to sort an array of
     *       HashAndIntTuple structs.
     *
     *  @param arr   The array of HashAndIntTuple structs to be sorted.
     *  @param left  The starting index of the segment to be sorted.
     *  @param right The ending index of the segment to be sorted.
     */
    function _quickSort(
        HashAndIntTuple[] memory arr,
        int256 left,
        int256 right
    ) internal pure {
        // Initialize pointers i and j to the left and right ends of the array
        // segment.
        int256 i = left;
        int256 j = right;

        // If the segment has one element or none, it's already sorted.
        if (i == j) return;

        // Pick a 'pivot' element from the middle of the list.
        bytes32 pivot = arr[uint256(left + (right - left) / 2)].hash;

        // The main loop to rearrange elements around the pivot.
        while (i <= j) {
            // Find an element larger than or equal to the pivot from the left.
            while (arr[uint256(i)].hash < pivot) i++;

            // Find an element smaller than or equal to the pivot from the
            // right.
            while (pivot < arr[uint256(j)].hash) j--;

            // Swap the elements at i and j if needed.
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                i++;
                j--;
            }
        }

        // Recursively sort the segment before 'j'.
        if (left < j) _quickSort(arr, left, j);

        // Recursively sort the segment after 'i'.
        if (i < right) _quickSort(arr, i, right);
    }
}
