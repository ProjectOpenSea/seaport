// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    OrderType,
    ItemType
} from "../../lib/ConsiderationEnums.sol";

// This file should only be used by the Reference Implementation

/**
 * @dev A struct used to hold Consideration Indexes and Fulfillment validity.
 */
struct ConsiderationItemIndicesAndValidity {
    uint256 orderIndex;
    uint256 itemIndex;
    bool invalidFulfillment;
}

/**
 * @dev A struct used to hold all Items of an Order to be hashed
 */
struct OrderToHash {
    bytes32 typeHash;
    address offerer;
    address zone;
    bytes32 offerHashes;
    bytes32 considerationHashes;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 nonce;
}

/**
 * @dev A struct used to hold all ItemTypes/Token of a Basic Order Fulfillment
 *       used in _prepareBasicFulfillmentFromCalldata
 */
struct FulfillmentItemTypes {
    OrderType orderType;
    ItemType receivedItemType;
    ItemType additionalRecipientsItemType;
    address additionalRecipientsToken;
    ItemType offeredItemType;
}
