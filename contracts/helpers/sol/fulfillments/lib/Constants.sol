// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// used to effectively "wipe" the mappings and enumerations each time getAggregated is called
bytes32 constant MATCH_FULFILLMENT_COUNTER_KEY =
    keccak256("MatchFulfillmentHelper.fulfillmentCounter");

bytes32 constant MATCH_FULFILLMENT_STORAGE_BASE_KEY =
    keccak256("MatchFulfillmentHelper.storageBase");
