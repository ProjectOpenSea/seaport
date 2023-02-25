//SPDX-License Identifier:MIT
pragma solidity ^0.8.13;

import { SignedZoneCaptain } from "./SignedZoneCaptain.sol";

contract OpenSeaSignedZoneCaptain is SignedZoneCaptain {
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
        if (
            tx.origin != address(0x939C8d89EBC11fA45e576215E2353673AD0bA18A) &&
            tx.origin != address(0xe80a65eB7a3018DedA407e621Ef5fb5B416678CA) &&
            tx.origin != address(0x86D26897267711ea4b173C8C124a0A73612001da) &&
            tx.origin != address(0x3B52ad533687Ce908bA0485ac177C5fb42972962)
        ) {
            revert InvalidDeployer();
        }
    }
}
