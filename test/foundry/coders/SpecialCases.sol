// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import "../../../contracts/lib/ConsiderationConstants.sol";

import {
    BasicOrderParameters,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    ConsiderationItem
} from "../../../contracts/lib/ConsiderationStructs.sol";

import {
    CalldataPointer,
    getFreeMemoryPointer,
    MemoryPointer
} from "../../../contracts/helpers/PointerLibraries.sol";

import {
    ConsiderationEncoder
} from "../../../contracts/lib/ConsiderationEncoder.sol";

contract SpecialCases {
    function _setEndAmountRecipient(ConsiderationItem memory consideration)
        internal pure
    {
        address recipient = consideration
            .toMemoryPointer()
            .offset(ConsiderItem_recipient_offset)
            .readAddress();
        consideration.toMemoryPointer().offset(Common_endAmount_offset).write(
            recipient
        );
    }
}
