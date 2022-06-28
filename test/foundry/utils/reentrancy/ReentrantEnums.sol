//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/**
 * @dev Enum of functions that set the reentrancy guard
 */
enum EntryPoint {
    FulfillBasicOrder,
    FulfillOrder,
    FulfillAdvancedOrder,
    FulfillAvailableOrders,
    FulfillAvailableAdvancedOrders,
    MatchOrders,
    MatchAdvancedOrders
}

/**
 * @dev Enum of functions that check the reentrancy guard
 */
enum ReentryPoint {
    FulfillBasicOrder,
    FulfillOrder,
    FulfillAdvancedOrder,
    FulfillAvailableOrders,
    FulfillAvailableAdvancedOrders,
    MatchOrders,
    MatchAdvancedOrders,
    Cancel,
    Validate,
    IncrementCounter
}
