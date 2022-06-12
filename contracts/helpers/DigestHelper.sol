// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

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
    uint256 constant EIP712_DomainSeparator_offset = 0x02;
    uint256 constant EIP712_OrderHash_offset = 0x22;
    uint256 constant EIP_712_PREFIX = (
        0x1901000000000000000000000000000000000000000000000000000000000000
    );
    uint256 constant EIP712_DigestPayload_size = 0x42;
    // Derived typehash constants 
    bytes32 constant EIP_712_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    bytes32 constant NAME_HASH = 0x32b5c112df393a49218d7552f96b2eeb829dfb4272f4f24eef510a586b85feef;
    bytes32 constant VERSION_HASH = 0x722c0e0c80487266e8c6a45e3a1a803aab23378a9c32e6ebe029d4fad7bfc965;
 
    /**
     * @dev Derive the digest from the domain separator for current chain with given marketplace address
     *
     * @param marketplaceAddress Address for the seaport marketplace
     *
     */

    constructor(address marketplaceAddress) {
        // Store the current chainId and derive the current domain separator.
        _CHAIN_ID = block.chainid;
        _MARKETPLACE_ADDRESS = marketplaceAddress;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
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
                EIP_712_DOMAIN_TYPEHASH,
                NAME_HASH,
                VERSION_HASH,
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
    function deriveEIP712Digest(bytes32 orderHash)
        internal
        view
        returns (bytes32 value)
    {
        // Leverage scratch space to perform an efficient hash.
        bytes32 domainSeparator = _domainSeparator();
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

            // Clear out the dirtied bits in the memory pointer.
            mstore(EIP712_OrderHash_offset, 0)
        }
    }
}
