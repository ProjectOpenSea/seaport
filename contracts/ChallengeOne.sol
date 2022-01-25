pragma solidity 0.8.11;

contract ChallengeOne {
    error InexactDivision();

    function exactDivide(
        uint128 numerator,
        uint128 denominator,
        uint256 value
    ) public pure returns (uint256 newValue) {
        newValue = (value * uint256(numerator)) / uint256(denominator);
        if (value != (newValue * uint256(denominator)) / uint256(numerator)) {
            revert InexactDivision();
        }
    }
}