// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

contract ExternalCounter {
    uint256 public value;

    function increment() external returns (uint256) {
        return value++;
    }
}
