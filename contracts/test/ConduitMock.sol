// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

contract ConduitMock is ConduitInterface {
    constructor() {}

    function execute(ConduitTransfer[] calldata transfers)
        external
        pure
        override
        returns (bytes4 magicValue)
    {
        // To test for more coverage paths, if transfers.length > 10,
        // then revert with empty reason.
        if (transfers.length > 10) {
            revert();
        }
        // Otherwise, we will return an invalid magic value.
        return 0xabc42069;
    }

    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external pure override returns (bytes4 magicValue) {
        return 0xabc69420;
    }

    function executeWithBatch1155(
        ConduitTransfer[] calldata, /* standardTransfers */
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external pure override returns (bytes4 magicValue) {
        return 0x42069420;
    }

    function updateChannel(address channel, bool isOpen) external override {}
}
