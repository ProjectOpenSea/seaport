// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderType, ItemType, Side } from "./ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "./ConsiderationStructs.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

import "./ConsiderationConstants.sol";

/**
 * @title ConsiderationPure
 * @author 0age
 * @notice ConsiderationPure contains all pure functions.
 */
contract ConsiderationPure is ConsiderationBase {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController           A contract that deploys conduits, or
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC20+721+1155
     *                                    tokens.
     */
    constructor(address conduitController)
        ConsiderationBase(conduitController)
    {}

    /**
     * @dev Internal pure function to "compress" executions, splitting them into
     *      "standard" (or unbatched) executions and "batch" executions. Note
     *      that there may be additional compression that could be performed,
     *      such as allowing contrarian orders to cancel one another.
     *
     * @param executions An array of uncompressed executions.
     *
     * @return standardExecutions An array of executions that were not able to
     *                            be compressed.
     * @return batchExecutions    An array of executions (all ERC1155 transfers)
     *                            that have been compressed into batches.
     */
    function _compressExecutions(Execution[] memory executions)
        internal
        pure
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            // Read executions array length from memory and place on the stack.
            uint256 totalExecutions = executions.length;

            // Return early if less than two executions are provided.
            if (totalExecutions <= 1) {
                return (executions, new BatchExecution[](0));
            }

            // Determine the toal number of ERC1155 executions in the array.
            uint256 total1155Executions = 0;

            // Allocate array in memory for indices of each ERC1155 execution.
            uint256[] memory indexBy1155 = new uint256[](totalExecutions);

            // Iterate over each execution.
            for (uint256 i = 0; i < totalExecutions; ++i) {
                // If the item specified by the execution is an ERC1155 item...
                if (executions[i].item.itemType == ItemType.ERC1155) {
                    // Set index of 1155 execution in memory, then increment it.
                    indexBy1155[total1155Executions++] = i;
                }
            }

            // Return early if less than two ERC1155 executions are located.
            if (total1155Executions <= 1) {
                return (executions, new BatchExecution[](0));
            }

            // Allocate array to track potential ERC1155 batch executions.
            Batch[] memory batches = new Batch[](total1155Executions);

            // Read initial execution index from memory and place on the stack.
            uint256 initialExecutionIndex = indexBy1155[0];

            // Get hash from initial token, offerer, recipient, & proxy usage.
            bytes32 hash = _getHashByExecutionIndex(
                executions,
                initialExecutionIndex
            );

            // Allocate an array of length 1 in memory for the execution index.
            uint256[] memory executionIndices = new uint256[](1);

            // Populate the memory region with the initial execution index.
            executionIndices[0] = initialExecutionIndex;

            // Set hash and array with execution index as first batch element.
            batches[0].hash = hash;
            batches[0].executionIndices = executionIndices;

            // Track total number of unique hashes (starts at one).
            uint256 uniqueHashes = 1;

            // Iterate over each additional 1155 execution.
            for (uint256 i = 1; i < total1155Executions; ++i) {
                // Read execution index from memory and place on the stack.
                uint256 executionIndex = indexBy1155[i];

                // Derive hash based on the same parameters as the initial hash.
                hash = _getHashByExecutionIndex(executions, executionIndex);

                // Assume no matching hash exists unless proven otherwise.
                bool foundMatchingHash = false;

                // Iterate over all known unique hashes.
                for (uint256 j = 0; j < uniqueHashes; ++j) {
                    // If the hash matches the known unique hash in question...
                    if (hash == batches[j].hash) {
                        // Retrieve execution index of the original execution.
                        uint256[] memory oldExecutionIndices = (
                            batches[j].executionIndices
                        );

                        // Place old execution indices array length on stack.
                        uint256 originalLength = oldExecutionIndices.length;

                        // Allocate execution indices array w/ an extra element.
                        uint256[] memory newExecutionIndices = (
                            new uint256[](originalLength + 1)
                        );

                        // Iterate over existing execution indices.
                        for (uint256 k = 0; k < originalLength; ++k) {
                            // Add them to the new execution indices array.
                            newExecutionIndices[k] = oldExecutionIndices[k];
                        }

                        // Add new execution index to the end of the array.
                        newExecutionIndices[originalLength] = executionIndex;

                        // Update the batch with the extended array.
                        batches[j].executionIndices = newExecutionIndices;

                        // Mark that new hash matches one already in a batch.
                        foundMatchingHash = true;

                        // Stop scanning for a match as one has now been found.
                        break;
                    }
                }

                // If no matching hash was located, create a new batch element.
                if (!foundMatchingHash) {
                    // Create a new execution indices array.
                    executionIndices = new uint256[](1);

                    // Set the current execution index as the first element.
                    executionIndices[0] = executionIndex;

                    // Set next batch element and increment total unique hashes.
                    batches[uniqueHashes].hash = hash;
                    batches[uniqueHashes++].executionIndices = executionIndices;
                }
            }

            // Return early if every hash is unique.
            if (uniqueHashes == total1155Executions) {
                return (executions, new BatchExecution[](0));
            }

            // Allocate an array to track the batch each execution is used in.
            // Values of zero indicate that it is not used in a batch, whereas
            // non-zero values indicate the execution index *plus one*.
            uint256[] memory usedInBatch = new uint256[](totalExecutions);

            // Stack elements have been exhausted, so utilize memory to track
            // total elements used as part of a batch as well as total batches.
            uint256[] memory totals = new uint256[](2);

            // Iterate over each potential batch (determined via unique hashes).
            for (uint256 i = 0; i < uniqueHashes; ++i) {
                // Retrieve the indices for the batch in question.
                uint256[] memory indices = batches[i].executionIndices;

                // Read total number of indices from memory and place on stack.
                uint256 indicesLength = indices.length;

                // if more than one execution applies to a potential batch...
                if (indicesLength >= 2) {
                    // Increment the total number of batches.
                    ++totals[1];

                    // Increment total executions used as part of a batch.
                    totals[0] += indicesLength;

                    // Iterate over each execution index for the batch.
                    for (uint256 j = 0; j < indicesLength; ++j) {
                        // Update array tracking batch the execution applies to.
                        usedInBatch[indices[j]] = i + 1;
                    }
                }
            }

            // Split executions into standard and batched executions and return.
            // prettier-ignore
            return _splitExecution(
                    executions,
                    batches,
                    usedInBatch,
                    totals[0],
                    totals[1]
                );
        }
    }

    /**
     * @dev Internal pure function to complete the process of "compressing"
     *      executions and return both unbatched and batched execution arrays.
     *
     * @param executions             An array of uncompressed executions.
     * @param batches                An array of elements indicating which
     *                               executions form the "baseline" for a batch.
     * @param batchExecutionPointers An array of indices, incremented by one (as
     *                               zero indicates no batching), that each
     *                               point to a respective batch per execution.
     * @param totalUsedInBatch       The total execution elements to batch.
     * @param totalBatches           The total number of batch executions.
     *
     * @return An array of executions that could not be compressed.
     * @return An array of executions (all ERC1155 transfers) that have been
     *         compressed into batches.
     */
    function _splitExecution(
        Execution[] memory executions,
        Batch[] memory batches,
        uint256[] memory batchExecutionPointers,
        uint256 totalUsedInBatch,
        uint256 totalBatches
    ) internal pure returns (Execution[] memory, BatchExecution[] memory) {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            // Read executions array length from memory and place on the stack.
            uint256 totalExecutions = executions.length;

            // Allocate standard executions array (exclude ones used in batch).
            Execution[] memory standardExecutions = new Execution[](
                totalExecutions - totalUsedInBatch
            );

            // Allocate batch executions array (length equal to total batches).
            BatchExecution[] memory batchExecutions = new BatchExecution[](
                totalBatches
            );

            // Track the index of the next available standard execution element.
            uint256 nextStandardExecutionIndex = 0;

            // Allocate array in memory to track next element index per batch.
            uint256[] memory batchElementIndices = new uint256[](totalBatches);

            // Iterate over each execution.
            for (uint256 i = 0; i < totalExecutions; ++i) {
                // Check if execution is standard (0) or part of a batch (1+).
                uint256 batchExecutionPointer = batchExecutionPointers[i];

                // Retrieve the execution element.
                Execution memory execution = executions[i];

                // If the execution is a standard execution...
                if (batchExecutionPointer == 0) {
                    // Copy it to next standard index, then increment the index.
                    standardExecutions[nextStandardExecutionIndex++] = (
                        execution
                    );
                    // Otherwise, it is a batch execution.
                } else {
                    // Decrement pointer to derive the batch execution index.
                    uint256 batchIndex = batchExecutionPointer - 1;

                    // If it is the first item applied to the batch execution...
                    if (batchExecutions[batchIndex].token == address(0)) {
                        // Determine total elements in batch and place on stack.
                        uint256 totalElements = (
                            batches[batchIndex].executionIndices.length
                        );

                        // Populate all other fields using execution parameters.
                        batchExecutions[batchIndex] = BatchExecution(
                            execution.item.token, // token
                            execution.offerer, // from
                            execution.item.recipient, // to
                            new uint256[](totalElements), // tokenIds
                            new uint256[](totalElements), // amounts
                            execution.conduitKey // conduitKey
                        );
                    }

                    // Put next batch element index on stack, then increment it.
                    uint256 batchElementIndex = (
                        batchElementIndices[batchIndex]++
                    );

                    // Update current element's batch with respective tokenId.
                    batchExecutions[batchIndex].tokenIds[batchElementIndex] = (
                        execution.item.identifier
                    );

                    // Retrieve execution item amount and place on the stack.
                    uint256 amount = execution.item.amount;

                    // Ensure that the amount is non-zero.
                    _assertNonZeroAmount(amount);

                    // Update current element's batch with respective amount.
                    batchExecutions[batchIndex].amounts[batchElementIndex] = (
                        amount
                    );
                }
            }

            // Return both the standard and batch execution arrays.
            return (standardExecutions, batchExecutions);
        }
    }

    /**
     * @dev Internal pure function to validate that a given order is fillable
     *      and not cancelled based on the order status.
     *
     * @param orderHash       The order hash.
     * @param orderStatus     The status of the order, including whether it has
     *                        been cancelled and the fraction filled.
     * @param onlyAllowUnused A boolean flag indicating whether partial fills
     *                        are supported by the calling function.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order has been cancelled or filled beyond the
     *                        allowable amount.
     *
     * @return valid A boolean indicating whether the order is valid.
     */
    function _verifyOrderStatus(
        bytes32 orderHash,
        OrderStatus memory orderStatus,
        bool onlyAllowUnused,
        bool revertOnInvalid
    ) internal pure returns (bool valid) {
        // Ensure that the order has not been cancelled.
        if (orderStatus.isCancelled) {
            // Only revert if revertOnInvalid has been supplied as true.
            if (revertOnInvalid) {
                revert OrderIsCancelled(orderHash);
            }

            // Return false as the order status is invalid.
            return false;
        }

        // If the order is not entirely unused...
        if (orderStatus.numerator != 0) {
            // ensure the order has not been partially filled when not allowed.
            if (onlyAllowUnused) {
                // Always revert on partial fills when onlyAllowUnused is true.
                revert OrderPartiallyFilled(orderHash);
                // Otherwise, ensure that order has not been entirely filled.
            } else if (orderStatus.numerator >= orderStatus.denominator) {
                // Only revert if revertOnInvalid has been supplied as true.
                if (revertOnInvalid) {
                    revert OrderAlreadyFilled(orderHash);
                }

                // Return false as the order status is invalid.
                return false;
            }
        }

        // Return true as the order status is valid.
        valid = true;
    }

    /**
     * @dev Internal pure function to hash key parameters of a given execution
     *      from an array of execution elements by index.
     *
     * @param executions     An array of execution elements.
     * @param executionIndex An index designating which execution element from
     *                       the array to hash.
     *
     * @return A hash of the key parameters of the execution.
     */
    function _getHashByExecutionIndex(
        Execution[] memory executions,
        uint256 executionIndex
    ) internal pure returns (bytes32) {
        // Retrieve ERC1155 execution element.
        Execution memory execution = executions[executionIndex];

        // Retrieve the received item for the given execution element.
        ReceivedItem memory item = execution.item;

        // Derive hash based on token, offerer, recipient, and proxy usage.
        // prettier-ignore
        return _hashBatchableItemIdentifier(
            item.token,
            execution.offerer,
            item.recipient,
            execution.conduitKey
        );
    }

    /**
     * @dev Internal pure function to derive a hash for comparing transfers to
     *      see if they can be batched. Only applies to ERC1155 tokens.
     *
     * @param token      The token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. The zero hash
     *                   signifies that no conduit should be used (and direct
     *                   approvals set on Consideration) and `bytes32(1)`
     *                   signifies to utilize the legacy user proxy for the
     *                   transfer.
     *
     * @return value The hash.
     */
    function _hashBatchableItemIdentifier(
        address token,
        address from,
        address to,
        bytes32 conduitKey
    ) internal pure returns (bytes32 value) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the free memory pointer on the stack; replace afterwards.
            let freeMemoryPointer := mload(FreeMemoryPointerSlot)

            mstore(0x3c, to) // Place to address in memory.
            mstore(0x28, from) // Place from address in memory
            mstore(0x14, token) // Place token address in memory.
            mstore(0x00, conduitKey) // Put conduit key at beginning of region.

            value := keccak256(0x00, 0x5c) // Hash the 92-byte memory region.

            // Restore the free memory pointer.
            mstore(FreeMemoryPointerSlot, freeMemoryPointer)
        }
    }

    /**
     * @dev Internal pure function to check whether a given order type indicates
     *      that partial fills are not supported (e.g. only "full fills" are
     *      allowed for the order in question).
     *
     * @param orderType The order type in question.
     *
     * @return isFullOrder A boolean indicating whether the order type only
     *                     supports full fills.
     */
    function _doesNotSupportPartialFills(OrderType orderType)
        internal
        pure
        returns (bool isFullOrder)
    {
        // The "full" order types are even, while "partial" order types are odd.
        // Bitwise and by 1 is equivalent to modulo by 2, but 2 gas cheaper.
        assembly {
            // Same thing as uint256(orderType) & 1 == 0
            isFullOrder := iszero(and(orderType, 1))
        }
    }

    /**
     * @dev Internal pure function to convert an order to an advanced order with
     *      numerator and denominator of 1 and empty extraData.
     *
     * @param order The order to convert.
     *
     * @return advancedOrder The new advanced order.
     */
    function _convertOrderToAdvanced(Order calldata order)
        internal
        pure
        returns (AdvancedOrder memory advancedOrder)
    {
        // Convert to partial order (1/1 or full fill) and return new value.
        advancedOrder = AdvancedOrder(
            order.parameters,
            1,
            1,
            order.signature,
            ""
        );
    }

    /**
     * @dev Internal pure function to convert an array of orders to an array of
     *      advanced orders with numerator and denominator of 1.
     *
     * @param orders The orders to convert.
     *
     * @return advancedOrders The new array of partial orders.
     */
    function _convertOrdersToAdvanced(Order[] calldata orders)
        internal
        pure
        returns (AdvancedOrder[] memory advancedOrders)
    {
        // Read the number of orders from calldata and place on the stack.
        uint256 totalOrders = orders.length;

        // Allocate new empty array for each partial order in memory.
        advancedOrders = new AdvancedOrder[](totalOrders);

        // Skip overflow check as the index for the loop starts at zero.
        unchecked {
            // Iterate over the given orders.
            for (uint256 i = 0; i < totalOrders; ++i) {
                // Convert to partial order (1/1 or full fill) and update array.
                advancedOrders[i] = _convertOrderToAdvanced(orders[i]);
            }
        }

        // Return the array of advanced orders.
        return advancedOrders;
    }

    /**
     * @dev Internal pure function to ensure that the supplied consideration
     *      array length for an order to be fulfilled is not less than the
     *      original consideration array length for that order.
     *
     * @param suppliedConsiderationItemTotal The number of consideration items
     *                                       supplied when fulfilling the order.
     * @param originalConsiderationItemTotal The number of consideration items
     *                                       supplied on initial order creation.
     */
    function _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
        uint256 suppliedConsiderationItemTotal,
        uint256 originalConsiderationItemTotal
    ) internal pure {
        // Ensure supplied consideration array length is not less than original.
        if (suppliedConsiderationItemTotal < originalConsiderationItemTotal) {
            revert MissingOriginalConsiderationItems();
        }
    }

    /**
     * @dev Internal pure function to ensure that a given item amount is not
     *      zero.
     *
     * @param amount The amount to check.
     */
    function _assertNonZeroAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert MissingItemAmount();
        }
    }

    /**
     * @dev Internal pure function to validate calldata offsets for dynamic
     *      types in BasicOrderParameters. This ensures that functions using the
     *      calldata object normally will be using the same data as the assembly
     *      functions. Note that no parameters are supplied as all basic order
     *      functions use the same calldata encoding.
     */
    function _assertValidBasicOrderParameterOffsets() internal pure {
        // Declare a boolean designating basic order parameter offset validity.
        bool validOffsets;

        // Utilize assembly in order to read offset data directly from calldata.
        assembly {
            /*
             * Checks:
             * 1. Order parameters struct offset == 0x20
             * 2. Additional recipients arr offset == 0x200
             * 3. Signature offset == 0x240 + (recipients.length * 0x40)
             */
            validOffsets := and(
                // Order parameters have offset of 0x20
                eq(calldataload(0x04), 0x20),
                // Additional recipients have offset of 0x200
                eq(calldataload(0x224), 0x240)
            )
            validOffsets := and(
                validOffsets,
                eq(
                    // Load signature offset from calldata
                    calldataload(0x244),
                    // Calculate expected offset: start of recipients + len * 64
                    add(0x260, mul(calldataload(0x264), 0x40))
                )
            )
        }

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            revert InvalidBasicOrderParameterEncoding();
        }
    }

    /**
     * @dev Internal pure function to efficiently derive an digest to sign for
     *      an order in accordance with EIP-712.
     *
     * @param domainSeparator The domain separator.
     * @param orderHash       The order hash.
     *
     * @return value The hash.
     */
    function _hashDigest(bytes32 domainSeparator, bytes32 orderHash)
        internal
        pure
        returns (bytes32 value)
    {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0x00, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(0x02, domainSeparator)

            // Place the order hash in scratch space, spilling into the first
            // two bytes of the free memory pointer — this should never be set
            // as memory cannot be expanded to that size, and will be zeroed out
            // after the hash is performed.
            mstore(0x22, orderHash)

            value := keccak256(0x00, 0x42) // Hash the relevant region.

            mstore(0x22, 0) // Clear out the dirtied bits in the memory pointer.
        }
    }
}
