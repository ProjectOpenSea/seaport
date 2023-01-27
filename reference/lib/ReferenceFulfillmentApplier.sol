// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";

import {
    Execution,
    FulfillmentComponent,
    ReceivedItem,
    SpentItem
} from "../../contracts/lib/ConsiderationStructs.sol";

import {
    ConsiderationItemIndicesAndValidity,
    OrderToExecute
} from "./ReferenceConsiderationStructs.sol";

import {
    FulfillmentApplicationErrors
} from "../../contracts/interfaces/FulfillmentApplicationErrors.sol";

import {
    TokenTransferrerErrors
} from "../../contracts/interfaces/TokenTransferrerErrors.sol";

/**
 * @title FulfillmentApplier
 * @author 0age
 * @notice FulfillmentApplier contains logic related to applying fulfillments,
 *         both as part of order matching (where offer items are matched to
 *         consideration items) as well as fulfilling available orders (where
 *         order items and consideration items are independently aggregated).
 */
contract ReferenceFulfillmentApplier is
    FulfillmentApplicationErrors,
    TokenTransferrerErrors
{
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
     * @param fulfillmentIndex        The index of the fulfillment component
     *                                that does not match the initial offer
     *                                item.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _applyFulfillment(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent[] memory considerationComponents,
        uint256 fulfillmentIndex
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
                considerationComponents
            )
        );

        // Skip aggregating offer items if no consideration items are available.
        if (considerationItem.amount == 0) {
            // Set the offerer and recipient to null address if execution
            // amount is zero. This will cause the execution item to be skipped.
            execution.offerer = address(0);
            execution.item.recipient = payable(0);
            return execution;
        }

        // Validate & aggregate offer items and store result as an Execution.
        (
            execution
            /**
             * ItemType itemType,
             * address token,
             * uint256 identifier,
             * address offerer,
             * bytes32 conduitKey,
             * uint256 offerAmount
             */
        ) = _aggregateValidFulfillmentOfferItems(
            ordersToExecute,
            offerComponents,
            address(0) // unused
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            execution.item.itemType != considerationItem.itemType ||
            execution.item.token != considerationItem.token ||
            execution.item.identifier != considerationItem.identifier
        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents(
                fulfillmentIndex
            );
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
            return
                Execution(
                    ReceivedItem(
                        ItemType.NATIVE,
                        address(0),
                        0,
                        0,
                        payable(address(0))
                    ),
                    address(0),
                    bytes32(0)
                );
        }

        // If the fulfillment components are offer components...
        if (side == Side.OFFER) {
            // Return execution for aggregated items provided by offerer.
            return
                _aggregateValidFulfillmentOfferItems(
                    ordersToExecute,
                    fulfillmentComponents,
                    recipient
                );
        } else {
            // Otherwise, fulfillment components are consideration
            // components. Return execution for aggregated items provided by
            // the fulfiller.
            return
                _aggregateConsiderationItems(
                    ordersToExecute,
                    fulfillmentComponents,
                    fulfillerConduitKey
                );
        }
    }

    /**
     * @dev Internal pure function to check the indicated offer item
     *      matches original item.
     *
     * @param orderToExecute The order to compare.
     * @param offer          The offer to compare.
     * @param execution      The aggregated offer item.
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
     * @param recipient       The recipient for the aggregated offer items.
     *
     * @return execution The aggregated offer items.
     */
    function _aggregateValidFulfillmentOfferItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory offerComponents,
        address recipient
    ) internal pure returns (Execution memory execution) {
        bool foundItem = false;

        // Get the order index and item index of the offer component.
        uint256 orderIndex;
        uint256 itemIndex;

        OrderToExecute memory orderToExecute;

        // Declare variables indicating whether the aggregation is invalid.
        // Ensure that the order index is not out of range.
        bool invalidFulfillment;

        // Ensure that no available items have missing amounts.
        bool missingItemAmount;

        // Loop through the offer components, checking for validity.
        for (uint256 i = 0; i < offerComponents.length; ++i) {
            // Get the order index and item index of the offer component.
            orderIndex = offerComponents[i].orderIndex;
            itemIndex = offerComponents[i].itemIndex;

            // Ensure that the order index is not out of range.
            invalidFulfillment = orderIndex >= ordersToExecute.length;
            // Break if invalid.
            if (invalidFulfillment) {
                break;
            }

            // Get the order based on offer components order index.
            orderToExecute = ordersToExecute[orderIndex];
            if (
                orderToExecute.numerator != 0 &&
                itemIndex < orderToExecute.spentItems.length
            ) {
                // Get the spent item based on the offer components item index.
                SpentItem memory offer = orderToExecute.spentItems[itemIndex];

                if (!foundItem) {
                    foundItem = true;

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

                    // If component index > 0, swap component pointer with
                    // pointer to first component so that any remainder after
                    // fulfillment can be added back to the first item.
                    if (i != 0) {
                        FulfillmentComponent
                            memory firstComponent = offerComponents[0];
                        offerComponents[0] = offerComponents[i];
                        offerComponents[i] = firstComponent;
                    }
                } else {
                    // Update the Received Item amount.
                    execution.item.amount =
                        execution.item.amount +
                        offer.amount;

                    // Ensure indicated offer item matches original item.
                    invalidFulfillment = _checkMatchingOffer(
                        orderToExecute,
                        offer,
                        execution
                    );
                }

                // Ensure the item has a nonzero amount.
                missingItemAmount = offer.amount == 0;
                invalidFulfillment = invalidFulfillment || missingItemAmount;

                // Zero out amount on original offerItem to indicate it's spent.
                offer.amount = 0;

                // Break if invalid.
                if (invalidFulfillment) {
                    break;
                }
            }
        }

        // Revert if an order/item was out of range or was not aggregatable.
        if (invalidFulfillment) {
            if (missingItemAmount) {
                revert MissingItemAmount();
            }
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
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Validate and aggregate consideration items on available orders and
        // store result as a ReceivedItem.
        ReceivedItem memory receiveConsiderationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                ordersToExecute,
                considerationComponents
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
     * @param consideration The consideration to compare.
     * @param receivedItem  The aggregated received item.
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
     *
     * @return receivedItem The aggregated consideration items.
     */
    function _aggregateValidFulfillmentConsiderationItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory considerationComponents
    ) internal pure returns (ReceivedItem memory receivedItem) {
        bool foundItem = false;

        // Declare struct in memory to avoid declaring multiple local variables.
        ConsiderationItemIndicesAndValidity memory potentialCandidate;

        ReceivedItem memory consideration;

        OrderToExecute memory orderToExecute;

        // Loop through the consideration components and validate
        // their fulfillment.
        for (uint256 i = 0; i < considerationComponents.length; ++i) {
            // Get the order index and item index of the consideration
            // component.
            potentialCandidate.orderIndex = considerationComponents[i]
                .orderIndex;
            potentialCandidate.itemIndex = considerationComponents[i].itemIndex;

            /// Ensure that the order index is not out of range.
            potentialCandidate.invalidFulfillment =
                potentialCandidate.orderIndex >= ordersToExecute.length;

            // Break if invalid.
            if (potentialCandidate.invalidFulfillment) {
                break;
            }

            // Get order based on consideration components order index.
            orderToExecute = ordersToExecute[potentialCandidate.orderIndex];

            // Confirm that the order is being fulfilled.
            if (
                orderToExecute.numerator != 0 &&
                potentialCandidate.itemIndex <
                orderToExecute.receivedItems.length
            ) {
                // Retrieve relevant item using item index.
                consideration = orderToExecute.receivedItems[
                    potentialCandidate.itemIndex
                ];

                if (!foundItem) {
                    foundItem = true;

                    // Create the received item.
                    receivedItem = ReceivedItem(
                        consideration.itemType,
                        consideration.token,
                        consideration.identifier,
                        consideration.amount,
                        consideration.recipient
                    );

                    // If component index > 0, swap component pointer with
                    // pointer to first component so that any remainder after
                    // fulfillment can be added back to the first item.
                    if (i != 0) {
                        FulfillmentComponent
                            memory firstComponent = considerationComponents[0];
                        considerationComponents[0] = considerationComponents[i];
                        considerationComponents[i] = firstComponent;
                    }
                } else {
                    // Update Received Item amount.
                    receivedItem.amount =
                        receivedItem.amount +
                        consideration.amount;

                    // Ensure the indicated consideration item matches
                    // original item.
                    potentialCandidate
                        .invalidFulfillment = _checkMatchingConsideration(
                        consideration,
                        receivedItem
                    );
                }

                // Ensure the item has a nonzero amount.
                potentialCandidate.missingItemAmount =
                    consideration.amount == 0;
                potentialCandidate.invalidFulfillment =
                    potentialCandidate.invalidFulfillment ||
                    potentialCandidate.missingItemAmount;

                // Zero out amount on original consideration item to
                // indicate it is spent.
                consideration.amount = 0;

                // Break if invalid.
                if (potentialCandidate.invalidFulfillment) {
                    break;
                }
            }
        }

        // Revert if an order/item was out of range or was not aggregatable.
        if (potentialCandidate.invalidFulfillment) {
            if (potentialCandidate.missingItemAmount) {
                revert MissingItemAmount();
            }
            revert InvalidFulfillmentComponentData();
        }
    }
}
