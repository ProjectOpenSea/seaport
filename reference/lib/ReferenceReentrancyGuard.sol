// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ReentrancyErrors } from "contracts/interfaces/ReentrancyErrors.sol";

import "contracts/lib/ConsiderationConstants.sol";

/**
 * @title ReentrancyGuard
 * @author 0age
 * @notice ReentrancyGuard contains a storage variable and related functionality
 *         for protecting against reentrancy.
 */
contract ReferenceReentrancyGuard is ReentrancyErrors {
    // Prevent reentrant calls on protected functions.
    uint256 private _reentrancyGuard;

    /**
     * @dev Initialize the reentrancy guard during deployment.
     *
     * @notice You can cut out 10 opcodes in the creation-time EVM bytecode
     * if you declare a constructor `payable`.
     *
     * For more in-depth information see here:
     * https://forum.openzeppelin.com/t/a-collection-of-gas-optimisation-tricks/19966/5
     */
    constructor() payable {
        // Initialize the reentrancy guard in a cleared state.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Modifier to set the reentrancy guard sentinel value for the duration of the call
     */
    modifier nonReentrant() {
        _reentrancyGuard = _ENTERED;
        _;
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Modifier to check that the sentinel value for the reentrancy guard is not currently set
     *      by a previous call
     */
    modifier notEntered() {
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
        _;
    }
}
