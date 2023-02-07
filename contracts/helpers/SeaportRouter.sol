// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    SeaportRouterInterface
} from "../interfaces/SeaportRouterInterface.sol";

import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

import { ReentrancyGuard } from "../lib/ReentrancyGuard.sol";

import {
    Execution,
    AdvancedOrder,
    CriteriaResolver,
    FulfillmentComponent
} from "../lib/ConsiderationStructs.sol";

/**
 * @title  SeaportRouter
 * @author Ryan Ghods (ralxz.eth), 0age (0age.eth), James Wenzel (emo.eth)
 * @notice A utility contract for fulfilling orders with multiple
 *         Seaport versions.
 */
contract SeaportRouter is SeaportRouterInterface, ReentrancyGuard {
    /// @dev The allowed v1.1 contract usable through this router.
    address private immutable _SEAPORT_V1_1;
    /// @dev The allowed v1.2 contract usable through this router.
    address private immutable _SEAPORT_V1_2;

    /**
     * @dev Deploy contract with the supported Seaport contracts.
     *
     * @param seaportV1point1 The address of the Seaport v1.1 contract.
     * @param seaportV1point2 The address of the Seaport v1.2 contract.
     */
    constructor(address seaportV1point1, address seaportV1point2) {
        _SEAPORT_V1_1 = seaportV1point1;
        _SEAPORT_V1_2 = seaportV1point2;
    }

    /**
     * @dev Fallback function to receive excess ether, in case total amount of
     *      ether sent is more than the amount required to fulfill the order.
     */
    receive() external payable override {
        // Ensure we only receive ether from Seaport.
        _assertSeaportAllowed(msg.sender);
    }

    /**
     * @notice Fulfill available advanced orders through multiple Seaport
     *         versions.
     *         See {SeaportInterface-fulfillAvailableAdvancedOrders}
     *
     * @param params The parameters for fulfilling available advanced orders.
     */
    function fulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersParams calldata params
    )
        external
        payable
        override
        returns (
            bool[][] memory availableOrders,
            Execution[][] memory executions
        )
    {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard(true);

        // Put the number of Seaport contracts on the stack.
        uint256 seaportContractsLength = params.seaportContracts.length;

        // Set the availableOrders and executions arrays to the correct length.
        availableOrders = new bool[][](seaportContractsLength);
        executions = new Execution[][](seaportContractsLength);

        // Track the number of order fulfillments left.
        uint256 fulfillmentsLeft = params.maximumFulfilled;

        // To help avoid stack too deep errors, we format the calldata
        // params in a struct and put it on the stack.
        CalldataParams memory calldataParams = CalldataParams({
            advancedOrders: new AdvancedOrder[](0),
            criteriaResolvers: new CriteriaResolver[](0),
            offerFulfillments: new FulfillmentComponent[][](0),
            considerationFulfillments: new FulfillmentComponent[][](0),
            fulfillerConduitKey: params.fulfillerConduitKey,
            recipient: params.recipient,
            maximumFulfilled: fulfillmentsLeft
        });

        // Iterate through the provided Seaport contracts.
        for (uint256 i = 0; i < params.seaportContracts.length; ) {
            // Ensure the provided Seaport contract is allowed.
            _assertSeaportAllowed(params.seaportContracts[i]);

            // Put the order params on the stack.
            AdvancedOrderParams calldata orderParams = params
                .advancedOrderParams[i];

            // Assign the variables to the calldata params.
            calldataParams.advancedOrders = orderParams.advancedOrders;
            calldataParams.criteriaResolvers = orderParams.criteriaResolvers;
            calldataParams.offerFulfillments = orderParams.offerFulfillments;
            calldataParams.considerationFulfillments = orderParams
                .considerationFulfillments;

            // Execute the orders, collecting availableOrders and executions.
            // This is wrapped in a try/catch in case a single order is
            // executed that is no longer available, leading to a revert
            // with `NoSpecifiedOrdersAvailable()`.
            try
                SeaportInterface(params.seaportContracts[i])
                    .fulfillAvailableAdvancedOrders{
                    value: orderParams.etherValue
                }(
                    calldataParams.advancedOrders,
                    calldataParams.criteriaResolvers,
                    calldataParams.offerFulfillments,
                    calldataParams.considerationFulfillments,
                    calldataParams.fulfillerConduitKey,
                    calldataParams.recipient,
                    calldataParams.maximumFulfilled
                )
            returns (
                bool[] memory newAvailableOrders,
                Execution[] memory newExecutions
            ) {
                availableOrders[i] = newAvailableOrders;
                executions[i] = newExecutions;

                // Subtract the number of orders fulfilled.
                uint256 newAvailableOrdersLength = newAvailableOrders.length;
                for (uint256 j = 0; j < newAvailableOrdersLength; ) {
                    if (newAvailableOrders[j]) {
                        unchecked {
                            --fulfillmentsLeft;
                            ++j;
                        }
                    }
                }

                // Break if the maximum number of executions has been reached.
                if (fulfillmentsLeft == 0) {
                    break;
                }
            } catch {}

            // Update fulfillments left.
            calldataParams.maximumFulfilled = fulfillmentsLeft;

            unchecked {
                ++i;
            }
        }

        // Return excess ether that may not have been used or was sent back.
        if (address(this).balance > 0) {
            _returnExcessEther();
        }

        // Clear the reentrancy guard.
        _clearReentrancyGuard();
    }

    /**
     * @notice Returns the Seaport contracts allowed to be used through this
     *         router.
     */
    function getAllowedSeaportContracts()
        external
        view
        override
        returns (address[] memory seaportContracts)
    {
        seaportContracts = new address[](2);
        seaportContracts[0] = _SEAPORT_V1_1;
        seaportContracts[1] = _SEAPORT_V1_2;
    }

    /**
     * @dev Reverts if the provided Seaport contract is not allowed.
     */
    function _assertSeaportAllowed(address seaport) internal view {
        if (
            _cast(seaport == _SEAPORT_V1_1) | _cast(seaport == _SEAPORT_V1_2) ==
            0
        ) {
            revert SeaportNotAllowed(seaport);
        }
    }

    /**
     * @dev Function to return excess ether, in case total amount of
     *      ether sent is more than the amount required to fulfill the order.
     */
    function _returnExcessEther() private {
        // Send received funds back to msg.sender.
        (bool success, bytes memory data) = payable(msg.sender).call{
            value: address(this).balance
        }("");

        // Revert with an error if the ether transfer failed.
        if (!success) {
            revert EtherReturnTransferFailed(
                msg.sender,
                address(this).balance,
                data
            );
        }
    }
}
