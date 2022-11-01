// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";

import {
    OfferItem,
    ConsiderationItem,
    ReceivedItem,
    OrderParameters,
    AdvancedOrder,
    Execution,
    FulfillmentComponent,
    SpentItem
} from "../../contracts/lib/ConsiderationStructs.sol";

import {
    ConsiderationItemIndicesAndValidity,
    OrderToExecute
} from "./ReferenceConsiderationStructs.sol";

import "../../contracts/lib/ConsiderationConstants.sol";

import {
    FulfillmentApplicationErrors
} from "../../contracts/interfaces/FulfillmentApplicationErrors.sol";

/**
 * @title FulfillmentApplier
 * @author 0age
 * @notice FulfillmentApplier contains logic related to applying fulfillments,
 *         both as part of order matching (where offer items are matched to
 *         consideration items) as well as fulfilling available orders (where
 *         order items and consideration items are independently aggregated).
 */
contract ReferenceFulfillmentApplier is FulfillmentApplicationErrors {
    /**
     * @dev Internal pure function to match offer items to consideration items
     *      on a group of orders via a supplied fulfillment.
     *
     * @param ordersToExecute         The orders to match.
     * @param offerComponents         An array designating offer components to
     *                                match to consideration components.
     * @param considerationComponents An array designating consideration
     *                                components to match to offer components.
     *                                Note that each consideration amount must
     *                                be zero in order for the match operation
     *                                to be valid.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _applyFulfillment(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] calldata offerComponents,
        FulfillmentComponent[] calldata considerationComponents
    ) internal pure returns (Execution memory execution) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            offerComponents.length == 0 || considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Recipient does not need to be specified because it will always be set
        // to that of the consideration.
        // Validate and aggregate consideration items and store the result as a
        // ReceivedItem.
        ReceivedItem memory considerationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                ordersToExecute,
                considerationComponents,
                0
            )
        );

        // Validate & aggregate offer items and store result as an Execution.

        (execution) = /**
         * ItemType itemType,
         * address token,
         * uint256 identifier,
         * address offerer,
         * bytes32 conduitKey,
         * uint256 offerAmount
         */
        _aggregateValidFulfillmentOfferItems(
            ordersToExecute,
            offerComponents,
            0,
            address(0) // unused
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            execution.item.itemType != considerationItem.itemType ||
            execution.item.token != considerationItem.token ||
            execution.item.identifier != considerationItem.identifier
        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents();
        }

        // If total consideration amount exceeds the offer amount...
        if (considerationItem.amount > execution.item.amount) {
            // Retrieve the first consideration component from the fulfillment.
            FulfillmentComponent memory targetComponent = (
                considerationComponents[0]
            );

            // Add excess consideration item amount to original array of orders.
            ordersToExecute[targetComponent.orderIndex]
                .receivedItems[targetComponent.itemIndex]
                .amount = considerationItem.amount - execution.item.amount;

            // Reduce total consideration amount to equal the offer amount.
            considerationItem.amount = execution.item.amount;
        } else {
            // Retrieve the first offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = (offerComponents[0]);

            // Add excess offer item amount to the original array of orders.
            ordersToExecute[targetComponent.orderIndex]
                .spentItems[targetComponent.itemIndex]
                .amount = execution.item.amount - considerationItem.amount;
        }

        // Reuse execution struct with consideration amount and recipient.
        execution.item.amount = considerationItem.amount;
        execution.item.recipient = considerationItem.recipient;

        // Return the final execution that will be triggered for relevant items.
        return execution; // Execution(considerationItem, offerer, conduitKey);
    }

    /**
     * @dev Internal view function to aggregate offer or consideration items
     *      from a group of orders into a single execution via a supplied array
     *      of fulfillment components. Items that are not available to aggregate
     *      will not be included in the aggregated execution.
     *
     * @param ordersToExecute       The orders to aggregate.
     * @param side                  The side (i.e. offer or consideration).
     * @param fulfillmentComponents An array designating item components to
     *                              aggregate if part of an available order.
     * @param fulfillerConduitKey   A bytes32 value indicating what conduit, if
     *                              any, to source the fulfiller's token
     *                              approvals from. The zero hash signifies that
     *                              no conduit should be used (and direct
     *                              approvals set on Consideration)
     * @param recipient             The intended recipient for all received
     *                              items.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateAvailable(
        OrderToExecute[] memory ordersToExecute,
        Side side,
        FulfillmentComponent[] memory fulfillmentComponents,
        bytes32 fulfillerConduitKey,
        address recipient
    ) internal view returns (Execution memory execution) {
        // Retrieve orders array length and place on the stack.
        uint256 totalOrders = ordersToExecute.length;

        // Retrieve fulfillment components array length and place on stack.
        uint256 totalFulfillmentComponents = fulfillmentComponents.length;

        // Ensure at least one fulfillment component has been supplied.
        if (totalFulfillmentComponents == 0) {
            revert MissingFulfillmentComponentOnAggregation(side);
        }

        // Determine component index after first available (0 implies none).
        uint256 nextComponentIndex = 0;

        // Iterate over components until finding one with a fulfilled order.
        for (uint256 i = 0; i < totalFulfillmentComponents; ++i) {
            // Retrieve the fulfillment component index.
            uint256 orderIndex = fulfillmentComponents[i].orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= totalOrders) {
                revert InvalidFulfillmentComponentData();
            }

            // If order is being fulfilled (i.e. it is still available)...
            if (ordersToExecute[orderIndex].numerator != 0) {
                // Update the next potential component index.
                nextComponentIndex = i + 1;

                // Exit the loop.
                break;
            }
        }

        // If no available order was located...
        if (nextComponentIndex == 0) {
            // Return with an empty execution element that will be filtered.
            // prettier-ignore
            return Execution(
                ReceivedItem(ItemType.NATIVE, address(0), 0, 0, payable(address(0))), address(0), bytes32(0)
            );
        }

        // If the fulfillment components are offer components...
        if (side == Side.OFFER) {
            // Return execution for aggregated items provided by offerer.
            // prettier-ignore
            return _aggregateValidFulfillmentOfferItems(
                ordersToExecute, fulfillmentComponents, nextComponentIndex - 1, recipient
            );
        } else {
            // Otherwise, fulfillment components are consideration
            // components. Return execution for aggregated items provided by
            // the fulfiller.
            // prettier-ignore
            return _aggregateConsiderationItems(
                ordersToExecute, fulfillmentComponents, nextComponentIndex - 1, fulfillerConduitKey
            );
        }
    }

    /**
     * @dev Internal pure function to check the indicated offer item
     *      matches original item.
     *
     * @param orderToExecute  The order to compare.
     * @param offer The offer to compare
     * @param execution  The aggregated offer item
     *
     * @return invalidFulfillment A boolean indicating whether the
     *                            fulfillment is invalid.
     */
    function _checkMatchingOffer(
        OrderToExecute memory orderToExecute,
        SpentItem memory offer,
        Execution memory execution
    ) internal pure returns (bool invalidFulfillment) {
        return
            execution.item.identifier != offer.identifier ||
            execution.offerer != orderToExecute.offerer ||
            execution.conduitKey != orderToExecute.conduitKey ||
            execution.item.itemType != offer.itemType ||
            execution.item.token != offer.token;
    }

    /**
     * @dev Internal pure function to aggregate a group of offer items using
     *      supplied directives on which component items are candidates for
     *      aggregation, skipping items on orders that are not available.
     *
     * @param ordersToExecute The orders to aggregate offer items from.
     * @param offerComponents An array of FulfillmentComponent structs
     *                        indicating the order index and item index of each
     *                        candidate offer item for aggregation.
     * @param startIndex      The initial order index to begin iteration on when
     *                        searching for offer items to aggregate.
     *
     * @return execution The aggregated offer items.
     */
    function _aggregateValidFulfillmentOfferItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory offerComponents,
        uint256 startIndex,
        address recipient
    ) internal pure returns (Execution memory execution) {
        // Get the order index and item index of the offer component.
        uint256 orderIndex = offerComponents[startIndex].orderIndex;
        uint256 itemIndex = offerComponents[startIndex].itemIndex;

        // Declare a variable indicating whether the aggregation is invalid.
        // Ensure that the order index is not out of range.
        bool invalidFulfillment = (orderIndex >= ordersToExecute.length);
        if (!invalidFulfillment) {
            // Get the order based on offer components order index.
            OrderToExecute memory orderToExecute = ordersToExecute[orderIndex];
            // Ensure that the item index is not out of range.
            invalidFulfillment =
                invalidFulfillment ||
                (itemIndex >= orderToExecute.spentItems.length);

            if (!invalidFulfillment) {
                // Get the spent item based on the offer components item index.
                SpentItem memory offer = orderToExecute.spentItems[itemIndex];

                // Create the Execution.
                execution = Execution(
                    ReceivedItem(
                        offer.itemType,
                        offer.token,
                        offer.identifier,
                        offer.amount,
                        payable(recipient)
                    ),
                    orderToExecute.offerer,
                    orderToExecute.conduitKey
                );

                // Zero out amount on original offerItem to indicate it is spent
                offer.amount = 0;

                // Loop through the offer components, checking for validity.
                for (
                    uint256 i = startIndex + 1;
                    i < offerComponents.length;
                    ++i
                ) {
                    // Get the order index and item index of the offer
                    // component.
                    orderIndex = offerComponents[i].orderIndex;
                    itemIndex = offerComponents[i].itemIndex;

                    // Ensure that the order index is not out of range.
                    invalidFulfillment = orderIndex >= ordersToExecute.length;
                    // Break if invalid
                    if (invalidFulfillment) {
                        break;
                    }
                    // Get the order based on offer components order index.
                    orderToExecute = ordersToExecute[orderIndex];
                    if (orderToExecute.numerator != 0) {
                        // Ensure that the item index is not out of range.
                        invalidFulfillment = (itemIndex >=
                            orderToExecute.spentItems.length);
                        // Break if invalid
                        if (invalidFulfillment) {
                            break;
                        }
                        // Get the spent item based on the offer components
                        // item index.
                        offer = orderToExecute.spentItems[itemIndex];
                        // Update the Received Item Amount.
                        execution.item.amount =
                            execution.item.amount +
                            offer.amount;
                        // Zero out amount on original offerItem to indicate
                        // it is spent,
                        offer.amount = 0;
                        // Ensure the indicated offer item matches original
                        // item.
                        invalidFulfillment = _checkMatchingOffer(
                            orderToExecute,
                            offer,
                            execution
                        );
                        // Break if invalid
                        if (invalidFulfillment) {
                            break;
                        }
                    }
                }
            }
        }
        // Revert if an order/item was out of range or was not aggregatable.
        if (invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
        }
    }

    /**
     * @dev Internal view function to aggregate consideration items from a group
     *      of orders into a single execution via a supplied components array.
     *      Consideration items that are not available to aggregate will not be
     *      included in the aggregated execution.
     *
     * @param ordersToExecute         The orders to aggregate.
     * @param considerationComponents An array designating consideration
     *                                components to aggregate if part of an
     *                                available order.
     * @param nextComponentIndex      The index of the next potential
     *                                consideration component.
     * @param fulfillerConduitKey     A bytes32 value indicating what conduit,
     *                                if any, to source the fulfiller's token
     *                                approvals from. The zero hash signifies
     *                                that no conduit should be used (and direct
     *                                approvals set on Consideration)
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateConsiderationItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory considerationComponents,
        uint256 nextComponentIndex,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Validate and aggregate consideration items on available orders and
        // store result as a ReceivedItem.
        ReceivedItem memory receiveConsiderationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                ordersToExecute,
                considerationComponents,
                nextComponentIndex
            )
        );

        // Return execution for aggregated items provided by the fulfiller.
        execution = Execution(
            receiveConsiderationItem,
            msg.sender,
            fulfillerConduitKey
        );
    }

    /**
     * @dev Internal pure function to check the indicated consideration item
     *      matches original item.
     *
     * @param consideration  The consideration to compare
     * @param receivedItem  The aggregated received item
     *
     * @return invalidFulfillment A boolean indicating whether the fulfillment
     *                            is invalid.
     */
    function _checkMatchingConsideration(
        ReceivedItem memory consideration,
        ReceivedItem memory receivedItem
    ) internal pure returns (bool invalidFulfillment) {
        return
            receivedItem.recipient != consideration.recipient ||
            receivedItem.itemType != consideration.itemType ||
            receivedItem.token != consideration.token ||
            receivedItem.identifier != consideration.identifier;
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
        // Ensure that order index is in range.
        potentialCandidate.invalidFulfillment = (potentialCandidate
            .orderIndex >= ordersToExecute.length);

        if (!potentialCandidate.invalidFulfillment) {
            // Retrieve relevant item using order index.
            OrderToExecute memory orderToExecute = ordersToExecute[
                potentialCandidate.orderIndex
            ];
            // Ensure that the item index is not out of range.
            potentialCandidate.invalidFulfillment =
                potentialCandidate.invalidFulfillment ||
                (potentialCandidate.itemIndex >=
                    orderToExecute.receivedItems.length);
            if (!potentialCandidate.invalidFulfillment) {
                // Retrieve relevant item using item index.
                ReceivedItem memory consideration = orderToExecute
                    .receivedItems[potentialCandidate.itemIndex];

                // Create the received item.
                receivedItem = ReceivedItem(
                    consideration.itemType,
                    consideration.token,
                    consideration.identifier,
                    consideration.amount,
                    consideration.recipient
                );

                // Zero out amount on original offerItem to indicate it is spent
                consideration.amount = 0;

                // Loop through the consideration components and validate
                // their fulfillment.
                for (
                    uint256 i = startIndex + 1;
                    i < considerationComponents.length;
                    ++i
                ) {
                    // Get the order index and item index of the consideration
                    // component.
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
                    // Get the order based on consideration components order
                    // index.
                    orderToExecute = ordersToExecute[
                        potentialCandidate.orderIndex
                    ];
                    // Confirm this is a fulfilled order.
                    if (orderToExecute.numerator != 0) {
                        // Ensure that the item index is not out of range.
                        potentialCandidate
                            .invalidFulfillment = (potentialCandidate
                            .itemIndex >= orderToExecute.receivedItems.length);
                        // Break if invalid
                        if (potentialCandidate.invalidFulfillment) {
                            break;
                        }
                        // Retrieve relevant item using item index.
                        consideration = orderToExecute.receivedItems[
                            potentialCandidate.itemIndex
                        ];
                        // Updating Received Item Amount
                        receivedItem.amount =
                            receivedItem.amount +
                            consideration.amount;
                        // Zero out amount on original consideration item to
                        // indicate it is spent
                        consideration.amount = 0;
                        // Ensure the indicated consideration item matches
                        // original item.
                        potentialCandidate
                            .invalidFulfillment = _checkMatchingConsideration(
                            consideration,
                            receivedItem
                        );
                        // Break if invalid
                        if (potentialCandidate.invalidFulfillment) {
                            break;
                        }
                    }
                }
            }
        }

        // Revert if an order/item was out of range or was not aggregatable.
        if (potentialCandidate.invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
        }
    }
}
