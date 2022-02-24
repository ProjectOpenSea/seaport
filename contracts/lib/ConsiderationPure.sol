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

    /// @dev Internal view function to ensure that the sentinel value for the reentrancy guard is not currently set.
    function _assertNonReentrant() internal view {
        // Ensure that the reentrancy guard is not currently set.
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
    }

    /// @dev Internal view function to ensure that the current time falls within an order's valid timespan.
    /// @param startTime The time at which the order becomes active.
    /// @param endTime The time at which the order becomes inactive.
    function _assertValidTime(
        uint256 startTime,
        uint256 endTime
    ) internal view {
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert InvalidTime();
        }
    }

    /// @dev Internal view function to validate whether a token transfer was successful based on the returned status and data. Note that malicious or non-compliant tokens may still return improper data — consider checking token balances before and after for more comprehensive transfer validation.
    /// @param ok The status of the call to transfer.
    /// Note that contract size must be checked on status of true and no returned data to rule out undeployed contracts.
    /// @param dataLength The length of the data returned from the call to transfer.
    /// Note that this value could also be read directly via returndatasize().
    /// @param token The token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param tokenId The tokenId to transfer (if applicable).
    /// @param amount The amount to transfer (if applicable).
    function _assertValidTokenTransfer(
        bool ok,
        uint256 dataLength,
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        if (!ok) {
            if (dataLength != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert TokenTransferGenericFailure(token, from, to, tokenId, amount);
            }
        }

        _assertContractIsDeployed(token, dataLength);
    }

    /// @dev Internal view function to item that a contract is deployed to a given account.
    /// @param account The account to check.
    /// @param dataLength The length of data returned from the last call to the account.
    function _assertContractIsDeployed(
        address account,
        uint256 dataLength
    ) internal view {
        if (dataLength == 0) {
            uint256 size;
            assembly {
                size := extcodesize(account)
            }
            if (size == 0) {
                revert NoContract(account);
            }
        }
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

                uint256 orderIndex = criteriaResolver.orderIndex;

                if (orderIndex >= orders.length) {
                    revert OrderCriteriaResolverOutOfRange();
                }

                uint256 componentIndex = criteriaResolver.index;

                if (criteriaResolver.side == Side.OFFER) {
                    if (componentIndex >= orders[orderIndex].parameters.offer.length) {
                        revert OfferCriteriaResolverOutOfRange();
                    }

                    OfferedItem memory offer = orders[orderIndex].parameters.offer[componentIndex];
                    ItemType itemType = offer.itemType;
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForOfferedItem();
                    }

                    // empty criteria signifies a collection-wide offer (sell any item)
                    if (offer.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            offer.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.offer[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    orders[orderIndex].parameters.offer[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                } else {
                    if (componentIndex >= orders[orderIndex].parameters.consideration.length) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    ReceivedItem memory consideration = orders[orderIndex].parameters.consideration[componentIndex];
                    ItemType itemType = consideration.itemType;
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForConsideredItem();
                    }

                    // empty criteria signifies a collection-wide consideration (buy any item)
                    if (consideration.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            consideration.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.consideration[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    orders[orderIndex].parameters.consideration[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                }
            }

            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    if (uint256(order.parameters.consideration[j].itemType) > 3) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
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
            uint256 totalExecutions = executions.length;

            if (totalExecutions < 2) {
                return (executions, new BatchExecution[](0));
            }

            uint256 total1155Executions = 0;
            uint256[] memory indexBy1155 = new uint256[](totalExecutions);

            // Iterate over each execution.
            for (uint256 i = 0; i < executions.length; ++i) {
                if (executions[i].item.itemType == ItemType.ERC1155) {
                    indexBy1155[total1155Executions] = i;
                    ++total1155Executions;
                }
            }

            if (total1155Executions < 2) {
                return (executions, new BatchExecution[](0));
            }

            Batch[] memory batches = new Batch[](total1155Executions);

            uint256 initialExecutionIndex = indexBy1155[0];
            Execution memory initialExecution = executions[initialExecutionIndex];
            ReceivedItem memory initialItem = initialExecution.item;
            bytes32 hash = _hashBatchableItemIdentifier(
                initialItem.token,
                initialExecution.offerer,
                initialItem.account,
                initialExecution.useProxy
            );

            uint256[] memory executionIndices = new uint256[](1);
            executionIndices[0] = initialExecutionIndex;

            batches[0].hash = hash;
            batches[0].executionIndices = executionIndices;

            uint256 uniqueHashes = 1;

            for (uint256 i = 1; i < total1155Executions; ++i) {
                uint256 executionIndex = indexBy1155[i];
                Execution memory execution = executions[executionIndex];
                ReceivedItem memory item = execution.item;

                hash = _hashBatchableItemIdentifier(
                    item.token,
                    execution.offerer,
                    item.account,
                    execution.useProxy
                );

                bool hasUniqueHash = true;
                for (uint256 j = 0; j < uniqueHashes; ++j) {
                    if (hash == batches[j].hash) {
                        uint256[] memory existingExecutionIndices = batches[j].executionIndices;

                        uint256[] memory newExecutionIndices = new uint256[](existingExecutionIndices.length + 1);
                        for (uint256 k = 0; k < existingExecutionIndices.length; ++k) {
                            newExecutionIndices[k] = existingExecutionIndices[k];
                        }
                        newExecutionIndices[existingExecutionIndices.length] = indexBy1155[j];

                        batches[j].executionIndices = newExecutionIndices;

                        hasUniqueHash = false;
                    }
                }

                if (hasUniqueHash) {
                    executionIndices = new uint256[](1);
                    executionIndices[0] = executionIndex;

                    batches[uniqueHashes++].hash = hash;
                    batches[uniqueHashes].executionIndices = executionIndices;
                }
            }

            if (uniqueHashes == total1155Executions) {
                return (executions, new BatchExecution[](0));
            }

            // add one to the batch ID if it's used in a batch
            uint256[] memory usedInBatch = new uint256[](totalExecutions);

            uint256[] memory totals = new uint256[](2);
            for (uint256 i = 0; i < uniqueHashes; ++i) {
                uint256[] memory indices = batches[i].executionIndices;
                uint256 indicesLength = indices.length;
                if (indicesLength > 1) {
                    ++totals[1];
                    totals[0] += indicesLength;
                    for (uint256 j = 0; j < indicesLength; ++j) {
                        usedInBatch[indices[j]] = i + 1;
                    }
                }
            }

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
    /// @param usedInBatch An array of indices (incremented by one as zero indicates no batching) per execution indicating which batch the execution should be applied to.
    /// @param totalUsedInBatch The total execution elements that can be batched.
    /// @param totalBatches The total number of batch executions.
    /// @return standardExecutions An array of executions that could not be compressed.
    /// @return batchExecutions An array of executions (all ERC1155 transfers) that have been compressed into batches.
    function _splitExecution(
        Execution[] memory executions,
        Batch[] memory batches,
        uint256[] memory usedInBatch,
        uint256 totalUsedInBatch,
        uint256 totalBatches
    ) internal pure returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            uint256 totalExecutions = executions.length;

            Execution[] memory executeWithoutBatch = new Execution[](
                totalExecutions - totalUsedInBatch
            );
            BatchExecution[] memory executeWithBatch = new BatchExecution[](
                totalBatches
            );

            uint256 lastNoBatchIndex = 0;
            uint256[] memory batchElementCounters = new uint256[](totalBatches);

            // Iterate over each execution.
            for (uint256 i = 0; i < totalExecutions; ++i) {
                uint256 isUsedInBatch = usedInBatch[i];
                if (isUsedInBatch == 0) {
                    executeWithoutBatch[lastNoBatchIndex++] = executions[i];
                } else {
                    uint256 batchUsed = isUsedInBatch - 1;

                    Execution memory execution = executions[i];

                    if (executeWithBatch[batchUsed].token == address(0)) {
                        uint256 tokenElements = batches[batchUsed].executionIndices.length;
                        executeWithBatch[batchUsed] = BatchExecution({
                            token: execution.item.token,
                            from: execution.offerer,
                            to: execution.item.account,
                            tokenIds: new uint256[](tokenElements),
                            amounts: new uint256[](tokenElements),
                            useProxy: execution.useProxy
                        });
                    }

                    uint256 counter = batchElementCounters[batchUsed]++;

                    executeWithBatch[batchUsed].tokenIds[counter] = execution.item.identifierOrCriteria;
                    executeWithBatch[batchUsed].amounts[counter] = execution.item.endAmount;
                }
            }

            return (executeWithoutBatch, executeWithBatch);
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
        if (index >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

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
        if (index >= orderParameters.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }
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
        if (index >= orderParameters.consideration.length) {
            revert FulfilledOrderConsiderationIndexOutOfRange();
        }
        return orderParameters.consideration[index];
    }

    /// @dev Internal pure function to match offer items to consideration items on a group of orders via a supplied fulfillment.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param orders The orders to match.
    /// @param fulfillment An element allocating offer components to consideration components.
    /// Note that each consideration component must be fully met in order for the match operation to be valid.
    /// @param useOffererProxyPerOrder An array of booleans indicating whether to source approvals for the fulfilled tokens on each order from their respective proxy.
    /// @return execution A transfer to performed as part of the supplied fulfillment.
    /// Note that this execution object may be compressed further in order to batch transfers.
    function _applyFulfillment(
        Order[] memory orders,
        Fulfillment memory fulfillment,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        Execution memory execution
    ) {
        if (
            fulfillment.offerComponents.length == 0 ||
            fulfillment.considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        uint256 currentOrderIndex = fulfillment.offerComponents[0].orderIndex;

        OrderParameters memory orderWithInitialOffer = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        bool useProxy = useOffererProxyPerOrder[currentOrderIndex];

        uint256 currentItemIndex = fulfillment.offerComponents[0].itemIndex;

        OfferedItem memory offeredItem = _getOrderOfferComponentByItemIndex(
            orderWithInitialOffer,
            currentItemIndex
        );

        orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.offerComponents.length;) {
            FulfillmentComponent memory offerComponent = fulfillment.offerComponents[i];
            currentOrderIndex = offerComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentItemIndex = offerComponent.itemIndex;

            OfferedItem memory additionalOfferedItem = _getOrderOfferComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            if (
                orderWithInitialOffer.offerer != subsequentOrder.offerer ||
                offeredItem.itemType != additionalOfferedItem.itemType ||
                offeredItem.token != additionalOfferedItem.token ||
                offeredItem.identifierOrCriteria != additionalOfferedItem.identifierOrCriteria ||
                useProxy != useOffererProxyPerOrder[currentOrderIndex]
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            offeredItem.endAmount += additionalOfferedItem.endAmount;
            orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        currentOrderIndex = fulfillment.considerationComponents[0].orderIndex;

        OrderParameters memory orderWithInitialConsideration = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        currentItemIndex = fulfillment.considerationComponents[0].itemIndex;

        ReceivedItem memory requiredConsideration = _getOrderConsiderationComponentByItemIndex(
            orderWithInitialConsideration,
            currentItemIndex
        );

        orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.considerationComponents.length;) {
            FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[i];
            currentOrderIndex = considerationComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentItemIndex = considerationComponent.itemIndex;

            ReceivedItem memory additionalRequiredConsideration = _getOrderConsiderationComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            if (
                requiredConsideration.account != additionalRequiredConsideration.account ||
                requiredConsideration.itemType != additionalRequiredConsideration.itemType ||
                requiredConsideration.token != additionalRequiredConsideration.token ||
                requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;
            orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        if (requiredConsideration.endAmount > offeredItem.endAmount) {
            FulfillmentComponent memory targetComponent = fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.consideration[targetComponent.itemIndex].endAmount = requiredConsideration.endAmount - offeredItem.endAmount;
            requiredConsideration.endAmount = offeredItem.endAmount;
        } else {
            FulfillmentComponent memory targetComponent = fulfillment.offerComponents[fulfillment.offerComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.offer[targetComponent.itemIndex].endAmount = offeredItem.endAmount - requiredConsideration.endAmount;
        }

        // Return the final execution that will be triggered for relevant items.
        return Execution(
            requiredConsideration,
            orderWithInitialOffer.offerer,
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