// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
     * @dev Emit an event when the contract owner updates the sanitizer.
     *
     * @param newSanitizer The new sanitizer of the contract.
     */
    event SanitizerUpdated(address newSanitizer);

    /**
     * @dev Emit an event when the sanitizer sanitizes a zone.
     *
     * @param zone The zone address being sanitized.
     */
    event ZoneSanitized(address zone);

    /**
     * @dev Revert with an error when attempting to deploy the contract with an
     *      invalid deployer.
     */
    error InvalidDeployer();

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
     * @dev Revert with an error when attempting to set the sanitizer
     *      to the null address.
     */
    error SanitizerCannotBeNullAddress();

    /**
     * @dev Revert with an error when attempting to call a function that
     *      requires the caller to be the owner or sanitizer of the zone.
     */
    error CallerIsNotOwnerOrSanitizer();

    /**
     * @dev Revert with an error when attempting to call a function that
     *      requires the caller to be the owner or rotator of the zone.
     */
    error CallerIsNotOwnerOrRotator();
}
