// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract EIP1271Offerer {
    error InvalidSignature(bytes32 digest, bytes signature);
    bytes4 private constant _EIP_1271_MAGIC_VALUE = 0x1626ba7e;

    mapping(bytes32 => bytes32) public digestToSignatureHash;

    function registerSignature(bytes32 digest, bytes memory signature) public {
        digestToSignatureHash[digest] = keccak256(signature);
    }

    function isValidSignature(
        bytes32 digest,
        bytes memory signature
    ) external view returns (bytes4) {
        bytes32 signatureHash = keccak256(signature);
        if (digestToSignatureHash[digest] == signatureHash) {
            return _EIP_1271_MAGIC_VALUE;
        }
        revert InvalidSignature(digest, signature);
    }
}
