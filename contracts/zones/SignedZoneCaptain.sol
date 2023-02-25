// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    SignedZoneCaptainInterface
} from "./interfaces/SignedZoneCaptainInterface.sol";

import {
    SignedZoneControllerInterface
} from "./interfaces/SignedZoneControllerInterface.sol";

import {
    SignedZoneCaptainEventsAndErrors
} from "./interfaces/SignedZoneCaptainEventsAndErrors.sol";

import { TwoStepOwnable } from "../ownable/TwoStepOwnable.sol";

/**
 * @title SignedZoneCaptain
 * @author BCLeFevre
 * @notice SignedZoneCaptain is a contract that owns signed zones and manages
 *         their active signers via two roles. The rotator role can update
 *         the active signers of a zone. The sanitizer role can remove all
 *         active signers of a zone controlled by the captain and clear the
 *         rotator role on the captain.
 */
contract SignedZoneCaptain is
    TwoStepOwnable,
    SignedZoneCaptainInterface,
    SignedZoneCaptainEventsAndErrors
{
    // The address of the signed zone controller. The signed zone controller
    // manages signed zones.
    SignedZoneControllerInterface private immutable _SIGNED_ZONE_CONTROLLER;

    // The address of the rotator. The rotator can manage the active signers of
    // a zone controlled by this contract.
    address private _rotator;

    // The address of the sanitizer. The sanitizer can remove all active
    // signers of a zone controlled by the captain and clear the rotator role
    // on the captain.
    address private _sanitizer;

    /**
     * @dev Initialize contract by setting the signed zone controller.
     *
     * @param signedZoneController The address of the signed zone controller.
     */
    constructor(address signedZoneController) {
        // Ensure that the contract is being deployed by an approved deployer.
        _assertValidDeployer();

        // Ensure that a contract is deployed to the given signed zone controller.
        if (signedZoneController.code.length == 0) {
            revert InvalidSignedZoneController(signedZoneController);
        }

        // Set the signed zone controller.
        _SIGNED_ZONE_CONTROLLER = SignedZoneControllerInterface(
            signedZoneController
        );
    }

    /**
     * @notice External initialization called by the deployer to set the owner,
     *         rotator and sanitizer, and create a signed zone with the given
     *         name, API endpoint, documentation URI. This function can only be
     *         called once, as there is a check to ensure that the current
     *         owner is address(0) before the initialization is performed, the
     *         owner must then be set to a non address(0) address during
     *         initialization and finally the owner cannot be set to address(0)
     *         after initialization.
     *
     * @param initialOwner     The address to be set as the owner.
     * @param initialRotator   The address to be set as the rotator.
     * @param initialSanitizer The address to be set as the sanitizer.
     * @param zoneName         The name of the zone being created.
     * @param apiEndpoint      The API endpoint of the zone being created.
     * @param documentationURI The documentation URI of the zone being created.
     * @param zoneSalt         The salt to use when creating the zone.
     */
    function initialize(
        address initialOwner,
        address initialRotator,
        address initialSanitizer,
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI,
        bytes32 zoneSalt
    ) external override {
        // Ensure the origin is an approved deployer.
        _assertValidDeployer();

        // Call initialize.
        _initialize(
            initialOwner,
            initialRotator,
            initialSanitizer,
            zoneName,
            apiEndpoint,
            documentationURI,
            zoneSalt
        );
    }

    /**
     * @notice Internal initialization function to set the owner, rotator, and
     *         sanitizer and create a new zone with the given name, API
     *         endpoint, documentation URI and the captain as the zone owner.
     *
     * @param initialOwner     The address to be set as the owner.
     * @param initialRotator   The address to be set as the rotator.
     * @param initialSanitizer The address to be set as the sanitizer.
     * @param zoneName         The name of the zone being created.
     * @param apiEndpoint      The API endpoint of the zone being created.
     * @param documentationURI The documentation URI of the zone being created.
     * @param zoneSalt         The salt to use when creating the zone.
     */
    function _initialize(
        address initialOwner,
        address initialRotator,
        address initialSanitizer,
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI,
        bytes32 zoneSalt
    ) internal {
        // Set the owner of the captain.
        _setInitialOwner(initialOwner);

        // Set the rotator.
        _setRotator(initialRotator);

        // Set the sanitizer.
        _setSanitizer(initialSanitizer);

        // Create a new zone, with the captain as the zone owner, the given
        // zone name, API endpoint, and documentation URI.
        SignedZoneControllerInterface(_SIGNED_ZONE_CONTROLLER).createZone(
            zoneName,
            apiEndpoint,
            documentationURI,
            address(this),
            zoneSalt
        );
    }

    /**
     * @notice Update the API endpoint returned by the supplied zone.
     *         Only the owner can call this function.
     *
     * @param zone           The signed zone to update the API endpoint for.
     * @param newApiEndpoint The new API endpoint.
     */
    function updateZoneAPIEndpoint(address zone, string calldata newApiEndpoint)
        external
        override
    {
        // Ensure caller is the owner.
        _assertCallerIsOwner();

        // Call to the signed zone controller to update the zone API endpoint.
        _SIGNED_ZONE_CONTROLLER.updateAPIEndpoint(zone, newApiEndpoint);
    }

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
    ) external override {
        // Ensure caller is the owner.
        _assertCallerIsOwner();

        // Call to the signed zone controller to update the zone documentation URI.
        _SIGNED_ZONE_CONTROLLER.updateDocumentationURI(
            zone,
            newDocumentationURI
        );
    }

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
    ) external override {
        // Ensure caller is the owner.
        _assertCallerIsOwner();

        // Call to the signed zone controller to update the zone signer.
        _SIGNED_ZONE_CONTROLLER.updateSigner(zone, signer, active);
    }

    /**
     * @notice Update the rotator role on the captain.
     *
     * @param newRotator The new rotator of the captain.
     */
    function updateRotator(address newRotator) external override {
        // Ensure caller is owner.
        _assertCallerIsOwner();

        // Set the new rotator.
        _setRotator(newRotator);
    }

    /**
     * @notice Update the sanitizer role on the captain.
     *
     * @param newSanitizer The new sanitizer of the captain.
     */
    function updateSanitizer(address newSanitizer) external override {
        // Ensure caller is owner.
        _assertCallerIsOwner();

        // Set the new sanitizer.
        _setSanitizer(newSanitizer);
    }

    /**
     * @notice Initiate zone ownership transfer by assigning a new potential
     *         owner for the given zone. Only callable by the owner.
     *
     * @param zone              The zone for which to initiate ownership
     *                          transfer.
     * @param newPotentialOwner The new potential owner to set.
     */
    function transferZoneOwnership(address zone, address newPotentialOwner)
        external
        override
    {
        // Ensure caller is the owner.
        _assertCallerIsOwner();

        // Call to the signed zone controller to transfer the zone ownership.
        _SIGNED_ZONE_CONTROLLER.transferOwnership(zone, newPotentialOwner);
    }

    /**
     * @notice Clear the currently set potential owner, if any, from a zone.
     *         Only callable by the owner.
     *
     * @param zone The zone for which to cancel ownership transfer.
     */
    function cancelZoneOwnershipTransfer(address zone) external override {
        // Ensure caller is the owner.
        _assertCallerIsOwner();

        // Call to the signed zone controller to cancel the zone ownership
        // transfer.
        _SIGNED_ZONE_CONTROLLER.cancelOwnershipTransfer(zone);
    }

    /**
     * @notice Accept ownership of a given zone once the address has been set
     *         as the current potential owner. Only callable by the owner.
     *
     * @param zone The zone for which to accept ownership transfer.
     */
    function acceptZoneOwnership(address zone) external override {
        // Call to the signed zone controller to accept the zone ownership.
        _SIGNED_ZONE_CONTROLLER.acceptOwnership(zone);
    }

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
    ) external override {
        // Ensure caller is the owner or the rotator.
        _assertCallerIsOwnerOrRotator();

        // Call to the signed zone controller to remove the signer.
        _SIGNED_ZONE_CONTROLLER.updateSigner(zone, signerToRemove, false);

        // Call to the signed zone controller to add the signer.
        _SIGNED_ZONE_CONTROLLER.updateSigner(zone, signerToAdd, true);
    }

    /**
     * @notice This will remove all active signers of the given zone and clear
     *         the rotator address on the captain. Only callable by the owner
     *         or the sanitizer of the zone.
     *
     * @param zone The zone to revoke.
     */
    function sanitizeSignedZone(address zone) external override {
        // Ensure caller is the owner or the sanitizer.
        _assertCallerIsOwnerOrSanitizer();

        // Call to the signed zone controller to sanitize the signed zone.
        address[] memory signers = _SIGNED_ZONE_CONTROLLER.getActiveSigners(
            zone
        );

        // Loop through the signers and deactivate them.
        for (uint256 i = 0; i < signers.length; i++) {
            _SIGNED_ZONE_CONTROLLER.updateSigner(zone, signers[i], false);
        }

        // Clear the rotator role.
        delete _rotator;

        // Emit the sanitized event.
        emit ZoneSanitized(zone);
    }

    /**
     * @notice Get the rotator address.
     *
     * @return The rotator address.
     */
    function getRotator() external view override returns (address) {
        return _rotator;
    }

    /**
     * @notice Get the sanitizer address.
     *
     * @return The sanitizer address.
     */
    function getSanitizer() external view override returns (address) {
        return _sanitizer;
    }

    /**
     * @notice Internal function to set the rotator role on the contract,
     *         checking to make sure the provided address is not the null
     *         address
     *
     * @param newRotator The new rotator address.
     */
    function _setRotator(address newRotator) internal {
        // Ensure new rotator is not null.
        if (newRotator == address(0)) {
            revert RotatorCannotBeNullAddress();
        }

        _rotator = newRotator;

        emit RotatorUpdated(newRotator);
    }

    /**
     * @notice Internal function to set the sanitizer role on the contract,
     *         checking to make sure the provided address is not the null
     *         address
     *
     * @param newSanitizer The new sanitizer address.
     */
    function _setSanitizer(address newSanitizer) internal {
        // Ensure new sanitizer is not null.
        if (newSanitizer == address(0)) {
            revert SanitizerCannotBeNullAddress();
        }

        _sanitizer = newSanitizer;

        emit SanitizerUpdated(newSanitizer);
    }

    /**
     * @notice Internal function to assert that the caller is a valid deployer.
     *         This must be overwritten by the contract that inherits from this
     *         contract.  This is to ensure that the caller or tx.orign is
     *         permitted to deploy this contract.
     */
    function _assertValidDeployer() internal view virtual {
        // TODO: Implement this.
        //revert("Not implemented assertValidDeployer");
    }

    /**
     * @dev Internal view function to revert if the caller is not the owner or
     *      the sanitizer.
     */
    function _assertCallerIsOwnerOrSanitizer() internal view {
        // Ensure caller is the owner or the sanitizer.
        if (msg.sender != owner() && msg.sender != _sanitizer) {
            revert CallerIsNotOwnerOrSanitizer();
        }
    }

    /**
     * @dev Internal view function to revert if the caller is not the owner or
     *      the rotator.
     */
    function _assertCallerIsOwnerOrRotator() internal view {
        // Ensure caller is the owner or the rotator.
        if (msg.sender != owner() && msg.sender != _rotator) {
            revert CallerIsNotOwnerOrRotator();
        }
    }
}
