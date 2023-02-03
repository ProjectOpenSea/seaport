// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  SignedZone
 * @author ryanio, BCLeFevre
 * @notice SignedZone is an implementation of SIP-7 that requires orders
 *         to be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 *
 */
interface SignedZoneInterface {
    /**
     * @notice Update the active status of a signer.
     *
     * @param signer The signer address to update.
     * @param active The new active status of the signer.
     */
    function updateSigner(address signer, bool active) external;

    /**
     * @notice Returns the active signers for the zone.
     *
     * @return signers The active signers.
     */
    function getActiveSigners()
        external
        view
        returns (address[] memory signers);
}
