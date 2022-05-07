// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { OrderType, ItemType, Side } from "contracts/lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "contracts/lib/ConsiderationStructs.sol";

import { ConsiderationItemIndicesAndValidity, OrderToExecute } from "./ReferenceConsiderationStructs.sol";

import { ZoneInterface } from "contracts/interfaces/ZoneInterface.sol";

import { ReferenceConsiderationBase } from "./ReferenceConsiderationBase.sol";

import "./ReferenceConsiderationConstants.sol";

/**
 * @title ReferenceConsiderationPure
 * @author 0age
 * @notice ConsiderationPure contains all pure functions.
 */
contract ReferenceConsiderationPure is ReferenceConsiderationBase {
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
        ReferenceConsiderationBase(conduitController)
    {}

    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param ordersToExecute    The orders to apply criteria resolvers to.
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
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Retrieve length of criteria resolvers array and place on stack.
        uint256 arraySize = criteriaResolvers.length;

        // Iterate over each criteria resolver.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the criteria resolver.
            CriteriaResolver memory criteriaResolver = (criteriaResolvers[i]);

            // Read the order index from memory and place it on the stack.
            uint256 orderIndex = criteriaResolver.orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= ordersToExecute.length) {
                revert OrderCriteriaResolverOutOfRange();
            }

            // Skip criteria resolution for order if not fulfilled.
            if (ordersToExecute[orderIndex].numerator == 0) {
                continue;
            }

            // Read component index from memory and place it on the stack.
            uint256 componentIndex = criteriaResolver.index;

            // Declare values for item's type and criteria.
            ItemType itemType;
            uint256 identifierOrCriteria;

            // If the criteria resolver refers to an offer item...
            if (criteriaResolver.side == Side.OFFER) {
                SpentItem[] memory spentItems = ordersToExecute[orderIndex]
                    .spentItems;
                // Ensure that the component index is in range.
                if (componentIndex >= spentItems.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using order and component index.
                SpentItem memory offer = (spentItems[componentIndex]);

                // Read item type and criteria from memory & place on stack.
                itemType = offer.itemType;
                identifierOrCriteria = offer.identifier;

                // Optimistically update item type to remove criteria usage.
                offer.itemType = (itemType == ItemType.ERC721_WITH_CRITERIA)
                    ? ItemType.ERC721
                    : ItemType.ERC1155;

                // Optimistically update identifier w/ supplied identifier.
                offer.identifier = criteriaResolver.identifier;
            } else {
                ReceivedItem[] memory receivedItems = ordersToExecute[
                    orderIndex
                ].receivedItems;
                // Otherwise, the resolver refers to a consideration item.
                // Ensure that the component index is in range.
                if (componentIndex >= receivedItems.length) {
                    revert ConsiderationCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using order and component index.
                ReceivedItem memory consideration = (
                    receivedItems[componentIndex]
                );

                // Read item type and criteria from memory & place on stack.
                itemType = consideration.itemType;
                identifierOrCriteria = consideration.identifier;

                // Optimistically update item type to remove criteria usage.
                consideration.itemType = (itemType ==
                    ItemType.ERC721_WITH_CRITERIA)
                    ? ItemType.ERC721
                    : ItemType.ERC1155;

                // Optimistically update identifier w/ supplied identifier.
                consideration.identifier = (criteriaResolver.identifier);
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

        // Retrieve length of orders array and place on stack.
        arraySize = ordersToExecute.length;

        // Iterate over each advanced order.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the advanced order.
            //AdvancedOrder memory advancedOrder = advancedOrders[i];
            //SpentItem[] memory spentItems = spentItemsByOrder[i];
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Read offer length from memory and place on stack.
            uint256 totalItems = orderToExecute.spentItems.length;

            // Skip criteria resolution for order if not fulfilled.
            if (orderToExecute.numerator == 0) {
                continue;
            }

            // Iterate over each offer item on the order.
            for (uint256 j = 0; j < totalItems; ++j) {
                // Ensure item type no longer indicates criteria usage.
                if (
                    _isItemWithCriteria(orderToExecute.spentItems[j].itemType)
                ) {
                    revert UnresolvedOfferCriteria();
                }
            }

            // Read consideration length from memory and place on stack.
            totalItems = (orderToExecute.receivedItems.length);

            // Iterate over each consideration item on the order.
            for (uint256 j = 0; j < totalItems; ++j) {
                // Ensure item type no longer indicates criteria usage.
                if (
                    _isItemWithCriteria(
                        orderToExecute.receivedItems[j].itemType
                    )
                ) {
                    revert UnresolvedConsiderationCriteria();
                }
            }
        }
    }

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
    // TODO: Remove this functon after Advanced Orders are no longer used here.
    function _applyCriteriaResolversAdvanced(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Retrieve length of criteria resolvers array and place on stack.
        uint256 arraySize = criteriaResolvers.length;

        // Iterate over each criteria resolver.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the criteria resolver.
            CriteriaResolver memory criteriaResolver = (criteriaResolvers[i]);

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
                offer.itemType = (itemType == ItemType.ERC721_WITH_CRITERIA)
                    ? ItemType.ERC721
                    : ItemType.ERC1155;

                // Optimistically update identifier w/ supplied identifier.
                offer.identifierOrCriteria = criteriaResolver.identifier;
            } else {
                // Otherwise, the resolver refers to a consideration item.
                // Ensure that the component index is in range.
                if (componentIndex >= orderParameters.consideration.length) {
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
                consideration.itemType = (itemType ==
                    ItemType.ERC721_WITH_CRITERIA)
                    ? ItemType.ERC721
                    : ItemType.ERC1155;

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

        // Retrieve length of advanced orders array and place on stack.
        arraySize = advancedOrders.length;

        // Iterate over each advanced order.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the advanced order.
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
                extraCeiling = duration - 1;
            }

            // Aggregate new amounts weighted by time with rounding factor
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed) +
                extraCeiling);

            // Division is performed without zero check as it cannot be zero.
            uint256 newAmount = totalBeforeDivision / duration;

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

        // Divide that value by the denominator to get the new value.
        newValue = valueTimesNumerator / denominator;

        // Ensure that division gave a final result with no remainder.
        bool exact = ((newValue * denominator) / numerator) == value;
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
                standardExecutions[nextStandardExecutionIndex++] = (execution);
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
                uint256 batchElementIndex = (batchElementIndices[batchIndex]++);

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
     * @dev Internal pure function to check the indicated consideration item matches original item.
     *
     * @param consideration  The consideration to compare
     * @param receievedItem  The aggregated receieved item
     *
     * @return invalidFulfillment A boolean indicating whether the fulfillment is invalid.
     */
    function _checkMatchingConsideration(
        ReceivedItem memory consideration,
        ReceivedItem memory receievedItem
    ) internal pure returns (bool invalidFulfillment) {
        return
            receievedItem.recipient != consideration.recipient ||
            receievedItem.itemType != consideration.itemType ||
            receievedItem.token != consideration.token ||
            receievedItem.identifier != consideration.identifier;
    }

    /**
     * @dev Internal pure function to aggregate a group of consideration items
     *      using supplied directives on which component items are candidates
     *      for aggregation, skipping items on orders that are not available.
     *
     * @param ordersToExecute         The orders to aggregate consideration
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
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory considerationComponents,
        uint256 startIndex
    ) internal pure returns (ReceivedItem memory receivedItem) {
        // Declare struct in memory to avoid declaring multiple local variables
        ConsiderationItemIndicesAndValidity memory potentialCandidate;
        potentialCandidate.orderIndex = considerationComponents[startIndex]
            .orderIndex;
        potentialCandidate.itemIndex = considerationComponents[startIndex]
            .itemIndex;
        potentialCandidate.invalidFulfillment = (potentialCandidate
            .orderIndex >= ordersToExecute.length);

        if (!potentialCandidate.invalidFulfillment) {
            OrderToExecute memory orderToExecute = ordersToExecute[
                potentialCandidate.orderIndex
            ];
            // Ensure that the item index is not out of range.
            potentialCandidate.invalidFulfillment =
                potentialCandidate.invalidFulfillment ||
                (potentialCandidate.itemIndex >=
                    orderToExecute.receivedItems.length);
            if (!potentialCandidate.invalidFulfillment) {
                ReceivedItem memory consideration = orderToExecute
                    .receivedItems[potentialCandidate.itemIndex];

                receivedItem = ReceivedItem(
                    consideration.itemType,
                    consideration.token,
                    consideration.identifier,
                    consideration.amount,
                    consideration.recipient
                );

                // Zero out amount on original offerItem to indicate it is spent
                consideration.amount = 0;

                for (
                    uint256 i = startIndex + 1;
                    i < considerationComponents.length;
                    ++i
                ) {
                    potentialCandidate.orderIndex = considerationComponents[i]
                        .orderIndex;
                    potentialCandidate.itemIndex = considerationComponents[i]
                        .itemIndex;

                    /// Ensure that the order index is not out of range.
                    potentialCandidate.invalidFulfillment =
                        potentialCandidate.orderIndex >= ordersToExecute.length;
                    // Break if invalid
                    if (potentialCandidate.invalidFulfillment) {
                        break;
                    }
                    orderToExecute = ordersToExecute[
                        potentialCandidate.orderIndex
                    ];
                    if (orderToExecute.numerator != 0) {
                        // Ensure that the item index is not out of range.
                        potentialCandidate
                            .invalidFulfillment = (potentialCandidate
                            .itemIndex >= orderToExecute.receivedItems.length);
                        // Break if invalid
                        if (potentialCandidate.invalidFulfillment) {
                            break;
                        }
                        consideration = orderToExecute.receivedItems[
                            potentialCandidate.itemIndex
                        ];
                        // Updating Received Item Amount
                        receivedItem.amount =
                            receivedItem.amount +
                            consideration.amount;
                        // Zero out amount on original offerItem to indicate it is spent
                        consideration.amount = 0;
                        // Ensure the indicated offer item matches original item.
                        potentialCandidate
                            .invalidFulfillment = _checkMatchingConsideration(
                            consideration,
                            receivedItem
                        );
                    }
                }
            }
        }

        // Revert if an order/item was out of range or was not aggregatable.
        if (potentialCandidate.invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
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
        value = keccak256(abi.encodePacked(conduitKey, token, from, to));
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
        value = keccak256(
            abi.encodePacked(uint16(0x1901), domainSeparator, orderHash)
        );
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
        withCriteria = uint256(itemType) > 3;
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
        isFullOrder = uint256(orderType) & 1 == 0;
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

        // Iterate over the given orders.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Convert to partial order (1/1 or full fill) and update array.
            advancedOrders[i] = _convertOrderToAdvanced(orders[i]);
        }

        // Return the array of advanced orders.
        return advancedOrders;
    }

    /**
     * @dev Internal pure function to convert an advanced order to an order to execute with
     *      numerator of 1.
     *
     * @param advancedOrder The advanced order to convert.
     *
     * @return orderToExecute The new order to execute.
     */
    function _convertAdvancedToOrder(AdvancedOrder memory advancedOrder)
        internal
        pure
        returns (OrderToExecute memory orderToExecute)
    {
        OfferItem[] memory offer = advancedOrder.parameters.offer;

        SpentItem[] memory spentItems = new SpentItem[](offer.length);

        // Iterate over each offer item on the order.
        for (uint256 i = 0; i < offer.length; ++i) {
            // Retrieve the offer item.
            OfferItem memory offerItem = offer[i];

            // Create Spent Item for Event
            SpentItem memory spentItem = SpentItem(
                offerItem.itemType,
                offerItem.token,
                offerItem.identifierOrCriteria,
                offerItem.startAmount
            );

            // Add to array of Received Items
            spentItems[i] = spentItem;
        }

        ConsiderationItem[] memory consideration = advancedOrder
            .parameters
            .consideration;

        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            consideration.length
        );

        // Iterate over each consideration item on the order.
        for (uint256 i = 0; i < consideration.length; ++i) {
            // Retrieve the consideration item.
            ConsiderationItem memory considerationItem = (consideration[i]);

            // Create Received Item for Event
            ReceivedItem memory receivedItem = ReceivedItem(
                considerationItem.itemType,
                considerationItem.token,
                considerationItem.identifierOrCriteria,
                considerationItem.startAmount,
                considerationItem.recipient
            );

            // Add to array of Received Items
            receivedItems[i] = receivedItem;
        }

        orderToExecute = OrderToExecute(
            advancedOrder.parameters.offerer,
            spentItems,
            receivedItems,
            advancedOrder.parameters.conduitKey,
            advancedOrder.numerator
        );

        return orderToExecute;
    }

    /**
     * @dev Internal pure function to convert an array of advanced orders to an array of
     *      orders to execute.
     *
     * @param advancedOrders The advanced orders to convert.
     *
     * @return ordersToExecute The new array of partial orders.
     */
    function _convertAdvancedtoOrdersToExecute(
        AdvancedOrder[] memory advancedOrders
    ) internal pure returns (OrderToExecute[] memory ordersToExecute) {
        // Read the number of orders from calldata and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Allocate new empty array for each partial order in memory.
        ordersToExecute = new OrderToExecute[](totalOrders);

        // Iterate over the given orders.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Convert to partial order (1/1 or full fill) and update array.
            ordersToExecute[i] = _convertAdvancedToOrder(advancedOrders[i]);
        }

        // Return the array of orders to Execute
        return ordersToExecute;
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

        // Iterate over each proof element.
        for (uint256 i = 0; i < proof.length; ++i) {
            // Retrieve the proof element.
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of proof)
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                // Hash(current element of proof + current computed hash)
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        // Ensure that the final derived hash matches the expected root.
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
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
     * @dev Internal pure function to ensure that a given item amount in not
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
     *      calldata object normally will be using the same data as optimized
     *      functions. Note that no parameters are supplied as all basic order
     *      functions use the same calldata encoding.
     */
    function _assertValidBasicOrderParameterOffsets() internal pure {
        /*
         * Checks:
         * 1. Order parameters struct offset == 0x20
         * 2. Additional recipients arr offset == 0x200
         * 3. Signature offset == 0x240 + (recipients.length * 0x40)
         */
        // Declare a boolean designating basic order parameter offset validity.
        bool validOffsets = (abi.decode(msg.data[4:36], (uint256)) == 32 &&
            abi.decode(msg.data[548:580], (uint256)) == 576 &&
            abi.decode(msg.data[580:612], (uint256)) ==
            608 + 64 * abi.decode(msg.data[612:644], (uint256)));

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            revert InvalidBasicOrderParameterEncoding();
        }
    }
}
