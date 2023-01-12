// SPDX-License-Identifier: MIT
//Author: Saw-mon and Natalie

pragma solidity ^0.8.17;

import { ConsiderationInterface } from
    "../../contracts/interfaces/ConsiderationInterface.sol";

import {
    NonMatchSelector_MagicMask,
    NonMatchSelector_InvalidErrorValue
} from "../../contracts/lib/ConsiderationConstants.sol";

import { Test } from "forge-std/Test.sol";

contract NonMatchSelectorTest is Test {
    function testNonMatchSelectorMagicMaskAndInvalidErrorValue() public {
        assertEq(
            NonMatchSelector_MagicMask + 1, NonMatchSelector_InvalidErrorValue
        );
    }

    function testSelectorMatchOrders() public {
        _testSelector(ConsiderationInterface.matchOrders.selector, false);
    }

    function testSelectorMatchAdvancedOrders() public {
        _testSelector(
            ConsiderationInterface.matchAdvancedOrders.selector, false
        );
    }

    function testSelectorFulfillAvailableOrders() public {
        _testSelector(
            ConsiderationInterface.fulfillAvailableOrders.selector, true
        );
    }

    function testSelectorFulfillAvailableAdvancedOrders() public {
        _testSelector(
            ConsiderationInterface.fulfillAvailableAdvancedOrders.selector, true
        );
    }

    function _testSelector(bytes4 selector, bool shouldBeSelected) internal {
        bool isSelected;

        assembly {
            isSelected :=
                eq(
                    NonMatchSelector_MagicMask,
                    and(NonMatchSelector_MagicMask, selector)
                )
        }

        assertEq(isSelected, shouldBeSelected);
    }
}
