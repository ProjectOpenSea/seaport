// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  SignedZoneControllerInterface
 * @author BCLeFevre
 * @notice SignedZoneControllerInterface enables the deploying of SignedZones.
 *         SignedZones are an implementation of SIP-7 that requires orders
 *         to be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 *
 */
interface SignedZoneControllerInterface {
    /**
     * @notice Deploy a SignedZone to a precomputed address.
     *
     * @param zoneName          The name for the zone returned in
     *                          getSeaportMetadata().
     * @param apiEndpoint       The API endpoint where orders for this zone can
     *                          be signed.
     * @param documentationURI  The URI to the documentation describing the
     *                          behavior of the contract. Request and response
     *                          payloads are defined in SIP-7.
     * @param salt              The salt to be used to derive the zone address
     * @param initialOwner      The initial owner to set for the new zone.
     *
     * @return signedZone The derived address for the zone.
     */
    function createZone(
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI,
        address initialOwner,
        bytes32 salt
    ) external returns (address signedZone);

    /**
     * @notice Returns the active signers for the zone.
     *
     * @param signedZone The signed zone to get the active signers for.
     *
     * @return signers The active signers.
     */
    function getActiveSigners(address signedZone)
        external
        view
        returns (address[] memory signers);

    /**
     * @notice Returns additional information about the zone.
     *
     * @param zone The zone to get the additional information for.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return zoneName         The name of the zone.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function getAdditionalZoneInformation(address zone)
        external
        view
        returns (
            bytes32 domainSeparator,
            string memory zoneName,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        );

    /**
     * @notice Update the API endpoint returned by the supplied zone.
     *         Only the owner or an active signer can call this function.
     *
     * @param signedZone     The signed zone to update the API endpoint for.
     * @param newApiEndpoint The new API endpoint.
     */
    function updateAPIEndpoint(
        address signedZone,
        string calldata newApiEndpoint
    ) external;

    /**
     * @notice Update the documentationURI returned by a zone.
     *         Only the owner or an active signer of the supplied zone can call
     *         this function.
     *
     * @param zone             The signed zone to update the API endpoint for.
     * @param documentationURI The new documentation URI.
     */
    function updateDocumentationURI(
        address zone,
        string calldata documentationURI
    ) external;

    /**
     * @notice Update the signer for a given signed zone.
     *
     * @param signedZone The signed zone to update the signer for.
     * @param signer     The signer to update.
     * @param active     If the signer should be active or not.
     */
    function updateSigner(
        address signedZone,
        address signer,
        bool active
    ) external;

    /**
     * @notice Initiate zone ownership transfer by assigning a new potential
     *         owner for the given zone. Once set, the new potential owner
     *         may call `acceptOwnership` to claim ownership of the zone.
     *         Only the owner of the zone in question may call this function.
     *
     * @param zone              The zone for which to initiate ownership
     *                          transfer.
     * @param newPotentialOwner The new potential owner of the zone.
     */
    function transferOwnership(address zone, address newPotentialOwner)
        external;

    /**
     * @notice Clear the currently set potential owner, if any, from a zone.
     *         Only the owner of the zone in question may call this function.
     *
     * @param zone The zone for which to cancel ownership transfer.
     */
    function cancelOwnershipTransfer(address zone) external;

    /**
     * @notice Accept ownership of a supplied zone. Only accounts that the
     *         current owner has set as the new potential owner may call this
     *         function.
     *
     * @param zone The zone for which to accept ownership.
     */
    function acceptOwnership(address zone) external;

    /**
     * @notice Retrieve the current owner of a deployed zone.
     *
     * @param zone The zone for which to retrieve the associated owner.
     *
     * @return owner The owner of the supplied zone.
     */
    function ownerOf(address zone) external view returns (address owner);

    /**
     * @notice Retrieve the potential owner, if any, for a given zone. The
     *         current owner may set a new potential owner via
     *         `transferOwnership` and that owner may then accept ownership of
     *         the zone in question via `acceptOwnership`.
     *
     * @param zone The zone for which to retrieve the potential owner.
     *
     * @return potentialOwner The potential owner, if any, for the zone.
     */
    function getPotentialOwner(address zone)
        external
        view
        returns (address potentialOwner);

    /**
     * @notice Derive the zone address associated with a salt.
     *
     * @param salt The salt to be used to derive the zone address
     *
     * @return derivedAddress The derived address of the signed zone.
     */
    function getZone(bytes32 salt)
        external
        view
        returns (address derivedAddress);

    /**
     * @notice Returns whether or not the supplied address is an active signer
     *         for the supplied zone.
     *
     * @param zone   The zone to check if the supplied address is an active
     *               signer for.
     * @param signer The address to check if it is an active signer for
     *
     * @return active If the supplied address is an active signer for the
     *                supplied zone.
     */
    function isActiveSigner(address zone, address signer)
        external
        view
        returns (bool);
}
