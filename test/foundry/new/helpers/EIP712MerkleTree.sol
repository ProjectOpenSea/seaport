// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MurkyBase } from "murky/common/MurkyBase.sol";

import {
    TypehashDirectory
} from "../../../../contracts/test/TypehashDirectory.sol";

import { Test } from "forge-std/Test.sol";

import {
    ConsiderationInterface
} from "../../../../contracts/interfaces/ConsiderationInterface.sol";

import {
    OrderComponents
} from "../../../../contracts/lib/ConsiderationStructs.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @dev Seaport doesn't sort leaves when hashing for bulk orders, but Murky
 * does, so implement a custom hashLeafPairs function
 */
contract MerkleUnsorted is MurkyBase {
    function hashLeafPairs(
        bytes32 left,
        bytes32 right
    ) public pure override returns (bytes32 _hash) {
        assembly {
            mstore(0x0, left)
            mstore(0x20, right)
            _hash := keccak256(0x0, 0x40)
        }
    }
}

contract EIP712MerkleTree is Test {
    // data contract to retrieve bulk order typehashes
    TypehashDirectory internal immutable _typehashDirectory;
    OrderComponents private emptyOrderComponents;
    MerkleUnsorted private merkle;

    constructor() {
        _typehashDirectory = new TypehashDirectory();
        merkle = new MerkleUnsorted();
    }

    /**
     * @dev Creates a single bulk signature: a base signature + a three byte
     * index + a series of 32 byte proofs.  The height of the tree is determined
     * by the length of the orderComponents array and only fills empty orders
     * into the tree to make the length a power of 2.
     */
    function signBulkOrder(
        ConsiderationInterface consideration,
        uint256 privateKey,
        OrderComponents[] memory orderComponents,
        uint24 orderIndex,
        bool useCompact2098
    ) public view returns (bytes memory) {
        // cache the hash of an empty order components struct to fill out any
        // nodes required to make the length a power of 2
        bytes32 emptyComponentsHash = consideration.getOrderHash(
            emptyOrderComponents
        );
        // declare vars here to avoid stack too deep errors
        bytes32[] memory leaves;
        bytes32 bulkOrderTypehash;
        // block scope to avoid stacc 2 dank
        {
            // height of merkle tree is log2(length), rounded up to next power
            // of 2
            uint256 height = Math.log2(orderComponents.length);
            // Murky won't let you compute a merkle tree with only 1 leaf, so
            // if height is 0 (length is 1), set height to 1
            if (2 ** height != orderComponents.length || height == 0) {
                height += 1;
            }
            // get the typehash for a bulk order of this height
            bulkOrderTypehash = _lookupBulkOrderTypehash(height);
            // allocate array for leaf hashes
            leaves = new bytes32[](2 ** height);
            // hash each original order component
            for (uint256 i = 0; i < orderComponents.length; i++) {
                leaves[i] = consideration.getOrderHash(orderComponents[i]);
            }
            // fill out empty node hashes
            for (uint256 i = orderComponents.length; i < 2 ** height; i++) {
                leaves[i] = emptyComponentsHash;
            }
        }

        // get the proof for the order index
        bytes32[] memory proof = merkle.getProof(leaves, orderIndex);
        bytes32 root = merkle.getRoot(leaves);

        return
            _getSignature(
                consideration,
                privateKey,
                bulkOrderTypehash,
                root,
                proof,
                orderIndex,
                useCompact2098
            );
    }

    /**
     *  @dev Creates a single bulk signature: a base signature + a three byte
     * index + a series of 32 byte proofs.  The height of the tree is determined
     * by the height parameter and this function will fill empty orders into the
     * tree until the specified height is reached.
     */
    function signSparseBulkOrder(
        ConsiderationInterface consideration,
        uint256 privateKey,
        OrderComponents memory orderComponents,
        uint256 height,
        uint24 orderIndex,
        bool useCompact2098
    ) public view returns (bytes memory) {
        require(orderIndex < 2 ** height, "orderIndex out of bounds");
        // get hash of actual order
        bytes32 orderHash = consideration.getOrderHash(orderComponents);
        // get initial empty order components hash
        bytes32 emptyComponentsHash = consideration.getOrderHash(
            emptyOrderComponents
        );

        // calculate intermediate hashes of a sparse order tree
        // this will also serve as our proof
        bytes32[] memory emptyHashes = new bytes32[]((height));
        // first layer is empty order hash
        emptyHashes[0] = emptyComponentsHash;
        for (uint256 i = 1; i < height; i++) {
            bytes32 nextHash;
            bytes32 lastHash = emptyHashes[i - 1];
            // subsequent layers are hash of emptyHeight+emptyHeight
            assembly {
                mstore(0, lastHash)
                mstore(0x20, lastHash)
                nextHash := keccak256(0, 0x40)
            }
            emptyHashes[i] = nextHash;
        }
        // begin calculating order tree root
        bytes32 root = orderHash;
        // hashIndex is the index within the layer of the non-sparse hash
        uint24 hashIndex = orderIndex;

        for (uint256 i = 0; i < height; i++) {
            // get sparse hash at this height
            bytes32 heightEmptyHash = emptyHashes[i];
            assembly {
                // if the hashIndex is odd, our "root" is second component
                if and(hashIndex, 1) {
                    mstore(0, heightEmptyHash)
                    mstore(0x20, root)
                }
                // else it is even and our "root" is first component
                // (this can def be done in a branchless way but who has the
                // time??)
                if iszero(and(hashIndex, 1)) {
                    mstore(0, root)
                    mstore(0x20, heightEmptyHash)
                }
                // compute new intermediate hash (or final root)
                root := keccak256(0, 0x40)
            }
            // divide hashIndex by 2 to get index of next layer
            // 0 -> 0
            // 1 -> 0
            // 2 -> 1
            // 3 -> 1
            // etc
            hashIndex /= 2;
        }

        return
            _getSignature(
                consideration,
                privateKey,
                _lookupBulkOrderTypehash(height),
                root,
                emptyHashes,
                orderIndex,
                useCompact2098
            );
    }

    /**
     * @dev same lookup seaport optimized does
     */
    function _lookupBulkOrderTypehash(
        uint256 treeHeight
    ) internal view returns (bytes32 typeHash) {
        TypehashDirectory directory = _typehashDirectory;
        assembly {
            let typeHashOffset := add(1, shl(0x5, sub(treeHeight, 1)))
            extcodecopy(directory, 0, typeHashOffset, 0x20)
            typeHash := mload(0)
        }
    }

    function _getSignature(
        ConsiderationInterface consideration,
        uint256 privateKey,
        bytes32 bulkOrderTypehash,
        bytes32 root,
        bytes32[] memory proof,
        uint24 orderIndex,
        bool useCompact2098
    ) internal view returns (bytes memory) {
        // bulkOrder hash is keccak256 of the specific bulk order typehash and
        // the merkle root of the order hashes
        bytes32 bulkOrderHash = keccak256(abi.encode(bulkOrderTypehash, root));

        // get domain separator from the particular seaport instance
        (, bytes32 domainSeparator, ) = consideration.information();

        // declare out here to avoid stack too deep errors
        bytes memory signature;
        // avoid stacc 2 thicc
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                privateKey,
                keccak256(
                    abi.encodePacked(
                        bytes2(0x1901),
                        domainSeparator,
                        bulkOrderHash
                    )
                )
            );
            // if useCompact2098 is true, encode yParity (v) into s
            if (useCompact2098) {
                uint256 yParity = (v == 27) ? 0 : 1;
                bytes32 yAndS = bytes32(uint256(s) | (yParity << 255));
                signature = abi.encodePacked(r, yAndS);
            } else {
                signature = abi.encodePacked(r, s, v);
            }
        }

        // return the packed signature, order index, and proof
        // encodePacked will pack everything tightly without lengths
        // ie, long-style rsv signatures will have 1 byte for v
        // orderIndex will be the next 3 bytes
        // then proof will be each element one after another; its offset and
        // length will not be encoded
        return abi.encodePacked(signature, orderIndex, proof);
    }
}
