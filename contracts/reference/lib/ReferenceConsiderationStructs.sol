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
