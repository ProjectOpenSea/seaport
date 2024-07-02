// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ItemType,
    OrderType,
    Side
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    SeaportInterface
} from "seaport-types/src/interfaces/SeaportInterface.sol";

import {
    AccumulatorStruct,
    OrderToExecute,
    StoredFractions,
    OrderValidation,
    OrderValidationParams
} from "./ReferenceConsiderationStructs.sol";

import { ReferenceOrderFulfiller } from "./ReferenceOrderFulfiller.sol";

import { ReferenceFulfillmentApplier } from "./ReferenceFulfillmentApplier.sol";

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
    constructor(
        address conduitController
    ) ReferenceOrderFulfiller(conduitController) {}

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
     *                                  explicit version of advancedOrders
     *                                  without memory optimization, that
     *                                  provides an array of spentItems and
     *                                  receivedItems for fulfillment and
     *                                  event emission.
     *
     * @param criteriaResolvers         An array where each element contains a
     *                                  reference to a specific offer or
     *                                  consideration, a token identifier, and a
     *                                  proof that the supplied token identifier
     *                                  is contained in the merkle root held by
     *                                  the item in question's criteria element.
     *                                  Note that an empty criteria indicates
     *                                  that any (transferable) token
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
     * @param recipient                 The intended recipient for all received
     *                                  items.
     * @param maximumFulfilled          The maximum number of orders to fulfill.
     *
     * @return availableOrders          An array of booleans indicating if each
     *                                  order with an index corresponding to the
     *                                  index of the returned boolean was
     *                                  fulfillable or not.
     * @return executions               An array of elements indicating the
     *                                  sequence of transfers performed as part
     *                                  of matching the given orders.
     */
    function _fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled
    )
        internal
        returns (bool[] memory availableOrders, Execution[] memory executions)
    {
        // Validate orders, apply amounts, & determine if they use conduits.
        (
            bytes32[] memory orderHashes,
            bool containsNonOpen
        ) = _validateOrdersAndPrepareToFulfill(
                advancedOrders,
                ordersToExecute,
                criteriaResolvers,
                OrderValidationParams(
                    false, // Signifies that invalid orders should NOT revert.
                    maximumFulfilled,
                    recipient
                )
            );

        // Execute transfers.
        (availableOrders, executions) = _executeAvailableFulfillments(
            advancedOrders,
            ordersToExecute,
            offerFulfillments,
            considerationFulfillments,
            fulfillerConduitKey,
            recipient,
            orderHashes,
            containsNonOpen
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
     *                          a root of zero indicates that any transferable
     *                          token identifier is valid and that no proof
     *                          needs to be supplied.
     * @param orderValidationParams Various order validation params.
     *
     * @return orderHashes      The hashes of the orders being fulfilled.
     * @return containsNonOpen  A boolean indicating whether any restricted or
     *                          contract orders are present within the provided
     *                          array of advanced orders.
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        OrderValidationParams memory orderValidationParams
    ) internal returns (bytes32[] memory orderHashes, bool containsNonOpen) {
        // Track the order hash for each order being fulfilled.
        orderHashes = new bytes32[](advancedOrders.length);

        // Declare a variable for tracking whether native offer items are
        // present on orders that are not contract orders.
        bool anyNativeOfferItemsOnNonContractOrders;

        StoredFractions[] memory storedFractions = new StoredFractions[](
            advancedOrders.length
        );

        // Iterate over each order.
        for (uint256 i = 0; i < advancedOrders.length; ++i) {
            // Retrieve the current order.
            AdvancedOrder memory advancedOrder = advancedOrders[i];

            // Validate the order and determine fraction to fill.
            OrderValidation memory orderValidation = _validateOrder(
                advancedOrder,
                orderValidationParams.revertOnInvalid
            );

            // Do not track hash or adjust prices if order is not fulfilled.
            if (orderValidation.newNumerator == 0) {
                // Mark fill fraction as zero if the order is not fulfilled.
                advancedOrder.numerator = 0;

                // Mark fill fraction as zero as the order will not be used.
                orderValidation.orderToExecute.numerator = 0;
                ordersToExecute[i] = orderValidation.orderToExecute;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Otherwise, track the order hash in question.
            orderHashes[i] = orderValidation.orderHash;

            // Store the numerator and denominator for the order status.
            storedFractions[i] = StoredFractions({
                storedNumerator: orderValidation.newNumerator,
                storedDenominator: orderValidation.newDenominator
            });

            {
                // Retrieve array of offer items for the order in question.
                OfferItem[] memory offer = advancedOrder.parameters.offer;

                // Determine the order type, used to check for eligibility for
                // native token offer items as well as for the presence of
                // restricted and contract orders (or non-open orders).
                OrderType orderType = advancedOrder.parameters.orderType;

                {
                    bool isNonContractOrder = orderType != OrderType.CONTRACT;
                    bool isNonOpenOrder = orderType != OrderType.FULL_OPEN &&
                        orderType != OrderType.PARTIAL_OPEN;

                    if (containsNonOpen == true || isNonOpenOrder == true) {
                        containsNonOpen = true;
                    }

                    // Iterate over each offer item on the order.
                    for (uint256 j = 0; j < offer.length; ++j) {
                        // Retrieve the offer item.
                        OfferItem memory offerItem = offer[j];

                        // Determine if there are any native offer items on
                        // non-contract orders.
                        anyNativeOfferItemsOnNonContractOrders =
                            anyNativeOfferItemsOnNonContractOrders ||
                            (offerItem.itemType == ItemType.NATIVE &&
                                isNonContractOrder);

                        // Apply order fill fraction to offer item end amount.
                        uint256 endAmount = _getFraction(
                            orderValidation.newNumerator,
                            orderValidation.newDenominator,
                            offerItem.endAmount
                        );

                        // Reuse same fraction if start & end amounts are equal.
                        if (offerItem.startAmount == offerItem.endAmount) {
                            // Apply derived amount to both start & end amount.
                            offerItem.startAmount = endAmount;
                        } else {
                            // Apply order fill fraction to item start amount.
                            offerItem.startAmount = _getFraction(
                                orderValidation.newNumerator,
                                orderValidation.newDenominator,
                                offerItem.startAmount
                            );
                        }

                        // Update end amount in memory to match derived amount.
                        offerItem.endAmount = endAmount;

                        // Adjust offer amount using current time; round down.
                        offerItem.startAmount = _locateCurrentAmount(
                            offerItem.startAmount,
                            offerItem.endAmount,
                            advancedOrder.parameters.startTime,
                            advancedOrder.parameters.endTime,
                            false // Round down.
                        );

                        // Modify the OrderToExecute Spent Item Amount.
                        orderValidation
                            .orderToExecute
                            .spentItems[j]
                            .amount = offerItem.startAmount;
                        // Modify the OrderToExecute Spent Item Original amount.
                        orderValidation.orderToExecute.spentItemOriginalAmounts[
                            j
                        ] = (offerItem.startAmount);
                    }
                }

                {
                    // Get array of consideration items for order in question.
                    ConsiderationItem[] memory consideration = (
                        advancedOrder.parameters.consideration
                    );

                    // Iterate over each consideration item on the order.
                    for (uint256 j = 0; j < consideration.length; ++j) {
                        // Retrieve the consideration item.
                        ConsiderationItem memory considerationItem = (
                            consideration[j]
                        );

                        // Apply fraction to consideration item end amount.
                        uint256 endAmount = _getFraction(
                            orderValidation.newNumerator,
                            orderValidation.newDenominator,
                            considerationItem.endAmount
                        );

                        // Reuse same fraction if start & end amounts are equal.
                        if (
                            considerationItem.startAmount ==
                            (considerationItem.endAmount)
                        ) {
                            // Apply derived amount to both start & end amount.
                            considerationItem.startAmount = endAmount;
                        } else {
                            // Apply fraction to item start amount.
                            considerationItem.startAmount = _getFraction(
                                orderValidation.newNumerator,
                                orderValidation.newDenominator,
                                considerationItem.startAmount
                            );
                        }

                        uint256 currentAmount = (
                            _locateCurrentAmount(
                                considerationItem.startAmount,
                                endAmount,
                                advancedOrder.parameters.startTime,
                                advancedOrder.parameters.endTime,
                                true // round up
                            )
                        );

                        considerationItem.startAmount = currentAmount;

                        // Modify the OrderToExecute Received item amount.
                        orderValidation
                            .orderToExecute
                            .receivedItems[j]
                            .amount = considerationItem.startAmount;
                        // Modify OrderToExecute Received item original amount.
                        orderValidation
                            .orderToExecute
                            .receivedItemOriginalAmounts[j] = (
                            considerationItem.startAmount
                        );
                    }
                }
            }

            ordersToExecute[i] = orderValidation.orderToExecute;
        }

        if (
            anyNativeOfferItemsOnNonContractOrders &&
            (msg.sig != SeaportInterface.matchAdvancedOrders.selector &&
                msg.sig != SeaportInterface.matchOrders.selector)
        ) {
            revert InvalidNativeOfferItem();
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(
            advancedOrders,
            ordersToExecute,
            criteriaResolvers
        );

        bool someOrderAvailable;

        // Iterate over each order to check authorization status (for restricted
        // orders), generate orders (for contract orders), and emit events (for
        // all available orders) signifying that they have been fulfilled.
        for (uint256 i = 0; i < advancedOrders.length; ++i) {
            // Do not emit an event if no order hash is present.
            if (orderHashes[i] == bytes32(0)) {
                continue;
            }

            // Determine if max number orders have already been fulfilled.
            if (orderValidationParams.maximumFulfilled == 0) {
                orderHashes[i] = bytes32(0);
                ordersToExecute[i].numerator = 0;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Retrieve parameters for the order in question.
            OrderParameters memory orderParameters = (
                advancedOrders[i].parameters
            );

            // Ensure restricted orders have valid submitter or pass zone check.
            (
                bool valid /* bool checked */,

            ) = _checkRestrictedAdvancedOrderAuthorization(
                    advancedOrders[i],
                    ordersToExecute[i],
                    _shorten(orderHashes, i),
                    orderHashes[i],
                    orderValidationParams.revertOnInvalid
                );

            if (!valid) {
                orderHashes[i] = bytes32(0);
                ordersToExecute[i].numerator = 0;
                continue;
            }

            // Update status if the order is still valid or skip if not checked
            if (orderParameters.orderType != OrderType.CONTRACT) {
                if (
                    !_updateStatus(
                        orderHashes[i],
                        storedFractions[i].storedNumerator,
                        storedFractions[i].storedDenominator,
                        _revertOnFailedUpdate(
                            orderParameters,
                            orderValidationParams.revertOnInvalid
                        )
                    )
                ) {
                    orderHashes[i] = bytes32(0);
                    ordersToExecute[i].numerator = 0;
                    continue;
                }
            } else {
                bytes32 orderHash = _getGeneratedOrder(
                    ordersToExecute[i],
                    orderParameters,
                    advancedOrders[i].extraData,
                    orderValidationParams.revertOnInvalid
                );

                orderHashes[i] = orderHash;

                if (orderHash == bytes32(0)) {
                    ordersToExecute[i].numerator = 0;
                    continue;
                }
            }

            // Decrement the number of fulfilled orders.
            orderValidationParams.maximumFulfilled--;

            // Get the array of spentItems from the orderToExecute struct.
            SpentItem[] memory spentItems = ordersToExecute[i].spentItems;

            // Get the array of spent receivedItems from the
            // orderToExecute struct.
            ReceivedItem[] memory receivedItems = (
                ordersToExecute[i].receivedItems
            );

            // Emit an event signifying that the order has been fulfilled.
            emit OrderFulfilled(
                orderHashes[i],
                orderParameters.offerer,
                orderParameters.zone,
                orderValidationParams.recipient,
                spentItems,
                receivedItems
            );

            someOrderAvailable = true;
        }

        // Revert if no orders are available.
        if (!someOrderAvailable) {
            revert NoSpecifiedOrdersAvailable();
        }
    }

    function _shorten(
        bytes32[] memory orderHashes,
        uint256 index
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory shortened = new bytes32[](index);
        for (uint256 i = 0; i < index; i++) {
            shortened[i] = orderHashes[i];
        }
        return shortened;
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
     *                                  explicit version of advancedOrders
     *                                  without memory optimization, that
     *                                  provides an array of spentItems and
     *                                  receivedItems for fulfillment and
     *                                  event emission.
     *                                  Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or the conduit if indicated
     *                                  by the order) to transfer any relevant
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
     * @param recipient                 The intended recipient for all received
     *                                  items.
     * @param orderHashes               An array of order hashes for each order.
     * @param containsNonOpen   A boolean indicating whether any restricted or
     *                          contract orders are present within the provided
     *                          array of advanced orders.
     *
     * @return availableOrders          An array of booleans indicating if each
     *                                  order with an index corresponding to the
     *                                  index of the returned boolean was
     *                                  fulfillable or not.
     * @return executions               An array of elements indicating the
     *                                  sequence of transfers performed as part
     *                                  of matching the given orders.
     */
    function _executeAvailableFulfillments(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        bytes32 fulfillerConduitKey,
        address recipient,
        bytes32[] memory orderHashes,
        bool containsNonOpen
    )
        internal
        returns (bool[] memory availableOrders, Execution[] memory executions)
    {
        // Retrieve length of offer fulfillments array and place on the stack.
        uint256 totalOfferFulfillments = offerFulfillments.length;

        // Retrieve length of consideration fulfillments array & place on stack.
        uint256 totalConsiderationFulfillments = (
            considerationFulfillments.length
        );

        // Allocate an execution for each offer and consideration fulfillment.
        executions = new Execution[](
            totalOfferFulfillments + totalConsiderationFulfillments
        );

        // Iterate over each offer fulfillment.
        for (uint256 i = 0; i < totalOfferFulfillments; ++i) {
            // Derive aggregated execution corresponding with fulfillment and
            // assign the execution to the executions array.
            executions[i] = _aggregateAvailable(
                ordersToExecute,
                Side.OFFER,
                offerFulfillments[i],
                fulfillerConduitKey,
                recipient
            );
        }

        // Iterate over each consideration fulfillment.
        for (uint256 i = 0; i < totalConsiderationFulfillments; ++i) {
            // Derive aggregated execution corresponding with fulfillment and
            // assign the execution to the executions array.
            executions[i + totalOfferFulfillments] = _aggregateAvailable(
                ordersToExecute,
                Side.CONSIDERATION,
                considerationFulfillments[i],
                fulfillerConduitKey,
                address(0) // unused
            );
        }

        // Perform final checks and compress executions into standard and batch.
        availableOrders = _performFinalChecksAndExecuteOrders(
            advancedOrders,
            ordersToExecute,
            executions,
            orderHashes,
            recipient,
            containsNonOpen
        );

        return (availableOrders, executions);
    }

    /**
     * @dev Internal function to perform a final check that each consideration
     *      item for an arbitrary number of fulfilled orders has been met and to
     *      trigger associated executions, transferring the respective items.
     *
     * @param ordersToExecute    The orders to check and perform executions.
     * @param executions         An array of uncompressed elements indicating
     *                           the sequence of transfers to perform when
     *                           fulfilling the given orders.
     *
     * @param executions         An array of elements indicating the sequence of
     *                           transfers to perform when fulfilling the given
     *                           orders.
     * @param orderHashes        An array of order hashes for each order.
     * @param containsNonOpen    A boolean indicating whether any restricted or
     *                           contract orders are present within the provided
     *                           array of advanced orders.
     *
     * @return availableOrders   An array of booleans indicating if each order
     *                           with an index corresponding to the index of the
     *                           returned boolean was fulfillable or not.
     */
    function _performFinalChecksAndExecuteOrders(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        Execution[] memory executions,
        bytes32[] memory orderHashes,
        address recipient,
        bool containsNonOpen
    ) internal returns (bool[] memory availableOrders) {
        // Retrieve the length of the advanced orders array and place on stack.
        uint256 totalOrders = advancedOrders.length;

        // Initialize array for tracking available orders.
        availableOrders = new bool[](totalOrders);

        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        {
            // Iterate over each execution.
            for (uint256 i = 0; i < executions.length; ++i) {
                // Retrieve the execution and the associated received item.
                Execution memory execution = executions[i];
                ReceivedItem memory item = execution.item;

                // Skip transfers if the execution amount is zero.
                if (item.amount == 0) {
                    continue;
                }

                // If execution transfers native tokens, reduce value available.
                if (item.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (item.amount > address(this).balance) {
                        revert InsufficientNativeTokensSupplied();
                    }
                }

                // Transfer the item specified by the execution.
                _transfer(
                    item,
                    execution.offerer,
                    execution.conduitKey,
                    accumulatorStruct
                );
            }
        }

        // Duplicate recipient onto stack to avoid stack-too-deep.
        address _recipient = recipient;

        // Iterate over orders to ensure all consideration items are met.
        for (uint256 i = 0; i < ordersToExecute.length; ++i) {
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

            // Retrieve the original order in question.
            AdvancedOrder memory advancedOrder = advancedOrders[i];

            // Retrieve the order parameters.
            OrderParameters memory parameters = advancedOrder.parameters;

            {
                // Retrieve offer items.
                SpentItem[] memory offer = orderToExecute.spentItems;

                // Read length of offer array & place on the stack.
                uint256 totalOfferItems = offer.length;

                // Iterate over each offer item to restore it.
                for (uint256 j = 0; j < totalOfferItems; ++j) {
                    SpentItem memory offerSpentItem = offer[j];

                    // Retrieve remaining amount on the offer item.
                    uint256 unspentAmount = offerSpentItem.amount;

                    // Retrieve original amount on the offer item.
                    uint256 originalAmount = (
                        orderToExecute.spentItemOriginalAmounts[j]
                    );

                    // Transfer to recipient if unspent amount is not zero.
                    // Note that the transfer will not be reflected in the
                    // executions array.
                    if (unspentAmount != 0) {
                        _transfer(
                            _convertSpentItemToReceivedItemWithRecipient(
                                offerSpentItem,
                                _recipient
                            ),
                            parameters.offerer,
                            parameters.conduitKey,
                            accumulatorStruct
                        );
                    }

                    // Restore original amount on the offer item.
                    offerSpentItem.amount = originalAmount;
                }
            }

            {
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

                    // Restore original amount.
                    consideration[j].amount = (
                        orderToExecute.receivedItemOriginalAmounts[j]
                    );
                }
            }
        }

        // Trigger any remaining accumulated transfers via call to the
        // conduit.
        _triggerIfArmed(accumulatorStruct);

        // If any native token remains after fulfillments, return it to the
        // caller.
        if (address(this).balance != 0) {
            _transferNativeTokens(payable(msg.sender), address(this).balance);
        }

        // If any restricted or contract orders are present in the group of
        // orders being fulfilled, perform any validateOrder or ratifyOrder
        // calls after all executions and related transfers are complete.
        if (containsNonOpen) {
            // Iterate over orders to ensure all consideration items are met.
            for (uint256 i = 0; i < ordersToExecute.length; ++i) {
                // Retrieve the order in question.
                OrderToExecute memory orderToExecute = ordersToExecute[i];

                // Skip consideration item checks for order if not fulfilled.
                if (orderToExecute.numerator == 0) {
                    continue;
                }

                // Retrieve the original order in question.
                AdvancedOrder memory advancedOrder = advancedOrders[i];

                // Ensure restricted orders have valid submitter or pass check.
                _assertRestrictedAdvancedOrderValidity(
                    advancedOrder,
                    orderToExecute,
                    orderHashes,
                    orderHashes[i],
                    advancedOrder.parameters.zoneHash,
                    advancedOrder.parameters.orderType,
                    orderToExecute.offerer,
                    advancedOrder.parameters.zone
                );
            }
        }

        // Return the array containing available orders.
        return availableOrders;
    }

    /**
     * @dev Internal function to convert a spent item to an equivalent
     *      ReceivedItem with a specified recipient.
     *
     * @param offerItem          The "offerItem" represented by a SpentItem
     *                           struct.
     * @param recipient          The intended recipient of the converted
     *                           ReceivedItem
     *
     * @return ReceivedItem      The derived ReceivedItem including the
     *                           specified recipient.
     */
    function _convertSpentItemToReceivedItemWithRecipient(
        SpentItem memory offerItem,
        address recipient
    ) internal pure returns (ReceivedItem memory) {
        address payable _recipient;

        _recipient = payable(recipient);

        return
            ReceivedItem(
                offerItem.itemType,
                offerItem.token,
                offerItem.identifier,
                offerItem.amount,
                _recipient
            );
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
     *                          order to receive ERC1155 tokens. Also note that
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
     *                          an empty root indicates that any (transferable)
     *                          token identifier is valid and that no associated
     *                          proof needs to be supplied.
     * @param fulfillments      An array of elements allocating offer components
     *                          to consideration components. Note that each
     *                          consideration component must be fully met in
     *                          order for the match operation to be valid.
     * @param recipient         The intended recipient for all unspent offer
     *                          item amounts.
     *
     * @return executions       An array of elements indicating the sequence of
     *                          transfers performed as part of matching the
     *                          given orders.
     */
    function _matchAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] calldata fulfillments,
        address recipient
    ) internal returns (Execution[] memory executions) {
        // Convert Advanced Orders to Orders to Execute
        OrderToExecute[] memory ordersToExecute = (
            _convertAdvancedToOrdersToExecute(advancedOrders)
        );

        // Validate orders, apply amounts, & determine if they utilize conduits.
        (
            bytes32[] memory orderHashes,
            bool containsNonOpen
        ) = _validateOrdersAndPrepareToFulfill(
                advancedOrders,
                ordersToExecute,
                criteriaResolvers,
                OrderValidationParams(
                    true, // Signifies that invalid orders should revert.
                    advancedOrders.length,
                    recipient
                )
            );

        // Emit OrdersMatched event.
        emit OrdersMatched(orderHashes);

        // Fulfill the orders using the supplied fulfillments.
        return
            _fulfillAdvancedOrders(
                advancedOrders,
                ordersToExecute,
                fulfillments,
                orderHashes,
                recipient,
                containsNonOpen
            );
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
     * @param orderHashes        An array of order hashes for each order.
     *
     * @param containsNonOpen   A boolean indicating whether any restricted or
     *                          contract orders are present within the provided
     *                          array of advanced orders.
     *
     * @return executions        An array of elements indicating the sequence
     *                           of transfers performed as part of
     *                           matching the given orders.
     */
    function _fulfillAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        Fulfillment[] calldata fulfillments,
        bytes32[] memory orderHashes,
        address recipient,
        bool containsNonOpen
    ) internal returns (Execution[] memory executions) {
        // Retrieve fulfillments array length and place on the stack.
        uint256 totalFulfillments = fulfillments.length;

        // Allocate executions by fulfillment and apply them to each execution.
        executions = new Execution[](totalFulfillments);

        // Iterate over each fulfillment.
        for (uint256 i = 0; i < totalFulfillments; ++i) {
            /// Retrieve the fulfillment in question.
            Fulfillment calldata fulfillment = fulfillments[i];

            // Derive the execution corresponding with the fulfillment and
            // assign the execution to the executions array.
            executions[i] = _applyFulfillment(
                ordersToExecute,
                fulfillment.offerComponents,
                fulfillment.considerationComponents,
                i
            );
        }

        // Perform final checks and execute orders.
        _performFinalChecksAndExecuteOrders(
            advancedOrders,
            ordersToExecute,
            executions,
            orderHashes,
            recipient,
            containsNonOpen
        );

        // Return executions.
        return executions;
    }

    /**
     * @dev Internal view function to determine whether a status update failure
     *      should cause a revert or allow a skipped order. The call must revert
     *      if an `authorizeOrder` call has been successfully performed and the
     *      status update cannot be performed, regardless of whether the order
     *      could be otherwise marked as skipped. Note that a revert is not
     *      required on a failed update if the call originates from the zone, as
     *      no `authorizeOrder` call is performed in that case.
     *
     * @param orderParameters The order parameters in question.
     * @param revertOnInvalid A boolean indicating whether the call should
     *                        revert for non-restricted order types.
     *
     * @return revertOnFailedUpdate A boolean indicating whether the order
     *                              should revert on a failed status update.
     */
    function _revertOnFailedUpdate(
        OrderParameters memory orderParameters,
        bool revertOnInvalid
    ) internal view returns (bool revertOnFailedUpdate) {
        OrderType orderType = orderParameters.orderType;
        address zone = orderParameters.zone;
        return (revertOnInvalid ||
            ((orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) &&
                zone != msg.sender));
    }
}
