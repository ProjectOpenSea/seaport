// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// prettier-ignore
import {
    AmountDerivationErrors
} from "contracts/interfaces/AmountDerivationErrors.sol";

import { FractionData } from "./ReferenceConsiderationStructs.sol";

/**
 * @title ReferenceAmountDeriver
 * @author 0age
 * @notice ReferenceAmountDeriver contains view and pure functions related to
 *         deriving item amounts based on partial fill quantity and on linear
 *         interpolation based on current time when the start amount and end
 *         amount differ.
 */
contract ReferenceAmountDeriver is AmountDerivationErrors {
    /**
     * @dev Internal view function to derive the current amount of a given item
     *      based on the current price, the starting price, and the ending
     *      price. If the start and end prices differ, the current price will be
     *      interpolated on a linear basis.
     *
     * @param startAmount The starting amount of the item.
     * @param endAmount   The ending amount of the item.
     * @param startTime   The starting time of the order.
     * @param endTime     The end time of the order.
     * @param roundUp     A boolean indicating whether the resultant amount
     *                    should be rounded up or down.
     *
     * @return The current amount.
     */
    function _locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            // Leave extra amount to add for rounding at zero (i.e. round down).
            uint256 extraCeiling = 0;

            // Derive the duration for the order and place it on the stack.
            uint256 duration = endTime - startTime;

            // Derive time elapsed since the order started & place on stack.
            uint256 elapsed = block.timestamp - startTime;

            // Derive time remaining until order expires and place on stack.
            uint256 remaining = duration - elapsed;

            // If rounding up, set rounding factor to one less than denominator.
            if (roundUp) {
                extraCeiling = duration - 1;
            }

            // Aggregate new amounts weighted by time with rounding factor.
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed) +
                extraCeiling);

            // Divide totalBeforeDivision by duration to get the new amount.
            uint256 newAmount = totalBeforeDivision / duration;

            // Return the current amount.
            return newAmount;
        }

        // Return the original amount.
        return endAmount;
    }

    /**
     * @dev Internal pure function to return a fraction of a given value and to
     *      ensure the resultant value does not have any fractional component.
     *
     * @param numerator   A value indicating the portion of the order that
     *                    should be filled.
     * @param denominator A value indicating the total size of the order.
     * @param value       The value for which to compute the fraction.
     *
     * @return newValue The value after applying the fraction.
     */
    function _getFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * numerator;

        // Divide that value by the denominator to get the new value.
        newValue = valueTimesNumerator / denominator;

        // Ensure that division gave a final result with no remainder.
        bool exact = ((newValue * denominator) / numerator) == value;
        if (!exact) {
            revert InexactFraction();
        }
    }

    /**
     * @dev Internal view function to apply a fraction to a consideration
     * or offer item.
     *
     * @param startAmount     The starting amount of the item.
     * @param endAmount       The ending amount of the item.
     * @param fractionData    A struct containing the data used to apply a
     *                        fraction to an order.
     * @param roundUp         A boolean indicating whether the resultant
     *                        amount should be rounded up or down.
     *
     * @return amount The received item to transfer with the final amount.
     */
    function _applyFraction(
        uint256 startAmount,
        uint256 endAmount,
        FractionData memory fractionData,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (startAmount == endAmount) {
            amount = _getFraction(
                fractionData.numerator,
                fractionData.denominator,
                endAmount
            );
        } else {
            // Otherwise, apply fraction to both to interpolated final amount.
            amount = _locateCurrentAmount(
                _getFraction(
                    fractionData.numerator,
                    fractionData.denominator,
                    startAmount
                ),
                _getFraction(
                    fractionData.numerator,
                    fractionData.denominator,
                    endAmount
                ),
                fractionData.startTime,
                fractionData.endTime,
                roundUp
            );
        }
    }
}
