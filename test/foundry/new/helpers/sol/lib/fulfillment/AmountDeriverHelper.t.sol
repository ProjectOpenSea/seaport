// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    AmountDeriverHelper
} from "seaport-sol/src/lib/fulfillment/AmountDeriverHelper.sol";

contract TestAmountDeriverHelper is AmountDeriverHelper {
    function applyFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 startTime,
        uint256 endTime,
        uint256 startAmount,
        uint256 endAmount,
        bool roundUp
    ) public view returns (uint256) {
        return
            _applyFraction({
                numerator: numerator,
                denominator: denominator,
                startAmount: startAmount,
                endAmount: endAmount,
                startTime: startTime,
                endTime: endTime,
                roundUp: roundUp // round up considerations
            });
    }

    function getFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 value
    ) public pure returns (uint256) {
        return
            _getFraction({
                numerator: numerator,
                denominator: denominator,
                value: value
            });
    }

    function locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) public view returns (uint256) {
        return
            _locateCurrentAmount({
                startAmount: startAmount,
                endAmount: endAmount,
                startTime: startTime,
                endTime: endTime,
                roundUp: roundUp
            });
    }
}

contract AmountDeriverHelperTest is Test {
    TestAmountDeriverHelper helper;

    function setUp() public {
        helper = new TestAmountDeriverHelper();
    }

    function coerceNumeratorAndDenominator(
        uint120 numerator,
        uint120 denominator
    ) internal view returns (uint120 newNumerator, uint120 newDenominator) {
        numerator = uint120(bound(numerator, 1, type(uint120).max));
        denominator = uint120(bound(denominator, 1, type(uint120).max));
        if (numerator > denominator) {
            (numerator, denominator) = (denominator, numerator);
        }
        return (numerator, denominator);
    }

    function testDeriveFractionCompatibleAmountsAndTimes(
        uint256 originalStartAmount,
        uint256 originalEndAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 currentTime,
        uint120 numerator,
        uint120 denominator
    ) public {
        startTime = bound(startTime, 1, type(uint40).max - 2);
        endTime = bound(endTime, startTime + 1, type(uint40).max);

        (numerator, denominator) = coerceNumeratorAndDenominator(
            numerator,
            denominator
        );

        originalStartAmount = bound(originalStartAmount, 1, type(uint256).max);
        originalEndAmount = bound(originalEndAmount, 1, type(uint256).max);

        (uint256 newStartAmount, uint256 newEndAmount) = helper
            .deriveFractionCompatibleAmounts(
                originalStartAmount,
                originalEndAmount,
                startTime,
                endTime,
                numerator,
                denominator
            );

        currentTime = bound(currentTime, startTime, endTime - 1);

        vm.warp(currentTime);

        // will revert if invalid
        helper.applyFraction({
            numerator: numerator,
            denominator: denominator,
            startTime: startTime,
            endTime: endTime,
            startAmount: newStartAmount,
            endAmount: newEndAmount,
            roundUp: false
        });

        // will revert if invalid
        helper.applyFraction({
            numerator: numerator,
            denominator: denominator,
            startTime: startTime,
            endTime: endTime,
            startAmount: newStartAmount,
            endAmount: newEndAmount,
            roundUp: true
        });
    }
}
