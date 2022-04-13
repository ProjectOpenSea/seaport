// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

enum OrderType {
    // 0: no partial fills, anyone can execute
    FULL_OPEN_1155,

    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN_1155,

    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_1155,

    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_1155,

    // 4: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_1155,

    // 5: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_1155,

    // 6: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_1155,

    // 7: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_1155

    // 8: no partial fills, anyone can execute
    FULL_OPEN_20,

    // 9: partial fills supported, anyone can execute
    PARTIAL_OPEN_20,

    // 10: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_20,

    // 11: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_20,

    // 12: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_20,

    // 13: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_20,

    // 14: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_20,

    // 15: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_20

    // 16: no partial fills, anyone can execute
    FULL_OPEN_721,

    // 17: partial fills supported, anyone can execute
    PARTIAL_OPEN_721,

    // 18: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_721,

    // 19: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_721,

    // 20: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_721,

    // 21: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_721,

    // 22: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_721,

    // 23: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_721
}

enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,

    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,

    // 2: ERC721 items
    ERC721,

    // 3: ERC1155 items
    ERC1155,

    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,

    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}

enum Side {
    // 0: Items that can be spent
    OFFER,

    // 1: Items that must be received
    CONSIDERATION
}
