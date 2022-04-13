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
    ETH_TO_ERC721_FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    ETH_TO_ERC721_PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    ETH_TO_ERC721_FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC721_PARTIAL_RESTRICTED,

    // 4: no partial fills, anyone can execute, routed through proxy
    ETH_TO_ERC721_FULL_OPEN_VIA_PROXY,

    // 5: partial fills supported, anyone can execute, routed through proxy
    ETH_TO_ERC721_PARTIAL_OPEN_VIA_PROXY,

    // 6: no partial fills, only offerer zone executes, routed through proxy
    ETH_TO_ERC721_FULL_RESTRICTED_VIA_PROXY,

    // 7: partial fills ok, only offerer or zone executes, routed through proxy
    ETH_TO_ERC721_PARTIAL_RESTRICTED_VIA_PROXY,

    // 8: no partial fills, anyone can execute
    ETH_TO_ERC1155_FULL_OPEN,

    // 9: partial fills supported, anyone can execute
    ETH_TO_ERC1155_PARTIAL_OPEN,

    // 10: no partial fills, only offerer or zone can execute
    ETH_TO_ERC1155_FULL_RESTRICTED,

    // 11: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC1155_PARTIAL_RESTRICTED,

    // 12: no partial fills, anyone can execute, routed through proxy
    ETH_TO_ERC1155_FULL_OPEN_VIA_PROXY,

    // 13: partial fills supported, anyone can execute, routed through proxy
    ETH_TO_ERC1155_PARTIAL_OPEN_VIA_PROXY,

    // 14: no partial fills, only offerer zone executes, routed through proxy
    ETH_TO_ERC1155_FULL_RESTRICTED_VIA_PROXY,

    // 15: partial fills ok, only offerer or zone executes, routed through proxy
    ETH_TO_ERC1155_PARTIAL_RESTRICTED_VIA_PROXY,

    // 16: no partial fills, anyone can execute
    ERC20_TO_ERC721_FULL_OPEN,

    // 17: partial fills supported, anyone can execute
    ERC20_TO_ERC721_PARTIAL_OPEN,

    // 18: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC721_FULL_RESTRICTED,

    // 19: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC721_PARTIAL_RESTRICTED,

    // 20: no partial fills, anyone can execute, routed through proxy
    ERC20_TO_ERC721_FULL_OPEN_VIA_PROXY,

    // 21: partial fills supported, anyone can execute, routed through proxy
    ERC20_TO_ERC721_PARTIAL_OPEN_VIA_PROXY,

    // 22: no partial fills, only offerer zone executes, routed through proxy
    ERC20_TO_ERC721_FULL_RESTRICTED_VIA_PROXY,

    // 23: partial fills ok, only offerer or zone executes, routed through proxy
    ERC20_TO_ERC721_PARTIAL_RESTRICTED_VIA_PROXY,

    // 24: no partial fills, anyone can execute
    ERC20_TO_ERC721_FULL_OPEN,

    // 25: partial fills supported, anyone can execute
    ERC20_TO_ERC721_PARTIAL_OPEN,

    // 26: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC721_FULL_RESTRICTED,

    // 27: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC721_PARTIAL_RESTRICTED,

    // 28: no partial fills, anyone can execute, routed through proxy
    ERC20_TO_ERC721_FULL_OPEN_VIA_PROXY,

    // 29: partial fills supported, anyone can execute, routed through proxy
    ERC20_TO_ERC721_PARTIAL_OPEN_VIA_PROXY,

    // 30: no partial fills, only offerer zone executes, routed through proxy
    ERC20_TO_ERC721_FULL_RESTRICTED_VIA_PROXY,

    // 31: partial fills ok, only offerer or zone executes, routed through proxy
    ERC20_TO_ERC721_PARTIAL_RESTRICTED_VIA_PROXY,

    // 32: no partial fills, anyone can execute
    ERC721_TO_ERC20_FULL_OPEN,

    // 33: partial fills supported, anyone can execute
    ERC721_TO_ERC20_PARTIAL_OPEN,

    // 34: no partial fills, only offerer or zone can execute
    ERC721_TO_ERC20_FULL_RESTRICTED0,

    // 35: partial fills supported, only offerer or zone can execute
    ERC721_TO_ERC20_PARTIAL_RESTRICTED,

    // 36: no partial fills, anyone can execute, routed through proxy
    ERC721_TO_ERC20_ULL_OPEN_VIA_PROXY,

    // 37: partial fills supported, anyone can execute, routed through proxy
    ERC721_TO_ERC20_PARTIAL_OPEN_VIA_PROXY,

    // 38: no partial fills, only offerer zone executes, routed through proxy
    ERC721_TO_ERC20_FULL_RESTRICTED_VIA_PROXY,

    // 39: partial fills ok, only offerer or zone executes, routed through proxy
    ERC721_TO_ERC20_PARTIAL_RESTRICTED_VIA_PROXY,

    // 40: no partial fills, anyone can execute
    ERC1155_TO_ERC20_FULL_OPEN,

    // 41: partial fills supported, anyone can execute
    ERC1155_TO_ERC20_PARTIAL_OPEN,

    // 42: no partial fills, only offerer or zone can execute
    ERC1155_TO_ERC20_FULL_RESTRICTED,

    // 43: partial fills supported, only offerer or zone can execute
    ERC1155_TO_ERC20_PARTIAL_RESTRICTED,

    // 44: no partial fills, anyone can execute, routed through proxy
    ERC1155_TO_ERC20_FULL_OPEN_VIA_PROXY,

    // 45: partial fills supported, anyone can execute, routed through proxy
    ERC1155_TO_ERC20_PARTIAL_OPEN_VIA_PROXY,

    // 46: no partial fills, only offerer zone executes, routed through proxy
    ERC1155_TO_ERC20_FULL_RESTRICTED_VIA_PROXY,

    // 47: partial fills ok, only offerer or zone executes, routed through proxy
    ERC1155_TO_ERC20_PARTIAL_RESTRICTED_VIA_PROXY
}

enum BasicOrderRouteType {
    // 0: provide Ether (or other native token) to receive offered ERC721 item.
    ETH_TO_ERC721,

    // 1: provide Ether (or other native token) to receive offered ERC1155 item.
    ETH_TO_ERC1155,

    // 2: provide ERC20 item to receive offered ERC721 item.
    ERC20_TO_ERC721,

    // 3: provide ERC20 item to receive offered ERC1155 item.
    ERC20_TO_ERC1155,

    // 4: provide ERC721 item to receive offered ERC20 item.
    ERC721_TO_ERC_20,

    // 5: provide ERC1155 item to receive offered ERC20 item.
    ERC1155_TO_ERC_20
}

enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,
    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,
    // 2: ERC721 items
    ERC721,
    // 3: ERC1155 items
    EthForERC1155,
    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,
    // 5: EthForERC1155 items where a number of ids are supported
    EthForERC1155_WITH_CRITERIA
}

enum Side {
    // 0: Items that can be spent
    OFFER,
    // 1: Items that must be received
    CONSIDERATION
}
