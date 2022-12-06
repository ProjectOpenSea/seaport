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

contract TestInvalidContractOffererRatifyOrder is TestContractOfferer {
    constructor(address seaport) TestContractOfferer(seaport) {}

    function ratifyOrder(
        SpentItem[] calldata offer,
        ReceivedItem[] calldata consideration,
        bytes calldata context,
        bytes32[] calldata orderHashes,
        uint256 contractNonce
    ) external pure override returns (bytes4) {
        return bytes4(keccak256("throw"));
    }
}
