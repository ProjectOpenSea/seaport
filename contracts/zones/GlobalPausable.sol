// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

import { ConsiderationInterface } from "../interfaces/ConsiderationInterface.sol";

import { AdvancedOrder, CriteriaResolver, Order, OrderComponents, Fulfillment } from "../lib/ConsiderationStructs.sol";

/*
 * Basic example Zone, that approves every order.
 * Can be self-destructed to pause orders using it as a zone, by its deployer.
 */

contract GlobalPausable is ZoneInterface {
    address internal immutable deployer;

    constructor(address owner) {
        deployer = owner;
    }

    // Called by Seaport whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    // Called by Seaport whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    //The zone can cancel orders which have agreed to use it as a zone
    function cancelOrder(address _seaport, OrderComponents[] calldata orders)
        external
        returns (bool cancelled)
    {
        require(
            msg.sender == deployer,
            "Only the owner can cancel restricted orders with this zone."
        );

        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);

        cancelled = seaport.cancel(orders);
    }

    //executes a restricted order
    function executeRestrictedOffer(
        address _seaport,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external returns (bool executed) {
        require(
            msg.sender == deployer,
            "Only the owner can execute restricted orders with this zone."
        );

        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);

        executed = seaport.matchOrders(orders, fulfillments);
    }

    function executeRestrictedAdvancedOffer(
        address _seaport,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external returns (bool executed) {
        require(
            msg.sender == deployer,
            "Only the owner can execute advanced restricted orders with this zone."
        );
        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);

        executed = seaport.matchAdvancedOrders(
            orders,
            criteriaResolvers,
            fulfillments
        );
    }

    /**
     * Self-descructs this contract, safely stopping orders from using this as a zone.
     * Oders with this address as a zone are bricked until the Deployer makes a new zone
     * with the same address as this one.
     */
    function kill() external {
        require(msg.sender == deployer);

        //There shouldn't be any eth on the zone, but in case there is, send it to the deployer caller address.
        selfdestruct(payable(tx.origin));
    }
}
