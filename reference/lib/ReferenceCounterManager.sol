// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ConsiderationEventsAndErrors
} from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";

import { ReferenceReentrancyGuard } from "./ReferenceReentrancyGuard.sol";

/**
 * @title CounterManager
 * @author 0age
 * @notice CounterManager contains a storage mapping and related functionality
 *         for retrieving and incrementing a per-offerer counter.
 */
contract ReferenceCounterManager is
    ConsiderationEventsAndErrors,
    ReferenceReentrancyGuard
{
    // Only orders signed using an offerer's current counter are fulfillable.
    mapping(address => uint256) private _counters;

    /**
     * @dev Internal function to cancel all orders from a given offerer in bulk
     *      by incrementing a counter. Note that only the offerer may increment
     *      the counter.
     *
     * @return newCounter The new counter.
     */
    function _incrementCounter() internal returns (uint256 newCounter) {
        // Use the previous block hash as a quasi-random number.
        uint256 quasiRandomNumber = blockhash(block.number - 1) >> 128;

        // Retrieve the original counter value.
        uint256 originalCounter = _counters[msg.sender];

        // Increment current counter for the supplied offerer.
        newCounter = quasiRandomNumber + originalCounter;

        // Update the counter with the new value.
        _counters[msg.sender] = newCounter;

        // Emit an event containing the new counter.
        emit CounterIncremented(newCounter, msg.sender);
    }

    /**
     * @dev Internal view function to retrieve the current counter for a given
     *      offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return currentCounter The current counter.
     */
    function _getCounter(
        address offerer
    ) internal view returns (uint256 currentCounter) {
        // Return the counter for the supplied offerer.
        currentCounter = _counters[offerer];
    }
}
