// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import { ProxyInterface } from "../interfaces/AbridgedProxyInterfaces.sol";

import {
    OrderType,
    ItemType
} from "./ConsiderationEnums.sol";

import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferedItem,
    ReceivedItem,
    ConsumedItem,
    FulfilledItem,
    OrderParameters,
    Fulfillment,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "./ConsiderationStructs.sol";

import { ConsiderationInternalView } from "./ConsiderationInternalView.sol";

/**
 * @title ConsiderationInternal
 * @author 0age
 * @notice ConsiderationInternal contains all internal functions.
 */
contract ConsiderationInternal is ConsiderationInternalView {
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
    ) ConsiderationInternalView(
        legacyProxyRegistry,
        requiredProxyImplementation
    ) {}

    /**
     * @dev Internal function to derive and validate an order based on a set of
     *      parameters and a primary item for offer and consideration.
     *
     * @param  parameters      The parameters of the basic order.
     * @param  offeredItem     The primary item being offered.
     * @param  receivedItem    The primary item being received as consideration.
     *
     * @return useOffererProxy A boolean indicating whether to utilize the
     *                         offerer's proxy.
     */
    function _prepareBasicFulfillment(
        BasicOrderParameters memory parameters,
        OfferedItem memory offeredItem,
        ReceivedItem memory receivedItem
    ) internal returns (bool useOffererProxy) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Pull frequently used arguments from memory & place them on the stack.
        address payable offerer = parameters.offerer;
        address zone = parameters.zone;
        uint256 startTime = parameters.startTime;
        uint256 endTime = parameters.endTime;

        // Ensure current timestamp falls between order start time and end time.
        _assertValidTime(startTime, endTime);

        // Allocate memory: 1 offer, 1+additionalRecipients consideration items.
        OfferedItem[] memory offer = new OfferedItem[](1);
        ReceivedItem[] memory consideration = new ReceivedItem[](
            1 + parameters.additionalRecipients.length
        );

        // Set primary offer + consideration item as respective first elements.
        offer[0] = offeredItem;
        consideration[0] = receivedItem;

        // Get offered item type and received item token and place on the stack.
        ItemType itemType = offeredItem.itemType;
        address token = receivedItem.token;

        // Use offered item's info for additional recipients of native or ERC20.
        if (_isEtherOrERC20Item(itemType)) {
            // Set token for additional recipients to offered item's token.
            token = offeredItem.token;
        } else {
            // Otherwise, set additional recipient type to received item's type.
            itemType = receivedItem.itemType;
        }

        // Skip overflow checks as for loop is indexed starting at one.
        unchecked {
            // Iterate over each consideration beyond primary one on the order.
            for (uint256 i = 1; i < consideration.length; ++i) {
                // Retrieve additional recipient corresponding to consideration.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[i - 1]
                );

                // Set new received item as an additional consideration item.
                consideration[i] = ReceivedItem(
                    itemType,
                    token,
                    0, // No identifier for native tokens or ERC20.
                    additionalRecipient.amount,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );
            }
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        bytes32 orderHash = _getNoncedOrderHash(
            OrderParameters(
                offerer,
                zone,
                parameters.orderType,
                startTime,
                endTime,
                parameters.salt,
                offer,
                consideration
            )
        );

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            orderHash,
            offerer,
            parameters.signature
        );

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
            parameters.orderType,
            offerer,
            zone
        );

        // Emit an event signifying that the order has been fulfilled.
        _emitOrderFulfilledEvent(
            orderHash,
            offerer,
            zone,
            msg.sender,
            offer,
            consideration
        );

        // Return a boolean indicating whether to utilize offerer's proxy.
        return useOffererProxy;
    }

    /**
     * @dev Internal function to verify and update the status of a basic order.
     *
     * @param orderHash The hash of the order.
     * @param offerer   The offerer of the order.
     * @param signature A signature from the offerer indicating that the order
     *                  has been approved.
     */
    function _validateBasicOrderAndUpdateStatus(
        bytes32 orderHash,
        address offerer,
        bytes memory signature
    ) internal {
        // Retrieve the order status for the given order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        _verifyOrderStatus(
            orderHash,
            orderStatus,
            true // Only allow unused orders as part of fulfilling basic orders.
        );

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                offerer, orderHash, signature
            );
        }

        // Update order status as fully filled, packing struct values.
        _orderStatus[orderHash].isValidated = true;
        _orderStatus[orderHash].isCancelled = false;
        _orderStatus[orderHash].numerator = 1;
        _orderStatus[orderHash].denominator = 1;
    }

    /**
     * @dev Internal function to validate an order, determine what portion to
     *      fill, and update its status. The desired fill amount is supplied as
     *      a fraction, as is the returned amount to fill.
     *
     * @param advancedOrder The order to fulfill as well as the fraction to
     *                      fill. Note that all offer and consideration amounts
     *                      must divide with no remainder in order for a partial
     *                      fill to be valid.
     *
     * @return orderHash       The order hash.
     * @return newNumerator    A value indicating the portion of the order that
     *                         will be filled.
     * @return newDenominator  A value indicating the total size of the order.
     * @return useOffererProxy A boolean indicating whether to utilize the
     *                         offerer's proxy.
     */
    function _validateOrderAndUpdateStatus(
        AdvancedOrder memory advancedOrder
    ) internal returns (
        bytes32 orderHash,
        uint256 newNumerator,
        uint256 newDenominator,
        bool useOffererProxy
    ) {
        // Retrieve the parameters for the order.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Ensure current timestamp falls between order start time and end time.
        _assertValidTime(
            orderParameters.startTime,
            orderParameters.endTime
        );

        // Read numerator and denominator from memory and place on the stack.
        uint256 numerator = uint256(advancedOrder.numerator);
        uint256 denominator = uint256(advancedOrder.denominator);

        // Ensure that the supplied numerator and denominator are valid.
        if (numerator > denominator || numerator == 0 || denominator == 0) {
            revert BadFraction();
        }

        // If attempting partial fill (n < d) check order type & ensure support.
        if (
            numerator < denominator &&
            _doesNotSupportPartialFills(orderParameters.orderType)
        ) {
            revert PartialFillsNotEnabledForOrder();
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _getNoncedOrderHash(orderParameters);

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
            orderParameters.orderType,
            orderParameters.offerer,
            orderParameters.zone
        );

        // Retrieve the order status using the derived order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        _verifyOrderStatus(
            orderHash,
            orderStatus,
            false // Allow partially used orders to be filled.
        );

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                orderParameters.offerer, orderHash, advancedOrder.signature
            );
        }

        // Read filled amount as numerator and denominator and put on the stack.
        uint256 filledNumerator = orderStatus.numerator;
        uint256 filledDenominator = orderStatus.denominator;

        // If order currently has a non-zero denominator it is partially filled.
        if (filledDenominator != 0) {
            // If denominator of 1 supplied, fill all remaining amount on order.
            if (denominator == 1) {
                // Scale numerator & denominator to match current denominator.
                numerator = filledDenominator;
                denominator = filledDenominator;
            } // Otherwise, if supplied denominator differs from current one...
            else if (filledDenominator != denominator) {
                // scale current numerator by the supplied denominator, then...
                filledNumerator *= denominator;

                // the supplied numerator & denominator by current denominator.
                numerator *= filledDenominator;
                denominator *= filledDenominator;
            }

            // Once adjusted, if current+supplied numerator exceeds denominator:
            if (filledNumerator + numerator > denominator) {
                // Skip underflow check: denominator >= orderStatus.numerator
                unchecked {
                    // Reduce current numerator so it + supplied = denominator.
                    numerator = denominator - filledNumerator;
                }
            }

            // Skip overflow check: checked above unless numerator is reduced.
            unchecked {
                // Update order status and fill amount, packing struct values.
                _orderStatus[orderHash].isValidated = true;
                _orderStatus[orderHash].isCancelled = false;
                _orderStatus[orderHash].numerator = uint120(
                    filledNumerator + numerator
                );
                _orderStatus[orderHash].denominator = uint120(denominator);
            }
        } else {
            // Update order status and fill amount, packing struct values.
            _orderStatus[orderHash].isValidated = true;
            _orderStatus[orderHash].isCancelled = false;
            _orderStatus[orderHash].numerator = uint120(numerator);
            _orderStatus[orderHash].denominator = uint120(denominator);
        }

        // Return order hash, new numerator and denominator, and proxy boolean.
        return (orderHash, numerator, denominator, useOffererProxy);
    }

    /**
     * @dev Internal function to validate an order and update its status, adjust
     *      prices based on current time, apply criteria resolvers, determine
     *      what portion to fill, and transfer relevant tokens.
     *
     * @param advancedOrder     The order to fulfill as well as the fraction to
     *                          fill. Note that all offer and consideration
     *                          components must divide with no remainder in
     *                          order for the partial fill to be valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the order's merkle
     *                          root. Note that a criteria of zero indicates
     *                          that any (transferrable) token identifier is
     *                          valid and that no proof needs to be supplied.
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) internal returns (bool) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint256 fillNumerator,
            uint256 fillDenominator,
            bool useOffererProxy
        ) = _validateOrderAndUpdateStatus(advancedOrder);

        // Apply criteria resolvers (requires array of orders to be supplied).
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = advancedOrder;
        _applyCriteriaResolvers(orders, criteriaResolvers);

        // Retrieve the parameters of the order.
        OrderParameters memory orderParameters = orders[0].parameters;

        // Perform each item transfer with the appropriate fractional amount.
        _applyFractionsAndTransferEach(
            orderParameters,
            fillNumerator,
            fillDenominator,
            useOffererProxy,
            useFulfillerProxy
        );

        // Emit an event signifying that the order has been fulfilled.
        _emitOrderFulfilledEvent(
            orderHash,
            orderParameters.offerer,
            orderParameters.zone,
            msg.sender,
            orderParameters.offer,
            orderParameters.consideration
        );

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;

        return true;
    }

    /**
     * @dev Internal function to transfer each item contained in a given single
     *      order fulfillment after applying a respective fraction to the amount
     *      being transferred.
     *
     * @param orderParameters   The parameters for the fulfilled order.
     * @param numerator         A value indicating the portion of the order that
     *                          should be filled.
     * @param denominator       A value indicating the total size of the order.
     * @param useOffererProxy   A flag indicating whether to source approvals
     *                          for consumed tokens from an associated proxy.
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        bool useOffererProxy,
        bool useFulfillerProxy
    ) internal {
        // Derive order duration, time elapsed, and time remaining.
        uint256 duration = orderParameters.endTime - orderParameters.startTime;
        uint256 elapsed = block.timestamp - orderParameters.startTime;
        uint256 remaining = duration - elapsed;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < orderParameters.offer.length;) {
            // Retrieve the offer item.
            OfferedItem memory offeredItem = orderParameters.offer[i];

            // Derive the amount to transfer and transfer the offered item.
            uint256 amount = _applyOfferedFractionAndTransfer(
                offeredItem,
                numerator,
                denominator,
                orderParameters.offerer,
                useOffererProxy,
                elapsed,
                remaining,
                duration
            );

            // If offer expects ETH or a native token, reduce value available.
            if (offeredItem.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= amount;
                }
            }

            // Update offered amount so that an accurate event can be emitted.
            offeredItem.endAmount = amount;

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // Iterate over each consideration on the order.
        for (uint256 i = 0; i < orderParameters.consideration.length;) {
            // Retrieve the consideration item.
            ReceivedItem memory receivedItem = orderParameters.consideration[i];

            // Derive the amount to transfer and transfer the received item.
            uint256 amount = _applyReceivedFractionAndTransfer(
                receivedItem,
                numerator,
                denominator,
                useFulfillerProxy,
                elapsed,
                remaining,
                duration
            );

            // If item expects ETH or a native token, reduce value available.
            if (receivedItem.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= amount;
                }
            }

            // Update offered amount so that an accurate event can be emitted.
            receivedItem.endAmount = amount;

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }
    }

    /**
     * @dev Internal function to validate a group of orders, update their
     *      statuses, reduce amounts by their previously filled fractions, apply
     *      criteria resolvers, and emit OrderFulfilled events.
     *
     * @param orders            The orders to validate and reduce by their
     *                          previously filled amounts.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          a root of zero indicates that any transferrable
     *                          token identifier is valid and that no proof
     *                          needs to be supplied.
     *
     * @return A array of booleans indicating whether to utilize a proxy for
     *         each order.
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory orders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal returns (bool[] memory) {
        uint256 ordersLength = orders.length;

        // Declare memory region to determine proxy utilization per order.
        bool[] memory ordersUseProxy = new bool[](ordersLength);

        bytes32[] memory orderHashes = new bytes32[](ordersLength);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < ordersLength; ++i) {
                // Retrieve the current order.
                AdvancedOrder memory order = orders[i];

                // Validate it, update status, and determine fraction to fill.
                (
                    bytes32 orderHash,
                    uint256 numerator,
                    uint256 denominator,
                    bool useOffererProxy
                ) = _validateOrderAndUpdateStatus(order);

                // Mark whether order should utilize offerer's proxy.
                ordersUseProxy[i] = useOffererProxy;

                // Retrieve offer items and consideration items on the order.
                OfferedItem[] memory offer = order.parameters.offer;
                ReceivedItem[] memory consideration = (
                    order.parameters.consideration
                );

                // Iterate over each offered item on the order.
                for (uint256 j = 0; j < offer.length; ++j) {
                    // Retrieve the offered item.
                    OfferedItem memory offeredItem = offer[j];

                    // Reuse same fraction if start and end amounts are equal.
                    if (offeredItem.startAmount == offeredItem.endAmount) {
                        // Derive the fractional amount based on the end amount.
                        uint256 amount = _getFraction(
                            numerator,
                            denominator,
                            offeredItem.endAmount
                        );

                        // Apply derived amount to both start and end amount.
                        offeredItem.startAmount = amount;
                        offeredItem.endAmount = amount;
                    } else {
                        // Apply order fill fraction to each offer amount.
                        offeredItem.startAmount = _getFraction(
                            numerator,
                            denominator,
                            offeredItem.startAmount
                        );

                        offeredItem.endAmount = _getFraction(
                            numerator,
                            denominator,
                            offeredItem.endAmount
                        );
                    }
                }

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < consideration.length; ++j) {
                    // Retrieve the consideration item.
                    ReceivedItem memory receivedItem = consideration[j];

                    // Reuse same fraction if start and end amounts are equal.
                    if (receivedItem.startAmount == receivedItem.endAmount) {
                        // Derive the fractional amount based on the end amount.
                        uint256 amount = _getFraction(
                            numerator,
                            denominator,
                            receivedItem.endAmount
                        );

                        // Apply derived amount to both start and end amount.
                        receivedItem.startAmount = amount;
                        receivedItem.endAmount = amount;
                    } else {
                        // Apply order fill fraction to each received amount.
                        receivedItem.startAmount = _getFraction(
                            numerator,
                            denominator,
                            receivedItem.startAmount
                        );

                        receivedItem.endAmount = _getFraction(
                            numerator,
                            denominator,
                            receivedItem.endAmount
                        );
                    }
                }

                // Adjust prices based on time, start amount, and end amount.
                _adjustAdvancedOrderPrice(order);

                // Track the order hash in question.
                orderHashes[i] = orderHash;
            }
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(orders, criteriaResolvers);

        // Emit an event for each order signifying that it has been fulfilled.
        unchecked {
            for (uint256 i = 0; i < ordersLength; ++i) {
                OrderParameters memory order = orders[i].parameters;
                _emitOrderFulfilledEvent(
                    orderHashes[i],
                    order.offerer,
                    order.zone,
                    address(0),
                    order.offer,
                    order.consideration
                );
            }
        }

        // Return memory region designating proxy utilization per order.
        return ordersUseProxy;
    }

    /**
     * @dev Internal function to apply a fraction to an offered item and
     *      transfer that amount.
     *
     * @param offeredItem       The offer item.
     * @param numerator         A value indicating the portion of the order that
     *                          should be filled.
     * @param denominator       A value indicating the total size of the order.
     * @param offerer           The offerer for the order.
     * @param useOffererProxy   A flag indicating whether to source approvals
     *                          for consumed tokens from an associated proxy.
     * @param elapsed           The time elapsed since the order's start time.
     * @param remaining         The time left until the order's end time.
     * @param duration          The total duration of the order.
     *
     * @return amount The final amount to transfer.
     */
    function _applyOfferedFractionAndTransfer(
        OfferedItem memory offeredItem,
        uint256 numerator,
        uint256 denominator,
        address offerer,
        bool useOffererProxy,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration
    ) internal returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (offeredItem.startAmount == offeredItem.endAmount) {
            amount = _getFraction(
                numerator,
                denominator,
                offeredItem.endAmount
            );
        } else {
            // Otherwise, apply fraction to both to extrapolate final amount.
            amount = _locateCurrentAmount(
                _getFraction(
                    numerator,
                    denominator,
                    offeredItem.startAmount
                ),
                _getFraction(
                    numerator,
                    denominator,
                    offeredItem.endAmount
                ),
                elapsed,
                remaining,
                duration,
                false // round down
            );
        }

        // Apply order fill fraction and set the caller as the receiver.
        FulfilledItem memory item = FulfilledItem(
            offeredItem.itemType,
            offeredItem.token,
            offeredItem.identifierOrCriteria,
            amount,
            payable(msg.sender)
        );

        // Transfer the item from the offerer to the caller.
        _transfer(
            item,
            offerer,
            useOffererProxy
        );
    }

    /**
     * @dev Internal function to apply a fraction to a received item and
     *      transfer that amount.
     *
     * @param receivedItem      The received item.
     * @param numerator         A value indicating the portion of the order that
     *                          should be filled.
     * @param denominator       A value indicating the total size of the order.
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     * @param elapsed           The time elapsed since the order's start time.
     * @param remaining         The time left until the order's end time.
     * @param duration          The total duration of the order.
     *
     * @return amount The final amount to transfer.
     */
    function _applyReceivedFractionAndTransfer(
        ReceivedItem memory receivedItem,
        uint256 numerator,
        uint256 denominator,
        bool useFulfillerProxy,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration
    ) internal returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (receivedItem.startAmount == receivedItem.endAmount) {
            amount = _getFraction(
                numerator,
                denominator,
                receivedItem.endAmount
            );
        } else {
            // Otherwise, apply fraction to both to extrapolate final amount.
            amount = _locateCurrentAmount(
                _getFraction(
                    numerator,
                    denominator,
                    receivedItem.startAmount
                ),
                _getFraction(
                    numerator,
                    denominator,
                    receivedItem.endAmount
                ),
                elapsed,
                remaining,
                duration,
                true // round up
            );
        }

        // Apply order fill fraction and set recipient as the receiver.
        FulfilledItem memory item = FulfilledItem(
            receivedItem.itemType,
            receivedItem.token,
            receivedItem.identifierOrCriteria,
            amount,
            receivedItem.recipient
        );

        // Transfer the item from the caller to the consideration recipient.
        _transfer(
            item,
            msg.sender,
            useFulfillerProxy
        );
    }

    /**
     * @dev Internal function to fulfill an arbitrary number of orders, either
     *      full or partial, after validating, adjusting amounts, and applying
     *      criteria resolvers.
     *
     * @param orders         The orders to match, including a fraction to
     *                       attempt to fill for each order.
     * @param fulfillments   An array of elements allocating offer components to
     *                       consideration components. Note that the end amount
     *                       of each consideration component must be zero in
     *                       order for the match operation to be valid.
     * @param ordersUseProxy An array of booleans indicating whether to source
     *                       approvals for the fulfilled tokens on each order
     *                       from their respective proxy.
     *
     * @return An array of elements indicating the sequence of non-batch
     *         transfers performed as part of matching the given orders.
     * @return An array of elements indicating the sequence of batch transfers
     *         performed as part of matching the given orders.
     */
    function _fulfillAdvancedOrders(
        AdvancedOrder[] memory orders,
        Fulfillment[] memory fulfillments,
        bool[] memory ordersUseProxy
    ) internal returns (Execution[] memory, BatchExecution[] memory) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Allocate executions by fulfillment and apply them to each execution.
        Execution[] memory executions = new Execution[](fulfillments.length);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Track number of filtered executions.
            uint256 totalFilteredExecutions = 0;

            // Iterate over each fulfillment.
            for (uint256 i = 0; i < fulfillments.length; ++i) {
                /// Retrieve the fulfillment in question.
                Fulfillment memory fulfillment = fulfillments[i];

                // Derive the execution corresponding with the fulfillment.
                Execution memory execution = _applyFulfillment(
                    orders,
                    fulfillment.offerComponents,
                    fulfillment.considerationComponents,
                    ordersUseProxy
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
                // reduce the total length of the executions array.
                assembly {
                    mstore(
                        executions,
                        sub(mload(executions), totalFilteredExecutions)
                    )
                }
            }

            // Iterate over orders to ensure all considerations are met.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve consideration items to ensure they are fulfilled.
                ReceivedItem[] memory receivedItems = (
                    orders[i].parameters.consideration
                );

                // Iterate over each consideration item to ensure it is met.
                for (uint256 j = 0; j < receivedItems.length; ++j) {
                    // Retrieve the remaining amount on the consideration.
                    uint256 unmetAmount = receivedItems[j].endAmount;

                    // Revert if the remaining amount is not zero.
                    if (unmetAmount != 0) {
                        revert ConsiderationNotMet(i, j, unmetAmount);
                    }
                }
            }
        }

        // Allocate memory for "standard" (no batch) and "batch" executions.
        Execution[] memory standardExecutions;
        BatchExecution[] memory batchExecutions;

        // Split executions into "standard" (no batch) and "batch" executions.
        (standardExecutions, batchExecutions) = _compressExecutions(executions);

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < standardExecutions.length;) {
            // Retrieve the execution.
            Execution memory execution = standardExecutions[i];
            FulfilledItem memory item = execution.item;

            // If execution transfers native tokens, reduce value available.
            if (item.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= item.amount;
                }
            }

            // Transfer the item specified by the execution.
            _transfer(
                item,
                execution.offerer,
                execution.useProxy
            );

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

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;

        // Return the arrays of executions that were triggered.
        return (standardExecutions, batchExecutions);
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item     The item to transfer, including an amount and recipient.
     * @param offerer  The account offering the item, i.e. the from address.
     * @param useProxy A boolean indicating whether to source approvals for the
     *                 fulfilled token from the offer's proxy.
     */
    function _transfer(
        FulfilledItem memory item,
        address offerer,
        bool useProxy
    ) internal {
        // If the item type is for Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // transfer the native tokens to the recipient.
            _transferEth(item.recipient, item.amount);
        // Otherwise, transfer the item based on item type and proxy preference.
        } else {
            // Place proxy owner on stack (or null address if not using proxy).
            address proxyOwner = useProxy ? offerer : address(0);

            if (item.itemType == ItemType.ERC20) {
                // Transfer ERC20 token from the offerer to the recipient.
                _transferERC20(
                    item.token,
                    offerer,
                    item.recipient,
                    item.amount,
                    proxyOwner
                );
            } else if (item.itemType == ItemType.ERC721) {
                // Ensure that exactly one 721 item is being transferred.
                if (item.amount != 1) {
                    revert InvalidERC721TransferAmount();
                }

                // Transfer ERC721 token from the offerer to the recipient.
                _transferERC721(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    proxyOwner
                );
            } else {
                // Transfer ERC1155 token from the offerer to the recipient.
                _transferERC1155(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    item.amount,
                    proxyOwner
                );
            }
        }
    }

    /**
     * @dev Internal function to transfer Ether or other native tokens to a
     *      given recipient.
     *
     * @param to     The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function _transferEth(address payable to, uint256 amount) internal {
        // Attempt to transfer the native tokens to the recipient.
        (bool success,) = to.call{value: amount}("");

        // If the call fails...
        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            revert EtherTransferGenericFailure(to, amount);
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective proxy or on this contract itself.
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     * @param proxyOwner An address indicating the owner of the proxy to utilize
     *                   when performing the transfer, or the null address if no
     *                   proxy should be utilized.
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Declare a boolean to represent whether call completes successfully.
        bool success;

        // If a proxy owner has been specified...
        if (proxyOwner != address(0)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            success = _callProxy(
                proxyOwner,
                abi.encodeWithSelector(
                    ProxyInterface.transferERC20.selector,
                    token,
                    from,
                    to,
                    amount
                )
            );
        } else {
            // Otherwise, perform transfer via the token contract directly.
            success = _call(
                token,
                abi.encodeCall(
                    ERC20Interface.transferFrom,
                    (
                        from,
                        to,
                        amount
                    )
                )
            );
        }

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            success,
            token,
            from,
            to,
            0,
            amount
        );

        // Extract result directly from returndata buffer if one is returned.
        bool result = true;
        assembly {
            // Only put result on the stack if return data is exactly 32 bytes.
            if eq(returndatasize(), 0x20) {
                // Copy directly from return data into memory in scratch space.
                returndatacopy(0, 0, 0x20)

                // Take the value from scratch space and place it on the stack.
                result := mload(0)
            }
        }

        // If a falsey result is extracted...
        if (!result) {
            // Revert with a "Bad Return Value" error.
            revert BadReturnValueFromERC20OnTransfer(
                token,
                from,
                to,
                amount
            );
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
     * @param proxyOwner An address indicating the owner of the proxy to utilize
     *                   when performing the transfer, or the null address if no
     *                   proxy should be utilized.
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        address proxyOwner
    ) internal {
        // Declare a boolean to represent whether call completes successfully.
        bool success;

        // If a proxy owner has been specified...
        if (proxyOwner != address(0)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            success = _callProxy(
                proxyOwner,
                abi.encodeWithSelector(
                    ProxyInterface.transferERC721.selector,
                    token,
                    from,
                    to,
                    identifier
                )
            );
        } else {
            // Otherwise, perform transfer via the token contract directly.
            success = _call(
                token,
                abi.encodeCall(
                    ERC721Interface.transferFrom,
                    (
                        from,
                        to,
                        identifier
                    )
                )
            );
        }

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            success,
            token,
            from,
            to,
            identifier,
            1
        );
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
     * @param proxyOwner An address indicating the owner of the proxy to utilize
     *                   when performing the transfer, or the null address if no
     *                   proxy should be utilized.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Declare a boolean to represent whether call completes successfully.
        bool success;

        // If a proxy owner has been specified...
        if (proxyOwner != address(0)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            success = _callProxy(
                proxyOwner,
                abi.encodeWithSelector(
                    ProxyInterface.transferERC1155.selector,
                    token,
                    from,
                    to,
                    identifier,
                    amount
                )
            );
        } else {
            // Otherwise, perform transfer via the token contract directly.
            success = _call(
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
        }

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            success,
            token,
            from,
            to,
            identifier,
            amount
        );
    }

    /**
     * @dev Internal function to transfer a batch of ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param batchExecution The batch of 1155 tokens to be transferred.
     */
    function _batchTransferERC1155(
        BatchExecution memory batchExecution
    ) internal {
        // Place elements of the batch execution in memory onto the stack.
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;

        // Retrieve the tokenIds and amounts.
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;

        // Declare a boolean to represent whether call completes successfully.
        bool success;

        // If proxy usage has been specified...
        if (batchExecution.useProxy) {
            // Perform transfers via a call to the proxy for the supplied owner.
            success = _callProxy(
                batchExecution.from,
                abi.encodeWithSelector(
                    ProxyInterface.batchTransferERC1155.selector,
                    token,
                    from,
                    to,
                    tokenIds,
                    amounts
                )
            );
        } else {
            // Otherwise, perform transfers via the token contract directly.
            success = _call(
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
        }

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
     * @dev Internal function to trigger a call to a proxy contract.
     *
     * @param proxyOwner The original owner of the proxy in question. Note that
     *                   this owner may have been modified since the proxy was
     *                   originally deployed.
     * @param callData   The calldata to supply when calling the proxy.
     *
     * @return success The status of the call to the proxy.
     */
    function _callProxy(
        address proxyOwner,
        bytes memory callData
    ) internal returns (bool success) {
        // Retrieve the user proxy from the registry.
        address proxy = _LEGACY_PROXY_REGISTRY.proxies(proxyOwner);

        // Assert that the user proxy has the correct implementation.
        if (
            ProxyInterface(
                proxy
            ).implementation() != _REQUIRED_PROXY_IMPLEMENTATION
        ) {
            revert InvalidProxyImplementation();
        }

        // perform the call to the proxy.
        (success,) = proxy.call(callData);
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
    function _call(
        address target,
        bytes memory callData
    ) internal returns (bool success) {
        (success, ) = target.call(callData);
    }

    /**
     * @dev Internal function to transfer Ether to a given recipient.
     *
     * @param amount     The amount of Ether to transfer.
     * @param parameters The parameters of the order.
     */
    function _transferEthAndFinalize(
        uint256 amount,
        BasicOrderParameters memory parameters
    ) internal {
        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length;) {
            // Retrieve the additional recipient.
            AdditionalRecipient memory additionalRecipient = (
                parameters.additionalRecipients[i]
            );

            // Read ether amount to transfer to recipient and place on stack.
            uint256 additionalRecipientAmount = additionalRecipient.amount;

            // Ensure that sufficient Ether is available.
            if (additionalRecipientAmount > etherRemaining) {
                revert InsufficientEtherSupplied();
            }

            // Transfer Ether to the additional recipient.
            _transferEth(
                additionalRecipient.recipient,
                additionalRecipientAmount
            );

            // Skip underflow check as subtracted value is less than remaining.
            unchecked {
                // Reduce ether value available.
                etherRemaining -= additionalRecipientAmount;
            }

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Ensure that sufficient Ether is still available.
        if (amount > etherRemaining) {
            revert InsufficientEtherSupplied();
        }

        // Transfer Ether to the offerer.
        _transferEth(parameters.offerer, amount);

        // If any Ether remains after transfers, return it to the caller.
        if (etherRemaining > amount) {
            // Skip underflow check as etherRemaining > amount.
            unchecked {
                // Transfer remaining Ether to the caller.
                _transferEth(payable(msg.sender), etherRemaining - amount);
            }
        }

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Internal function to transfer ERC20 tokens to a given recipient.
     *
     * @param from       The originator of the ERC20 token transfer.
     * @param to         The recipient of the ERC20 token transfer.
     * @param erc20Token The ERC20 token to transfer.
     * @param amount     The amount of ERC20 tokens to transfer.
     * @param parameters The parameters of the order.
     */
    function _transferERC20AndFinalize(
        address from,
        address to,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters memory parameters
    ) internal {
        // Place proxy owner on the stack (or null address if not using proxy).
        address proxyOwner = parameters.useFulfillerProxy ? from : address(0);

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each additional recipient.
            for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
                // Retrieve the additional recipient.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[i]
                );

                // Transfer ERC20 tokens to additional recipient given approval.
                _transferERC20(
                    erc20Token,
                    from,
                    additionalRecipient.recipient,
                    additionalRecipient.amount,
                    proxyOwner
                );
            }
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(
            erc20Token,
            from,
            to,
            amount,
            proxyOwner
        );

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Internal function to ensure that the sentinel value for the
     *      reentrancy guard is not currently set and, if not, to set the
     *      sentinel value for the reentrancy guard.
     */
    function _setReentrancyGuard() internal {
        // Ensure that the reentrancy guard is not already set.
        _assertNonReentrant();

        // Set the reentrancy guard.
        _reentrancyGuard = _ENTERED;
    }

    function _emitOrderFulfilledEvent(
        bytes32 orderHash,
        address offerer,
        address zone,
        address fulfiller,
        OfferedItem[] memory offer,
        ReceivedItem[] memory consideration
    ) internal {
        ConsumedItem[] memory consumedItems = new ConsumedItem[](offer.length);
        FulfilledItem[] memory fulfilledItems = new FulfilledItem[](consideration.length);

        unchecked {
            for (uint256 i = 0; i < offer.length; ++i) {
                OfferedItem memory offeredItem = offer[i];
                consumedItems[i] = ConsumedItem(
                    offeredItem.itemType,
                    offeredItem.token,
                    offeredItem.identifierOrCriteria,
                    offeredItem.endAmount
                );
            }

            for (uint256 i = 0; i < consideration.length; ++i) {
                ReceivedItem memory receivedItem = consideration[i];
                fulfilledItems[i] = FulfilledItem(
                    receivedItem.itemType,
                    receivedItem.token,
                    receivedItem.identifierOrCriteria,
                    receivedItem.endAmount,
                    receivedItem.recipient
                );
            }
        }

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderHash,
            offerer,
            zone,
            fulfiller,
            consumedItems,
            fulfilledItems
        );
    }
}