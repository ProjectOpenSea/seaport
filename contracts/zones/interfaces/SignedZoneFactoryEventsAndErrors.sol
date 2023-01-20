// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @notice SignedZoneFactoryEventsAndErrors contains errors and events
 *         related to deploying of a SignedZone (SIP-7).
 */
interface SignedZoneFactoryEventsAndErrors {
    /**
     * @dev Emit an event whenever a new zone is created.
     *
     * @param zoneAddress The address of the zone.
     * @param zoneName    The name for the zone returned in
     *                    getSeaportMetadata().
     * @param apiEndpoint The API endpoint where orders for this zone can be
     *                    signed.
     *                    Request and response payloads are defined in SIP-7.
     * @param salt        The salt used to deploy the zone.
     */
    event ZoneCreated(
        address zoneAddress,
        string zoneName,
        string apiEndpoint,
        bytes32 salt
    );

    /**
     * @dev Revert with an error when attempting to create a new signed zone
     *      using a salt where the first twenty bytes do not match the address
     *      of the caller or are not set to zero.
     */
    error InvalidCreator();

    /**
     * @dev Revert with an error when attempting to deploy a zone that is
     *      currently deployed.
     */
    error ZoneAlreadyExists(address zone);
}
