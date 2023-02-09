// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  SignedZoneCaptainInterface
 * @author BCLeFevre
 * @notice SignedZoneCaptainInterface contains function declarations for the
 *         SignedZoneCaptain contract.
 */
interface SignedZoneCaptainInterface {
    /**
     * @notice Update the signer for a given signed zone.
     *
     * @param zone       The signed zone to update the signer for.
     * @param signer     The signer to update.
     * @param active     If the signer should be active or not.
     */
    function updateZoneSigner(
        address zone,
        address signer,
        bool active
    ) external;

    /**
     * @notice Update the API endpoint returned by the supplied zone.
     *         Only the owner can call this function.
     *
     * @param zone           The signed zone to update the API endpoint for.
     * @param newApiEndpoint The new API endpoint.
     */
    function updateZoneAPIEndpoint(address zone, string calldata newApiEndpoint)
        external;

    /**
     * @notice Update the documentationURI returned by a zone. Only the owner
     *         of the supplied zone can call this function.
     *
     * @param zone                The signed zone to update the API endpoint
     *                            for.
     * @param newDocumentationURI The new documentation URI.
     */
    function updateZoneDocumentationURI(
        address zone,
        string calldata newDocumentationURI
    ) external;

    /**
     * @notice Initiate zone ownership transfer by assigning a new potential
     *         owner for the given zone. Only callable by the owner.
     *
     * @param zone              The zone for which to initiate ownership
     *                          transfer.
     * @param newPotentialOwner The new potential owner to set.
     */
    function transferZoneOwnership(address zone, address newPotentialOwner)
        external;

    /**
     * @notice Clear the currently set potential owner, if any, from a zone.
     *         Only callable by the owner.
     *
     * @param zone The zone for which to cancel ownership transfer.
     */
    function cancelZoneOwnershipTransfer(address zone) external;

    /**
     * @notice Accept ownership of a given zone once the address has been set
     *         as the current potential owner. Only callable by the owner.
     *
     * @param zone The zone for which to accept ownership transfer.
     */
    function acceptZoneOwnership(address zone) external;

    /**
     * @notice Rotate the signers for a given zone. Only callable by the owner
     *         or the rotator of the zone.
     *
     * @param zone              The zone to rotate the signers for.
     * @param signerToRemove    The signer to remove.
     * @param signerToAdd       The signer to add.
     */
    function rotateSigners(
        address zone,
        address signerToRemove,
        address signerToAdd
    ) external;

    /**
     * @notice Pause a zone, this will remove all active signers and clear the
     *         rotator address on the captain. Only callable by the owner or
     *         the pauser of the zone.
     *
     * @param zone The zone to pause.
     */
    function pauseSignedZone(address zone) external;

    /**
     * @notice Update the rotator role on the captain.
     *
     * @param newRotator The new rotator of the captain.
     */
    function updateRotator(address newRotator) external;

    /**
     * @notice Update the pauser role on the captain.
     *
     * @param newPauser The new pauser of the captain.
     */
    function updatePauser(address newPauser) external;

    /**
     * @notice Get the rotator address.
     *
     * @return The rotator address.
     */
    function getRotator() external view returns (address);

    /**
     * @notice Get the pauser address.
     *
     * @return The pauser address.
     */
    function getPauser() external view returns (address);
}
