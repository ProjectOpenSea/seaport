//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

/**
 * @dev Enum of functions that set the reentrancy guard
 */
enum EntryPoint {
    FulfillBasicOrder,
    FulfillBasicOrderEfficient,
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
    FulfillBasicOrderEfficient,
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
