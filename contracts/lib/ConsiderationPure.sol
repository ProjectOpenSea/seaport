// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    OrderType,
    ItemType,
    Side
} from "./ConsiderationEnums.sol";

import {
    OfferedItem,
    ReceivedItem,
    ConsumedItem,
    FulfilledItem,
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
} from "./ConsiderationStructs.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

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
     *                                    transfer approved tokens.
     * @param requiredProxyImplementation The implementation that must be set on
     *                                    each proxy in order to utilize it.
     */
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationBase(legacyProxyRegistry, requiredProxyImplementation) {}

    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param orders            The orders to apply criteria resolvers to.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          a root of zero indicates that any transferrable
     *                          token identifier is valid and that no proof
     *                          needs to be supplied.
     */
    function _applyCriteriaResolvers(
        AdvancedOrder[] memory orders,
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
                if (orderIndex >= orders.length) {
                    revert OrderCriteriaResolverOutOfRange();
                }

                // Retrieve the parameters for the order.
                OrderParameters memory orderParameters = (
                    orders[orderIndex].parameters
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
                    OfferedItem memory offer = (
                        orderParameters.offer[componentIndex]
                    );

                    // Read item type and criteria from memory & place on stack.
                    itemType = offer.itemType;
                    identifierOrCriteria = offer.identifierOrCriteria;

                    // Optimistically update item type to remove criteria usage.
                    offer.itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

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
                    ReceivedItem memory consideration = (
                        orderParameters.consideration[componentIndex]
                    );

                    // Read item type and criteria from memory & place on stack.
                    itemType = consideration.itemType;
                    identifierOrCriteria = consideration.identifierOrCriteria;

                    // Optimistically update item type to remove criteria usage.
                    consideration.itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

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
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                AdvancedOrder memory order = orders[i];

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(
                            order.parameters.consideration[j].itemType
                        )
                    ) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                // Iterate over each offer item on the order.
                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(
                            order.parameters.offer[j].itemType
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
            uint256 roundingFactor = 0;

            // If rounding up, set rounding factor to one less than denominator.
            if (roundUp) {
                // Skip underflow check: duration cannot be zero.
                unchecked {
                    roundingFactor = duration - 1;
                }
            }

            // Aggregate new amounts weighted by time with rounding factor
            uint256 totalBeforeDivision = (
                (startAmount * remaining) + (endAmount * elapsed) + roundingFactor
            );

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
        bool inexact;
        assembly {
            newValue := div(valueTimesNumerator, denominator)
            inexact := iszero(iszero(mulmod(value, numerator, denominator)))
        }

        // Ensure that division gave a final result with no remainder.
        if (inexact) {
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
    function _compressExecutions(
        Execution[] memory executions
    ) internal pure returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            // Read executions array length from memory and place on the stack.
            uint256 totalExecutions = executions.length;

            // Return early if less than two executions are provided.
            if (totalExecutions < 2) {
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
            if (total1155Executions < 2) {
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

                        // Allocate execution indices array w/ an extra element.
                        uint256[] memory newExecutionIndices = (
                            new uint256[](oldExecutionIndices.length + 1)
                        );

                        // Iterate over existing execution indices.
                        for (uint256 k = 0; k < oldExecutionIndices.length; ++k) {
                            // Add them to the new execution indices array.
                            newExecutionIndices[k] = oldExecutionIndices[k];
                        }

                        // Add new execution index to the end of the array.
                        newExecutionIndices[oldExecutionIndices.length] = (
                            indexBy1155[j]
                        );

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
                if (indicesLength > 1) {
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
    ) internal pure returns (
        Execution[] memory,
        BatchExecution[] memory
    ) {
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
                    // Derive batch execution index by decrementing the pointer.
                    uint256 batchExecutionIndex = batchExecutionPointer - 1;

                    // If it is the first item applied to the batch execution...
                    if (batchExecutions[batchExecutionIndex].token == address(0)) {
                        // Allocate an empty array for each tokenId and amount.
                        uint256[] memory emptyElementsArray = new uint256[](
                            batches[batchExecutionIndex].executionIndices.length
                        );

                        // Populate all other fields using execution parameters.
                        batchExecutions[batchExecutionIndex] = BatchExecution(
                            execution.item.token,     // token
                            execution.offerer,        // from
                            execution.item.recipient, // to
                            emptyElementsArray,       // tokenIds
                            emptyElementsArray,       // amounts
                            execution.useProxy        // useProxy
                        );
                    }

                    // Put next batch element index on stack, then increment it.
                    uint256 batchElementIndex = (
                        batchElementIndices[batchExecutionIndex]++
                    );

                    // Update current element's batch with respective tokenId.
                    batchExecutions[
                        batchExecutionIndex
                    ].tokenIds[
                        batchElementIndex
                    ] = (
                        execution.item.identifier
                    );

                    // Update current element's batch with respective amount.
                    batchExecutions[
                        batchExecutionIndex
                    ].amounts[
                        batchElementIndex
                    ] = (
                        execution.item.amount
                    );
                }
            }

            // Return both the standard and batch execution arrays.
            return (standardExecutions, batchExecutions);
        }
    }

    /**
     * @dev Internal pure function to match offer items to consideration items
     *      on a group of orders via a supplied fulfillment.
     *
     * @param orders                  The orders to match.
     * @param offerComponents         An array designating offer components to
     *                                match to consideration components.
     * @param considerationComponents An array designating consideration
     *                                components to match to offer components.
     *                                Note that each consideration amount must
     *                                be zero in order for the match operation
     *                                to be valid.
     * @param useOffererProxyPerOrder An array of booleans indicating whether to
     *                                source approvals for the fulfilled tokens
     *                                on each order from their respective proxy.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     *                   Note that this execution object could potentially be
     *                   compressed further by aggregating batch transfers.
     */
    function _applyFulfillment(
        AdvancedOrder[] memory orders,
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent[] memory considerationComponents,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        Execution memory execution
    ) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            offerComponents.length == 0 ||
            considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Consume offerer & offered item at offer component's first item index.
        (
            address offerer,
            ConsumedItem memory offeredItem,
            bool useProxy
        ) = _consumeOfferComponent(
            orders,
            offerComponents[0].orderIndex,
            offerComponents[0].itemIndex,
            useOffererProxyPerOrder
        );

        // Consume consideration item designated by first item component index.
        FulfilledItem memory requiredConsideration = (
            _consumeConsiderationComponent(
                orders,
                considerationComponents[0].orderIndex,
                considerationComponents[0].itemIndex
            )
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            offeredItem.itemType != requiredConsideration.itemType ||
            offeredItem.token != requiredConsideration.token ||
            offeredItem.identifier != requiredConsideration.identifier

        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents();
        }

        // Iterate over each offer component on the fulfillment.
        for (uint256 i = 1; i < offerComponents.length;) {
            // Retrieve the offer component from the fulfillment.
            FulfillmentComponent memory offerComponent = (
                offerComponents[i]
            );

            // Consume offerer & offered item at offer component's item index.
            (
                address subsequentOfferer,
                ConsumedItem memory nextOfferedItem,
                bool subsequentUseProxy
            ) = _consumeOfferComponent(
                orders,
                offerComponent.orderIndex,
                offerComponent.itemIndex,
                useOffererProxyPerOrder
            );

            // Ensure all relevant parameters are consistent with initial offer.
            if (
                offerer != subsequentOfferer ||
                offeredItem.itemType != nextOfferedItem.itemType ||
                offeredItem.token != nextOfferedItem.token ||
                offeredItem.identifier != nextOfferedItem.identifier ||
                useProxy != subsequentUseProxy
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            // Increase the total offer amount by the current amount.
            offeredItem.amount += nextOfferedItem.amount;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // Iterate over each consideration component on the fulfillment.
        for (uint256 i = 1; i < considerationComponents.length;) {
            // Retrieve the consideration component from the fulfillment.
            FulfillmentComponent memory considerationComponent = (
                considerationComponents[i]
            );

            // Consume consideration designated by the component's item index.
            FulfilledItem memory nextRequiredConsideration = (
                _consumeConsiderationComponent(
                    orders,
                    considerationComponent.orderIndex,
                    considerationComponent.itemIndex
                )
            );

            // Ensure key parameters are consistent with initial consideration.
            if (
                requiredConsideration.recipient != (
                    nextRequiredConsideration.recipient
                ) ||
                requiredConsideration.itemType != (
                    nextRequiredConsideration.itemType
                ) ||
                requiredConsideration.token != (
                    nextRequiredConsideration.token
                ) ||
                requiredConsideration.identifier != (
                    nextRequiredConsideration.identifier
                )
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            // Increase the total consideration amount by the current amount.
            requiredConsideration.amount += (
                nextRequiredConsideration.amount
            );

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // If total consideration amount exceeds the offer amount...
        if (requiredConsideration.amount > offeredItem.amount) {
            // Retrieve the first consideration component from the fulfillment.
            FulfillmentComponent memory targetComponent = (
                considerationComponents[0]
            );

            // Add excess consideration amount to the original orders array.
            _setConsiderationAmount(
                orders,
                targetComponent.orderIndex,
                targetComponent.itemIndex,
                requiredConsideration.amount - offeredItem.amount
            );

            // Reduce total consideration amount to equal the offer amount.
            requiredConsideration.amount = offeredItem.amount;
        } else {
            // Retrieve the first offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = (
                offerComponents[0]
            );

            // Add excess offer amount to the original orders array.
            _setOfferAmount(
                orders,
                targetComponent.orderIndex,
                targetComponent.itemIndex,
                offeredItem.amount - requiredConsideration.amount
            );
        }

        // Return the final execution that will be triggered for relevant items.
        return Execution(requiredConsideration, offerer, useProxy);
    }

    /**
     * @dev Internal pure function to ensure that an order index is in range
     *      and, if so, to return the parameters of the associated order.
     *
     * @param orders An array of orders.
     * @param index  The order index specified by the fulfillment component.
     *
     * @return The parameters of the order at the given index.
     */
    function _getOrderParametersByFulfillmentIndexIfInRange(
        AdvancedOrder[] memory orders,
        uint256 index
    ) internal pure returns (OrderParameters memory) {
        // Ensure that the order index is in range.
        if (index >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

        // Return the parameters of the order at the given order index.
        return orders[index].parameters;
    }

    /**
     * @dev Internal pure function to ensure that an offer component index is in
     *      range and, if so, to zero out the offer amount and return the
     *      associated offer item.
     *
     * @param orders                  An array of orders.
     * @param orderIndex              The order index specified by the
     *                                fulfillment component.
     * @param itemIndex               The item index specified by the
     *                                fulfillment component.
     * @param useOffererProxyPerOrder An array of booleans indicating whether to
     *                                source approvals for the fulfilled tokens
     *                                on each order from their respective proxy.
     *
     * @return offerer      The offerer for the given order.
     * @return consumedItem The consumed offer item at the given index.
     * @return useProxy     A boolean indicating whether to source approvals for
     *                      fulfilled tokens from the order's respective proxy.
     */
    function _consumeOfferComponent(
        AdvancedOrder[] memory orders,
        uint256 orderIndex,
        uint256 itemIndex,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        address offerer,
        ConsumedItem memory consumedItem,
        bool useProxy
    ) {
        // Retrieve the order parameters using the supplied order index.
        OrderParameters memory orderParameters = (
            _getOrderParametersByFulfillmentIndexIfInRange(orders, orderIndex)
        );

        // Ensure that the offer index is in range.
        if (itemIndex >= orderParameters.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }

        // Retrieve the offered item.
        OfferedItem memory offeredItem = orderParameters.offer[itemIndex];

        // Convert to a consumed item.
        ConsumedItem memory offerItemToConsume = ConsumedItem(
            offeredItem.itemType,
            offeredItem.token,
            offeredItem.identifierOrCriteria,
            offeredItem.endAmount
        );

        // Clear offer amount to indicate offer item has been consumed.
        _setOfferAmount(orders, orderIndex, itemIndex, 0);

        // Return the offerer and the consumed offer item at the given index.
        return (
            orderParameters.offerer,
            offerItemToConsume,
            useOffererProxyPerOrder[orderIndex]
        );
    }

    /**
     * @dev Internal pure function to ensure that a consideration component
     *      index is in range and, if so, to zero out the amount and return the
     *      associated consideration item.
     *
     * @param orders     An array of orders.
     * @param orderIndex The order index specified by the fulfillment component.
     * @param itemIndex  The item index specified by the fulfillment component.
     *
     * @return The consideration item at the given index.
     */
    function _consumeConsiderationComponent(
        AdvancedOrder[] memory orders,
        uint256 orderIndex,
        uint256 itemIndex
    ) internal pure returns (FulfilledItem memory) {
        // Retrieve the order parameters using the supplied order index.
        OrderParameters memory orderParameters = (
            _getOrderParametersByFulfillmentIndexIfInRange(orders, orderIndex)
        );

        // Ensure that the consideration index is in range.
        if (itemIndex >= orderParameters.consideration.length) {
            revert FulfilledOrderConsiderationIndexOutOfRange();
        }

        // Retrieve the received consideration item.
        ReceivedItem memory receivedItem = (
            orderParameters.consideration[itemIndex]
        );

        // Convert to a fulfilled item.
        FulfilledItem memory fulfilledItem = FulfilledItem(
            receivedItem.itemType,
            receivedItem.token,
            receivedItem.identifierOrCriteria,
            receivedItem.endAmount,
            receivedItem.recipient
        );

        // Clear consideration amount to indicate item has been consumed.
        _setConsiderationAmount(orders, orderIndex, itemIndex, 0);

        // Return the fulfilled consideration item at the given index.
        return fulfilledItem;
    }

    /**
     * @dev Internal pure function to update the offer amount for an order.
     *
     * @param orders      An array of orders.
     * @param orderIndex  The order index specified by fulfillment component.
     * @param itemIndex   The offer item index specified by the fulfillment
     *                    component.
     * @param amount      The new offer item amount.
     */
    function _setOfferAmount(
        AdvancedOrder[] memory orders,
        uint256 orderIndex,
        uint256 itemIndex,
        uint256 amount
    ) internal pure {
        orders[orderIndex].parameters.offer[itemIndex].endAmount = amount;
    }

    /**
     * @dev Internal pure function to update the consideration amount for an
     *      order.
     *
     * @param orders      An array of orders.
     * @param orderIndex  The order index specified by fulfillment component.
     * @param itemIndex   The consideration item index specified by the
     *                    fulfillment component.
     * @param amount      The new consideration item amount.
     */
    function _setConsiderationAmount(
        AdvancedOrder[] memory orders,
        uint256 orderIndex,
        uint256 itemIndex,
        uint256 amount
    ) internal pure {
        orders[orderIndex].parameters.consideration[itemIndex].endAmount = (
            amount
        );
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
     */
    function _verifyOrderStatus(
        bytes32 orderHash,
        OrderStatus memory orderStatus,
        bool onlyAllowUnused
    ) internal pure {
        // Ensure that the order has not been cancelled.
        if (orderStatus.isCancelled) {
            revert OrderIsCancelled(orderHash);
        }

        // If the order is not entirely unused...
        if (orderStatus.numerator != 0) {
            // ensure the order has not been partially filled when not allowed.
            if (onlyAllowUnused) {
                revert OrderPartiallyFilled(orderHash);
            // Otherwise, ensure that order has not been entirely filled.
            } else if (orderStatus.numerator >= orderStatus.denominator) {
                revert OrderAlreadyFilled(orderHash);
            }
        }
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

        // Retrieve the item of the execution element.
        FulfilledItem memory item = execution.item;

        // Derive hash based on token, offerer, recipient, and proxy usage.
        return _hashBatchableItemIdentifier(
            item.token,
            execution.offerer,
            item.recipient,
            execution.useProxy
        );
    }

    /**
     * @dev Internal pure function to derive a hash for comparing transfers to
     *      see if they can be batched. Only applies to ERC1155 tokens.
     *
     * @param token    The token to transfer.
     * @param from     The originator of the transfer.
     * @param to       The recipient of the transfer.
     * @param useProxy A boolean indicating whether to utilize a proxy when
     *                 performing the transfer.
     *
     * @return value The hash.
     */
    function _hashBatchableItemIdentifier(
        address token,
        address from,
        address to,
        bool useProxy
    ) internal pure returns (bytes32 value) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            mstore(0x20, useProxy) // Place proxy bool at end of scratch space.
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
    function _hashDigest(
        bytes32 domainSeparator,
        bytes32 orderHash
    ) internal pure returns (bytes32 value) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(
                0x00,
                0x1901000000000000000000000000000000000000000000000000000000000000
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
     *      an Ether or ERC20 item.
     *
     * @param itemType The item type in question.
     *
     * @return A boolean indicating that the item type represents either Ether
     *         or an ERC20 item.
     */
    function _isEtherOrERC20Item(
        ItemType itemType
    ) internal pure returns (bool) {
        // Ether is item type 0 and ERC20 is item type 1.
        return uint256(itemType) < 2;
    }

    /**
     * @dev Internal pure function to check whether a given item type represents
     *      a criteria-based ERC721 or ERC1155 item (e.g. an item that can be
     *      resolved to one of a number of different identifiers at the time of
     *      order fulfillment).
     *
     * @param itemType The item type in question.
     *
     * @return A boolean indicating that the item type in question represents a
     *         criteria-based item.
     */
    function _isItemWithCriteria(
        ItemType itemType
    ) internal pure returns (bool) {
        // ERC721WithCriteria is item type 4. ERC115WithCriteria is item type 5.
        return uint256(itemType) > 3;
    }

    /**
     * @dev Internal pure function to check whether a given order type indicates
     *      that partial fills are not supported (e.g. only "full fills" are
     *      allowed for the order in question).
     *
     * @param orderType The order type in question.
     *
     * @return A boolean indicating whether the order type only supports full
     *         fills.
     */
    function _doesNotSupportPartialFills(
        OrderType orderType
    ) internal pure returns (bool) {
        // The "full" order types are even, while "partial" order types are odd.
        return uint256(orderType) % 2 == 0;
    }

    /**
     * @dev Internal pure function to convert an array of orders to an array of
     *      advanced orders with numerator and denominator of 1.
     *
     * @param orders The orders to convert.
     *
     * @return The new array of partial orders.
     */
    function _convertOrdersToAdvanced(
        Order[] memory orders
    ) internal pure returns (AdvancedOrder[] memory) {
        // Allocate new empty array for each partial order in memory.
        AdvancedOrder[] memory advancedOrders = (
            new AdvancedOrder[](orders.length)
        );

        // Skip overflow check as the index for the loop starts at zero.
        unchecked {
            // Iterate over the given orders.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrive the order.
                Order memory order = orders[i];

                // Convert to partial order (1/1 or full fill) and update array.
                advancedOrders[i] = AdvancedOrder(
                    order.parameters,
                    1,
                    1,
                    order.signature
                );
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
    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a) // Place element a in first word of scratch space.
            mstore(0x20, b) // Place element b in second word of scratch space.
            value := keccak256(0x00, 0x40) // Hash scratch space region.
        }
    }
}
