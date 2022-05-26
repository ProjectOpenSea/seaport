// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

import { ConsiderationInterface } from "../interfaces/ConsiderationInterface.sol";

import { AdvancedOrder } from "../lib/ConsiderationStructs.sol";

/*
 * Basic example Zone, that approves every order.
 * Can be self-destructed to pause orders using it as a zone, by its deployer.
 */

contract GlobalPausable is ZoneInterface {
    address internal immutable deployer;

    constructor() {
        deployer = msg.sender;
    }

    // Called by Seaport whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = 1;
    }

    // Called by Seaport whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = 1;
    }

    //The zone can cancel orders which have agreed to use it as a zone
    function cancelOrder(address _seaport, OrderComponents[] calldata orders)
        external
        returns (bool cancelled)
    {
        //only the deployer is allowed to call this.
        require(msg.sender == deployer);

        //Create seaport object
        Consideration seaport = ConsiderationInterface(_seaport);

        cancelled = seaport.cancel(order);
    }

    function executeRestrictedOffer() external {
        //only the deployer is allowed to call this.
        require(msg.sender == deployer);

        //Create seaport object
        Consideration seaport = ConsiderationInterface(_seaport);
    }

    //self descructs this contract, safely stopping orders from using this as a zone.
    function kill() external {
        require(msg.sender == deployer);

        //TODO nuke it, motha'fucka
    }
}
