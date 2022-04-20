// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderType, ItemType, Side } from "./ConsiderationEnums.sol";

import { OfferItem, ConsiderationItem, SpentItem, ReceivedItem, OrderParameters, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver, Batch, BatchExecution } from "./ConsiderationStructs.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

import "./ConsiderationPointers.sol";

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
     * @param legacyProxyRegistry         A proxy registry that stores per-user
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC721+1155 tokens.
     * @param legacyTokenTransferProxy    A shared proxy contract that may
     *                                    optionally be used to transfer
     *                                    approved ERC20 tokens.
     * @param requiredProxyImplementation The implementation that must be set on
     *                                    each proxy in order to utilize it.
     */
    constructor(
        address legacyProxyRegistry,
        address legacyTokenTransferProxy,
        address requiredProxyImplementation
    )
        ConsiderationBase(
            legacyProxyRegistry,
            legacyTokenTransferProxy,
            requiredProxyImplementation
        )
    {}

    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param advancedOrders     The orders to apply criteria resolvers to.
     * @param criteriaResolvers  An array where each element contains a
     *                           reference to a specific order as well as that
     *                           order's offer or consideration, a token
     *                           identifier, and a proof that the supplied token
     *                           identifier is contained in the order's merkle
     *                           root. Note that a root of zero indicates that
     *                           any transferrable token identifier is valid and
     *                           that no proof needs to be supplied.
     */
    function _applyCriteriaResolvers(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each criteria resolver.
            for (uint256 i = 0; i < criteriaResolvers.length; ++i) {
                // Retrieve the criteria resolver.
                CriteriaResolver memory criteriaResolver = criteriaResolvers[i];

                // Read the order index from memory and place it on the stack.
                uint256 orderIndex = criteriaResolver.orderIndex;

                // Ensure that the order index is in range.
                if (orderIndex >= advancedOrders.length) {
                    revert OrderCriteriaResolverOutOfRange();
                }

                // Skip criteria resolution for order if not fulfilled.
                if (advancedOrders[orderIndex].numerator == 0) {
                    continue;
                }

                // Retrieve the parameters for the order.
                OrderParameters memory orderParameters = (
                    advancedOrders[orderIndex].parameters
                );

                // Read component index from memory and place it on the stack.
                uint256 componentIndex = criteriaResolver.index;

                // Declare values for item's type and criteria.
                ItemType itemType;
                uint256 identifierOrCriteria;

                // If the criteria resolver refers to an offer item...
                if (criteriaResolver.side == Side.OFFER) {
                    // Ensure that the component index is in range.
                    if (componentIndex >= orderParameters.offer.length) {
                        revert OfferCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using order and component index.
                    OfferItem memory offer = (
                        orderParameters.offer[componentIndex]
                    );

                    // Read item type and criteria from memory & place on stack.
                    itemType = offer.itemType;
                    identifierOrCriteria = offer.identifierOrCriteria;

                    // Optimistically update item type to remove criteria usage.
                    ItemType newItemType;
                    assembly {
                        newItemType := sub(3, eq(itemType, 4))
                    }
                    offer.itemType = newItemType;

                    // Optimistically update identifier w/ supplied identifier.
                    offer.identifierOrCriteria = criteriaResolver.identifier;
                    // Otherwise, criteria resolver refers to a consideration item.
                } else {
                    // Ensure that the component index is in range.
                    if (
                        componentIndex >= orderParameters.consideration.length
                    ) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using order and component index.
                    ConsiderationItem memory consideration = (
                        orderParameters.consideration[componentIndex]
                    );

                    // Read item type and criteria from memory & place on stack.
                    itemType = consideration.itemType;
                    identifierOrCriteria = consideration.identifierOrCriteria;

                    // Optimistically update item type to remove criteria usage.
                    ItemType newItemType;
                    assembly {
                        newItemType := sub(3, eq(itemType, 4))
                    }
                    consideration.itemType = newItemType;

                    // Optimistically update identifier w/ supplied identifier.
                    consideration.identifierOrCriteria = (
                        criteriaResolver.identifier
                    );
                }

                // Ensure the specified item type indicates criteria usage.
                if (!_isItemWithCriteria(itemType)) {
                    revert CriteriaNotEnabledForItem();
                }

                // If criteria is not 0 (i.e. a collection-wide offer)...
                if (identifierOrCriteria != uint256(0)) {
                    // Verify identifier inclusion in criteria root using proof.
                    _verifyProof(
                        criteriaResolver.identifier,
                        identifierOrCriteria,
                        criteriaResolver.criteriaProof
                    );
                }
            }

            // Iterate over each order.
            for (uint256 i = 0; i < advancedOrders.length; ++i) {
                // Retrieve the order.
                AdvancedOrder memory advancedOrder = advancedOrders[i];

                // Skip criteria resolution for order if not fulfilled.
                if (advancedOrder.numerator == 0) {
                    continue;
                }

                // Read consideration length from memory and place on stack.
                uint256 totalItems = (
                    advancedOrder.parameters.consideration.length
                );

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < totalItems; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(
                            advancedOrder.parameters.consideration[j].itemType
                        )
                    ) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                // Read offer length from memory and place on stack.
                totalItems = advancedOrder.parameters.offer.length;

                // Iterate over each offer item on the order.
                for (uint256 j = 0; j < totalItems; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(
                            advancedOrder.parameters.offer[j].itemType
                        )
                    ) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }
        }
    }

    /**
     * @dev Internal pure function to derive the current amount of a given item
     *      based on the current price, the starting price, and the ending
     *      price. If the start and end prices differ, the current price will be
     *      extrapolated on a linear basis.
     *
     * @param startAmount The starting amount of the item.
     * @param endAmount   The ending amount of the item.
     * @param elapsed     The time elapsed since the order's start time.
     * @param remaining   The time left until the order's end time.
     * @param duration    The total duration of the order.
     * @param roundUp     A boolean indicating whether the resultant amount
     *                    should be rounded up or down.
     *
     * @return The current amount.
     */
    function _locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration,
        bool roundUp
    ) internal pure returns (uint256) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            // Leave extra amount to add for rounding at zero (i.e. round down).
            uint256 extraCeiling = 0;

            // If rounding up, set rounding factor to one less than denominator.
            if (roundUp) {
                // Skip underflow check: duration cannot be zero.
                unchecked {
                    extraCeiling = duration - 1;
                }
            }

            // Aggregate new amounts weighted by time with rounding factor
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed) +
                extraCeiling);

            // Division is performed without zero check as it cannot be zero.
            uint256 newAmount;
            assembly {
                newAmount := div(totalBeforeDivision, duration)
            }

            // Return the current amount (expressed as endAmount internally).
            return newAmount;
        }

        // Return the original amount (now expressed as endAmount internally).
        return endAmount;
    }

    /**
     * @dev Internal pure function to return a fraction of a given value and to
     *      ensure the resultant value does not have any fractional component.
     *
     * @param numerator   A value indicating the portion of the order that
     *                    should be filled.
     * @param denominator A value indicating the total size of the order.
     * @param value       The value for which to compute the fraction.
     *
     * @return newValue The value after applying the fraction.
     */
    function _getFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * numerator;

        // Divide (Note: denominator must not be zero!) and check for remainder.
        bool exact;
        assembly {
            newValue := div(valueTimesNumerator, denominator)
            exact := iszero(mulmod(value, numerator, denominator))
        }

        // Ensure that division gave a final result with no remainder.
        if (!exact) {
            revert InexactFraction();
        }
    }

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
            for (uint256 i = 0; i < executions.length; ++i) {
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
                    // Reuse existing array & update w/ current execution index.
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
                            execution.conduit // conduit
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

                    // Update current element's batch with respective amount.
                    batchExecutions[batchIndex].amounts[batchElementIndex] = (
                        execution.item.amount
                    );
                }
            }

            // Return both the standard and batch execution arrays.
            return (standardExecutions, batchExecutions);
        }
    }

    /**
     * @dev Internal pure function to apply a fraction to a consideration
     * or offer item.
     *
     * @param startAmount     The starting amount of the item.
     * @param endAmount       The ending amount of the item.
     * @param numerator       A value indicating the portion of the order that
     *                        should be filled.
     * @param denominator     A value indicating the total size of the order.
     * @param elapsed         The time elapsed since the order's start time.
     * @param remaining       The time left until the order's end time.
     * @param duration        The total duration of the order.
     *
     * @return amount The received item to transfer with the final amount.
     */
    function _applyFraction(
        uint256 startAmount,
        uint256 endAmount,
        uint256 numerator,
        uint256 denominator,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration,
        bool roundUp
    ) internal pure returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (startAmount == endAmount) {
            amount = _getFraction(numerator, denominator, endAmount);
        } else {
            // Otherwise, apply fraction to both to extrapolate final amount.
            amount = _locateCurrentAmount(
                _getFraction(numerator, denominator, startAmount),
                _getFraction(numerator, denominator, endAmount),
                elapsed,
                remaining,
                duration,
                roundUp
            );
        }
    }

    /**
     * @dev Internal pure function to aggregate a group of consideration items
     *      using supplied directives on which component items are candidates
     *      for aggregation, skipping items on orders that are not available.
     *
     * @param advancedOrders          The orders to aggregate consideration
     *                                items from.
     * @param considerationComponents An array of FulfillmentComponent structs
     *                                indicating the order index and item index
     *                                of each candidate consideration item for
     *                                aggregation.
     * @param startIndex              The initial order index to begin iteration
     *                                on when searching for consideration items
     *                                to aggregate.
     *
     * @return receivedItem The aggregated consideration items.
     */
    function _aggregateValidFulfillmentConsiderationItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory considerationComponents,
        uint256 startIndex
    ) internal pure returns (ReceivedItem memory receivedItem) {
        bool invalidFulfillment;
        assembly {
            let ordersLen := mload(advancedOrders)
            let i := startIndex
            let fulfillmentPtr := mload(
                add(add(considerationComponents, 0x20), mul(i, 0x20))
            )

            let orderIndex := mload(fulfillmentPtr)
            let itemIndex := mload(add(fulfillmentPtr, 0x20))
            invalidFulfillment := iszero(lt(orderIndex, ordersLen))
            if iszero(invalidFulfillment) {
                // Calculate pointer to AdvancedOrder element at advancedOrders[orderIndex]
                // OrderParameters pointer is first word of AdvancedOrder struct, so we mload twice
                let orderPtr := mload(
                    // Read the pointer to advancedOrders[orderIndex] from its head in the array
                    mload(
                        // Calculate the position of the head for advancedOrders[orderIndex]
                        add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
                    )
                )
                // Load consideration array pointer
                let considerationArrPtr := mload(
                    add(orderPtr, OrderParameters_consideration_head_offset)
                )
                // Check if itemIndex is within the range of the array
                invalidFulfillment := iszero(
                    lt(itemIndex, mload(considerationArrPtr))
                )
                if iszero(invalidFulfillment) {
                    let considerationItemPtr := mload(
                        add(
                            // Get pointer to beginning of receivedItem
                            add(considerationArrPtr, 0x20),
                            // Calculate offset to pointer for desired order
                            mul(itemIndex, 0x20)
                        )
                    )

                    // itemType
                    mstore(receivedItem, mload(considerationItemPtr))
                    // token
                    mstore(
                        add(receivedItem, Common_token_offset),
                        mload(add(considerationItemPtr, Common_token_offset))
                    )
                    // identifier
                    mstore(
                        add(receivedItem, Common_identifier_offset),
                        mload(
                            add(considerationItemPtr, Common_identifier_offset)
                        )
                    )
                    let amountPtr := add(
                        considerationItemPtr,
                        Common_amount_offset
                    )
                    // amount
                    mstore(
                        add(receivedItem, Common_amount_offset),
                        mload(amountPtr)
                    )
                    mstore(amountPtr, 0)
                    // recipient
                    mstore(
                        add(receivedItem, ReceivedItem_recipient_offset),
                        mload(
                            add(
                                considerationItemPtr,
                                ConsiderationItem_recipient_offset
                            )
                        )
                    )
                    i := add(i, 1)
                    // prettier-ignore
                    for {} lt(i, mload(considerationComponents)) {
                        i := add(i, 1)
                    } {
                        fulfillmentPtr := mload(
                            add(
                                add(considerationComponents, 0x20),
                                mul(i, 0x20)
                            )
                        )
                        orderIndex := mload(fulfillmentPtr)
                        itemIndex := mload(add(fulfillmentPtr, 0x20))
                        invalidFulfillment := iszero(lt(orderIndex, ordersLen))
                        if invalidFulfillment {
                            break
                        }
                        // Get pointer to AdvancedOrder element
                        // orderPtr will be reused as the pointer to OrderParameters
                        orderPtr := mload(
                            add(
                                add(advancedOrders, 0x20),
                                mul(orderIndex, 0x20)
                            )
                        )

                        // Only continue if numerator is >0
                        if mload(
                            add(orderPtr, AdvancedOrder_numerator_offset)
                        ) {
                            // First word of AdvancedOrder is pointer to OrderParameters
                            orderPtr := mload(orderPtr)
                            // Load consideration array pointer
                            considerationArrPtr := mload(
                                add(orderPtr, OrderParameters_consideration_head_offset)
                            )
                            // Check if itemIndex is within the range of the array
                            invalidFulfillment := iszero(
                                lt(itemIndex, mload(considerationArrPtr))
                            )
                            if invalidFulfillment {
                                break
                            }
                            considerationItemPtr := mload(
                                add(
                                    // Get pointer to beginning of receivedItem
                                    add(considerationArrPtr, 0x20),
                                    // Calculate offset to pointer for desired order
                                    mul(itemIndex, 0x20)
                                )
                            )
                            amountPtr := add(
                                considerationItemPtr,
                                Common_amount_offset
                            )

                            mstore(
                                add(receivedItem, Common_amount_offset),
                                add(
                                    mload(
                                        add(receivedItem, Common_amount_offset)
                                    ),
                                    mload(amountPtr)
                                )
                            )

                            mstore(amountPtr, 0)
                            invalidFulfillment := iszero(
                                and(
                                    // recipient
                                    eq(
                                        mload(
                                            add(
                                                considerationItemPtr,
                                                ConsiderationItem_recipient_offset
                                            )
                                        ),
                                        mload(
                                            add(
                                                receivedItem,
                                                ReceivedItem_recipient_offset
                                            )
                                        )
                                    ),
                                    and(
                                        // item type
                                        eq(
                                            mload(considerationItemPtr),
                                            mload(receivedItem)
                                        ),
                                        and(
                                            // token
                                            eq(
                                                mload(
                                                    add(
                                                        considerationItemPtr,
                                                        Common_token_offset
                                                    )
                                                ),
                                                mload(
                                                    add(
                                                        receivedItem,
                                                        Common_token_offset
                                                    )
                                                )
                                            ),
                                            // identifier
                                            eq(
                                                mload(
                                                    add(
                                                        considerationItemPtr,
                                                        Common_identifier_offset
                                                    )
                                                ),
                                                mload(
                                                    add(
                                                        receivedItem,
                                                        Common_identifier_offset
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                            if invalidFulfillment {
                                break
                            }
                        }
                    }
                }
            }
        }
        if (invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
        }
    }

    /**
     * @dev Internal pure function to ensure that a staticcall to `isValidOrder`
     *      or `isValidOrderIncludingExtraData` as part of validating a
     *      restricted order that was not submitted by the named offerer or zone
     *      was successful and returned the required magic value.
     *
     * @param success   A boolean indicating the status of the staticcall.
     * @param orderHash The order hash of the order in question.
     */
    function _assertIsValidOrderStaticcallSuccess(
        bool success,
        bytes32 orderHash
    ) internal pure {
        // If the call failed...
        if (!success) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            revert InvalidRestrictedOrder(orderHash);
        }

        // Extract result from returndata buffer in case of memory overflow.
        bytes4 result;
        assembly {
            // Only put result on stack if return data is exactly 32 bytes.
            if eq(returndatasize(), 0x20) {
                // Copy directly from return data into scratch space.
                returndatacopy(0, 0, 0x20)

                // Take value from scratch space and place it on the stack.
                result := mload(0)
            }
        }

        // Ensure result was extracted and matches isValidOrder magic value.
        if (result != ZoneInterface.isValidOrder.selector) {
            revert InvalidRestrictedOrder(orderHash);
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
            execution.conduit
        );
    }

    /**
     * @dev Internal pure function to derive a hash for comparing transfers to
     *      see if they can be batched. Only applies to ERC1155 tokens.
     *
     * @param token    The token to transfer.
     * @param from     The originator of the transfer.
     * @param to       The recipient of the transfer.
     * @param conduit A boolean indicating whether to utilize a proxy when
     *                 performing the transfer.
     *
     * @return value The hash.
     */
    function _hashBatchableItemIdentifier(
        address token,
        address from,
        address to,
        address conduit
    ) internal pure returns (bytes32 value) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            mstore(0x20, conduit) // Place proxy bool at end of scratch space.
            mstore(0x1c, to) // Place to address just before bool.
            mstore(0x08, from) // Place from address just before to.

            // Place combined token + start of from at start of scratch space.
            mstore(0x00, or(shl(0x60, token), shr(0x40, from)))

            value := keccak256(0x00, 0x40) // Hash scratch space region.
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
            mstore(
                0x00,
                0x1901000000000000000000000000000000000000000000000000000000000000 // solhint-disable-line max-line-length
            )

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

    /**
     * @dev Internal pure function to check whether a given item type represents
     *      a criteria-based ERC721 or ERC1155 item (e.g. an item that can be
     *      resolved to one of a number of different identifiers at the time of
     *      order fulfillment).
     *
     * @param itemType The item type in question.
     *
     * @return withCriteria A boolean indicating that the item type in question
     *                      represents a criteria-based item.
     */
    function _isItemWithCriteria(ItemType itemType)
        internal
        pure
        returns (bool withCriteria)
    {
        // ERC721WithCriteria is item type 4. ERC1155WithCriteria is item type
        // 5.
        assembly {
            withCriteria := gt(itemType, 3)
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
     * @dev Internal pure function to revert and pass along the revert reason if
     *      data was returned by the last call.
     */
    function _revertWithReasonIfOneIsReturned() internal pure {
        assembly {
            // If data was returned...
            if returndatasize() {
                // Copy returndata to memory, overwriting existing memory.
                returndatacopy(0, 0, returndatasize())

                // Revert, specifying memory region with copied returndata.
                revert(0, returndatasize())
            }
        }
    }

    /**
     * @dev Internal pure function to ensure that a given element is contained
     *      in a merkle root via a supplied proof.
     *
     * @param leaf  The element for which to prove inclusion.
     * @param root  The merkle root that inclusion will be proved against.
     * @param proof The merkle proof.
     */
    function _verifyProof(
        uint256 leaf,
        uint256 root,
        bytes32[] memory proof
    ) internal pure {
        // Convert the supplied leaf element from uint256 to bytes32.
        bytes32 computedHash = bytes32(leaf);

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each proof element.
            for (uint256 i = 0; i < proof.length; ++i) {
                // Retrieve the proof element.
                bytes32 proofElement = proof[i];

                if (computedHash <= proofElement) {
                    // Hash(current computed hash + current element of proof)
                    computedHash = _efficientHash(computedHash, proofElement);
                } else {
                    // Hash(current element of proof + current computed hash)
                    computedHash = _efficientHash(proofElement, computedHash);
                }
            }
        }

        // Ensure that the final derived hash matches the expected root.
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
        }
    }

    /**
     * @dev Internal pure function to efficiently hash two bytes32 values.
     *
     * @param a The first component of the hash.
     * @param b The second component of the hash.
     *
     * @return value The hash.
     */
    function _efficientHash(bytes32 a, bytes32 b)
        internal
        pure
        returns (bytes32 value)
    {
        assembly {
            mstore(0x00, a) // Place element a in first word of scratch space.
            mstore(0x20, b) // Place element b in second word of scratch space.
            value := keccak256(0x00, 0x40) // Hash scratch space region.
        }
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
                    // Calculate expected offset (start of recipients + len * 64)
                    add(0x260, mul(calldataload(0x264), 0x40))
                )
            )
        }

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            revert InvalidBasicOrderParameterEncoding();
        }
    }
}
