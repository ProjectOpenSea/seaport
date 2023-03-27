// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @dev Low level helpers. getTopicsHash and getEventHash are used to generate
 *      the hashes for topics and events respectively. getEventHashWithTopics is
 *      a convenience wrapper around the two.
 */
function getTopicsHash(
    bytes32 topic0,
    bytes32 topic1,
    bytes32 topic2,
    bytes32 topic3
) pure returns (bytes32 topicsHash) {
    topicsHash = keccak256(abi.encode(topic0, topic1, topic2, topic3));
}

function getTopicsHash(
    bytes32 topic0,
    bytes32 topic1,
    bytes32 topic2
) pure returns (bytes32 topicsHash) {
    topicsHash = keccak256(abi.encode(topic0, topic1, topic2));
}

function getTopicsHash(
    bytes32 topic0,
    bytes32 topic1
) pure returns (bytes32 topicsHash) {
    topicsHash = keccak256(abi.encode(topic0, topic1));
}

function getTopicsHash(bytes32 topic0) pure returns (bytes32 topicsHash) {
    topicsHash = keccak256(abi.encode(topic0));
}

function getTopicsHash() pure returns (bytes32 topicsHash) {
    topicsHash = keccak256("");
}

function getEventHash(
    address emitter,
    bytes32 topicsHash,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    return keccak256(abi.encode(emitter, topicsHash, dataHash));
}

function getEventHashWithTopics(
    address emitter,
    bytes32 topic0,
    bytes32 topic1,
    bytes32 topic2,
    bytes32 topic3,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    bytes32 topicsHash = getTopicsHash(topic0, topic1, topic2, topic3);
    return getEventHash(emitter, topicsHash, dataHash);
}

function getEventHashWithTopics(
    address emitter,
    bytes32 topic0,
    bytes32 topic1,
    bytes32 topic2,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    bytes32 topicsHash = getTopicsHash(topic0, topic1, topic2);
    return getEventHash(emitter, topicsHash, dataHash);
}

function getEventHashWithTopics(
    address emitter,
    bytes32 topic0,
    bytes32 topic1,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    bytes32 topicsHash = getTopicsHash(topic0, topic1);
    return getEventHash(emitter, topicsHash, dataHash);
}

function getEventHashWithTopics(
    address emitter,
    bytes32 topic0,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    bytes32 topicsHash = getTopicsHash(topic0);
    return getEventHash(emitter, topicsHash, dataHash);
}

function getEventHashWithTopics(
    address emitter,
    bytes32 dataHash
) pure returns (bytes32 eventHash) {
    bytes32 topicsHash = getTopicsHash();
    return getEventHash(emitter, topicsHash, dataHash);
}
