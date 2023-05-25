// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MerkleLib } from "./MerkleLib.sol";

struct HashAndIntTuple {
    uint256 num;
    bytes32 hash;
}

library CriteriaHelperLib {
    function criteriaRoot(
        uint256[] memory tokenIds
    ) internal pure returns (bytes32) {
        return
            MerkleLib.getRoot(toSortedHashes(tokenIds), MerkleLib.merkleHash);
    }

    function criteriaProof(
        uint256[] memory tokenIds,
        uint256 index
    ) internal pure returns (bytes32[] memory) {
        return
            MerkleLib.getProof(
                toSortedHashes(tokenIds),
                index,
                MerkleLib.merkleHash
            );
    }

    function sortByHash(
        uint256[] memory tokenIds
    ) internal pure returns (uint256[] memory sortedIds) {
        HashAndIntTuple[] memory toSort = new HashAndIntTuple[](
            tokenIds.length
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            toSort[i] = HashAndIntTuple(
                tokenIds[i],
                keccak256(abi.encode(tokenIds[i]))
            );
        }

        _quickSort(toSort, 0, int256(toSort.length - 1));

        sortedIds = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            sortedIds[i] = toSort[i].num;
        }
    }

    function toSortedHashes(
        uint256[] memory tokenIds
    ) internal pure returns (bytes32[] memory hashes) {
        hashes = new bytes32[](tokenIds.length);
        uint256[] memory ids = sortByHash(tokenIds);
        for (uint256 i; i < ids.length; ++i) {
            hashes[i] = keccak256(abi.encode(ids[i]));
        }
    }

    function _quickSort(
        HashAndIntTuple[] memory arr,
        int256 left,
        int256 right
    ) internal pure {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        bytes32 pivot = arr[uint256(left + (right - left) / 2)].hash;
        while (i <= j) {
            while (arr[uint256(i)].hash < pivot) i++;
            while (pivot < arr[uint256(j)].hash) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (left < j) _quickSort(arr, left, j);
        if (i < right) _quickSort(arr, i, right);
    }
}
