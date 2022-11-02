// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ConsiderationConstants.sol";
import "./SignatureVerification.sol";
import "hardhat/console.sol";

type Eip712MerkleProof is uint256;

// =====================================================================//
//                    EIP712 Type String Derivation                     //
// =====================================================================//

/**
 * EIP712 Type String Derivation
 * For use in
 */

function _getMerkleTypeString(
    string memory baseTypeName,
    string memory baseTypeString,
    uint256 levels
) pure returns (string memory newString) {
    string memory arraySuffixes;
    assembly {
        arraySuffixes := mload(0x40)
        let suffixLength := mul(levels, 3)

        let suffixStringLength := and(add(suffixLength, 63), 0xffe0)
        mstore(0x40, add(arraySuffixes, suffixStringLength))

        let writePtr := add(arraySuffixes, suffixLength)

        for {

        } gt(writePtr, arraySuffixes) {

        } {
            mstore(writePtr, 0x5b325d)
            writePtr := sub(writePtr, 3)
        }
        mstore(arraySuffixes, suffixLength)
    }
    return
        string(
            abi.encodePacked(
                "Tree(",
                baseTypeName,
                arraySuffixes,
                " tree)",
                baseTypeString
            )
        );
}

function _getMerkleTypeHash(
    string memory baseTypeName,
    string memory baseTypeString,
    uint256 levels
) pure returns (bytes32) {
    return
        keccak256(
            bytes(_getMerkleTypeString(baseTypeName, baseTypeString, levels))
        );
}

// =====================================================================//
//               Conversion between signature and proof                 //
// =====================================================================//

contract SevenLevelMerkleTree is SignatureVerification {
    string public merkleTypeString;
    bytes32 public immutable eip712MerkleTypeHash;
    bytes32 public immutable _domainSeparator;

    constructor(string memory baseTypeName, string memory baseTypeString) {
        merkleTypeString = _getMerkleTypeString(
            baseTypeName,
            baseTypeString,
            7
        );
        eip712MerkleTypeHash = keccak256(bytes(merkleTypeString));

        bytes32 eip712DomainTypehash = keccak256(
            abi.encodePacked(
                "EIP712Domain(",
                "string name,",
                "string version,",
                "uint256 chainId,",
                "address verifyingContract",
                ")"
            )
        );
        // prettier-ignore
        _domainSeparator = keccak256(
            abi.encode(
                eip712DomainTypehash,
                "Domain",
                "1",
                block.chainid,
                address(this)
            )
        );
    }

    function _deriveEIP712Digest(bytes32 domainSeparator, bytes32 orderHash)
        internal
        pure
        returns (bytes32 value)
    {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(EIP712_DomainSeparator_offset, domainSeparator)

            // Place the order hash in scratch space, spilling into the first
            // two bytes of the free memory pointer — this should never be set
            // as memory cannot be expanded to that size, and will be zeroed out
            // after the hash is performed.
            mstore(EIP712_OrderHash_offset, orderHash)

            // Hash the relevant region (65 bytes).
            value := keccak256(0, EIP712_DigestPayload_size)

            // reset the upper dirty bit of the free memory pointer.
            mstore(EIP712_OrderHash_offset, 0)
        }
    }

    // @todo Remove when a specific size is decided on
    function _signatureToSevenLevelProof(bytes calldata signature)
        internal
        pure
        returns (Eip712MerkleProof proofPtr)
    {
        assembly {
            proofPtr := signature.offset
            let signatureLength := signature.length
            let key := shr(248, calldataload(proofPtr))
            let invalidProof := iszero(
                and(
                    lt(key, 128),
                    // Get proof size:
                    // - 64 bytes for minimum signature length,
                    // - 1 byte for key
                    // - 32 bytes for each level of the tree
                    lt(sub(signatureLength, 0x121), 2)
                )
            )
            if invalidProof {
                revert(0, 0)
            }
        }
    }

    function _proofToSignature(Eip712MerkleProof proofPtr)
        internal
        pure
        returns (bytes memory signature)
    {
        assembly {
            signature := mload(0x40)
            let length := sub(calldataload(sub(proofPtr, 32)), 0xe1)
            let paddedLength := and(add(length, 63), 0xe0)
            mstore(signature, length)
            mstore(0x40, add(signature, paddedLength))
            let dataPtr := add(proofPtr, 0xe1)
            calldatacopy(add(signature, 32), dataPtr, length)
        }
    }

    function _computeMerkleProofDepth7(Eip712MerkleProof proofPtr, bytes32 leaf)
        internal
        pure
        returns (bytes32 root)
    {
        assembly {
            let key := shr(248, calldataload(proofPtr))
            let proof := add(proofPtr, 1)

            // Compute level 1
            let scratch := shl(5, and(key, 1))
            mstore(scratch, leaf)
            mstore(xor(scratch, OneWord), calldataload(proof))

            // Compute level 2
            scratch := shl(5, and(shr(1, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0x20)))

            // Compute level 3
            scratch := shl(5, and(shr(2, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0x40)))

            // Compute level 4
            scratch := shl(5, and(shr(3, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0x60)))

            // Compute level 5
            scratch := shl(5, and(shr(4, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0x80)))

            // Compute level 6
            scratch := shl(5, and(shr(5, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0xa0)))

            // Compute root hash
            scratch := shl(5, and(shr(6, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), calldataload(add(proof, 0xc0)))
            root := keccak256(0, TwoWords)
        }
    }

    function getEip712Digest(bytes calldata signature, bytes32 leafHash)
        external
        view
        returns (bytes32)
    {
        Eip712MerkleProof proofPtr = _signatureToSevenLevelProof(signature);
        bytes32 root = _computeMerkleProofDepth7(proofPtr, leafHash);
        bytes32 rootTypeHash = eip712MerkleTypeHash;
        assembly {
            mstore(0, rootTypeHash)
            mstore(0x20, root)
            root := keccak256(0, 0x40)
        }
        return _deriveEIP712Digest(_domainSeparator, root);
    }

    function verifyProof(bytes calldata signature, bytes32 leafHash)
        external
        view
    {
        Eip712MerkleProof proofPtr = _signatureToSevenLevelProof(signature);
        bytes32 root = _computeMerkleProofDepth7(proofPtr, leafHash);
        bytes32 rootTypeHash = eip712MerkleTypeHash;
        assembly {
            mstore(0, rootTypeHash)
            mstore(0x20, root)
            root := keccak256(0, 0x40)
        }
        bytes32 digest = _deriveEIP712Digest(_domainSeparator, root);
        _assertValidSignature(msg.sender, digest, _proofToSignature(proofPtr));
    }
}

// contract TestFixedMerkleTreeSizes {
//     /**
//      * @notice Compute a merkle root from an inclusion proof.
//      * @param proof The sibling nodes along the way.
//      * @param key The index of the leaf node inclusion is being proven for.
//      * @param leaf The leaf node inclusion is being proven for (already hashed).
//      * @return root The root hash of the tree
//      */
//     function _processMerkleProofDepth7_JankEdition(
//         uint256[7] calldata proof,
//         uint256 key,
//         uint256 leaf
//     ) internal pure returns (bytes32 root) {
//         assembly {
//             function computeNextLevel(nodeHash, siblingHash, nodeIsOdd)
//                 -> nextHash
//             {
//                 // Sort proof elements and place them in scratch space.
//                 // Slot of `computedHash` in scratch space.
//                 // If the condition is true: 0x20, otherwise: 0x00.
//                 let scratch := shl(5, nodeIsOdd)
//                 // Store elements to hash contiguously in scratch space. Scratch
//                 // space is 64 bytes (0x00 - 0x3f) & both elements are 32 bytes.
//                 mstore(scratch, nodeHash)
//                 mstore(xor(scratch, OneWord), siblingHash)
//                 nextHash := keccak256(0, TwoWords)
//             }
//             let computedHash := computeNextLevel(
//                 leaf,
//                 calldataload(proof),
//                 and(key, 1)
//             )
//             computedHash := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0x20)),
//                 and(shr(1, key), 1)
//             )
//             computedHash := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0x40)),
//                 and(shr(2, key), 1)
//             )
//             computedHash := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0x60)),
//                 and(shr(3, key), 1)
//             )
//             computedHash := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0x80)),
//                 and(shr(4, key), 1)
//             )
//             computedHash := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0xa0)),
//                 and(shr(5, key), 1)
//             )
//             root := computeNextLevel(
//                 computedHash,
//                 calldataload(add(proof, 0xc0)),
//                 and(shr(6, key), 1)
//             )
//         }
//     }

//     function _processMerkleProofDepth3(Eip712MerkleProof proofPtr, uint256 leaf)
//         internal
//         pure
//         returns (bytes32 root)
//     {
//         assembly {
//             let key := shr(248, proofPtr)
//             let proof := add(proofPtr, 1)

//             // Compute level 1
//             let scratch := shl(5, and(key, 1))
//             mstore(scratch, leaf)
//             mstore(xor(scratch, OneWord), calldataload(proof))

//             // Compute level 2
//             scratch := shl(5, and(shr(1, key), 1))
//             mstore(scratch, keccak256(0, TwoWords))
//             mstore(xor(scratch, OneWord), calldataload(add(proof, 0x20)))

//             // Compute root hash
//             scratch := shl(5, and(shr(2, key), 1))
//             mstore(scratch, keccak256(0, TwoWords))
//             mstore(xor(scratch, OneWord), calldataload(add(proof, 0x40)))
//             root := keccak256(0, TwoWords)
//         }
//     }

//     function processMerkleProofDepth7_JankEdition(
//         uint256[7] calldata proof,
//         uint256 key,
//         uint256 leaf
//     ) external pure returns (bytes32 root) {
//         return _processMerkleProofDepth7_JankEdition(proof, key, leaf);
//     }

//     function processMerkleProofDepth3(
//         uint256[3] calldata proof,
//         uint256 key,
//         uint256 leaf
//     ) external pure returns (bytes32 root) {
//         return _processMerkleProofDepth3(proof, key, leaf);
//     }
// }

// contract DynamicEip712MerkleProofs {
//     function computeMerkleProofDynamic(bytes calldata signature, uint256 leaf)
//         external
//         pure
//         returns (bytes32 root)
//     {
//         Eip712MerkleProof proofPtr = _signatureToDynamicMerkleProof(signature);
//         return _processMerkleProofDynamic(proofPtr, leaf);
//     }

//     // =====================================================================//
//     // Dynamic depth merkle trees - requires dynamic type hash selection    //
//     // =====================================================================//

//     function _signatureToDynamicMerkleProof(bytes calldata signature)
//         internal
//         pure
//         returns (Eip712MerkleProof proofPtr)
//     {
//         assembly {
//             let signaturePtr := signature.offset
//             let signatureLength := signature.length
//             let key := shr(248, calldataload(signaturePtr))
//             let height := shr(248, calldataload(add(signaturePtr, 1)))
//             let proofLength := mul(height, 0x20)
//             let invalidProof := iszero(
//                 and(
//                     and(lt(key, shl(height, 1)), gt(height, 1)),
//                     // Get proof size:
//                     // - 64 bytes for minimum signature length,
//                     // - 2 bytes for key and depth
//                     // - 32 bytes for each level of the tree
//                     lt(sub(signatureLength, add(0x42, proofLength)), 2)
//                 )
//             )
//             if invalidProof {
//                 revert(0, 0)
//             }
//             proofPtr := signaturePtr
//         }
//     }

//     function _processMerkleProofDynamic(
//         Eip712MerkleProof proofPtr,
//         uint256 leaf
//     ) internal pure returns (bytes32 root) {
//         assembly {
//             let key := shr(248, calldataload(proofPtr))
//             let height := shr(248, calldataload(add(proofPtr, 1)))
//             let proof := add(proofPtr, 2)

//             let scratch0 := shl(5, and(key, 1))
//             mstore(scratch0, leaf)
//             mstore(xor(scratch0, OneWord), calldataload(proof))

//             for {
//                 let i := 1
//             } lt(i, height) {
//                 i := add(i, 1)
//             } {
//                 proof := add(proof, 0x20)
//                 let scratch := shl(5, and(shr(i, key), 1))
//                 // Store elements to hash contiguously in scratch space. Scratch
//                 // space is 64 bytes (0x00 - 0x3f) & both elements are 32 bytes.
//                 mstore(scratch, keccak256(0, TwoWords))
//                 mstore(xor(scratch, OneWord), calldataload(proof))
//             }
//             root := keccak256(0, TwoWords)
//         }
//     }
// }
