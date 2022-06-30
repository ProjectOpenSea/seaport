// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;
import { ConsiderationInterface } from "contracts/interfaces/ConsiderationInterface.sol";

/**
 * @title DigestHelper
 * @author iamameme
 * @notice DigestHelper contains an internal pure view function
 *         related to deriving a digest.
 */
contract ReferenceDigestHelper {
    // Immutables
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    address internal immutable _MARKETPLACE_ADDRESS;
    // Derived typehash constants
    bytes32 constant _EIP_712_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // Name should be 'Seaport', but for reference it's 'Consideration'
    bytes32 constant _NAME_HASH =
        0x64987f6373075400d7cbff689f2b7bc23753c7e6ce20688196489b8f5d9d7e6c;
    // Version is normally '1.1', but in reference it's '1.1-reference'
    bytes32 constant _VERSION_HASH =
        0xb6759aa1fb159fcc9380ddea57bb2003d7f8dfca6c4641b175f1a2cc262affa9;
    error BadDomainSeparator();

    /**
     * @dev Derive the digest from the domain separator for current chain with given marketplace address
     *
     * @param marketplaceAddress Address for the seaport marketplace
     *
     */

    constructor(address marketplaceAddress) {
        // Store the current chainId and derive the current domain separator.
        bytes32 derivedDomainSeparator = keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                marketplaceAddress
            )
        );
        _CHAIN_ID = block.chainid;
        _MARKETPLACE_ADDRESS = marketplaceAddress;
        _DOMAIN_SEPARATOR = derivedDomainSeparator;

        // Get the marketplace domainSeparator and verify that ours
        ConsiderationInterface marketplace = ConsiderationInterface(
            marketplaceAddress
        );
        (, bytes32 domainSeparator, ) = marketplace.information();
        if (domainSeparator != derivedDomainSeparator) {
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
        value = keccak256(
            abi.encodePacked(uint16(0x1901), _domainSeparator(), orderHash)
        );
    }
}
