// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitItemType } from "../conduit/lib/ConduitEnums.sol";

struct TransferHelperItem {
    ConduitItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

struct TransferHelperItemsWithRecipient {
    TransferHelperItem[] items;
    address recipient;
    /* Pass true to call onERC721Received on a recipient contract. */
    bool validateERC721Receiver;
}
