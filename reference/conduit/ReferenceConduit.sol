// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ConduitInterface
} from "../../contracts/interfaces/ConduitInterface.sol";

import { ConduitItemType } from "../../contracts/conduit/lib/ConduitEnums.sol";

import {
    ReferenceTokenTransferrer
} from "../lib/ReferenceTokenTransferrer.sol";

import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../../contracts/conduit/lib/ConduitStructs.sol";

/**
 * @title ReferenceConduit
 * @author 0age
 * @notice This contract serves as an originator for "proxied" transfers. Each
 *         conduit contract will be deployed and controlled by a "conduit
 *         controller" that can add and remove "channels" or contracts that can
 *         instruct the conduit to transfer approved ERC20/721/1155 tokens.
 */
contract ReferenceConduit is ConduitInterface, ReferenceTokenTransferrer {
    address private immutable _controller;

    mapping(address => bool) private _channels;

    constructor() {
        _controller = msg.sender;
    }

    /**
     * @notice Execute a sequence of ERC20/721/1155 transfers. Only a caller
     *         with an open channel can call this function. Note that channels
     *         are expected to implement reentrancy protection if desired, and
     *         that cross-channel reentrancy may be possible if the conduit has
     *         multiple open channels at once. Also note that channels are
     *         expected to implement checks against transferring any zero-amount
     *         items if that constraint is desired.
     *
     * @param transfers The ERC20/721/1155 transfers to perform.
     *
     * @return magicValue A magic value indicating that the transfers were
     *                    performed successfully.
     */
    function execute(
        ConduitTransfer[] calldata transfers
    ) external override returns (bytes4 magicValue) {
        // Ensure that the caller is an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        // Perform standard transfers
        _performTransfers(transfers);

        return this.execute.selector;
    }

    /**
     * @notice Execute a sequence of batch 1155 transfers. Only a caller with an
     *         open channel can call this function. Note that channels are
     *         expected to implement reentrancy protection if desired, and that
     *         cross-channel reentrancy may be possible if the conduit has
     *         multiple open channels at once. Also note that channels are
     *         expected to implement checks against transferring any zero-amount
     *         items if that constraint is desired.
     *
     * @param batchTransfers The 1155 batch transfers to perform.
     *
     * @return magicValue A magic value indicating that the transfers were
     *                    performed successfully.
     */
    function executeBatch1155(
        ConduitBatch1155Transfer[] calldata batchTransfers
    ) external override returns (bytes4 magicValue) {
        // Ensure that the caller is an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        uint256 totalBatchTransfers = batchTransfers.length;

        // Iterate over each batch transfer.
        for (uint256 i = 0; i < totalBatchTransfers; ++i) {
            // Retrieve the batch transfer in question.
            ConduitBatch1155Transfer calldata batchTransfer = batchTransfers[i];

            // Perform the batch transfer.
            _batchTransferERC1155(batchTransfer);
        }

        return this.executeBatch1155.selector;
    }

    /**
     * @notice Execute a sequence of transfers, both single and batch 1155. Only
     *         a caller with an open channel can call this function. Note that
     *         channels are expected to implement reentrancy protection if
     *         desired, and that cross-channel reentrancy may be possible if the
     *         conduit has multiple open channels at once. Also note that
     *         channels are expected to implement checks against transferring
     *         any zero-amount items if that constraint is desired.
     *
     * @param standardTransfers The ERC20/721/1155 transfers to perform.
     * @param batchTransfers    The 1155 batch transfers to perform.
     *
     * @return magicValue A magic value indicating that the transfers were
     *                    performed successfully.
     */
    function executeWithBatch1155(
        ConduitTransfer[] calldata standardTransfers,
        ConduitBatch1155Transfer[] calldata batchTransfers
    ) external override returns (bytes4 magicValue) {
        // Ensure that the caller is an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        // Perform standard transfers
        _performTransfers(standardTransfers);

        uint256 totalBatchTransfers = batchTransfers.length;

        // Iterate over each batch transfer.
        for (uint256 i = 0; i < totalBatchTransfers; ++i) {
            // Retrieve the batch transfer in question.
            ConduitBatch1155Transfer calldata batchTransfer = batchTransfers[i];

            // Perform the batch transfer.
            _batchTransferERC1155(batchTransfer);
        }

        return this.executeWithBatch1155.selector;
    }

    /**
     * @notice Open or close a given channel. Only callable by the controller.
     *
     * @param channel The channel to open or close.
     * @param isOpen  The status of the channel (either open or closed).
     */
    function updateChannel(address channel, bool isOpen) external override {
        // Ensure that the caller is the controller.
        if (msg.sender != _controller) {
            revert InvalidController();
        }

        // Ensure that the channel does not already have the indicated status.
        if (_channels[channel] == isOpen) {
            revert ChannelStatusAlreadySet(channel, isOpen);
        }

        // Update the channel status.
        _channels[channel] = isOpen;

        // Emit an event indicating that the channel status was updated.
        emit ChannelUpdated(channel, isOpen);
    }

    /**
     * @dev Internal function to transfer a list of given ERC20/721/1155 items.
     *      Sufficient approvals must be set, either on the respective proxy or
     *      on this contract itself.
     *
     * @param transfers The tokens to be transferred.
     */
    function _performTransfers(ConduitTransfer[] calldata transfers) internal {
        uint256 totalStandardTransfers = transfers.length;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < totalStandardTransfers; ++i) {
            // Retrieve the transfer in question.
            ConduitTransfer calldata standardTransfer = transfers[i];

            // Perform the transfer.
            _transfer(standardTransfer);
        }
    }

    /**
     * @dev Internal function to transfer a given ERC20/721/1155 item. Note that
     *      channels are expected to implement checks against transferring any
     *      zero-amount items if that constraint is desired.
     *
     * @param item The ERC20/721/1155 item to transfer, including an amount and
     *             recipient.
     */
    function _transfer(ConduitTransfer calldata item) internal {
        // Perform the transfer based on the item's type.
        if (item.itemType == ConduitItemType.ERC20) {
            // Transfer ERC20 token. Note that item.identifier is ignored and
            // therefore ERC20 transfer items are potentially malleable — this
            // check should be performed by the calling channel if a constraint
            // on item malleability is desired.
            _performERC20Transfer(item.token, item.from, item.to, item.amount);
        } else if (item.itemType == ConduitItemType.ERC721) {
            // Ensure that exactly one 721 item is being transferred.
            if (item.amount != 1) {
                revert InvalidERC721TransferAmount(item.amount);
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
