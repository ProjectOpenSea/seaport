// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    ConsiderationEventsAndErrors
} from "contracts/interfaces/ConsiderationEventsAndErrors.sol";

import { ReferenceReentrancyGuard } from "./ReferenceReentrancyGuard.sol";

/**
 * @title NonceManager
 * @author 0age
 * @notice NonceManager contains a storage mapping and related functionality
 *         for retreiving and incrementing a per-offerer nonce.
 */
contract ReferenceNonceManager is
    ConsiderationEventsAndErrors,
    ReferenceReentrancyGuard
{
    // Only orders signed using an offerer's current nonce are fulfillable.
    mapping(address => uint256) private _nonces;

    /**
     * @dev Internal function to cancel all orders from a given offerer with a
     *      given zone in bulk by incrementing a nonce. Note that only the
     *      offerer may increment the nonce.
     *
     * @return newNonce The new nonce.
     */
    function _incrementNonce() internal notEntered returns (uint256 newNonce) {
        // Increment current nonce for the supplied offerer.
        newNonce = ++_nonces[msg.sender];

        // Emit an event containing the new nonce.
        emit NonceIncremented(newNonce, msg.sender);
    }

    /**
     * @dev Internal view function to retrieve the current nonce for a given
     *      offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return currentNonce The current nonce.
     */
    function _getNonce(address offerer)
        internal
        view
        returns (uint256 currentNonce)
    {
        // Return the nonce for the supplied offerer.
        currentNonce = _nonces[offerer];
    }
}
