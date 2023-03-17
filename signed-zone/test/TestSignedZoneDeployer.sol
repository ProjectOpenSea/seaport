//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SignedZoneCaptain } from "../SignedZoneCaptain.sol";

import {
    SignedZoneController
} from "../../signed-zone/SignedZoneController.sol";

import {
    ImmutableCreate2FactoryInterface
} from "../../contracts/interfaces/ImmutableCreate2FactoryInterface.sol";

import "./lib/TestSignedZoneDeployerConstants.sol";

/**
 * @title   TestSignedZoneDeployer
 * @author  OpenSea Protocol Team
 * @notice  TestSignedZoneDeployer is a contract that is used to deploy the
 *          SignedZoneController, a SignedZone and the SignedZoneCaptain to
 *          deterministic addresses via an immutable create2 factory.
 *
 *          Expected Addresses:
 *
 *          TestSignedZoneController  -  0x000066470b8ae18200009a2DB42C895e00d1fB00
 *          TestSignedZoneCaptain     -  0x000000Ac396B2102db11B86Cdd31005100064cB1
 *          TestSignedZone            -  0x0000000045CA1F93419BBB768fcE00775EAD9f90
 */
contract TestSignedZoneDeployer {
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
        if (address(TEST_SIGNED_ZONE_CONTROLLER_ADDRESS).code.length == 0) {
            // Deploy the Signed Zone Controller.
            _deployTestSignedZoneController();
        }

        // Deploy the Signed Zone Captain via CREATE2.
        address testSignedZoneCaptain = _deployTestSignedZoneCaptain();

        // Initialize the Signed Zone Captain, setting this contract as the
        // temporary owner.
        SignedZoneCaptain(testSignedZoneCaptain).initialize(
            address(this),
            rotatorToAssign,
            sanitizerToAssign,
            zoneName,
            apiEndpoint,
            documentationURI,
            zoneSalt
        );

        // Initiate transfer ownership.
        SignedZoneCaptain(testSignedZoneCaptain).transferOwnership(
            ownerOfCaptain
        );
    }

    /**
     * @notice Deploys the Signed Zone Captain through the immutable create2
     *         factory at TODO: Add address.
     *
     * @return testSignedZoneCaptain The address of the Signed Zone Captain.
     */
    function _deployTestSignedZoneCaptain()
        internal
        returns (address testSignedZoneCaptain)
    {
        // Deploy the Signed Zone Captain via CREATE2.
        testSignedZoneCaptain = ImmutableCreate2FactoryInterface(
            CREATE_2_FACTORY_ADDRESS
        ).safeCreate2(
                TEST_SIGNED_ZONE_CAPTAIN_SALT,
                TEST_SIGNED_ZONE_CAPTAIN_CODE
            );
    }

    /**
     * @notice Deploys the Signed Zone Controller through the immutable create2
     *         factory at TODO: Add address.
     *
     * @return testSignedZoneController The address of the Signed Zone Captain.
     */
    function _deployTestSignedZoneController()
        internal
        returns (address testSignedZoneController)
    {
        // Deploy the Signed Zone Controller via CREATE2.
        testSignedZoneController = ImmutableCreate2FactoryInterface(
            CREATE_2_FACTORY_ADDRESS
        ).safeCreate2(
                TEST_SIGNED_ZONE_CONTROLLER_SALT,
                TEST_SIGNED_ZONE_CONTROLLER_CODE
            );
    }
}
