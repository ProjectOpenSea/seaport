// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";
// prettier-ignore
import {
    GlobalPausableEventsAndErrors
} from "./interfaces/GlobalPausableEventsAndErrors.sol";

import { ConsiderationInterface } from "../interfaces/ConsiderationInterface.sol";

import { AdvancedOrder, CriteriaResolver, Order, OrderComponents, Fulfillment, Execution } from "../lib/ConsiderationStructs.sol";

/*
 * Basic example Zone, that approves every order.
 * Can be self-destructed to pause orders using it as a zone, by its deployer.
 */

contract GlobalPausable is GlobalPausableEventsAndErrors, ZoneInterface {
    // Address of the deployer of the zone.
    address internal immutable deployer;

    // Address with the ability to call operations on the zone.
    address public operatorAddress;

    /**
     * @dev Throws if called by any account other than the owner or operator.
     */
    modifier isOperator() {
        if (msg.sender != operatorAddress && msg.sender != deployer) {
            revert InvalidOperator();
        }
        _;
    }

    constructor(address owner) {
        deployer = owner;
    }

    // Called by Seaport whenever extraData is not provided by the caller.
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view override returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    // Called by Seaport whenever any extraData is provided by the caller.
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view override returns (bytes4 validOrderMagicValue) {
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    //The zone can cancel orders which have agreed to use it as a zone
    function cancelOrder(address _seaport, OrderComponents[] calldata orders)
        external
        isOperator
        returns (bool cancelled)
    {
        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);

        cancelled = seaport.cancel(orders);
    }

    //executes a restricted order
    function executeRestrictedOffer(
        address _seaport,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external payable isOperator returns (Execution[] memory executions) {
        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);
        executions = seaport.matchOrders{ value: msg.value }(
            orders,
            fulfillments
        );
    }

    function executeRestrictedAdvancedOffer(
        address _seaport,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable isOperator returns (Execution[] memory executions) {
        //Create seaport object
        ConsiderationInterface seaport = ConsiderationInterface(_seaport);

        executions = seaport.matchAdvancedOrders{ value: msg.value }(
            orders,
            criteriaResolvers,
            fulfillments
        );
    }

    /**
     * Self-descructs this contract, safely stopping orders from using this as a zone.
     * Orders with this address as a zone are bricked until the Deployer makes a new zone
     * with the same address as this one.
     */
    function kill() external {
        require(
            msg.sender == deployer,
            "Only the owner can kill this contract."
        );

        //There shouldn't be any eth on the zone, but in case there is, send it to the deployer caller address.
        selfdestruct(payable(tx.origin));
    }

    /**
     * @notice Assigns the given address with the ability to operate the zone.
     *
     * @param operatorToAssign Address to assign role.
     */
    function assignOperator(address operatorToAssign) external {
        require(msg.sender == deployer, "Can only be set by the deployer");
        require(
            operatorToAssign != address(0),
            "Operator can not be set to the null address"
        );
        operatorAddress = operatorToAssign;

        // Emit the event
        emit OperatorUpdated(operatorAddress);
    }
}
