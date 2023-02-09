// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @notice SignedZoneCaptainEventsAndErrors contains errors and events
 *         related to owning signed zones.
 */
interface SignedZoneCaptainEventsAndErrors {
    /**
     * @dev Emit an event when the contract owner updates the rotator.
     *
     * @param newRotator The new rotator of the contract.
     */
    event RotatorUpdated(address newRotator);

    /**
     * @dev Emit an event when the contract owner updates the pauser.
     *
     * @param newPauser The new pauser of the contract.
     */
    event PauserUpdated(address newPauser);

    /**
     * @dev Emit an event when the pauser pauses a zone.
     *
     * @param zone The zone address being paused.
     */
    event ZonePaused(address zone);

    /**
     * @dev Revert with an error when attempting to set a zone controller
     *      that does not contain contract code.
     *
     * @param signedZoneController The invalid address.
     */
    error InvalidSignedZoneController(address signedZoneController);

    /**
     * @dev Revert with an error when attempting to set the rotator
     *      to the null address.
     */
    error RotatorCannotBeNullAddress();

    /**
     * @dev Revert with an error when attempting to set the pauser
     *      to the null address.
     */
    error PauserCannotBeNullAddress();

    /**
     * @dev Revert with an error when attempting to call a function that
     *      requires the caller to be the owner or pauser of the zone.
     */
    error CallerIsNotOwnerOrPauser();

    /**
     * @dev Revert with an error when attempting to call a function that
     *      requires the caller to be the owner or rotator of the zone.
     */
    error CallerIsNotOwnerOrRotator();
}
