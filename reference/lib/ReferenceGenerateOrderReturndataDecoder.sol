// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ReceivedItem,
    SpentItem
} from "../../contracts/lib/ConsiderationStructs.sol";

contract ReferenceGenerateOrderReturndataDecoder {
    function decode(
        bytes calldata returnedBytes
    ) external pure returns (SpentItem[] memory, ReceivedItem[] memory) {
        return abi.decode(returnedBytes, (SpentItem[], ReceivedItem[]));
    }
}
