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

/**
 * @dev A struct used to hold all the hashes of a Basic Order Fulfillment
 *       used in _prepareBasicFulfillmentFromCalldata and _hashOrder
 */
struct BasicFulfillmentHashes {
    bytes32 typeHash;
    bytes32 orderHash;
    bytes32 offerItemsHash;
    bytes32[] considerationHashes;
    bytes32 receivedItemsHash;
    bytes32 receivedItemHash;
    bytes32 offerItemHash;
}

/**    
* @dev A struct that is an explicit version of advancedOrders without
*       memory optimization, that provides an array of spentItems
*       and receivedItems for fulfillment and event emission.       
*/
struct OrderToExecute {
    address offerer;
    SpentItem[] spentItems; // Offer
    ReceivedItem[] receivedItems; // Consideration
    bytes32 conduitKey;
    uint120 numerator;
}

/**
* @dev  A struct containing the data used to apply a
*       fraction to an order.  
*/
struct FractionData {
    uint256 numerator; // The portion of the order that should be filled.             
    uint256 denominator; // The total size of the order
    bytes32 offererConduitKey; // The offerer's conduit key.
    bytes32 fulfillerConduitKey; // The fulfiller's conduit key.
    uint256 duration; // The total duration of the order.
    uint256 elapsed; // The time elapsed since the order's start time.
    uint256 remaining; // The time left until the order's end time.
}

/**
 * @dev A struct containing conduit transfer data and it's
 *      corresponding conduitKey.   
 */
struct AccumulatorStruct {
    bytes32 conduitKey;
    ConduitTransfer[] transfers;
}
