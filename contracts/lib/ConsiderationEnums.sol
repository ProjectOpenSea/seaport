// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

enum OrderType {
    // 0: no partial fills, anyone can execute
    FULL_OPEN,
    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN,
    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED,
    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED,
    // 4: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY,
    // 5: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY,
    // 6: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY,
    // 7: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY
}

enum BasicOrderType {
    // 0: no partial fills, anyone can execute
    FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED,

    // 4: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY,

    // 5: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY,

    // 6: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY,

    // 7: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY,

    // 8: no partial fills, anyone can execute
    FULL_OPEN_ERC721,

    // 9: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC721,

    // 10: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC721,

    // 11: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC721,

    // 12: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC721,

    // 13: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC721,

    // 14: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC721,

    // 15: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC721,

    // 16: no partial fills, anyone can execute
    FULL_OPEN_ERC1155,

    // 17: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC1155,

    // 18: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC1155,

    // 19: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC1155,

    // 20: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC1155,

    // 21: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC1155,

    // 22: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC1155,

    // 23: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC1155
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
