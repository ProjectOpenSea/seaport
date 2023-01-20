// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @dev SIP-5: Contract Metadata Interface for Seaport Contracts
 *      https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-5.md
 */
interface SIP5Interface {
    /**
     * @dev Zones and contract offerers can communicate which schemas they implement
     *      along with any associated metadata related to each schema.
     */
    struct Schema {
        uint256 id; /// Seaport Improvement Proposal (SIP) ID
        bytes metadata; /// Optional additional metadata
    }

    /**
     * @dev Returns Seaport metadata for this contract, returning the
     *      contract name and supported schemas.
     *
     * @return name The contract name
     * @return schemas The supported SIPs
     */
    function getSeaportMetadata()
        external
        view
        returns (string memory name, Schema[] memory schemas);
}
