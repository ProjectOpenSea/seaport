// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC20Interface, ERC721Interface, ERC1155Interface } from "../interfaces/AbridgedTokenInterfaces.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import { Execution, BatchExecution, ReceivedItem } from "../lib/ConsiderationStructs.sol";

/**
 * @title ConsiderationConduit
 * @notice WORK IN PROGRESS! The idea here is that this contract will be another
 *         valid target for "proxied" transfers and will be specified by a new
 *         `conduit` argument on orderParameters, and that the orderType will
 *         now only be 4 options rather than 8 (with 0 being "no conduit" and 1
 *         being "legacy proxy"). The conduit contract will be controlled by
 *         another account (set as an immutable, so any logic around ownership
 *         transfer will live there) that can add and remove "channels" which
 *         are contracts that can instruct the conduit to move ERC20/721/1155
 *         tokens. This lets offerers / facilitators "opt in" to managed upgrade
 *         paths away from the original Consideration contract — they just grant
 *         their preferred conduit the token approvals and the controller of the
 *         conduit adds new channels that are authorized to move those approved
 *         tokens.
 */
contract ConsiderationConduit {
    error ChannelClosed();
    error InvalidController();

    error BadReturnValueFromERC20OnTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    );
    error NoContract(address account);
    error TokenTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    );
    error ERC1155BatchTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256[] tokenIds,
        uint256[] amounts
    );
    error InvalidERC721TransferAmount();

    event ChannelUpdated(address channel, bool open);

    address public immutable controller;

    mapping(address => bool) public channels;

    constructor(address _controller) {
        controller = _controller;
    }

    function execute(
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) external {
        if (!channels[msg.sender]) {
            revert ChannelClosed();
        }

        // Iterate over each standard execution.
        for (uint256 i = 0; i < standardExecutions.length; ) {
            // Retrieve the execution and the associated received item.
            Execution memory execution = standardExecutions[i];
            ReceivedItem memory item = execution.item;

            // Transfer the item specified by the execution.
            _transfer(item, execution.offerer);

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each batch execution.
            for (uint256 i = 0; i < batchExecutions.length; ++i) {
                _batchTransferERC1155(batchExecutions[i]);
            }
        }
    }

    function updateChannel(address channel, bool isOpen) external {
        if (msg.sender != controller) {
            revert InvalidController();
        }

        channels[channel] = isOpen;

        emit ChannelUpdated(channel, isOpen);
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item     The item to transfer, including an amount and recipient.
     * @param offerer  The account offering the item, i.e. the from address.
     */
    function _transfer(ReceivedItem memory item, address offerer) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.ERC20) {
            // Transfer ERC20 token from the offerer to the recipient.
            _transferERC20(item.token, offerer, item.recipient, item.amount);
            // Otherwise, transfer the item based on item type and proxy preference.
        } else if (item.itemType == ItemType.ERC721) {
            // Transfer ERC721 token from the offerer to the recipient.
            _transferERC721(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount
            );
        } else {
            // Transfer ERC1155 token from the offerer to the recipient.
            _transferERC1155(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount
            );
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on this
     *      contract (note that proxies are not utilized for ERC20 items).
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        // Perform ERC20 transfer via the token contract directly.
        bool success = _call(
            token,
            abi.encodeCall(ERC20Interface.transferFrom, (from, to, amount))
        );

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(success, token, from, to, 0, amount);

        // Extract result directly from returndata buffer if one is returned.
        bool result;

        assembly {
            // Default to true if no data is returned.
            result := eq(returndatasize(), 0)

            // Only put result on the stack if return data is at least 32 bytes.
            if gt(returndatasize(), 0x19) {
                // Copy directly from return data into memory in scratch space.
                returndatacopy(0, 0, 0x20)

                // Take the value from scratch space and place it on the stack.
                result := mload(0)
            }
        }

        // If a falsey result is extracted or returndatasize is not zero...
        if (!result) {
            // Revert with a "Bad Return Value" error.
            revert BadReturnValueFromERC20OnTransfer(token, from, to, amount);
        }
    }

    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The "amount" (this value must be equal to one).
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal {
        // Ensure that exactly one 721 item is being transferred.
        if (amount != 1) {
            revert InvalidERC721TransferAmount();
        }

        // Perform transfer, either directly or via proxy.
        bool success = _call(
            token,
            abi.encodeCall(ERC721Interface.transferFrom, (from, to, identifier))
        );

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(success, token, from, to, identifier, 1);
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective proxy or on this contract itself.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The amount to transfer.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal {
        // Perform transfer, either directly or via proxy.
        bool success = _call(
            token,
            abi.encodeWithSelector(
                ERC1155Interface.safeTransferFrom.selector,
                from,
                to,
                identifier,
                amount,
                ""
            )
        );

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(success, token, from, to, identifier, amount);
    }

    /**
     * @dev Internal function to transfer a batch of ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param batchExecution The batch of 1155 tokens to be transferred.
     */
    function _batchTransferERC1155(BatchExecution memory batchExecution)
        internal
    {
        // Place elements of the batch execution in memory onto the stack.
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;

        // Retrieve the tokenIds and amounts.
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;

        // Perform transfer, either directly or via proxy.
        bool success = _call(
            token,
            abi.encodeWithSelector(
                ERC1155Interface.safeBatchTransferFrom.selector,
                from,
                to,
                tokenIds,
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
                tokenIds,
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
     * @dev Internal view function to validate whether a token transfer was
     *      successful based on the returned status and data. Note that
     *      malicious or non-compliant tokens (like fee-on-transfer tokens) may
     *      still return improper data — consider checking token balances before
     *      and after for more comprehensive transfer validation. Also note that
     *      this function must be called after the account in question has been
     *      called and before any other contracts have been called.
     *
     * @param success The status of the call to transfer. Note that contract
     *                size must be checked on status of true and no returned
     *                data to rule out undeployed contracts.
     * @param token   The token to transfer.
     * @param from    The originator of the transfer.
     * @param to      The recipient of the transfer.
     * @param tokenId The tokenId to transfer (if applicable).
     * @param amount  The amount to transfer (if applicable).
     */
    function _assertValidTokenTransfer(
        bool success,
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        // If the call failed...
        if (!success) {
            // Revert and pass reason along if one was returned from the token.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error.
            revert TokenTransferGenericFailure(
                token,
                from,
                to,
                tokenId,
                amount
            );
        }

        // Ensure that the token contract has code.
        _assertContractIsDeployed(token);
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
