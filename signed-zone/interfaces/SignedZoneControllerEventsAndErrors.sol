// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @notice SignedZoneControllerEventsAndErrors contains errors and events
 *         related to deploying and managing new signed zones.
 */
interface SignedZoneControllerEventsAndErrors {
    /**
     * @dev Emit an event whenever a new zone is created.
     *
     * @param zoneAddress       The address of the zone.
     * @param zoneName          The name for the zone returned in
     *                          getSeaportMetadata().
     * @param apiEndpoint       The API endpoint where orders for this zone can
     *                          be signed.
     * @param documentationURI  The URI to the documentation describing the
     *                          behavior of the contract.
     *                          Request and response payloads are defined in
     *                          SIP-7.
     * @param salt              The salt used to deploy the zone.
     */
    event ZoneCreated(
        address zoneAddress,
        string zoneName,
        string apiEndpoint,
        string documentationURI,
        bytes32 salt
    );

    /**
     * @dev Emit an event whenever zone ownership is transferred.
     *
     * @param zone          The zone for which ownership has been
     *                      transferred.
     * @param previousOwner The previous owner of the zone.
     * @param newOwner      The new owner of the zone.
     */
    event OwnershipTransferred(
        address indexed zone,
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Emit an event whenever a zone owner registers a new potential
     *      owner for that zone.
     *
     * @param newPotentialOwner The new potential owner of the zone.
     */
    event PotentialOwnerUpdated(address indexed newPotentialOwner);

    /**
     * @dev Emit an event when a signer has been updated.
     */
    event SignerUpdated(address signedZone, address signer, bool active);

    /**
     * @dev Revert with an error when attempting to update zone information or
     *      transfer ownership of a zone when the caller is not the owner of
     *      the zone in question.
     */
    error CallerIsNotOwner(address zone);

    /**
     * @dev Revert with an error when attempting to claim ownership of a zone
     *      with a caller that is not the current potential owner for the
     *      zone in question.
     */
    error CallerIsNotNewPotentialOwner(address zone);

    /**
     * @dev Revert with an error when attempting to create a new signed zone
     *      using a salt where the first twenty bytes do not match the address
     *      of the caller or are not set to zero.
     */
    error InvalidCreator();

    /**
     * @dev Revert with an error when attempting to create a new zone when no
     *      initial owner address is supplied.
     */
    error InvalidInitialOwner();

    /**
     * @dev Revert with an error when attempting to set a new potential owner
     *      that is already set.
     */
    error NewPotentialOwnerAlreadySet(address zone, address newPotentialOwner);

    /**
     * @dev Revert with an error when attempting to cancel ownership transfer
     *      when no new potential owner is currently set.
     */
    error NoPotentialOwnerCurrentlySet(address zone);
    /**
     * @dev Revert with an error when attempting to register a new potential
     *      owner and supplying the null address.
     */
    error NewPotentialOwnerIsNullAddress(address zone);

    /**
     * @dev Revert with an error when attempting to interact with a zone that
     *      does not yet exist.
     */
    error NoZone();

    /**
     * @dev Revert with an error if trying to add a signer that is
     *      already active.
     */
    error SignerAlreadyAdded(address signer);

    /**
     * @dev Revert with an error if a new signer is the null address.
     */
    error SignerCannotBeNullAddress();

    /**
     * @dev Revert with an error if a removed signer is trying to be
     *      reauthorized.
     */
    error SignerCannotBeReauthorized(address signer);

    /**
     * @dev Revert with an error if trying to remove a signer that is
     *      not present.
     */
    error SignerNotPresent(address signer);

    /**
     * @dev Revert with an error when attempting to deploy a zone that is
     *      currently deployed.
     */
    error ZoneAlreadyExists(address zone);
}
