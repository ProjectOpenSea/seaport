// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

contract ConduitMockInvalidMagic is ConduitInterface {
    constructor() {}

    function execute(
        ConduitTransfer[] calldata /* transfers */
    ) external pure override returns (bytes4) {
        return 0xabcd0000;
    }

    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {}

    function executeWithBatch1155(
        ConduitTransfer[] calldata /* standardTransfers */,
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {}

    function updateChannel(address channel, bool isOpen) external override {}
}
