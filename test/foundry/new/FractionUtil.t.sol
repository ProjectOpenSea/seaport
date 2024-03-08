// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    FractionUtil,
    FractionResults,
    FractionStatus
} from "./helpers/FractionUtil.sol";

contract FractionUtilTest is Test {
    function testGetWholeFillResults() public {
        uint120 currentStatusNumerator = 2;
        uint120 currentStatusDenominator = 3;
        uint120 numeratorToFill = 1;
        uint120 denominatorToFill = 4;

        FractionResults memory results = FractionUtil.getPartialFillResults(
            currentStatusNumerator,
            currentStatusDenominator,
            numeratorToFill,
            denominatorToFill
        );

        assertEq(
            results.realizedNumerator,
            3,
            "Realized numerator should be 3"
        );
        assertEq(
            results.realizedDenominator,
            12,
            "Realized denominator should be 12"
        );
        assertEq(
            results.finalFilledNumerator,
            33,
            "Final filled numerator should be 33"
        );
        assertEq(
            results.finalFilledDenominator,
            36,
            "Final filled denominator should be 36"
        );
        assertEq(
            uint256(results.status),
            uint256(FractionStatus.WHOLE_FILL),
            "Status should be WHOLE_FILL"
        );
    }

    function testGetPartialFillResults() public {
        // Test for PARTIAL_FILL
        uint120 currentStatusNumerator1 = 2;
        uint120 currentStatusDenominator1 = 3;
        uint120 numeratorToFill1 = 1;
        uint120 denominatorToFill1 = 2;

        FractionResults memory results1 = FractionUtil.getPartialFillResults(
            currentStatusNumerator1,
            currentStatusDenominator1,
            numeratorToFill1,
            denominatorToFill1
        );

        assertEq(
            results1.realizedNumerator,
            2,
            "Realized numerator should be 2"
        );
        assertEq(
            results1.realizedDenominator,
            6,
            "Realized denominator should be 6"
        );
        assertEq(
            results1.finalFilledNumerator,
            18,
            "Final filled numerator should be 18"
        );
        assertEq(
            results1.finalFilledDenominator,
            18,
            "Final filled denominator should be 18"
        );
        assertEq(
            uint256(results1.status),
            uint256(FractionStatus.PARTIAL_FILL),
            "Status should be PARTIAL_FILL"
        );
    }

    function testGetWholeFillResultsGCD() public {
        // Test for WHOLE_FILL_GCD
        uint120 currentStatusDenominator = type(uint120).max -
            (type(uint120).max % 3);
        uint120 currentStatusNumerator = (currentStatusDenominator / 3) * 2;

        uint120 numeratorToFill = 2;
        uint120 denominatorToFill = 6;

        FractionResults memory results2 = FractionUtil.getPartialFillResults(
            currentStatusNumerator,
            currentStatusDenominator,
            numeratorToFill,
            denominatorToFill
        );

        assertEq(
            results2.realizedNumerator,
            1,
            "Realized numerator should be 1"
        );
        assertEq(
            results2.realizedDenominator,
            3,
            "Realized denominator should be 3"
        );
        assertEq(
            results2.finalFilledNumerator,
            1,
            "Final filled numerator should be 1"
        );
        assertEq(
            results2.finalFilledDenominator,
            1,
            "Final filled denominator should be 1"
        );
        assertEq(
            uint256(results2.status),
            uint256(FractionStatus.WHOLE_FILL_GCD),
            "Status should be WHOLE_FILL_GCD"
        );
    }

    function testGetPartialFillResultsGCD() public {
        // Test for PARTIAL_FILL_GCD
        uint120 currentStatusDenominator = type(uint120).max -
            (type(uint120).max % 3);
        uint120 currentStatusNumerator = (currentStatusDenominator / 3) * 2;

        uint120 numeratorToFill = 1;
        uint120 denominatorToFill = 2;

        FractionResults memory results3 = FractionUtil.getPartialFillResults(
            currentStatusNumerator,
            currentStatusDenominator,
            numeratorToFill,
            denominatorToFill
        );

        assertEq(
            results3.realizedNumerator,
            1,
            "Realized numerator should be 1"
        );
        assertEq(
            results3.realizedDenominator,
            3,
            "Realized denominator should be 3"
        );
        assertEq(
            results3.finalFilledNumerator,
            1,
            "Final filled numerator should be 1"
        );
        assertEq(
            results3.finalFilledDenominator,
            1,
            "Final filled denominator should be 1"
        );
        assertEq(
            uint256(results3.status),
            uint256(FractionStatus.PARTIAL_FILL_GCD),
            "Status should be PARTIAL_FILL_GCD"
        );
    }

    function testGetInvalidResults() public {
        // Test for INVALID
        // prime?s generated using Miller-Rabin test
        uint120 currentStatusNumerator = 1;
        // 2 ** 119 < prime1 < 2 ** 120
        uint120 currentStatusDenominator = 664613997892457936451903530140172393;
        uint120 numeratorToFill = 1;
        // prime1 < prime2 < 2 ** 120
        uint120 denominatorToFill = 664613997892457936451903530140172297;

        FractionResults memory results4 = FractionUtil.getPartialFillResults(
            currentStatusNumerator,
            currentStatusDenominator,
            numeratorToFill,
            denominatorToFill
        );

        assertEq(
            results4.realizedNumerator,
            0,
            "Realized numerator should be 0"
        );
        assertEq(
            results4.realizedDenominator,
            0,
            "Realized denominator should be 0"
        );
        assertEq(
            results4.finalFilledNumerator,
            0,
            "Final filled numerator should be 0"
        );
        assertEq(
            results4.finalFilledDenominator,
            0,
            "Final filled denominator should be 0"
        );
        assertEq(
            uint256(results4.status),
            uint256(FractionStatus.INVALID),
            "Status should be INVALID"
        );
    }
}
