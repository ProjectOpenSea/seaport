// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// prettier-ignore
import { 
    ConsiderationInterface 
} from "../interfaces/ConsiderationInterface.sol";

/**
 * @title DigestHelper
 * @author iamameme
 * @notice DigestHelper contains an internal pure view function
 *         related to deriving a digest.
 */
contract DigestHelper {
    // Immutables
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    address internal immutable _MARKETPLACE_ADDRESS;
    // Cached constants from ConsiderationConstants
    uint256 internal constant _EIP712_DOMAINSEPARATOR_OFFSET = 0x02;
    uint256 internal constant _EIP712_ORDERHASH_OFFSET = 0x22;
    uint256 internal constant _EIP_712_PREFIX = (
        0x1901000000000000000000000000000000000000000000000000000000000000
    );
    uint256 internal constant _EIP712_DIGESTPAYLOAD_SIZE = 0x42;
    // Derived typehash constants
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    bytes32 internal constant _NAME_HASH =
        0x32b5c112df393a49218d7552f96b2eeb829dfb4272f4f24eef510a586b85feef;
    bytes32 internal constant _VERSION_HASH =
        0x722c0e0c80487266e8c6a45e3a1a803aab23378a9c32e6ebe029d4fad7bfc965;
    error BadDomainSeparator();

    /**
     * @dev Derive the digest from the domain separator for
     *      current chain with given marketplace address
     *
     * @param marketplaceAddress Address for the seaport marketplace
     *
     */
    constructor(address marketplaceAddress) {
        // Store the current chainId and derive the current domain separator.
        _CHAIN_ID = block.chainid;
        _MARKETPLACE_ADDRESS = marketplaceAddress;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // Get the marketplace domainSeparator and verify that ours matches
        ConsiderationInterface marketplace = ConsiderationInterface(
            marketplaceAddress
        );
        (, bytes32 domainSeparator, ) = marketplace.information();
        if (domainSeparator != _DOMAIN_SEPARATOR) {
            revert BadDomainSeparator();
        }
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                _MARKETPLACE_ADDRESS
            )
        );
    }

    /**
     * @dev Internal view function to efficiently derive an digest to sign for
     *      an order in accordance with EIP-712.
     *
     * @param orderHash       The order hash.
     *
     * @return value The hash.
     */
    function _deriveEIP712Digest(bytes32 orderHash)
        internal
        view
        returns (bytes32 value)
    {
        // Leverage scratch space to perform an efficient hash.
        bytes32 domainSeparator = _domainSeparator();
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, _EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(_EIP712_DOMAINSEPARATOR_OFFSET, domainSeparator)

            // Place the order hash in scratch space, spilling into the first
            // two bytes of the free memory pointer — this should never be set
            // as memory cannot be expanded to that size, and will be zeroed out
            // after the hash is performed.
            mstore(_EIP712_ORDERHASH_OFFSET, orderHash)

            // Hash the relevant region (65 bytes).
            value := keccak256(0, _EIP712_DIGESTPAYLOAD_SIZE)

            // Clear out the dirtied bits in the memory pointer.
            mstore(_EIP712_ORDERHASH_OFFSET, 0)
        }
    }
}
