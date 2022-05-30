// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { ConduitItemType } from "../conduit/lib/ConduitEnums.sol";

struct TransferHelperItem {
    ConduitItemType itemType;
    address token;
    uint256 tokenIdentifier;
    uint256 amount;
}
