// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ConduitItemType } from "./ConduitEnums.sol";

/**
 * @dev A ConduitTransfer is a struct that contains the information needed for a
 *      conduit to transfer an item from one address to another.
 */
struct ConduitTransfer {
    ConduitItemType itemType;
    address token;
    address from;
    address to;
    uint256 identifier;
    uint256 amount;
}

/**
 * @dev A ConduitBatch1155Transfer is a struct that contains the information
 *      needed for a conduit to transfer a batch of ERC-1155 tokens from one
 *      address to another.
 */
struct ConduitBatch1155Transfer {
    address token;
    address from;
    address to;
    uint256[] ids;
    uint256[] amounts;
}
