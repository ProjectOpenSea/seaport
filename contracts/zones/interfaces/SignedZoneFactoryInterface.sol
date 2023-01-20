// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  SignedZoneFactoryInterface
 * @author LeFevre
 * @notice SignedZoneFactoryInterface enables the deploying of SignedZones.
 *         SignedZones are an implementation of SIP-7 that requires orders
 *         to be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 *
 */
interface SignedZoneFactoryInterface {
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
    ) external returns (address derivedAddress);

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
    ) external view returns (address derivedAddress);
}
