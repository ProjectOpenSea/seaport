// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

library ArithmeticUtil {
    ///@dev utility function to avoid overflows when multiplying fuzzed uints with widths <256
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    ///@dev utility function to avoid overflows when adding fuzzed uints with widths <256
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    ///@dev utility function to avoid overflows when subtracting fuzzed uints with widths <256
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    ///@dev utility function to avoid overflows when dividing fuzzed uints with widths <256
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}
