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
     * @dev The struct for storing signer info.
     */
    struct SignerInfo {
        bool active; /// If the signer is currently active.
        bool previouslyActive; /// If the signer has been active before.
    }

    /**
     * @notice Add a new signer to the zone.
     *
     * @param signer The new signer address to add.
     */
    function addSigner(address signer) external;

    /**
     * @notice Remove an active signer from the zone.
     *
     * @param signer The signer address to remove.
     */
    function removeSigner(address signer) external;

    /**
     * @notice Update the API endpoint returned by this zone.
     *
     * @param newApiEndpoint The new API endpoint.
     */
    function updateAPIEndpoint(string calldata newApiEndpoint) external;

    /**
     * @notice Returns the active signers for the zone.
     *
     * @return signers The active signers.
     */
    function getActiveSigners()
        external
        view
        returns (address[] memory signers);

    /**
     * @notice Returns signing information about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function sip7Information()
        external
        view
        returns (
            bytes32 domainSeparator,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        );
}
