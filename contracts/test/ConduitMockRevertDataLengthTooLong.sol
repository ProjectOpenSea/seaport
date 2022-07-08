// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

import { ConduitMockErrors } from "./ConduitMockErrors.sol";

contract ConduitMockRevertDataLengthTooLong is
    ConduitMockErrors,
    ConduitInterface
{
    constructor() {}

    function execute(
        ConduitTransfer[] calldata /* transfers */
    ) external view override returns (bytes4) {
        // Revert with data length > 256.
        revert(
            "RevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevert"
        );
    }

    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {}

    function executeWithBatch1155(
        ConduitTransfer[] calldata, /* standardTransfers */
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {}

    function updateChannel(address channel, bool isOpen) external override {}
}
