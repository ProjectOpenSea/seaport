// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AmountDegree} from "../../SpaceEnums.sol";
import {bound} from "./GeneratorUtils.sol";

library AmountDegreeGenerator {

    function generate(
        AmountDegree degree,
        uint256 amount
    ) internal pure returns (uint256) {
        if (degree == AmountDegree.SMALL) {
            return bound(amount, 0, 100e18);
        }
        if (degree == AmountDegree.MEDIUM) {
            return bound(amount, 100e18, 1_000_000e18);
        }
        if (degree == AmountDegree.LARGE) {
            return bound(amount, 1_000_000e18, type(uint128).max);
        }
        if (degree == AmountDegree.WUMBO) {
            return bound(amount, type(uint128).max, type(uint256).max);
        }
        return amount;
    }

}