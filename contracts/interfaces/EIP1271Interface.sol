// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title EIP1271Interface
 * @notice Interface for the EIP-1271 standard signature validation method for
 *         contracts.
 */
interface EIP1271Interface {
    /**
     * @dev Validates a smart contract signature
     *
     * @param digest    bytes32 The digest of the data to be signed.
     * @param signature bytes The signature of the data to be validated.
     *
     * @return bytes4 The magic value, if the signature is valid.
     */
    function isValidSignature(
        bytes32 digest,
        bytes calldata signature
    ) external view returns (bytes4);
}
