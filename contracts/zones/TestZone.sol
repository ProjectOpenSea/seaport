// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    TestZoneEventsAndErrors
} from "./interfaces/TestZoneEventsAndErrors.sol";

import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    Order,
    OrderComponents,
    Schema,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

import { PausableZoneInterface } from "./interfaces/PausableZoneInterface.sol";

/**
 * @title  TestZone
 * @author cupOJoseph, BCLeFevre, ryanio
 * @notice TestZone is a simple zone implementation that approves every
 *         order. It can be self-destructed by its controller to pause
 *         restricted orders that have it set as their zone. Note that this zone
 *         cannot execute orders that return native tokens to the fulfiller.
 */
contract TestZone is
    TestZoneEventsAndErrors,
    ZoneInterface,
    PausableZoneInterface
{
    // Set an immutable controller that can pause the zone & update an operator.
    address internal immutable _controller;

    // Set an operator that can instruct the zone to cancel or execute orders.
    address public operator;

    // Domain separator for the zone
    // bytes32 private immutable _DOMAIN_SEPARATOR;

    // TradeDetails hash
    bytes32 private constant _TRADE_DETAILS_TYPE =
        keccak256(
            "TradeDetails(uint256 marketId,uint256 value,uint256 blockNumber,bytes tradeData,bytes32[] merkleProof)"
        );

    // Trade details to execute non-seaport fulfillments
    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        uint256 blockNumber;
        bytes tradeData;
        bytes32[] merkleProof;
    }

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

        // Initialize domain separator
        // _DOMAIN_SEPARATOR = keccak256(
        //     abi.encode(
        //         EIP712_DOMAIN_TYPEHASH,
        //         keccak256(bytes(_name)),
        //         keccak256(bytes(_version)),
        //         _chainId,
        //         address(this)
        //     )
        // );
    }

    /// @notice Hashes the TradeDetails object to get a tradeHash
    /// @dev Hashes the TradeDetails object to get a tradeHash
    /// @param tradeDetails TradeDetails object to be hashed
    /// @return tradeHash for the passed TradeDetails object
    // function hashTradeDetails(
    //     TradeDetails memory tradeDetails
    // ) public view returns (bytes32) {
    //     return
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 _DOMAIN_SEPARATOR,
    //                 keccak256(
    //                     abi.encode(
    //                         _TRADE_DETAILS_TYPE,
    //                         tradeDetails.marketId,
    //                         tradeDetails.value,
    //                         tradeDetails.blockNumber,
    //                         keccak256(abi.encodePacked(tradeDetails.tradeData)),
    //                         keccak256(
    //                             abi.encodePacked(tradeDetails.merkleProof)
    //                         )
    //                     )
    //                 )
    //             )
    //         );
    // }

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
     * @notice Pause this contract, safely stopping orders from using
     *         the contract as a zone. Restricted orders with this address as a
     *         zone will not be fulfillable unless the zone is redeployed to the
     *         same address.
     */
    function pause(address payee) external override isController {
        // Emit an event signifying that the zone is paused.
        emit Paused();

        // Destroy the zone, sending any native tokens to the transaction
        // submitter.
        selfdestruct(payable(payee));
    }

    /**
     * @notice Assign the given address with the ability to operate the zone.
     *
     * @param operatorToAssign The address to assign as the operator.
     */
    function assignOperator(
        address operatorToAssign
    ) external override isController {
        // Ensure the operator being assigned is not the null address.
        if (operatorToAssign == address(0)) {
            revert PauserCanNotBeSetAsZero();
        }

        // Set the given address as the new operator.
        operator = operatorToAssign;

        // Emit an event indicating the operator has been updated.
        emit OperatorUpdated(operatorToAssign);
    }

    /**
     * @notice Execute an arbitrary number of matched orders, each with
     *         an arbitrary number of items for offer and consideration
     *         along with a set of fulfillments allocating offer components
     *         to consideration components. Note that this call will revert if
     *         excess native tokens are returned by Seaport.
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
     *         offer components to consideration components. Note that this call
     *         will revert if excess native tokens are returned by Seaport.
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
            fulfillments,
            msg.sender
        );
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData is
     *      provided by the caller.
     *
     * @custom:param zoneParameters A struct that provides context about the
     *                              order fulfillment and any supplied
     *                              extraData, as well as all order hashes
     *                              fulfilled in a call to a match or
     *                              fulfillAvailable method.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function validateOrder(
        /**
         * @custom:name zoneParameters
         */
        ZoneParameters calldata zoneParameters
    ) external override returns (bytes4 validOrderMagicValue) {
        emit TestEvent(
            zoneParameters.orderHash,
            zoneParameters.fulfiller,
            zoneParameters.orderHashes,
            zoneParameters.startTime,
            zoneParameters.endTime,
            zoneParameters.zoneHash,
            zoneParameters.offer,
            zoneParameters.consideration
        );

        // TradeDetails[] memory tradeDetails = abi.decode(
        //     zoneParameters.extraData,
        //     (TradeDetails[])
        // );

        /**
        
        Server Side Sig Struct:
        - struct TradeDetails {
            uint256 marketId;
            uint256 value;
            uint256 blockNumber;
            bytes tradeData;
            bytes32[] merkleProof;
        }

        zoneHash arguments:
        - maxGasPrice
        - perTrxGasLimit
        - minEthPricePerItem
        - maxEthPricePerItem
        - ethSpendLimit
         */

        // Verify the server signature
        // TODO: write hashTradeDetails in assembly to save gas
        // bytes32 tradeHash = hashTradeDetails(tradeDetails);
        // require(
        //     ECDSA.recover(tradeHash, serverSignature) == serverSigner,
        //     "fulfillOrderWithWeth: invalid server signature"
        // );

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    /**
     * @dev Returns the metadata for this zone.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("TestZone", schemas);
    }
}
