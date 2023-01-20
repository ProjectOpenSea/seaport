// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SignedZone } from "./SignedZone.sol";

import {
    SignedZoneFactoryInterface
} from "./interfaces/SignedZoneFactoryInterface.sol";

import {
    SignedZoneFactoryEventsAndErrors
} from "./interfaces/SignedZoneFactoryEventsAndErrors.sol";

/**
 * @title  SignedZoneFactory
 * @author LeFevre
 * @notice SignedZoneFactory enables the deploying of SignedZones. SignedZones
 *         are an implementation of SIP-7 that requires orders to be signed by
 *         an  approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 */
contract SignedZoneFactory is
    SignedZoneFactoryInterface,
    SignedZoneFactoryEventsAndErrors
{
    /**
     * @dev Initialize contract
     */
    constructor() {}

    /**
     * @notice Deploy a SignedZone to a precomputed address.
     *
     * @param zoneName    The name for the zone returned in
     *                    getSeaportMetadata().
     * @param apiEndpoint The API endpoint where orders for this zone can be
     *                    signed.
     *                    Request and response payloads are defined in SIP-7.
     * @param salt        The salt to be used to derive the zone address
     *
     * @return derivedAddress The derived address for the zone.
     */
    function createZone(
        string memory zoneName,
        string memory apiEndpoint,
        bytes32 salt
    ) external override returns (address derivedAddress) {
        // Ensure the first 20 bytes of the salt are the same as the msg.sender
        // or are set to zero.
        if (
            (address(uint160(bytes20(salt))) != msg.sender) &&
            (bytes20(salt) != bytes20(0))
        ) {
            // Revert with an error indicating that the creator is invalid.
            revert InvalidCreator();
        }

        //Hash the zone creation code, zoneName and apiEndpoint.
        bytes32 SIGNED_ZONE_CREATION_CODE_HASH = keccak256(
            abi.encodePacked(
                type(SignedZone).creationCode,
                abi.encode(zoneName, apiEndpoint)
            )
        );

        // Derive the SignedZone address from the deployer, salt and creation
        // code hash.
        derivedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            SIGNED_ZONE_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );

        // Revert if a zone is currently deployed to the derived address.
        if (derivedAddress.code.length != 0) {
            revert ZoneAlreadyExists(derivedAddress);
        }

        // Deploy the zone using the supplied salt, zoneName and apiEndpoint.
        new SignedZone{ salt: salt }(zoneName, apiEndpoint);

        // Emit an event signifying that the zone was created.
        emit ZoneCreated(derivedAddress, zoneName, apiEndpoint, salt);
    }

    /**
     * @notice Derive the zone address associated with a given zoneName,
     *         apiEndpoint and salt.
     *
     * @param zoneName    The name for the zone returned in
     *                    getSeaportMetadata().
     * @param apiEndpoint The API endpoint where orders for this zone can be
     *                    signed.
     *                    Request and response payloads are defined in SIP-7.
     * @param salt        The salt to be used to derive the zone address
     *
     * @return derivedAddress The derived address of the signed zone.
     */
    function getZone(
        string memory zoneName,
        string memory apiEndpoint,
        bytes32 salt
    ) external view override returns (address derivedAddress) {
        // Hash the zone creation code, zoneName and apiEndpoint.
        bytes32 SIGNED_ZONE_CREATION_CODE_HASH = keccak256(
            abi.encodePacked(
                type(SignedZone).creationCode,
                abi.encode(zoneName, apiEndpoint)
            )
        );

        // Derive the SignedZone address from deployer, salt and creation code hash.
        derivedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            SIGNED_ZONE_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
