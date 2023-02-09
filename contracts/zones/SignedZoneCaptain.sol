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
 *         the active signers of a zone. The pauser role can pause a zone,
 *         which will remove all active signers and clear the rotator role.
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

    // The address of the pauser. The pauser can pause a zone controlled by
    // this contract. Pausing a zone will remove all active signers and clear
    // the rotator role.
    address private _pauser;

    /**
     * @dev Initialize contract by setting the signed zone controller, the
     *      initial owner, the initial rotator, and initial pauser role.
     *
     * @param signedZoneController The address of the signed zone controller.
     * @param initialOwner         The address of the initial owner.
     * @param initialRotator       The address of the initial rotator.
     * @param initialPauser        The address of the initial pauser.
     */
    constructor(
        address signedZoneController,
        address initialOwner,
        address initialRotator,
        address initialPauser
    ) {
        // Ensure that a contract is deployed to the given signed zone controller.
        if (signedZoneController.code.length == 0) {
            revert InvalidSignedZoneController(signedZoneController);
        }

        // Set the signed zone controller.
        _SIGNED_ZONE_CONTROLLER = SignedZoneControllerInterface(
            signedZoneController
        );

        // Set the initial owner.
        _setInitialOwner(initialOwner);

        // Set the initial rotator.
        _setRotator(initialRotator);

        // Set the initial pauser.
        _setPauser(initialPauser);
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
     * @notice Update the pauser role on the captain.
     *
     * @param newPauser The new pauser of the captain.
     */
    function updatePauser(address newPauser) external override {
        // Ensure caller is owner.
        _assertCallerIsOwner();

        // Set the new pauser.
        _setPauser(newPauser);
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
     * @notice Pause a zone, this will remove all active signers and clear the
     *         rotator address on the captain. Only callable by the owner or
     *         the pauser of the zone.
     *
     * @param zone The zone to pause.
     */
    function pauseSignedZone(address zone) external override {
        // Ensure caller is the owner or the pauser.
        _assertCallerIsOwnerOrPauser();

        // Call to the signed zone controller to pause the signed zone.
        address[] memory signers = _SIGNED_ZONE_CONTROLLER.getActiveSigners(
            zone
        );

        // Loop through the signers and deactivate them.
        for (uint256 i = 0; i < signers.length; i++) {
            _SIGNED_ZONE_CONTROLLER.updateSigner(zone, signers[i], false);
        }

        // Clear the rotator role.
        delete _rotator;

        // Emit the paused event.
        emit ZonePaused(zone);
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
     * @notice Get the pauser address.
     *
     * @return The pauser address.
     */
    function getPauser() external view override returns (address) {
        return _pauser;
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
     * @notice Internal function to set the pauser role on the contract,
     *         checking to make sure the provided address is not the null
     *         address
     *
     * @param newPauser The new pauser address.
     */
    function _setPauser(address newPauser) internal {
        // Ensure new pauser is not null.
        if (newPauser == address(0)) {
            revert PauserCannotBeNullAddress();
        }

        _pauser = newPauser;

        emit PauserUpdated(newPauser);
    }

    /**
     * @dev Internal view function to revert if the caller is not the owner or
     *      the pauser.
     */
    function _assertCallerIsOwnerOrPauser() internal view {
        // Ensure caller is the owner or the pauser.
        if (msg.sender != owner() && msg.sender != _pauser) {
            revert CallerIsNotOwnerOrPauser();
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
