// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    OrderType,
    ItemType,
    Side
} from "./Enums.sol";

import {
    OfferedItem,
    ReceivedItem,
    OrderParameters,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "./Structs.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

/// @title ConsiderationPure contains all pure functions for Consideration.
/// @author 0age
contract ConsiderationPure is ConsiderationBase {
    /// @dev Derive and set hashes, reference chainId, and associated domain separator during deployment.
    /// @param legacyProxyRegistry A proxy registry that stores per-user proxies that may optionally be used to transfer tokens.
    /// @param requiredProxyImplementation The implementation that this contract will require be set on each per-user proxy.
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationBase(legacyProxyRegistry, requiredProxyImplementation) {}


    /// @dev Internal pure function to derive a hash for comparing transfers to see if they can be batched. Only applies to ERC1155 tokens.
    /// @param token The token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param useProxy A boolean indicating whether to utilize a proxy for the transfer.
    /// @return The hash.
    function _hashBatchableItemIdentifier(
        address token,
        address from,
        address to,
        bool useProxy
    ) internal pure returns (bytes32) {
        // Note: this could use a variant of efficientHash as it's < 64 bytes.
        return keccak256(abi.encode(token, from, to, useProxy));
    }

    /// @dev Internal pure function to derive the current amount of a given item based on the current price, the starting price, and the ending price. If the start and end prices differ, the current price will be extrapolated on a linear basis.
    /// @param startAmount The starting amount of the item.
    /// @param endAmount The ending amount of the item.
    /// @param elapsed The amount of time that has elapsed since the order's start time.
    /// @param remaining The amount of time left until the order's end time.
    /// @param duration The total duration of the order.
    /// @param roundUp A boolean indicating whether the resultant amount should be rounded up or down.
    /// @return The current amount.
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

    /// @dev Internal pure function to ensure that partial fills are not attempted on orders that do not support them.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// @param denominator A value indicating the total size of the order.
    /// @param orderType The order type.
    function _assertPartialFillsEnabled(
        uint120 numerator,
        uint120 denominator,
        OrderType orderType
    ) internal pure {
        // If attempting partial fill (n < d) check order type & ensure support.
        if (
            numerator < denominator &&
            uint256(orderType) % 2 == 0
        ) {
            revert PartialFillsNotEnabledForOrder();
        }
    }

    /// @dev Internal pure function to apply criteria resolvers containing specific token identifiers and associated proofs as well as fulfillments allocating offer components to consideration components.
    /// @param orders The orders to apply criteria resolvers to.
    /// @param criteriaResolvers An array where each element contains a reference to a specific order as well as that order's offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a root of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    function _applyCriteriaResolvers(
        Order[] memory orders,
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

                // Read component index from memory and place it on the stack.
                uint256 componentIndex = criteriaResolver.index;

                // If the criteria resolver refers to an offer item...
                if (criteriaResolver.side == Side.OFFER) {
                    // Ensure that the component index is in range.
                    if (componentIndex >= orders[orderIndex].parameters.offer.length) {
                        revert OfferCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using order and component index.
                    OfferedItem memory offer = orders[orderIndex].parameters.offer[componentIndex];

                    // Read item type from memory and place it on the stack.
                    ItemType itemType = offer.itemType;

                    // Ensure the specified item type indicates criteria usage.
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForOfferedItem();
                    }

                    // If criteria is not 0 (i.e. a collection-wide offer)...
                    if (offer.identifierOrCriteria != uint256(0)) {
                        // Verifiy identifier inclusion in criteria using proof.
                        _verifyProof(
                            criteriaResolver.identifier,
                            offer.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    // Update item type to remove criteria usage.
                    orders[orderIndex].parameters.offer[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    // Update item's identifier with the supplied identifier.
                    orders[orderIndex].parameters.offer[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                // Otherwise, criteria resolver refers to a consideration item.
                } else {
                    // Ensure that the component index is in range.
                    if (componentIndex >= orders[orderIndex].parameters.consideration.length) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using order and component index.
                    ReceivedItem memory consideration = orders[orderIndex].parameters.consideration[componentIndex];

                    // Read item type from memory and place it on the stack.
                    ItemType itemType = consideration.itemType;

                    // Ensure the specified item type indicates criteria usage.
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForConsideredItem();
                    }

                    // If criteria is not 0 (i.e. a collection-wide offer)...
                    if (consideration.identifierOrCriteria != uint256(0)) {
                        // Verifiy identifier inclusion in criteria using proof.
                        _verifyProof(
                            criteriaResolver.identifier,
                            consideration.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    // Update item type to remove criteria usage.
                    orders[orderIndex].parameters.consideration[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    // Update item's identifier with the supplied identifier.
                    orders[orderIndex].parameters.consideration[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                }
            }

            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                Order memory order = orders[i];

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (uint256(order.parameters.consideration[j].itemType) > 3) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                // Iterate over each offer item on the order.
                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (uint256(order.parameters.offer[j].itemType) > 3) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }
        }
    }

    /// @dev Internal pure function to "compress" executions, splitting them into "standard" (or unbatched) executions and "batch" executions.
    /// Note that there may be additional compression that could be performed, such as allowing contrarian orders to cancel one another or to better aggregate standard orders.
    /// @param executions An array of uncompressed executions.
    /// @return standardExecutions An array of executions that could not be compressed.
    /// @return batchExecutions An array of executions (all ERC1155 transfers) that have been compressed into batches.
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

            // Retrieve initial 1155 execution element.
            Execution memory initialExecution = executions[initialExecutionIndex];

            // Retrieve the item of the initial execution element.
            ReceivedItem memory initialItem = initialExecution.item;

            // Derive hash based on token, offerer, recipient, and proxy usage.
            bytes32 hash = _hashBatchableItemIdentifier(
                initialItem.token,
                initialExecution.offerer,
                initialItem.recipient,
                initialExecution.useProxy
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

                // Retrieve the associated 1155 execution element.
                Execution memory execution = executions[executionIndex];

                // Retrieve the item of the execution element.
                ReceivedItem memory item = execution.item;

                // Derive hash based on the same parameters as the initial hash.
                hash = _hashBatchableItemIdentifier(
                    item.token,
                    execution.offerer,
                    item.recipient,
                    execution.useProxy
                );

                // Assume no matching hash exists unless proven otherwise.
                bool foundMatchingHash = false;

                // Iterate over all known unique hashes.
                for (uint256 j = 0; j < uniqueHashes; ++j) {
                    // If the hash matches the known unique hash in question...
                    if (hash == batches[j].hash) {
                        // Retrieve execution index of the original execution.
                        uint256[] memory existingExecutionIndices = batches[j].executionIndices;

                        // Allocate execution indices array w/ an extra element.
                        uint256[] memory newExecutionIndices = new uint256[](existingExecutionIndices.length + 1);

                        // Iterate over existing execution indices.
                        for (uint256 k = 0; k < existingExecutionIndices.length; ++k) {
                            // Add them to the new execution indices array.
                            newExecutionIndices[k] = existingExecutionIndices[k];
                        }

                        // Add new execution index to the end of the array.
                        newExecutionIndices[existingExecutionIndices.length] = indexBy1155[j];

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

            // Iterate over each potential batch (determined by total unique hashes).
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

    /// @dev Internal pure function to complete the process of "compressing" executions.
    /// @param executions An array of uncompressed executions.
    /// @param batches An array of elements indicating which executions form the "baseline" for a batch.
    /// @param batchExecutionPointers An array of indices, incremented by one (as zero indicates no batching), that each point to a respective batch per execution.
    /// @param totalUsedInBatch The total execution elements that can be batched.
    /// @param totalBatches The total number of batch executions.
    /// @return An array of executions that could not be compressed.
    /// @return An array of executions (all ERC1155 transfers) that have been compressed into batches.
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

                // If the execution is a standard execution...
                if (batchExecutionPointer == 0) {
                    // Copy it to next standard index, then increment the index.
                    standardExecutions[nextStandardExecutionIndex++] = executions[i];
                // Otherwise, it is a batch execution.
                } else {
                    // Retrieve the execution element.
                    Execution memory execution = executions[i];

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
                    uint256 batchElementIndex = batchElementIndices[batchExecutionIndex]++;

                    // Update current element's batch with tokenId and amount.
                    batchExecutions[batchExecutionIndex].tokenIds[batchElementIndex] = execution.item.identifierOrCriteria;
                    batchExecutions[batchExecutionIndex].amounts[batchElementIndex] = execution.item.endAmount;
                }
            }

            // Return both the standard and batch execution arrays.
            return (standardExecutions, batchExecutions);
        }
    }

    /// @dev Internal pure function to ensure that an order index is in range and, if so, to return the parameters of the associated order.
    /// @param orders An array of orders.
    /// @param index The order index specified by the fulfillment component.
    /// @return The parameters of the order at the given index.
    function _getOrderParametersByFulfillmentIndex(
        Order[] memory orders,
        uint256 index
    ) internal pure returns (OrderParameters memory) {
        // Ensure that the order index is in range.
        if (index >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

        // Return the parameters of the order at the given order index.
        return orders[index].parameters;
    }

    /// @dev Internal pure function to ensure that an offer component index is in range and, if so, to return the associated offer item.
    /// @param orderParameters The parameters of the order.
    /// @param index The item index specified by the fulfillment component.
    /// @return The offer item at the given index.
    function _getOrderOfferComponentByItemIndex(
        OrderParameters memory orderParameters,
        uint256 index
    ) internal pure returns (OfferedItem memory) {
        // Ensure that the offer index is in range.
        if (index >= orderParameters.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }

        // Return the offer item at the given index.
        return orderParameters.offer[index];
    }

    /// @dev Internal pure function to ensure that a consideration component index is in range and, if so, to return the associated consideration item.
    /// @param orderParameters The parameters of the order.
    /// @param index The item index specified by the fulfillment component.
    /// @return The consideration item at the given index.
    function _getOrderConsiderationComponentByItemIndex(
        OrderParameters memory orderParameters,
        uint256 index
    ) internal pure returns (ReceivedItem memory) {
        // Ensure that the consideration index is in range.
        if (index >= orderParameters.consideration.length) {
            revert FulfilledOrderConsiderationIndexOutOfRange();
        }

        // Return the consideration item at the given index.
        return orderParameters.consideration[index];
    }

    /// @dev Internal pure function to match offer items to consideration items on a group of orders via a supplied fulfillment.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param orders The orders to match.
    /// @param fulfillment An element allocating offer components to consideration components.
    /// Note that each consideration component must be fully met in order for the match operation to be valid.
    /// @param useOffererProxyPerOrder An array of booleans indicating whether to source approvals for the fulfilled tokens on each order from their respective proxy.
    /// @return execution A transfer to performed as part of the supplied fulfillment.
    /// Note that this execution object can be compressed further by aggregating batch transfers.
    function _applyFulfillment(
        Order[] memory orders,
        Fulfillment memory fulfillment,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        Execution memory execution
    ) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            fulfillment.offerComponents.length == 0 ||
            fulfillment.considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Read offer component's initial order index and place it on the stack.
        uint256 currentOrderIndex = fulfillment.offerComponents[0].orderIndex;

        // Retrieve order designated by offer component's initial order index.
        OrderParameters memory initialOfferComponentOrder = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        // Read proxy usage flag from respective array and place on the stack.
        bool useProxy = useOffererProxyPerOrder[currentOrderIndex];

        // Read offer component's initial item index and place it on the stack.
        uint256 currentItemIndex = fulfillment.offerComponents[0].itemIndex;

        // Retrieve offer designated by the offer component's first item index.
        OfferedItem memory offeredItem = _getOrderOfferComponentByItemIndex(
            initialOfferComponentOrder,
            currentItemIndex
        );

        // Read consideration component's initial order index & place on stack.
        currentOrderIndex = fulfillment.considerationComponents[0].orderIndex;

        // Retrieve consideration order at the first order component index.
        OrderParameters memory initialConsiderationComponentOrder = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        // Read consideration component's initial item index and place on stack.
        currentItemIndex = fulfillment.considerationComponents[0].itemIndex;

        // Retrieve consideration item designated by first item component index.
        ReceivedItem memory requiredConsideration = _getOrderConsiderationComponentByItemIndex(
            initialConsiderationComponentOrder,
            currentItemIndex
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            offeredItem.itemType != requiredConsideration.itemType ||
            offeredItem.token != requiredConsideration.token ||
            offeredItem.identifierOrCriteria != requiredConsideration.identifierOrCriteria
        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents();
        }

        // Clear initial offer amount to indicate offer item has been consumed.
        orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

        // Clear initial consideration amount to indicate item is fulfilled.
        orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

        // Iterate over each offer component on the fulfillment.
        for (uint256 i = 1; i < fulfillment.offerComponents.length;) {
            // Retrieve the offer component from the fulfillment.
            FulfillmentComponent memory offerComponent = fulfillment.offerComponents[i];

            // Read offer component's order index and place it on the stack.
            currentOrderIndex = offerComponent.orderIndex;

            // Retrieve offer designated by the offer component's item index.
            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            // Read offer component's item index and place it on the stack.
            currentItemIndex = offerComponent.itemIndex;

            // Retrieve offer designated by the offer component's item index.
            OfferedItem memory additionalOfferedItem = _getOrderOfferComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            // Ensure all relevant parameters are consistent with initial offer.
            if (
                initialOfferComponentOrder.offerer != subsequentOrder.offerer ||
                offeredItem.itemType != additionalOfferedItem.itemType ||
                offeredItem.token != additionalOfferedItem.token ||
                offeredItem.identifierOrCriteria != additionalOfferedItem.identifierOrCriteria ||
                useProxy != useOffererProxyPerOrder[currentOrderIndex]
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            // Increase the total offer amount by the current amount.
            offeredItem.endAmount += additionalOfferedItem.endAmount;

            // Clear offer amount to indicate that offer item has been consumed.
            orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // Iterate over each consideration component on the fulfillment.
        for (uint256 i = 1; i < fulfillment.considerationComponents.length;) {
            // Retrieve the consideration component from the fulfillment.
            FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[i];

            // Read consideration component's order index and place on stack.
            currentOrderIndex = considerationComponent.orderIndex;

            // Retrieve consideration designated by offer component's item index.
            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            // Read consideration component's item index and place on the stack.
            currentItemIndex = considerationComponent.itemIndex;

            // Retrieve consideration designated by the component's item index.
            ReceivedItem memory additionalRequiredConsideration = _getOrderConsiderationComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            // Ensure key parameters are consistent with initial consideration.
            if (
                requiredConsideration.recipient != additionalRequiredConsideration.recipient ||
                requiredConsideration.itemType != additionalRequiredConsideration.itemType ||
                requiredConsideration.token != additionalRequiredConsideration.token ||
                requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            // Increase the total consideration amount by the current amount.
            requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;

            // Clear consideration amount to indicate item has been fulfilled.
            orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // If total consideration amount exceeds the offer amount...
        if (requiredConsideration.endAmount > offeredItem.endAmount) {
            // Retrieve the final consideration component from the fulfillment.
            FulfillmentComponent memory targetComponent = fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1];

            // Add excess consideration amount to the original orders array.
            orders[targetComponent.orderIndex].parameters.consideration[targetComponent.itemIndex].endAmount = requiredConsideration.endAmount - offeredItem.endAmount;

            // Reduce total consideration amount to equal the offer amount.
            requiredConsideration.endAmount = offeredItem.endAmount;
        } else {
            // Retrieve the final offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = fulfillment.offerComponents[fulfillment.offerComponents.length - 1];

            // Add excess offer amount to the original orders array.
            orders[targetComponent.orderIndex].parameters.offer[targetComponent.itemIndex].endAmount = offeredItem.endAmount - requiredConsideration.endAmount;
        }

        // Return the final execution that will be triggered for relevant items.
        return Execution(
            requiredConsideration,
            initialOfferComponentOrder.offerer,
            useProxy
        );
    }

    /// @dev Internal pure function to return a fraction of a given value and to ensure that the resultant value does not have any fractional component.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// @param denominator A value indicating the total size of the order.
    /// @param value The value for which to compute the fraction.
    function _getFraction(
        uint120 numerator,
        uint120 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * uint256(numerator);

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

    /// @dev Internal pure function to ensure that a given element is contained in a merkle root via a supplied proof.
    /// @param leaf The element for which to prove inclusion.
    /// @param root The merkle root that inclusion will be proved against.
    /// @param proof The merkle proof.
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

    /// @dev Internal pure function to efficiently hash two bytes32 values.
    /// @param a The first component of the hash.
    /// @param b The second component of the hash.
    /// @return value The hash.
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