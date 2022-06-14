// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

// prettier-ignore
import {
    PausableZoneEventsAndErrors
} from "./interfaces/PausableZoneEventsAndErrors.sol";

import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

// prettier-ignore
import {
    AdvancedOrder,
    CriteriaResolver,
    Order,
    OrderComponents,
    Fulfillment,
    Execution
} from "../lib/ConsiderationStructs.sol";

import { PausableZoneInterface } from "./interfaces/PausableZoneInterface.sol";

/**
 * @title  PausableZone
 * @author cupOJoseph, BCLeFevre, ryanio
 * @notice PausableZone is a simple zone implementation that approves every
 *         order. It can be self-destructed by its controller to pause
 *         restricted orders that have it set as their zone.
 */
contract PausableZone is
    PausableZoneEventsAndErrors,
    ZoneInterface,
    PausableZoneInterface
{
    // Set an immutable controller that can pause the zone & update an operator.
    address internal immutable _controller;

    // Set an operator that can instruct the zone to cancel or execute orders.
    address public operator;

    /**
     * @dev Ensure that the caller is either the operator or controller.
     */
    modifier isOperator() {
        // Ensure that the caller is either the operator or the controller.
        if (msg.sender != operator && msg.sender != _controller) {
            revert InvalidOperator();
        }

        // Continue with function execution.
        _;
    }

    /**
     * @dev Ensure that the caller is the controller.
     */
    modifier isController() {
        // Ensure that the caller is the controller.
        if (msg.sender != _controller) {
            revert InvalidController();
        }

        // Continue with function execution.
        _;
    }

    /**
     * @notice Set the deployer as the controller of the zone.
     */
    constructor() {
        // Set the controller to the deployer.
        _controller = msg.sender;
        // Emit an event signifying that the zone is unpaused.
        emit Unpaused();
    }

    /**
     * @notice Check if a given order is currently valid.
     *
     * @dev This function is called by Seaport whenever extraData is not
     *      provided by the caller.
     *
     * @param orderHash The hash of the order.
     * @param caller    The caller in question.
     * @param offerer   The offerer in question.
     * @param zoneHash  The hash to provide upon calling the zone.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external pure override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        offerer;
        zoneHash;

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData is
     *      provided by the caller.
     *
     * @param orderHash         The hash of the order.
     * @param caller            The caller in question.
     * @param order             The order in question.
     * @param priorOrderHashes  The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment.
     * @param criteriaResolvers The criteria resolvers corresponding to
     *                          the order.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external pure override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        order;
        priorOrderHashes;
        criteriaResolvers;

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Cancel an arbitrary number of orders that have agreed to use the
     *         contract as their zone.
     *
     * @param seaport  The Seaport address.
     * @param orders   The orders to cancel.
     *
     * @return cancelled A boolean indicating whether the supplied orders have
     *                   been successfully cancelled.
     */
    function cancelOrders(
        SeaportInterface seaport,
        OrderComponents[] calldata orders
    ) external override isOperator returns (bool cancelled) {
        // Call cancel on Seaport and return its boolean value.
        cancelled = seaport.cancel(orders);
    }

    /**
     * @notice Execute an arbitrary number of matched orders, each with
     *         an arbitrary number of items for offer and consideration
     *         along with a set of fulfillments allocating offer components
     *         to consideration components.
     *
     * @param seaport      The Seaport address.
     * @param orders       The orders to match.
     * @param fulfillments An array of elements allocating offer components
     *                     to consideration components.
     *
     * @return executions An array of elements indicating the sequence of
     *                    transfers performed as part of matching the given
     *                    orders.
     */
    function executeMatchOrders(
        SeaportInterface seaport,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        override
        isOperator
        returns (Execution[] memory executions)
    {
        // Call matchOrders on Seaport and return the sequence of transfers
        // performed as part of matching the given orders.
        executions = seaport.matchOrders{ value: msg.value }(
            orders,
            fulfillments
        );
    }

    /**
     * @notice Execute an arbitrary number of matched advanced orders,
     *         each with an arbitrary number of items for offer and
     *         consideration along with a set of fulfillments allocating
     *         offer components to consideration components.
     *
     * @param seaport           The Seaport address.
     * @param orders            The orders to match.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root.
     * @param fulfillments      An array of elements allocating offer components
     *                          to consideration components.
     *
     * @return executions An array of elements indicating the sequence of
     *                    transfers performed as part of matching the given
     *                    orders.
     */
    function executeMatchAdvancedOrders(
        SeaportInterface seaport,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        override
        isOperator
        returns (Execution[] memory executions)
    {
        // Call matchAdvancedOrders on Seaport and return the sequence of
        // transfers performed as part of matching the given orders.
        executions = seaport.matchAdvancedOrders{ value: msg.value }(
            orders,
            criteriaResolvers,
            fulfillments
        );
    }

    /**
     * @notice Pause this contract, safely stopping orders from using
     *         the contract as a zone. Restricted orders with this address as a
     *         zone will not be fulfillable unless the zone is redeployed to the
     *         same address.
     */
    function pause() external override isController {
        // Emit an event signifying that the zone is paused.
        emit Paused();
        // Destroy the zone, sending any ether to the transaction submitter.
        selfdestruct(payable(tx.origin));
    }

    /**
     * @notice Assign the given address with the ability to operate the zone.
     *
     * @param operatorToAssign The address to assign as the operator.
     */
    function assignOperator(address operatorToAssign)
        external
        override
        isController
    {
        // Ensure the operator being assigned is not the null address.
        require(
            operatorToAssign != address(0),
            "Operator can not be set to the null address"
        );

        // Set the given address as the new operator.
        operator = operatorToAssign;

        // Emit an event indicating the operator has been updated.
        emit OperatorUpdated(operator);
    }
}
