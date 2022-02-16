// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {
    OrderType,
    AssetType,
    Side
} from "./Enums.sol";

struct AdditionalRecipient {
    address payable account;
    uint256 amount;
}

struct BasicOrderParameters {
    address payable offerer;
    address facilitator;
    OrderType orderType;
    address token;
    uint256 identifier;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    bool useFulfillerProxy;
    bytes signature;
    AdditionalRecipient[] additionalRecipients;
}

struct OfferedAsset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

struct ReceivedAsset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable account;
}

struct OrderParameters {
    address offerer;
    address facilitator;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    OfferedAsset[] offer;
    ReceivedAsset[] consideration;
}

struct OrderComponents {
    address offerer;
    address facilitator;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    OfferedAsset[] offer;
    ReceivedAsset[] consideration;
    uint256 nonce;
}

struct FulfillmentComponent {
    uint256 orderIndex;
    uint256 assetIndex;
}

struct Fulfillment {
    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;
}

struct Execution {
    ReceivedAsset asset;
    address offerer;
    bool useProxy;
}

struct Order {
    OrderParameters parameters;
    bytes signature;
}

struct OrderStatus {
    bool isValidated;
    bool isCancelled;
    uint120 numerator;
    uint120 denominator;
}

struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}