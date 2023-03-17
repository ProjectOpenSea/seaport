// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Schema } from "../../../contracts/lib/ConsiderationStructs.sol";

/**
 * @dev SIP-5: Contract Metadata Interface for Seaport Contracts
 *      https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-5.md
 */
interface SIP5Interface {
    /**
     * @dev An event that is emitted when a SIP-5 compatible contract is deployed.
     */
    event SeaportCompatibleContractDeployed();

    /**
     * @dev Returns Seaport metadata for this contract, returning the
     *      contract name and supported schemas.
     *
     * @return name    The contract name
     * @return schemas The supported SIPs
     */
    function getSeaportMetadata()
        external
        view
        returns (string memory name, Schema[] memory schemas);
}
