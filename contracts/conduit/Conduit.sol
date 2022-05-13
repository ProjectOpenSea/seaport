// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { ConduitItemType } from "./lib/ConduitEnums.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import "../lib/ConsiderationConstants.sol";

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
 *         to transfer approved ERC20/721/1155 tokens.
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
     *         with an open channel can call this function.
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
            revert ChannelClosed();
        }

        // Retrieve the total number of transfers and place on the stack.
        uint256 totalStandardTransfers = transfers.length;

        // Iterate over each transfer.
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

        // Return a magic value indicating that the transfers were performed.
        return this.execute.selector;
    }

    /**
     * @notice Execute a sequence of transfers, both single and batch 1155. Only
     *         a caller with an open channel can call this function.
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
            revert ChannelClosed();
        }

        // Retrieve the total number of transfers and place on the stack.
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

        // Retrieve the total number of batch transfers and place on the stack.

        _performERC1155BatchTransfers(batchTransfers);

        // Return a magic value indicating that the transfers were performed.
        return this.execute.selector;
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

        // Update the status of the channel.
        _channels[channel] = isOpen;

        // Emit a corresponding event.
        emit ChannelUpdated(channel, isOpen);
    }

    /**
     * @dev Internal function to transfer a given ERC20/721/1155 item.
     *
     * @param item The ERC20/721/1155 item to transfer.
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
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement onReceived to indicate that they are willing to accept the
     *      transfer.
     */
    function _performERC1155BatchTransfers(
        ConduitBatch1155Transfer[] calldata batchTransfers
    ) internal {
        // Utilize assembly to perform an optimized ERC1155 token transfer.
        assembly {
            let len := batchTransfers.length
            // Pointer to first head in the array, which is offset to the struct
            // at each index. This gets incremented after each loop to avoid
            // multiplying by 32 to get the offset for each element.
            let nextElementHeadPtr := batchTransfers.offset

            // Pointer to beginning of the head of the array. This is the reference
            // position each offset references. It's held static to let each loop
            // calculate the data position for an element.
            let arrayHeadPtr := nextElementHeadPtr

            // Write the function selector for safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
            // This will be reused for each call
            mstore(0x20, ERC1155_safeBatchTransferFrom_selector)

            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                // Read the offset to the beginning of the element and add
                // it to pointer to the beginning of the array head to get
                // the absolute position of the element in calldata.
                let elementPtr := add(
                    arrayHeadPtr,
                    calldataload(nextElementHeadPtr)
                )

                // Update the offset position for the next loop
                nextElementHeadPtr := add(nextElementHeadPtr, 0x20)

                // Copy head from calldata
                calldatacopy(
                  BatchTransfer1155Params_ptr,
                  add(elementPtr, ConduitBatch1155Transfer_from_offset),
                  ConduitBatch1155Transfer_usable_head_size
                )

                let idsLength := calldataload(
                    add(elementPtr, ConduitBatch1155Transfer_ids_length_offset)
                )
                let idsAndAmountsSize := add(0x40, mul(idsLength, 0x40))

                mstore(
                  BatchTransfer1155Params_data_head_ptr,
                  add(
                    BatchTransfer1155Params_ids_length_offset,
                    idsAndAmountsSize
                  )
                )

                mstore(
                  add(BatchTransfer1155Params_data_length_basePtr, idsAndAmountsSize),
                  0x00
                )

                let transferDataSize := add(
                    0x104,
                    mul(idsLength, 0x40)
                )

                calldatacopy(
                  BatchTransfer1155Params_ids_length_ptr,
                  add(elementPtr, ConduitBatch1155Transfer_ids_length_offset),
                  idsAndAmountsSize
                )

                let expectedAmountsOffset := add(
                    ConduitBatch1155Transfer_amounts_length_baseOffset,
                    mul(idsLength, 0x20)
                )

                // Validate struct encoding
                let invalidEncoding := iszero(
                    and(
                        // ids.length == amounts.length
                        eq(
                            idsLength,
                            calldataload(add(elementPtr, expectedAmountsOffset))
                        ),
                        and(
                            // ids_offset == 0xa0
                            eq(
                                calldataload(
                                    add(
                                        elementPtr,
                                        ConduitBatch1155Transfer_ids_head_offset
                                    )
                                ),
                                0xa0
                            ),
                            // amounts_offset == 0xc0 + ids.length*32
                            eq(
                                calldataload(
                                    add(
                                        elementPtr,
                                        ConduitBatch1155Transfer_amounts_head_offset
                                    )
                                ),
                                expectedAmountsOffset
                            )
                        )
                    )
                )

                if invalidEncoding {
                    mstore(Invalid1155BatchTransferEncoding_ptr, Invalid1155BatchTransferEncoding_selector)
                    revert(Invalid1155BatchTransferEncoding_ptr, Invalid1155BatchTransferEncoding_length)
                }

                let token := calldataload(elementPtr)

                // If the token has no code, revert.
                if iszero(extcodesize(token)) {
                    mstore(NoContract_error_sig_ptr, NoContract_error_signature)
                    mstore(NoContract_error_token_ptr, token)
                    revert(NoContract_error_sig_ptr, NoContract_error_length)
                }

                let success := call(
                    gas(),
                    token,
                    0,
                    0x20, // Start of the "data" portion of callData.
                    transferDataSize, // Location of the length of callData.
                    0,
                    0
                )

                // If the transfer reverted:
                if iszero(success) {
                    // If it returned a message, bubble it up as long as sufficient
                    // gas remains to do so:
                    if returndatasize() {
                        // Ensure that sufficient gas is available to copy
                        // returndata while expanding memory where necessary. Start
                        // by computing word size of returndata & allocated memory.
                        let returnDataWords := div(returndatasize(), 0x20)

                        // Note: use transferDataSize in place of msize() to work around a Yul
                        // warning that prevents accessing msize directly when the IR pipeline is activated.
                        // We do not use the free memory pointer because this contract does almost all memory
                        // management manually and does not update it, and transferDataSize should be the
                        // highest memory value used (unless a previous batch was higher)
                        let msizeWords := div(
                            transferDataSize,
                            0x20
                        )

                        // Next, compute the cost of the returndatacopy.
                        let cost := mul(3, returnDataWords)

                        // Then, compute cost of new memory allocation.
                        if gt(returnDataWords, msizeWords) {
                            cost := add(
                                cost,
                                add(
                                    mul(sub(returnDataWords, msizeWords), 3),
                                    div(
                                        sub(
                                            mul(
                                                returnDataWords,
                                                returnDataWords
                                            ),
                                            mul(msizeWords, msizeWords)
                                        ),
                                        0x200
                                    )
                                )
                            )
                        }

                        // Finally, add a small constant and compare to gas
                        // remaining; bubble up the revert data if enough gas is
                        // still available.
                        if lt(add(cost, 0x20), gas()) {
                            // Copy returndata to memory; overwrite existing memory.
                            returndatacopy(0, 0, returndatasize())

                            // Revert, giving memory region with copied returndata.
                            revert(0, returndatasize())
                        }
                    }

                    // Set the error signature
                    mstore(
                        0x00,
                        ERC1155BatchTransferGenericFailure_error_signature
                    )

                    // Write the token
                    mstore(0x04, token)

                    // Move the ids and amounts offsets forward a word
                    mstore(
                        BatchTransfer1155Params_ids_head_ptr,
                        ConduitBatch1155Transfer_amounts_head_offset
                    )
                    mstore(
                        BatchTransfer1155Params_amounts_head_ptr,
                        add(
                            0x20,
                            mload(BatchTransfer1155Params_amounts_head_ptr)
                        )
                    )

                    // Return modified region with one fewer word at the end.
                    revert(0x00, add(transferDataSize, 0x24))
                }
            }

            // reset the free memory pointer to the default value.
            mstore(0x40, 0x80)
        }
    }
}
