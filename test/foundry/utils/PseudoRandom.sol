// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract PseudoRandom {
    bytes32 seedHash;

    constructor(bytes32 _seedHash) {
        seedHash = _seedHash;
    }

    function prandUint256() external returns (uint256) {
        return uint256(updateSeedHash());
    }

    function prandBytes32() external returns (bytes32) {
        return updateSeedHash();
    }

    function updateSeedHash() internal returns (bytes32) {
        seedHash = keccak256(abi.encode(seedHash));
        return seedHash;
    }
}
