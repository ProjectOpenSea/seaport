// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

contract CeilEquivalenceTest {
    function testCeilEquivalence(uint256 numerator, uint256 denominator)
        public
        pure
    {
        uint256 optimized;
        assembly {
            optimized := mul(
                add(div(sub(numerator, 1), denominator), 1),
                iszero(iszero(numerator))
            )
        }

        uint256 unoptimized;
        assembly {
            unoptimized := div(add(numerator, sub(denominator, 1)), denominator)
        }

        assert(optimized == unoptimized);
    }
}
