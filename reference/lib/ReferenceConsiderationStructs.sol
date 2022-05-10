// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    OrderType,
    ItemType
} from "contracts/lib/ConsiderationEnums.sol";

import { SpentItem, ReceivedItem } from "contracts/lib/ConsiderationStructs.sol";

import { ConduitTransfer } from "contracts/conduit/lib/ConduitStructs.sol";

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

struct OrderToExecute {
    address offerer;
    SpentItem[] spentItems; // Offer
    ReceivedItem[] receivedItems; // Consideration
    bytes32 conduitKey;
    uint120 numerator;
}

struct FractionData {
    uint256 numerator;
    uint256 denominator;
    bytes32 offererConduitKey;
    bytes32 fulfillerConduitKey;
    uint256 duration;
    uint256 elapsed;
    uint256 remaining;
}

struct AccumulatorStruct {
    bytes32 conduitKey;
    ConduitTransfer[] transfers;
}
