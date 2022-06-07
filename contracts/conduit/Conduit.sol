// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

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
 *         conduit is deployed and controlled by a "conduit controller" that can
 *         add and remove "channels" or contracts that can instruct the conduit
 *         to transfer approved ERC20/721/1155 tokens. *IMPORTANT NOTE: each
 *         conduit has an owner that can arbitrarily add or remove channels, and
 *         a malicious or negligent owner can add a channel that allows for any
 *         approved ERC20/721/1155 tokens to be taken immediately — be extremely
 *         cautious with what conduits you give token approvals to!*
 */
contract Conduit is ConduitInterface, TokenTransferrer {
    // Set deployer as an immutable controller that can update channel statuses.
    address private immutable _controller;

    // Track the status of each channel.
    mapping(address => bool) private _channels;

    /**
     * @notice In the constructor, set the deployer as the controller.
     */
    constructor() {
        // Set the deployer as the controller.
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
    function execute(ConduitTransfer[] calldata transfers)
        external
        override
        returns (bytes4 magicValue)
    {
        // Ensure that the caller has an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        // Retrieve the total number of transfers and place on the stack.
        uint256 totalStandardTransfers = transfers.length;

        // Iterate over each transfer.
        for (uint256 i = 0; i < totalStandardTransfers; ) {

            // Perform the transfer.
            _transfer(transfers[i]);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.execute.selector;
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
        // Ensure that the caller has an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        // Perform 1155 batch transfers. Note that memory should be considered
        // entirely corrupted from this point forward.
        _performERC1155BatchTransfers(batchTransfers);

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.executeBatch1155.selector;
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
        // Ensure that the caller has an open channel.
        if (!_channels[msg.sender]) {
            revert ChannelClosed(msg.sender);
        }

        // Retrieve the total number of transfers and place on the stack.
        uint256 totalStandardTransfers = standardTransfers.length;

        // Iterate over each standard transfer.
        for (uint256 i = 0; i < totalStandardTransfers; ) {

            // Perform the transfer.
            _transfer(standardTransfers[i]);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Perform 1155 batch transfers. Note that memory should be considered
        // entirely corrupted from this point forward.
        _performERC1155BatchTransfers(batchTransfers);

        // Return a magic value indicating that the transfers were performed.
        magicValue = this.executeWithBatch1155.selector;
    }

    /**
     * @notice Open or close a given channel. Only callable by the controller.
     *
     * @param channel The channel to open or close.
     * @param isOpen  The status of the channel (either open or closed).
     */
    function updateChannel(address channel, bool isOpen) external override {
        // Ensure that the caller is the controller of this contract.
        if (msg.sender != _controller) {
            revert InvalidController();
        }

        // Ensure that the channel does not already have the indicated status.
        if (_channels[channel] == isOpen) {
            revert ChannelStatusAlreadySet(channel, isOpen);
        }

        // Update the status of the channel.
        _channels[channel] = isOpen;

        // Emit a corresponding event.
        emit ChannelUpdated(channel, isOpen);
    }

    /**
     * @dev Internal function to transfer a given ERC20/721/1155 item. Note that
     *      channels are expected to implement checks against transferring any
     *      zero-amount items if that constraint is desired.
     *
     * @param item The ERC20/721/1155 item to transfer.
     */
    function _transfer(ConduitTransfer calldata item) internal {
        // Determine the transfer method based on the respective item type.
        if (item.itemType == ConduitItemType.ERC20) {
            // Transfer ERC20 token. Note that item.identifier is ignored and
            // therefore ERC20 transfer items are potentially malleable — this
            // check should be performed by the calling channel if a constraint
            // on item malleability is desired.
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
}
