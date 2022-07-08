// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

contract ConduitMock is ConduitInterface {
    enum Error {
        None,
        RevertWithNoErrorString,
        RevertWithDataLengthOver256,
        InvalidMagicValue
    }

    bytes4 private immutable _retval;
    Error private immutable _error;

    constructor(bytes4 retval, Error error) {
        _retval = retval;
        _error = error;
    }

    function execute(
        ConduitTransfer[] calldata /* transfers */
    ) external view override returns (bytes4) {
        if (_error == Error.RevertWithNoErrorString) {
            revert InvalidController();
        } else if (_error == Error.RevertWithDataLengthOver256) {
            revert InvalidController();
        } else if (_error == Error.InvalidMagicValue) {
            return 0xabcd0000;
        }

        // Otherwise, we will return the valid magic value.
        return _retval;
    }

    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {
        if (_error == Error.RevertWithNoErrorString) {
            revert();
        } else if (_error == Error.RevertWithDataLengthOver256) {
            revert(
                "RevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevert"
            );
        }
        return _retval;
    }

    function executeWithBatch1155(
        ConduitTransfer[] calldata, /* standardTransfers */
        ConduitBatch1155Transfer[] calldata /*  batch1155Transfers */
    ) external view override returns (bytes4 magicValue) {
        if (_error == Error.RevertWithNoErrorString) {
            revert();
        } else if (_error == Error.RevertWithDataLengthOver256) {
            revert(
                "RevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevertRevert"
            );
        }
        return _retval;
    }

    function updateChannel(address channel, bool isOpen) external override {}
}
