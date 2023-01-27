// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SpentItem, ReceivedItem } from "../lib/ConsiderationStructs.sol";

import { TestContractOfferer } from "./TestContractOfferer.sol";

contract TestInvalidContractOfferer is TestContractOfferer {
    error RevertWithData(bytes revertData);

    constructor(address seaport) TestContractOfferer(seaport) {}

    function generateOrder(
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata context
    )
        external
        pure
        override
        returns (SpentItem[] memory, ReceivedItem[] memory)
    {
        revert RevertWithData(context);
    }
}
