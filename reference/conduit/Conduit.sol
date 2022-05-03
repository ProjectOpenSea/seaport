// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// prettier-ignore
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { ConduitItemType } from "./lib/ConduitEnums.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

// prettier-ignore
import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "./lib/ConduitStructs.sol";

/**
 * @title Conduit
 * @author 0age
 * @notice This contract serves as an originator for "proxied" transfers. Each
 *         conduit contract will be deployed and controlled by a "conduit
 *         controller" that can add and remove "channels" or contracts that can
 *         instruct the conduit to transfer approved ERC20/721/1155 tokens.
 */
contract Conduit is ConduitInterface, TokenTransferrer {
    address private immutable _controller;

    mapping(address => bool) private _channels;

    constructor() {
        _controller = msg.sender;
    }

    function execute(ConduitTransfer[] calldata transfers)
        external
        override
        returns (bytes4 magicValue)
    {
        if (!_channels[msg.sender]) {
            revert ChannelClosed();
        }

        uint256 totalStandardTransfers = transfers.length;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < totalStandardTransfers; ) {
            // Retrieve the transfer in question.
            ConduitTransfer calldata standardTransfer = transfers[i];

            // Perform the transfer.
            _transfer(standardTransfer);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        return this.execute.selector;
    }

    function executeWithBatch1155(
        ConduitTransfer[] calldata standardTransfers,
        ConduitBatch1155Transfer[] calldata batchTransfers
    ) external override returns (bytes4 magicValue) {
        if (!_channels[msg.sender]) {
            revert ChannelClosed();
        }

        uint256 totalStandardTransfers = standardTransfers.length;

        // Iterate over each standard transfer.
        for (uint256 i = 0; i < totalStandardTransfers; ) {
            // Retrieve the transfer in question.
            ConduitTransfer calldata standardTransfer = standardTransfers[i];

            // Perform the transfer.
            _transfer(standardTransfer);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        uint256 totalBatchTransfers = batchTransfers.length;

        // Iterate over each batch transfer.
        for (uint256 i = 0; i < totalBatchTransfers; ) {
            // Retrieve the batch transfer in question.
            ConduitBatch1155Transfer calldata batchTransfer = batchTransfers[i];

            // Perform the batch transfer.
            _batchTransferERC1155(batchTransfer);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        return this.execute.selector;
    }

    function updateChannel(address channel, bool isOpen) external override {
        if (msg.sender != _controller) {
            revert InvalidController();
        }

        _channels[channel] = isOpen;

        emit ChannelUpdated(channel, isOpen);
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item     The item to transfer, including an amount and recipient.
     */
    function _transfer(ConduitTransfer calldata item) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ConduitItemType.ERC20) {
            // Transfer ERC20 token.
            _performERC20Transfer(item.token, item.from, item.to, item.amount);
        } else if (item.itemType == ConduitItemType.ERC721) {
            // Ensure that exactly one 721 item is being transferred.
            if (item.amount != 1) {
                revert InvalidERC721TransferAmount();
            }

            // Transfer ERC721 token.
            _performERC721Transfer(
                item.token,
                item.from,
                item.to,
                item.identifier
            );
        } else if (item.itemType == ConduitItemType.ERC1155) {
            // Transfer ERC1155 token.
            _performERC1155Transfer(
                item.token,
                item.from,
                item.to,
                item.identifier,
                item.amount
            );
        } else {
            // Throw with an error.
            revert InvalidItemType();
        }
    }

    /**
     * @dev Internal function to transfer a batch of ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param batchTransfer The batch of 1155 tokens to be transferred.
     */
    function _batchTransferERC1155(
        ConduitBatch1155Transfer calldata batchTransfer
    ) internal {
        // Place elements of the batch execution in memory onto the stack.
        address token = batchTransfer.token;
        address from = batchTransfer.from;
        address to = batchTransfer.to;

        // Retrieve the tokenIds and amounts.
        uint256[] calldata ids = batchTransfer.ids;
        uint256[] calldata amounts = batchTransfer.amounts;

        // Perform optimized batch 1155 transfer.
        _performERC1155BatchTransfer(token, from, to, ids, amounts);
    }
}
