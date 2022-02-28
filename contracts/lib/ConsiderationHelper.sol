// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

/* @title ConsiderationHelper
 * @author 0age
 * @notice ConsiderationHelper contains logic to derive an EIP-712 domain
 *         separator. It is only run on deployment or after a chain split. */
contract ConsiderationHelper {

    // Precompute hashes on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    address internal immutable _VERIFYING_CONTRACT;

    /* @notice Derive and set hashes during deployment. Note that the verifying
     *         contract must deploy this contract.
     *
     * @param name    The name of the verifying contract.
     * @param version The version of the verifying contract. */
    constructor() {
        // Derive hashes and set immutable variables.
        _NAME_HASH = keccak256("Consideration");
        _VERSION_HASH = keccak256("1");
        _EIP_712_DOMAIN_TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _VERIFYING_CONTRACT = msg.sender;
    }

    /* @notice Derive the EIP-712 domain separator for the helped contract.
     *
     * @return The derived domain separator for the helped contract. */
    function deriveDomainSeparator() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                _VERIFYING_CONTRACT
            )
        );
    }
}