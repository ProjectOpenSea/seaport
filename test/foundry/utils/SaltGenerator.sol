// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract SaltGenerator {
    bytes32 seed;

    constructor(bytes32 seedHash) {
        seed = seedHash;
    }

    function salt() external returns (uint256) {
        uint256 result = uint256(seed);
        seed = keccak256(abi.encode(seed));
        return result;
    }
}
