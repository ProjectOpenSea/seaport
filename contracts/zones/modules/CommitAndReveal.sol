// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { BaseZone } from "../BaseZone.sol";

abstract contract CommitAndReveal is BaseZone {
    error MessageAlreadyCommitted();
    error InvalidSecret();

    uint256 private immutable _EXTRA_DATA_INDEX = _VARIABLE_EXTRA_DATA_LENGTH++;

    mapping(bytes32 => uint256) committedTimes;

    function commitMessage(bytes32 messageHash) external {
        if (committedTimes[messageHash] != 0) {
            revert MessageAlreadyCommitted();
        }
        committedTimes[messageHash] = block.timestamp;
    }

    function _validateOrder(bytes32, address) internal view virtual override {
        // Reverts on basic validation call since required data is not available
        revert ExtraDataRequired();
    }

    function _validateOrder(
        bytes32 orderHash,
        address caller,
        bytes[] memory,
        bytes[] memory variableExtraDatas
    ) internal view virtual override {
        bytes32 secret = abi.decode(
            variableExtraDatas[_EXTRA_DATA_INDEX],
            (bytes32)
        );

        bytes32 message = keccak256(
            abi.encodePacked(caller, orderHash, secret)
        );
        uint256 committedTime = committedTimes[message];

        if (
            committedTime + 15 minutes < block.timestamp ||
            committedTime + 5 minutes > block.timestamp
        ) {
            revert InvalidSecret();
        }
    }
}
