// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  SignedZone
 * @author ryanio
 * @notice SignedZone is a zone implementation that requires orders
 *         to be signed by an approved signer.
 */
interface SignedZoneInterface {
    /**
     * @notice Add a new signer.
     *
     * @param signer The new signer address to add.
     */
    function addSigner(address signer) external;

    /**
     * @notice Remove an active signer.
     *
     * @param signer The signer address to remove.
     */
    function removeSigner(address signer) external;

    /**
     * @notice Returns information about the zone.
     *
     * @return domainSeparator The domain separator used for signing.
     */
    function information() external view returns (bytes32 domainSeparator);
}
