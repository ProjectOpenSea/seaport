// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ConduitItemType } from "./ConduitEnums.sol";

struct ConduitTransfer {
    ConduitItemType itemType;
    address token;
    address from;
    address to;
    uint256 identifier;
    uint256 amount;
}

struct ConduitBatch1155Transfer {
    address token;      // 0x00
    address from;       // 0x20
    address to;         // 0x40
    uint256[] ids;      // 0x60: stores 0xa0
    uint256[] amounts;  // 0x80: stores 0xc0 + (ids.length * 32)
    // ids.length          0xa0
}
