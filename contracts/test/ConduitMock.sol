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

contract ConduitMock is Conduit {
    function execute(ConduitTransfer[] calldata transfers)
        external
        override
        onlyOpenChannel
        returns (bytes4 magicValue)
    {
        // Retrieve the total number of transfers and place on the stack.
        uint256 totalStandardTransfers = transfers.length;

        // Iterate over each transfer.
        for (uint256 i = 0; i < totalStandardTransfers; ) {
            // Retrieve the transfer in question and perform the transfer.
            _transfer(transfers[i]);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Return a magic value indicating that the transfers were performed.
        magicValue = 0xabc42069;
    }
}
