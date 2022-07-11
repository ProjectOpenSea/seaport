// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

contract ConduitMockRevertBytes is ConduitInterface {
    constructor() {}

    error CustomError();

    function execute(
        ConduitTransfer[] calldata /* transfers */
    ) external view override returns (bytes4) {
        // Revert with data.length != 0 && data.length < 256.
        // bytes memory revertData = "36e5236fcd4c61044949678014f0d085";
        // if (revertData.length != 32) {
        //     revert("Incorrect length");
        // }
        // bytes memory revertDataStringBytes = abi.encode(string(revertData));
        // uint256 stringLength = revertDataStringBytes.length;

        // assembly {
        //     revert(add(0x20, revertDataStringBytes), stringLength)
        // }
        // assembly {
        //     let pointer := mload(0x40)
        //     mstore(pointer, "36e5236fcd4c61044949678014f0d085")
        //     revert(pointer, 32)
        // }
        revert CustomError();
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
