// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ReentrancyErrors
} from "seaport-types/src/interfaces/ReentrancyErrors.sol";

import {
    _ENTERED_AND_ACCEPTING_NATIVE_TOKENS_SSTORE,
    _ENTERED_SSTORE,
    _NOT_ENTERED_SSTORE
} from "seaport-types/src/lib/ConsiderationConstants.sol";

/**
 * @title ReentrancyGuard
 * @author 0age
 * @notice ReentrancyGuard contains a storage variable and related functionality
 *         for protecting against reentrancy.
 */
contract ReferenceReentrancyGuard is
    ConsiderationEventsAndErrors,
    ReentrancyErrors
{
    // Prevent reentrant calls on protected functions.
    uint256 private _reentrancyGuard;

    /**
     * @dev Initialize the reentrancy guard during deployment.
     */
    constructor() {
        // Initialize the reentrancy guard in a cleared state.
        _reentrancyGuard = _NOT_ENTERED_SSTORE;
    }

    /**
     * @dev Modifier to check that the sentinel value for the reentrancy guard
     *      is not currently set by a previous call.
     */
    modifier notEntered() {
        if (_reentrancyGuard != _NOT_ENTERED_SSTORE) {
            revert NoReentrantCalls();
        }

        _;
    }

    /**
     * @dev Modifier to set the reentrancy guard sentinel value for the duration
     *      of the call and check if it is already set by a previous call.
     *
     * @param acceptNativeTokens A boolean indicating whether native tokens may
     *                           be received during execution or not.
     */
    modifier nonReentrant(bool acceptNativeTokens) {
        if (_reentrancyGuard != _NOT_ENTERED_SSTORE) {
            revert NoReentrantCalls();
        }

        if (acceptNativeTokens) {
            _reentrancyGuard = _ENTERED_AND_ACCEPTING_NATIVE_TOKENS_SSTORE;
        } else {
            _reentrancyGuard = _ENTERED_SSTORE;
        }

        _;

        _reentrancyGuard = _NOT_ENTERED_SSTORE;
    }

    /**
     * @dev Internal view function to ensure that the sentinel value indicating
     *      native tokens may be received during execution is currently set.
     */
    function _assertAcceptingNativeTokens() internal view {
        // Ensure that the reentrancy guard is not currently set.
        if (_reentrancyGuard != _ENTERED_AND_ACCEPTING_NATIVE_TOKENS_SSTORE) {
            revert InvalidMsgValue(msg.value);
        }
    }
}
