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

        // Perform transfer, either directly or via proxy.
        bool success = _call(
            token,
            abi.encodeWithSelector(
                ERC1155Interface.safeBatchTransferFrom.selector,
                from,
                to,
                ids,
                amounts,
                ""
            )
        );

        // If the call fails...
        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic 1155 batch transfer error.
            revert ERC1155BatchTransferGenericFailure(
                token,
                from,
                to,
                ids,
                amounts
            );
        }

        // Ensure that a contract is deployed to the token address.
        _assertContractIsDeployed(token);
    }

    /**
     * @dev Internal function to call an arbitrary target with given calldata.
     *      Note that no data is written to memory and no contract size check is
     *      performed.
     *
     * @param target   The account to call.
     * @param callData The calldata to supply when calling the target.
     *
     * @return success The status of the call to the target.
     */
    function _call(address target, bytes memory callData)
        internal
        returns (bool success)
    {
        (success, ) = target.call(callData);
    }

    /**
     * @dev Internal view function to item that a contract is deployed to a
     *      given account. Note that this function must be called after the
     *      account in question has been called and before any other contracts
     *      have been called.
     *
     * @param account The account to check.
     */
    function _assertContractIsDeployed(address account) internal view {
        // Find out whether data was returned by inspecting returndata buffer.
        uint256 returnDataSize;
        assembly {
            returnDataSize := returndatasize()
        }

        // If no data was returned, ensure that the account has code.
        if (returnDataSize == 0 && account.code.length == 0) {
            revert NoContract(account);
        }
    }

    /**
     * @dev Internal pure function to revert and pass along the revert reason if
     *      data was returned by the last call.
     */
    function _revertWithReasonIfOneIsReturned() internal pure {
        // Find out whether data was returned by inspecting returndata buffer.
        uint256 returnDataSize;
        assembly {
            returnDataSize := returndatasize()
        }

        // If no data was returned...
        if (returnDataSize != 0) {
            assembly {
                // Copy returndata to memory, overwriting existing memory.
                returndatacopy(0, 0, returndatasize())

                // Revert, specifying memory region with copied returndata.
                revert(0, returndatasize())
            }
        }
    }
}
