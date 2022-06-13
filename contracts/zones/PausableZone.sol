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

/**
 * @title  PausableZone
 * @author cupOJoseph, BCLeFevre, ryanio
 * @notice PausableZone is a basic example zone that approves every order.
 *         It can be self-destructed by its deployer to pause orders
 *         using it as a zone.
 */
contract PausableZone is GlobalPausableEventsAndErrors, ZoneInterface {
    // Set an immutable deployer that can pause orders passing through the zone.
    address internal immutable deployer;

    // Set an operator that can call operations on the zone.
    address public operator;

    /**
     * @dev Modifier to check that the caller is either the owner or operator.
     */
    modifier isOperator() {
        // Check if msg.sender is either the operator or deployer.
        if (msg.sender != operator && msg.sender != deployer) {
            revert InvalidOperator();
        }
        _;
    }

    /**
     * @notice Set an address as the deployer of PausableZone.
     *
     * @param owner An address to be set as the deployer.
     */
    constructor(address owner) {
        deployer = owner;
    }

    /**
     * @notice Checks that a given order is currently valid.
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
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Checks that a given order is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData
     *      is provided by the caller.
     *
     * @param orderHash         The hash of the order.
     * @param caller            The caller in question.
     * @param order             The order in question.
     * @param priorOrderHashes  The prior order hashes of the order.
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

    // executes a restricted order
    function executeMatchOrders(
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
    function pause() external {
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
        operator = operatorToAssign;

        // Emit the event
        emit OperatorUpdated(operator);
    }
}
