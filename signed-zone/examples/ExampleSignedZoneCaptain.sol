//SPDX-License Identifier:MIT
pragma solidity ^0.8.13;

import { SignedZoneCaptain } from "../SignedZoneCaptain.sol";

/**
 * @title  ExampleSignedZoneCaptain
 * @author OpenSea Protocol Team
 * @notice ExampleSignedZoneCaptain is a test contract that owns signed zones
 *         and manages their active signers via two roles. The rotator role can
 *         update the active signers of a zone. The sanitizer role can remove
 *         all  active signers of a zone controlled by the captain and clear
 *         the  rotator role on the captain.
 *         In order to ensure the captain is deployed by an approved deployer,
 *         the _assertValidDeployer function is overridden to check that the
 *         deployer is the address is valid.
 */
contract ExampleSignedZoneCaptain is SignedZoneCaptain {
    constructor(address signedZoneController)
        SignedZoneCaptain(signedZoneController)
    {}

    /**
     * @notice Internal function to assert that the caller is a valid deployer.
     */
    function _assertValidDeployer() internal view override {
        // Ensure that the contract is being deployed by an approved
        // deployer.
        // tx.origin is used here, because we use the SignedZoneDeployer
        // contract to deploy this contract, and initailize the owner,
        // rotator, and sanitizer roles.

        /// @dev 0x1010101010101010101010101010101010101010 should be overridden
        ///      with the address of your approved deployer.
        if (tx.origin != address(0x1010101010101010101010101010101010101010)) {
            revert InvalidDeployer();
        }
    }
}
