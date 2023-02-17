//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SignedZoneCaptain } from "./SignedZoneCaptain.sol";

import { SignedZoneController } from "./SignedZoneController.sol";

import {
    ImmutableCreate2FactoryInterface
} from "../interfaces/ImmutableCreate2FactoryInterface.sol";

import "./lib/SignedZoneDeployerConstants.sol";

/**
 * @title   SignedZoneDeployer
 * @author  OpenSea Protocol Team
 * @notice  SignedZoneDeployer is a contract that is used to deploy the
 *          SignedZoneController, a SignedZone and the SignedZoneCaptain to
 *          deterministic addresses via an immutable create2 factory.
 *
 *          Expected Addresses:
 *
 *          SignedZoneController  -  TODO: Add address
 *          SignedZoneCaptain     -  TODO: Add address
 *          SignedZone            -  TODO: Add address
 */
contract SignedZoneDeployer {
    /**
     * @notice Deploys the Signed Zone Controller and the Signed Zone Captain.
     *
     * @param   ownerOfCaptain     The address that will be set as owner of the
     *                             Signed Zone Captain.
     * @param   rotatorToAssign    The address that will be set as the rotator
     *                             of the Signed Zone Captain.
     * @param   sanitizerToAssign  The address that will be set as the
     *                             sanitizer of the Signed Zone Captain.
     * @param   zoneName           The name of the zone to create.
     * @param   apiEndpoint        The API endpoint of the zone to create.
     * @param   documentationURI   The documentation URI of the zone to
     *                             create.
     * @param   zoneSalt           The salt used to create the deterministic
     *                             address via create2 for the Signed Zone.
     */
    constructor(
        address ownerOfCaptain,
        address rotatorToAssign,
        address sanitizerToAssign,
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI,
        bytes32 zoneSalt
    ) {
        // Check if the controller already exists.
        if (address(SIGNED_ZONE_CONTROLLER_ADDRESS).code.length == 0) {
            // Deploy the Signed Zone Controller.
            _deploySignedZoneController();
        }

        // Deploy the Signed Zone Captain via CREATE2.
        address signedZoneCaptain = _deploySignedZoneCaptain();

        // Initialize the Signed Zone Captain, setting this contract as the
        // temporary owner.
        SignedZoneCaptain(signedZoneCaptain).initialize(
            address(this),
            rotatorToAssign,
            sanitizerToAssign,
            zoneName,
            apiEndpoint,
            documentationURI,
            zoneSalt
        );

        // Initiate transfer ownership.
        SignedZoneCaptain(signedZoneCaptain).transferOwnership(ownerOfCaptain);
    }

    /**
     * @notice Deploys the Signed Zone Captain through the immutable create2
     *         factory at TODO: Add address.
     *
     * @return signedZoneCaptain The address of the Signed Zone Captain.
     */
    function _deploySignedZoneCaptain()
        internal
        returns (address signedZoneCaptain)
    {
        // Deploy the Signed Zone Captain via CREATE2.
        signedZoneCaptain = ImmutableCreate2FactoryInterface(
            CREATE_2_FACTORY_ADDRESS
        ).safeCreate2(SIGNED_ZONE_CAPTAIN_SALT, SIGNED_ZONE_CAPTAIN_CODE);
    }

    /**
     * @notice Deploys the Signed Zone Controller through the immutable create2
     *         factory at TODO: Add address.
     *
     * @return signedZoneController The address of the Signed Zone Captain.
     */
    function _deploySignedZoneController()
        internal
        returns (address signedZoneController)
    {
        // Deploy the Signed Zone Controller via CREATE2.
        signedZoneController = ImmutableCreate2FactoryInterface(
            CREATE_2_FACTORY_ADDRESS
        ).safeCreate2(SIGNED_ZONE_CONTROLLER_SALT, SIGNED_ZONE_CONTROLLER_CODE);
    }
}
