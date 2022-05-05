// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// prettier-ignore
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

struct BasicFulfillmentHashes {
    bytes32 typeHash;
    bytes32 orderHash;
    bytes32 offerItemsHash;
    bytes32[] considerationHashes;
    bytes32 receivedItemsHash;
    bytes32 receivedItemHash;
    bytes32 offerItemHash;
}
