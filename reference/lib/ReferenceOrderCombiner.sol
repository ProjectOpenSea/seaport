// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { Side, ItemType } from "contracts/lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    AdditionalRecipient,
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
    CriteriaResolver
} from "contracts/lib/ConsiderationStructs.sol";

import { AccumulatorStruct, OrderToExecute } from "./ReferenceConsiderationStructs.sol";

import { ReferenceOrderFulfiller } from "./ReferenceOrderFulfiller.sol";

import { ReferenceFulfillmentApplier } from "./ReferenceFulfillmentApplier.sol";

import "./ReferenceConsiderationConstants.sol";

/**
 * @title OrderCombiner
 * @author 0age
 * @notice OrderCombiner contains logic for fulfilling combinations of orders,
 *         either by matching offer items to consideration items or by
 *         fulfilling orders where available.
 */
contract ReferenceOrderCombiner is
    ReferenceOrderFulfiller,
    ReferenceFulfillmentApplier
{
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController)
        ReferenceOrderFulfiller(conduitController)
    {}

    /**
     * @notice Internal function to attempt to fill a group of orders, fully or
     *         partially, with an arbitrary number of items for offer and
     *         consideration per order alongside criteria resolvers containing
     *         specific token identifiers and associated proofs. Any order that
     *         is not currently active, has already been fully filled, or has
     *         been cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible as indicated by the
     *         supplied offer and consideration component arrays and aggregated
     *         items will be transferred to the fulfiller or to each intended
     *         recipient, respectively. Note that a failing item transfer or an
     *         issue with order formatting will cause the entire batch to fail.
     *
     * @param advancedOrders            The orders to fulfill along with the
     *                                  fraction of those orders to attempt to
     *                                  fill. Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or their proxy if indicated by
     *                                  the order) to transfer any relevant
     *                                  tokens on their behalf and that
     *                                  contracts must implement
     *                                  `onERC1155Received` in order to receive
     *                                  ERC1155 tokens as consideration. Also
     *                                  note that all offer and consideration
     *                                  components must have no remainder after
     *                                  multiplication of the respective amount
     *                                  with the supplied fraction for an
     *                                  order's partial fill amount to be
     *                                  considered valid.
     *
     * @param ordersToExecute           The orders to execute.  This is an
     *                                  explicit version of advancedOrders without
     *                                  memory optimization, that provides
     *                                  an array of spentItems and receivedItems
     *                                  for fulfillment and event emission.
     *
     * @param criteriaResolvers         An array where each element contains a
     *                                  reference to a specific offer or
     *                                  consideration, a token identifier, and a
     *                                  proof that the supplied token identifier
     *                                  is contained in the merkle root held by
     *                                  the item in question's criteria element.
     *                                  Note that an empty criteria indicates
     *                                  that any (transferrable) token
     *                                  identifier on the token in question is
     *                                  valid and that no associated proof needs
     *                                  to be supplied.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used (and
     *                                  direct approvals set on Consideration).
     * @param maximumFulfilled          The maximum number of orders to fulfill.
     *
     * @return availableOrders          An array of booleans indicating if each order
     *                                  with an index corresponding to the index of the
     *                                  returned boolean was fulfillable or not.
     * @return executions               An array of elements indicating the sequence of
     *                                  transfers performed as part of matching the given
     *                                  orders.
     */
    function _fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        uint256 maximumFulfilled
    )
        internal
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions
        )
    {
        // Validate orders, apply amounts, & determine if they utilize conduits
        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            ordersToExecute,
            criteriaResolvers,
            false, // Signifies that invalid orders should NOT revert.
            maximumFulfilled
        );

        // Aggregate used offer and consideration items and execute transfers.
        (availableOrders, executions) = _executeAvailableFulfillments(
            ordersToExecute,
            offerFulfillments,
            considerationFulfillments,
            fulfillerConduitKey
        );

        // Return order fulfillment details and executions.
        return (availableOrders, executions);
    }

    /**
     * @dev Internal function to validate a group of orders, update their
     *      statuses, reduce amounts by their previously filled fractions, apply
     *      criteria resolvers, and emit OrderFulfilled events.
     *
     * @param advancedOrders    The advanced orders to validate and reduce by
     *                          their previously filled amounts.
     * @param ordersToExecute   The orders to validate and execute.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          a root of zero indicates that any transferrable
     *                          token identifier is valid and that no proof
     *                          needs to be supplied.
     * @param revertOnInvalid   A boolean indicating whether to revert on any
     *                          order being invalid; setting this to false will
     *                          instead cause the invalid order to be skipped.
     * @param maximumFulfilled  The maximum number of orders to fulfill.
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid,
        uint256 maximumFulfilled
    ) internal notEntered nonReentrant {
        // Read length of orders array and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Track the order hash for each order being fulfilled.
        bytes32[] memory orderHashes = new bytes32[](totalOrders);

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the current order.
            AdvancedOrder memory advancedOrder = advancedOrders[i];
            // Retreive the order to execute.
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Determine if max number orders have already been fulfilled.
            if (maximumFulfilled == 0) {
                // Mark fill fraction as zero as the order will not be used.
                advancedOrder.numerator = 0;

                // Mark fill fraction as zero as the order will not be used.
                orderToExecute.numerator = 0;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Validate it, update status, and determine fraction to fill.
            (
                bytes32 orderHash,
                uint256 numerator,
                uint256 denominator
            ) = _validateOrderAndUpdateStatus(
                    advancedOrder,
                    criteriaResolvers,
                    revertOnInvalid,
                    orderHashes
                );

            // Do not track hash or adjust prices if order is not fulfilled.
            if (numerator == 0) {
                // Mark fill fraction as zero if the order is not fulfilled.
                advancedOrder.numerator = 0;

                // Mark fill fraction as zero as the order will not be used.
                orderToExecute.numerator = 0;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Otherwise, track the order hash in question.
            orderHashes[i] = orderHash;

            // Decrement the number of fulfilled orders.
            maximumFulfilled--;

            // Place the start time for the order on the stack.
            uint256 startTime = advancedOrder.parameters.startTime;

            // Derive the duration for the order and place it on the stack.
            uint256 duration = advancedOrder.parameters.endTime - startTime;

            // Derive time elapsed since the order started & place on stack.
            uint256 elapsed = block.timestamp - startTime;

            // Derive time remaining until order expires and place on stack.
            uint256 remaining = duration - elapsed;

            // Retrieve array of offer items for the order in question.
            OfferItem[] memory offer = advancedOrder.parameters.offer;

            // Iterate over each offer item on the order.
            for (uint256 j = 0; j < offer.length; ++j) {
                // Retrieve the offer item.
                OfferItem memory offerItem = offer[j];

                // Apply order fill fraction to offer item end amount.
                uint256 endAmount = _getFraction(
                    numerator,
                    denominator,
                    offerItem.endAmount
                );

                // Reuse same fraction if start and end amounts are equal.
                if (offerItem.startAmount == offerItem.endAmount) {
                    // Apply derived amount to both start and end amount.
                    offerItem.startAmount = endAmount;
                } else {
                    // Apply order fill fraction to offer item start amount.
                    offerItem.startAmount = _getFraction(
                        numerator,
                        denominator,
                        offerItem.startAmount
                    );
                }

                // Update end amount in memory to match the derived amount.
                offerItem.endAmount = endAmount;

                // Adjust offer amount using current time; round down.
                offerItem.startAmount = _locateCurrentAmount(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    elapsed,
                    remaining,
                    duration,
                    false // Round down.
                );

                // Modify the OrderToExecute Spent Item Amount.
                orderToExecute.spentItems[j].amount = offerItem.startAmount;
            }

            // Retrieve array of consideration items for order in question.
            ConsiderationItem[] memory consideration = (
                advancedOrder.parameters.consideration
            );

            // Iterate over each consideration item on the order.
            for (uint256 j = 0; j < consideration.length; ++j) {
                // Retrieve the consideration item.
                ConsiderationItem memory considerationItem = (consideration[j]);

                // Apply fraction to consideration item end amount.
                uint256 endAmount = _getFraction(
                    numerator,
                    denominator,
                    considerationItem.endAmount
                );

                // Reuse same fraction if start and end amounts are equal.
                if (
                    considerationItem.startAmount == considerationItem.endAmount
                ) {
                    // Apply derived amount to both start and end amount.
                    considerationItem.startAmount = endAmount;
                } else {
                    // Apply fraction to consideration item start amount.
                    considerationItem.startAmount = _getFraction(
                        numerator,
                        denominator,
                        considerationItem.startAmount
                    );
                }

                // Update end amount in memory to match the derived amount.
                considerationItem.endAmount = endAmount;

                // Adjust consideration amount using current time; round up.
                considerationItem.startAmount = (
                    _locateCurrentAmount(
                        considerationItem.startAmount,
                        considerationItem.endAmount,
                        elapsed,
                        remaining,
                        duration,
                        true // Round up.
                    )
                );

                // Modify the OrderToExecute Received item amount.
                orderToExecute.receivedItems[j].amount = considerationItem
                    .startAmount;
            }
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(ordersToExecute, criteriaResolvers);
        // Determine the fulfiller (revertOnInvalid ? address(0) : msg.sender).
        address fulfiller = revertOnInvalid ? address(0) : msg.sender;

        // Emit an event for each order signifying that it has been fulfilled.

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Do not emit an event if no order hash is present.
            if (orderHashes[i] == bytes32(0)) {
                continue;
            }

            // Retrieve parameters for the order in question.
            OrderParameters memory orderParameters = (
                advancedOrders[i].parameters
            );

            // Get the array of spentItems from the orderToExecute struct.
            SpentItem[] memory spentItems = ordersToExecute[i].spentItems;

            // Get the array of spentIreceivedItemstems from the orderToExecute struct.
            ReceivedItem[] memory receivedItems = ordersToExecute[i]
                .receivedItems;

            // Emit an event signifying that the order has been fulfilled.
            emit OrderFulfilled(
                orderHashes[i],
                orderParameters.offerer,
                orderParameters.zone,
                fulfiller,
                spentItems,
                receivedItems
            );
        }
    }

    /**
     * @dev Internal function to fulfill a group of validated orders, fully or
     *      partially, with an arbitrary number of items for offer and
     *      consideration per order and to execute transfers. Any order that is
     *      not currently active, has already been fully filled, or has been
     *      cancelled will be omitted. Remaining offer and consideration items
     *      will then be aggregated where possible as indicated by the supplied
     *      offer and consideration component arrays and aggregated items will
     *      be transferred to the fulfiller or to each intended recipient,
     *      respectively. Note that a failing item transfer or an issue with
     *      order formatting will cause the entire batch to fail.
     *
     * @param ordersToExecute           The orders to execute.  This is an
     *                                  explicit version of advancedOrders without
     *                                  memory optimization, that provides
     *                                  an array of spentItems and receivedItems
     *                                  for fulfillment and event emission.
     *                                  Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or the conduit if indicated by
     *                                  the order) to transfer any relevant
     *                                  tokens on their behalf and that
     *                                  contracts must implement
     *                                  `onERC1155Received` in order to receive
     *                                  ERC1155 tokens as consideration. Also
     *                                  note that all offer and consideration
     *                                  components must have no remainder after
     *                                  multiplication of the respective amount
     *                                  with the supplied fraction for an
     *                                  order's partial fill amount to be
     *                                  considered valid.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used (and
     *                                  direct approvals set on Consideration).
     *
     * * @return availableOrders        An array of booleans indicating if each order
     *                                  with an index corresponding to the index of the
     *                                  returned boolean was fulfillable or not.
     * @return executions               An array of elements indicating the sequence of
     *                                  transfers performed as part of matching the given
     *                                  orders.
     */
    function _executeAvailableFulfillments(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        bytes32 fulfillerConduitKey
    )
        internal
        returns (bool[] memory availableOrders, Execution[] memory executions)
    {
        // Retrieve length of offer fulfillments array and place on the stack.
        uint256 totalOfferFulfillments = offerFulfillments.length;

        // Retrieve length of consideration fulfillments array & place on stack.
        uint256 totalConsiderationFulfillments = ();

        // Allocate an execution for each offer and consideration fulfillment.
        executions = new Execution[](
            totalOfferFulfillments + totalConsiderationFulfillments
        );

        // Track number of filtered executions.
        uint256 totalFilteredExecutions = 0;

        // Iterate over each offer fulfillment.
        for (uint256 i = 0; i < totalOfferFulfillments; ++i) {
            /// Retrieve the offer fulfillment components in question.
            FulfillmentComponent[] memory components = (offerFulfillments[i]);

            // Derive aggregated execution corresponding with fulfillment.
            Execution memory execution = _aggregateAvailable(
                ordersToExecute,
                Side.OFFER,
                components,
                fulfillerConduitKey
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[i - totalFilteredExecutions] = execution;
            }
        }

        // Iterate over each consideration fulfillment.
        for (uint256 i = 0; i < totalConsiderationFulfillments; ++i) {
            /// Retrieve consideration fulfillment components in question.
            FulfillmentComponent[] memory components = (
                considerationFulfillments[i]
            );

            // Derive aggregated execution corresponding with fulfillment.
            Execution memory execution = _aggregateAvailable(
                ordersToExecute,
                Side.CONSIDERATION,
                components,
                fulfillerConduitKey
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[
                    i + totalOfferFulfillments - totalFilteredExecutions
                ] = execution;
            }
        }

        // If some number of executions have been filtered...
        if (totalFilteredExecutions != 0) {
            /**
             *   The following is highly inefficient, but written this way
             *   to show in the most simplest form what the optimized
             *   contract is performing inside its assembly.
             */

            // Get the total execution length.
            uint256 executionLength = (totalOfferFulfillments +
                totalConsiderationFulfillments) - totalFilteredExecutions;

            // Create an array of executions that will be executed.
            Execution[] memory filteredExecutions = new Execution[](
                executionLength
            );

            // Create new array from the exsiting Executions
            for (uint256 i = 0; i < executionLength; ++i) {
                filteredExecutions[i] = executions[i];
            }

            // Set the executions array to the newly created array.
            executions = filteredExecutions;
        }
        // Revert if no orders are available.
        if (executions.length == 0) {
            revert NoSpecifiedOrdersAvailable();
        }
        // Perform final checks and compress executions into standard and batch.
        availableOrders = _performFinalChecksAndExecuteOrders(
            ordersToExecute,
            executions
        );

        return (availableOrders, executions);
    }

    /**
     * @dev Internal function to perform a final check that each consideration
     *      item for an arbitrary number of fulfilled orders has been met and to
     *      trigger associated execututions, transferring the respective items.
     *
     * @param ordersToExecute    The orders to check and perform executions.
     * @param executions         An array of uncompressed elements indicating
     *                           the sequence of transfers to perform when
     *                           fulfilling the given orders.
     *
     * @param executions         An array of elements indicating the sequence of
     *                           transfers to perform when fulfilling the given
     *                           orders.
     *
     * @return availableOrders  An array of booleans indicating if each order
     *                          with an index corresponding to the index of the
     *                          returned boolean was fulfillable or not.
     */
    function _performFinalChecksAndExecuteOrders(
        OrderToExecute[] memory ordersToExecute,
        Execution[] memory executions
    ) internal returns (bool[] memory availableOrders) {
        // Retrieve the length of the advanced orders array and place on stack.
        uint256 totalOrders = ordersToExecute.length;

        // Initialize array for tracking available orders.
        availableOrders = new bool[](totalOrders);
        // Iterate over orders to ensure all considerations are met.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order in question.
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Skip consideration item checks for order if not fulfilled.
            if (orderToExecute.numerator == 0) {
                // Note: orders do not need to be marked as unavailable as a
                // new memory region has been allocated. Review carefully if
                // altering compiler version or managing memory manually.
                continue;
            }

            // Mark the order as available.
            availableOrders[i] = true;

            // Retrieve consideration items to ensure they are fulfilled.
            ReceivedItem[] memory consideration = (
                orderToExecute.receivedItems
            );

            // Iterate over each consideration item to ensure it is met.
            for (uint256 j = 0; j < consideration.length; ++j) {
                // Retrieve remaining amount on the consideration item.
                uint256 unmetAmount = consideration[j].amount;

                // Revert if the remaining amount is not zero.
                if (unmetAmount != 0) {
                    revert ConsiderationNotMet(i, j, unmetAmount);
                }
            }
        }

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        // Iterate over each execution.
        for (uint256 i = 0; i < executions.length; ++i) {
            // Retrieve the execution and the associated received item.
            Execution memory execution = executions[i];
            ReceivedItem memory item = execution.item;

            // If execution transfers native tokens, reduce value available.
            if (item.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Reduce ether remaining by amount.
                etherRemaining -= item.amount;
            }

            // Transfer the item specified by the execution.
            _transfer(
                item,
                execution.offerer,
                execution.conduitKey,
                accumulatorStruct
            );
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // Iterate over each batch execution.
        for (uint256 i = 0; i < batchExecutions.length; ++i) {
            // Perform the batch transfer.
            _batchTransferERC1155(batchExecutions[i]);
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }

        // Return the array containing available orders.
        return (availableOrders);
    }

    /**
     * @dev Internal function to match an arbitrary number of full or partial
     *      orders, each with an arbitrary number of items for offer and
     *      consideration, supplying criteria resolvers containing specific
     *      token identifiers and associated proofs as well as fulfillments
     *      allocating offer components to consideration components.
     *
     * @param advancedOrders    The advanced orders to match. Note that both the
     *                          offerer and fulfiller on each order must first
     *                          approve this contract (or their conduit if
     *                          indicated by the order) to transfer any relevant
     *                          tokens on their behalf and each consideration
     *                          recipient must implement `onERC1155Received` in
     *                          order toreceive ERC1155 tokens. Also note that
     *                          the offer and consideration components for each
     *                          order must have no remainder after multiplying
     *                          the respective amount with the supplied fraction
     *                          in order for the group of partial fills to be
     *                          considered valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          an empty root indicates that any (transferrable)
     *                          token identifier is valid and that no associated
     *                          proof needs to be supplied.
     * @param fulfillments      An array of elements allocating offer components
     *                          to consideration components. Note that each
     *                          consideration component must be fully met in
     *                          order for the match operation to be valid.
     *
     * @return executions       An array of elements indicating the sequence of
     *                          transfers performed as part of matching the given
     *                          orders.
     */
    function _matchAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) internal returns (Execution[] memory executions) {
        // Convert Advanced Orders to Orders to Execute
        OrderToExecute[]
            memory ordersToExecute = _convertAdvancedtoOrdersToExecute(
                advancedOrders
            );

        // Validate orders, apply amounts, & determine if they utilize conduits.
        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            ordersToExecute,
            criteriaResolvers,
            true, // Signifies that invalid orders should revert.
            advancedOrders.length
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(ordersToExecute, fulfillments);
    }

    /**
     * @dev Internal function to fulfill an arbitrary number of orders, either
     *      full or partial, after validating, adjusting amounts, and applying
     *      criteria resolvers.
     *
     * @param ordersToExecute    The orders to match, including a fraction to
     *                           attempt to fill for each order.
     * @param fulfillments       An array of elements allocating offer
     *                           components to consideration components. Note
     *                           that the final amount of each consideration
     *                           component must be zero for a match operation to
     *                           be considered valid.
     *
     * @return executions          An array of elements indicating the sequence
     *                            of transfers performed as part of
     *                            matching the given orders.
     */
    function _fulfillAdvancedOrders(
        OrderToExecute[] memory ordersToExecute,
        Fulfillment[] calldata fulfillments
    ) internal returns (Execution[] memory executions) {
        // Retrieve fulfillments array length and place on the stack.
        uint256 totalFulfillments = fulfillments.length;

        // Allocate executions by fulfillment and apply them to each execution.
        executions = new Execution[](totalFulfillments);

        // Track number of filtered executions.
        uint256 totalFilteredExecutions = 0;

        // Iterate over each fulfillment.
        for (uint256 i = 0; i < totalFulfillments; ++i) {
            /// Retrieve the fulfillment in question.
            Fulfillment calldata fulfillment = fulfillments[i];

            // Derive the execution corresponding with the fulfillment.
            Execution memory execution = _applyFulfillment(
                ordersToExecute,
                fulfillment.offerComponents,
                fulfillment.considerationComponents
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[i - totalFilteredExecutions] = execution;
            }
        }

        // If some number of executions have been filtered...
        if (totalFilteredExecutions != 0) {
            uint256 executionLength = totalFulfillments -
                totalFilteredExecutions;
            Execution[] memory filteredExecutions = new Execution[](
                executionLength
            );
            // Create new array from executions.
            for (uint256 i = 0; i < executionLength; ++i) {
                filteredExecutions[i] = executions[i];
            }
            // Perform final checks and compress executions into standard and batch.
            (, standardExecutions) = _performFinalChecksAndExecuteOrders(
                ordersToExecute,
                filteredExecutions
            );
        }

        // Perform final checks and execute orders.
        _performFinalChecksAndExecuteOrders(advancedOrders, executions);

        // Return both standard and batch ERC1155 executions.
        return (executions);
    }
}
