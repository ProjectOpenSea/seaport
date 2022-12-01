// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import { SpentItem, ReceivedItem } from "../lib/ConsiderationStructs.sol";

import { TestContractOfferer } from "./TestContractOfferer.sol";

contract TestInvalidContractOfferer is TestContractOfferer {
    error RevertWithData(bytes revertData);

    constructor(address seaport) TestContractOfferer(seaport) {}

    function generateOrder(
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata context
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        revert RevertWithData(context);
    }
}
