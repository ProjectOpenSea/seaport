// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import { Conduit } from "../conduit/Conduit.sol";

// prettier-ignore
import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

contract ConduitMock is ConduitInterface {
    constructor() {}

    function execute(ConduitTransfer[] calldata /* transfers */)
        external pure override
        returns (bytes4 magicValue)
    {
        return 0xabc42069;
    }

    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external pure override returns (bytes4 magicValue) {
        return 0xabc69420;
    }

    function executeWithBatch1155(
        ConduitTransfer[] calldata /* standardTransfers */,
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external pure override returns (bytes4 magicValue) {
        return 0x42069420;
    }

    function updateChannel(address channel, bool isOpen) external override {}
}
