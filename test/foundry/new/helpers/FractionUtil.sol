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
        uint256 finalNumerator;
        uint256 finalDenominator;

        // if the denominators are different, we need to convert the numerator to the same denominator
        if (currentStatusDenominator != denominatorToFill) {
            finalNumerator =
                uint256(currentStatusNumerator) *
                denominatorToFill +
                uint256(numeratorToFill) *
                currentStatusDenominator;

            finalDenominator =
                uint256(currentStatusDenominator) *
                denominatorToFill;
        } else {
            // if the denominators are the same, we can just add the numerators
            finalNumerator = uint256(currentStatusNumerator) + numeratorToFill;
            finalDenominator = currentStatusDenominator;
        }

        uint256 realizedNumerator;
        uint256 realizedDenominator;
        bool partialFill;
        if (finalNumerator > finalDenominator) {
            partialFill = true;
            // the numerator is larger than the denominator, so entire order is filled
            finalNumerator = finalDenominator;
            // the realized numerator is the remaining portion that was actually filled
            realizedNumerator =
                finalDenominator -
                (uint256(currentStatusNumerator) * denominatorToFill);
            realizedDenominator = finalDenominator;
        } else {
            partialFill = false;
            realizedNumerator = numeratorToFill;
            realizedDenominator = denominatorToFill;
        }

        bool applyGcd;
        // reduce by gcd if necessary
        if (finalDenominator > type(uint120).max) {
            applyGcd = true;
            // the denominator is too large to fit in a uint120, so we need to reduce it

            if (partialFill) {
                uint256 gcd = _gcd(realizedNumerator, finalDenominator);
                finalNumerator /= gcd;
                finalDenominator /= gcd;
                // if the order was partially filled, we need to reduce the realized numerator and denominator as well
                realizedNumerator /= gcd;
                realizedDenominator /= gcd;
            } else {
                uint256 gcd = _gcd(finalNumerator, finalDenominator);
                finalNumerator /= gcd;
                finalDenominator /= gcd;
            }
        }

        if (finalDenominator > type(uint120).max) {
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
        return
            FractionResults({
                realizedNumerator: uint120(realizedNumerator),
                realizedDenominator: uint120(realizedDenominator),
                finalFilledNumerator: uint120(finalNumerator),
                finalFilledDenominator: uint120(finalDenominator),
                originalStatusNumerator: currentStatusNumerator,
                originalStatusDenominator: currentStatusDenominator,
                requestedNumerator: numeratorToFill,
                requestedDenominator: denominatorToFill,
                status: status
            });
    }
}