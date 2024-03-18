//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum FractionStatus {
    INVALID,
    WHOLE_FILL,
    WHOLE_FILL_GCD,
    PARTIAL_FILL,
    PARTIAL_FILL_GCD
}

struct FractionResults {
    uint120 realizedNumerator;
    uint120 realizedDenominator;
    uint120 finalFilledNumerator;
    uint120 finalFilledDenominator;
    uint120 originalStatusNumerator;
    uint120 originalStatusDenominator;
    uint120 requestedNumerator;
    uint120 requestedDenominator;
    FractionStatus status;
}

/**
 * @dev Helper utilities for calculating partial fill fractions.
 */
library FractionUtil {
    function _gcd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 temp;
        while (b != 0) {
            temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    }

    function getPartialFillResults(
        uint120 currentStatusNumerator,
        uint120 currentStatusDenominator,
        uint120 numeratorToFill,
        uint120 denominatorToFill
    ) internal pure returns (FractionResults memory) {
        uint256 filledNumerator = uint256(currentStatusNumerator);
        uint256 filledDenominator = uint256(currentStatusDenominator);
        uint256 numerator = uint256(numeratorToFill);
        uint256 denominator = uint256(denominatorToFill);
        bool partialFill;
        bool applyGcd;

        // If denominator of 1 supplied, fill all remaining amount on order.
        if (denominator == 1) {
            // Scale numerator & denominator to match current denominator.
            numerator = filledDenominator;
            denominator = filledDenominator;
        }
        // Otherwise, if supplied denominator differs from current one...
        else if (filledDenominator != denominator) {
            // scale current numerator by the supplied denominator, then...
            filledNumerator *= denominator;

            // the supplied numerator & denominator by current denominator.
            numerator *= filledDenominator;
            denominator *= filledDenominator;
        }

        // Once adjusted, if current+supplied numerator exceeds denominator:
        if (filledNumerator + numerator > denominator) {
            // Reduce current numerator so it + supplied = denominator.
            numerator = denominator - filledNumerator;

            partialFill = true;
        }

        // Increment the filled numerator by the new numerator.
        filledNumerator += numerator;

        // Ensure fractional amounts are below max uint120.
        if (
            filledNumerator > type(uint120).max ||
            denominator > type(uint120).max
        ) {
            applyGcd = true;

            // Derive greatest common divisor using euclidean algorithm.
            uint256 scaleDown = _gcd(
                numerator,
                _gcd(filledNumerator, denominator)
            );

            // Scale all fractional values down by gcd.
            numerator = numerator / scaleDown;
            filledNumerator = filledNumerator / scaleDown;
            denominator = denominator / scaleDown;
        }

        if (denominator > type(uint120).max) {
            return
                FractionResults({
                    realizedNumerator: 0,
                    realizedDenominator: 0,
                    finalFilledNumerator: 0,
                    finalFilledDenominator: 0,
                    originalStatusNumerator: currentStatusNumerator,
                    originalStatusDenominator: currentStatusDenominator,
                    requestedNumerator: numeratorToFill,
                    requestedDenominator: denominatorToFill,
                    status: FractionStatus.INVALID
                });
        }
        FractionStatus status;
        if (partialFill && applyGcd) {
            status = FractionStatus.PARTIAL_FILL_GCD;
        } else if (partialFill) {
            status = FractionStatus.PARTIAL_FILL;
        } else if (applyGcd) {
            status = FractionStatus.WHOLE_FILL_GCD;
        } else {
            status = FractionStatus.WHOLE_FILL;
        }

        uint120 realizedNumerator = uint120(numerator);
        uint120 realizedDenominator = uint120(denominator);

        filledNumerator = currentStatusNumerator;

        // if supplied denominator differs from current one...
        if (currentStatusDenominator != denominator) {
            // scale current numerator by the supplied denominator, then...
            filledNumerator *= denominator;

            // the supplied numerator & denominator by current denominator.
            numerator *= currentStatusDenominator;
            denominator *= currentStatusDenominator;
        }

        // Increment the filled numerator by the new numerator.
        filledNumerator += numerator;

        // Ensure fractional amounts are below max uint120.
        if (
            filledNumerator > type(uint120).max ||
            denominator > type(uint120).max
        ) {
            // Derive greatest common divisor using euclidean algorithm.
            uint256 scaleDown = _gcd(filledNumerator, denominator);

            // Scale new filled fractional values down by gcd.
            filledNumerator = filledNumerator / scaleDown;
            denominator = denominator / scaleDown;
        }

        return
            FractionResults({
                realizedNumerator: realizedNumerator,
                realizedDenominator: realizedDenominator,
                finalFilledNumerator: uint120(filledNumerator),
                finalFilledDenominator: uint120(denominator),
                originalStatusNumerator: currentStatusNumerator,
                originalStatusDenominator: currentStatusDenominator,
                requestedNumerator: numeratorToFill,
                requestedDenominator: denominatorToFill,
                status: status
            });
    }
}
