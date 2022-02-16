// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

enum OrderType {
    FULL_OPEN,                   // no partial fills, anyone can execute
    PARTIAL_OPEN,                // partial fills supported, anyone can execute
    FULL_RESTRICTED,             // no partial fills, only offerer or facilitator can execute
    PARTIAL_RESTRICTED,          // partial fills supported, only offerer or facilitator can execute
    FULL_OPEN_VIA_PROXY,         // no partial fills, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY,      // partial fills supported, anyone can execute, routed through proxy
    FULL_RESTRICTED_VIA_PROXY,   // no partial fills, only offerer or facilitator can execute, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY // partial fills supported, only offerer or facilitator can execute, routed through proxy
}

enum AssetType {
    ETH,
    ERC20,
    ERC721,
    ERC1155,
    ERC721_WITH_CRITERIA,
    ERC1155_WITH_CRITERIA
}

enum Side {
    OFFER,
    CONSIDERATION
}