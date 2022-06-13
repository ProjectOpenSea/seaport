// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";
// prettier-ignore
import {
    GlobalPausableEventsAndErrors
} from "./interfaces/GlobalPausableEventsAndErrors.sol";

import { ConsiderationInterface } from "../interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Order,
    OrderComponents,
    Fulfillment,
    Execution
} from "../lib/ConsiderationStructs.sol";

/**
 * @title  PausableZone
 * @author cupOJoseph, BCLeFevre, ryanio
 * @notice PausableZone is a basic example zone that approves every order.
 *         It can be self-destructed by its deployer to pause orders
 *         using it as a zone.
 */
contract PausableZone is GlobalPausableEventsAndErrors, ZoneInterface {
    // Set an immutable deployer that can pause orders on the zone.
    address internal immutable deployer;

    // Set an operator that can call operations on the zone.
    address public operator;

    /**
     * @dev Ensure that the caller is either the operator or deployer.
     */
    modifier isOperator() {
        // Check if the caller is either the operator or deployer.
        if (msg.sender != operator && msg.sender != deployer) {
            revert InvalidOperator();
        }
        _;
    }

    /**
     * @notice Set the owner as the deployer of the zone.
     *
     * @param owner The owner to be set as the deployer.
     */
    constructor(address owner) {
        deployer = owner;
    }

    /**
     * @notice Check if a given order is currently valid.
     *
     * @dev This function is called by Seaport whenever extraData
     *      is not provided by the caller.
     *
     * @param orderHash The hash of the order.
     * @param caller    The caller in question.
     * @param offerer   The offerer in question.
     * @param zoneHash  The hash to provide upon calling the zone.
     *
     * @return validOrderMagicValue A magic value indicating if the order
     *         is currently valid.
     */
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view override returns (bytes4 validOrderMagicValue) {
        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData
     *      is provided by the caller.
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
     * @return validOrderMagicValue A magic value indicating if the order
     *         is currently valid.
     */
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view override returns (bytes4 validOrderMagicValue) {
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
    function cancelOrder(address seaport, OrderComponents[] calldata orders)
        external
        isOperator
        returns (bool cancelled)
    {
        // Create a seaport object.
        ConsiderationInterface seaportObject = ConsiderationInterface(seaport);

        // Call cancel on the seaport object and return its boolean value.
        cancelled = seaportObject.cancel(orders);
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
        address seaport,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external payable isOperator returns (Execution[] memory executions) {
        // Create a seaport object.
        ConsiderationInterface seaportObject = ConsiderationInterface(seaport);

        // Call matchOrders on the seaport object and return the sequence
        // of transfers performed as part of matching the given orders.
        executions = seaportObject.matchOrders{ value: msg.value }(
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
        address seaport,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable isOperator returns (Execution[] memory executions) {
        // Create a seaport object.
        ConsiderationInterface seaportObject = ConsiderationInterface(seaport);

        // Call matchAdvancedOrders on the seaport object and return
        // the sequence of transfers performed as part of matching
        // the given orders
        executions = seaportObject.matchAdvancedOrders{ value: msg.value }(
            orders,
            criteriaResolvers,
            fulfillments
        );
    }

    /**
     * @notice Pause this contract, safely stopping orders from using
     *         the contract as a zone. Orders with this address as a zone are
     *         bricked until the deployer makes a new zone with the same address
     *         as this one.
     */
    function pause() external {
        // Ensure the deployer is pausing the contract.
        require(
            msg.sender == deployer,
            "Only the owner can kill this contract."
        );

        // In case there is Ether on the zone, send it to the deployer
        // caller address.
        selfdestruct(payable(tx.origin));
    }

    /**
     * @notice Assign the given address with the ability to operate the zone.
     *
     * @param operatorToAssign The address to assign as the operator.
     */
    function assignOperator(address operatorToAssign) external {
        // Ensure the deployer is assigning the operator.
        require(msg.sender == deployer, "Can only be set by the deployer");

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
