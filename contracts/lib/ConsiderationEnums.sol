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
    FULL_OPEN_EthForERC721,

    // 1: partial fills supported, anyone can execute
    PARTIAL_OPEN_EthForERC721,

    // 2: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_EthForERC721,

    // 3: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_EthForERC721,

    // 4: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_EthForERC721,

    // 5: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_EthForERC721,

    // 6: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_EthForERC721,

    // 7: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_EthForERC721,

    //new section
    // 8: no partial fills, anyone can execute
    FULL_OPEN_EthForERC1155,

    // 9: partial fills supported, anyone can execute
    PARTIAL_OPEN_EthForERC1155,

    // 10: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_EthForERC1155,

    // 11: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_EthForERC1155,

    // 12: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_EthForERC1155,

    // 13: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_EthForERC1155,

    // 14: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_EthForERC1155,

    // 15: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_EthForERC1155

    //new section
    // 16: no partial fills, anyone can execute
    FULL_OPEN_ERC20ForERC721,

    // 17: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC20ForERC721,

    // 18: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC20ForERC721,

    // 19: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC20ForERC721,

    // 20: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC20ForERC721,

    // 21: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC20ForERC721,

    // 22: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC20ForERC721,

    // 23: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC20ForERC721

    //new section
    // 24: no partial fills, anyone can execute
    FULL_OPEN_ERC20ForERC1155,

    // 25: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC20ForERC1155,

    // 26: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC20ForERC1155,

    // 27: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC20ForERC1155,

    // 28: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC20ForERC1155,

    // 29: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC20ForERC1155,

    // 30: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC20ForERC1155,

    // 31: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC20ForERC1155

    //new section
    // 32: no partial fills, anyone can execute
    FULL_OPEN_ERC721ForERC20,

    // 33: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC721ForERC20,

    // 34: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC721ForERC20,

    // 35: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC721ForERC20,

    // 36: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC721ForERC20,

    // 37: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC721ForERC20,

    // 38: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC721ForERC20,

    // 39: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC721ForERC20

    //new section
    // 40: no partial fills, anyone can execute
    FULL_OPEN_ERC1155ForERC20,

    // 41: partial fills supported, anyone can execute
    PARTIAL_OPEN_ERC1155ForERC20,

    // 42: no partial fills, only offerer or zone can execute
    FULL_RESTRICTED_ERC1155ForERC20,

    // 43: partial fills supported, only offerer or zone can execute
    PARTIAL_RESTRICTED_ERC1155ForERC20,

    // 44: no partial fills, anyone can execute, routed through proxy
    FULL_OPEN_VIA_PROXY_ERC1155ForERC20,

    // 45: partial fills supported, anyone can execute, routed through proxy
    PARTIAL_OPEN_VIA_PROXY_ERC1155ForERC20,

    // 46: no partial fills, only offerer zone executes, routed through proxy
    FULL_RESTRICTED_VIA_PROXY_ERC1155ForERC20,

    // 47: partial fills ok, only offerer or zone executes, routed through proxy
    PARTIAL_RESTRICTED_VIA_PROXY_ERC1155ForERC20
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
