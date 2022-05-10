// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ItemType, Side } from "./ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    ReceivedItem,
    OrderParameters,
    AdvancedOrder,
    Execution,
    FulfillmentComponent
} from "./ConsiderationStructs.sol";

import "./ConsiderationConstants.sol";

// prettier-ignore
import {
    FulfillmentApplicationErrors
} from "../interfaces/FulfillmentApplicationErrors.sol";

/**
 * @title FulfillmentApplier
 * @author 0age
 * @notice FulfillmentApplier contains logic related to applying fulfillments,
 *         both as part of order matching (where offer items are matched to
 *         consideration items) as well as fulfilling available orders (where
 *         order items and consideration items are independently aggregated).
 */
contract FulfillmentApplier is FulfillmentApplicationErrors {
    /**
     * @dev Internal view function to match offer items to consideration items
     *      on a group of orders via a supplied fulfillment.
     *
     * @param advancedOrders          The orders to match.
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
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] calldata offerComponents,
        FulfillmentComponent[] calldata considerationComponents
    ) internal view returns (Execution memory execution) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            offerComponents.length == 0 || considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Validate and aggregate consideration items and store the result as a
        // ReceivedItem.
        ReceivedItem memory considerationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                advancedOrders,
                considerationComponents,
                0
            )
        );

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
            advancedOrders,
            offerComponents,
            0
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
            advancedOrders[targetComponent.orderIndex]
                .parameters
                .consideration[targetComponent.itemIndex]
                .startAmount = considerationItem.amount - execution.item.amount;

            // Reduce total consideration amount to equal the offer amount.
            considerationItem.amount = execution.item.amount;
        } else {
            // Retrieve the first offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = (offerComponents[0]);

            // Add excess offer item amount to the original array of orders.
            advancedOrders[targetComponent.orderIndex]
                .parameters
                .offer[targetComponent.itemIndex]
                .startAmount = execution.item.amount - considerationItem.amount;
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
     * @param advancedOrders        The orders to aggregate.
     * @param side                  The side (i.e. offer or consideration).
     * @param fulfillmentComponents An array designating item components to
     *                              aggregate if part of an available order.
     * @param fulfillerConduitKey   A bytes32 value indicating what conduit, if
     *                              any, to source the fulfiller's token
     *                              approvals from. The zero hash signifies that
     *                              no conduit should be used, with approvals
     *                              set directly on this contract.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateAvailable(
        AdvancedOrder[] memory advancedOrders,
        Side side,
        FulfillmentComponent[] memory fulfillmentComponents,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Skip overflow / underflow checks; conditions checked or unreachable.
        unchecked {
            // Retrieve advanced orders array length and place on the stack.
            uint256 totalOrders = advancedOrders.length;

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
                if (advancedOrders[orderIndex].numerator != 0) {
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
                // prettier-ignore
                return _aggregateValidFulfillmentOfferItems(
                    advancedOrders,
                    fulfillmentComponents,
                    nextComponentIndex - 1
                );
            } else {
                // Otherwise, fulfillment components are consideration
                // components. Return execution for aggregated items provided by
                // the fulfiller.
                // prettier-ignore
                return _aggregateConsiderationItems(
                    advancedOrders,
                    fulfillmentComponents,
                    nextComponentIndex - 1,
                    fulfillerConduitKey
                );
            }
        }
    }

    /**
     * @dev Internal pure function to aggregate a group of offer items using
     *      supplied directives on which component items are candidates for
     *      aggregation, skipping items on orders that are not available.
     *
     * @param advancedOrders  The orders to aggregate offer items from.
     * @param offerComponents An array of FulfillmentComponent structs
     *                        indicating the order index and item index of each
     *                        candidate offer item for aggregation.
     * @param startIndex      The initial order index to begin iteration on when
     *                        searching for offer items to aggregate.
     *
     * @return execution The aggregated offer items.
     */
    function _aggregateValidFulfillmentOfferItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory offerComponents,
        uint256 startIndex
    ) internal view returns (Execution memory execution) {
        // Declare a variable for the final aggregated item amount.
        uint256 amount;

        // Declare a variable indicating whether the aggregation is invalid.
        bool invalidFulfillment;

        // Utilize assembly in order to efficiently aggregate the items.
        assembly {
            // Retrieve fulfillment pointer from offer component & start index.
            let fulfillmentPtr := mload(
                add(add(offerComponents, 0x20), mul(startIndex, 0x20))
            )

            // Retrieve the order index using the fulfillment pointer.
            let orderIndex := mload(fulfillmentPtr)

            // Retrieve item index using an offset of the fulfillment pointer.
            let itemIndex := mload(
                add(fulfillmentPtr, Fulfillment_itemIndex_offset)
            )

            // Ensure that the order index is not out of range.
            invalidFulfillment := iszero(lt(orderIndex, mload(advancedOrders)))

            // Retrieve the initial order pointer from the order index.
            let orderPtr := mload(
                mload(
                    add(
                        // Calculate pointer to start of advancedOrders head.
                        add(advancedOrders, 0x20),
                        // Calculate offset to pointer for desired order.
                        mul(orderIndex, 0x20)
                    )
                )
            )
            // Retrieve offer array pointer using offset of the order pointer.
            let offerArrPtr := mload(
                add(orderPtr, OrderParameters_offer_head_offset)
            )

            // Ensure that the item index is not out of range.
            invalidFulfillment := or(
                iszero(lt(itemIndex, mload(offerArrPtr))),
                invalidFulfillment
            )

            // Retrieve the offer item pointer using offset of the item index.
            let offerItemPtr := mload(
                add(
                    // Get pointer to beginning of OfferItem.
                    add(offerArrPtr, 0x20),
                    // Calculate offset to pointer for desired order.
                    mul(itemIndex, 0x20)
                )
            )

            // Retrieve the received item pointer.
            let receivedItemPtr := mload(execution)

            // Set itemType located at the offerItem pointer on receivedItem.
            mstore(receivedItemPtr, mload(offerItemPtr))

            // Set token located at offset of offerItem pointer on receivedItem.
            mstore(
                add(receivedItemPtr, Common_token_offset),
                mload(add(offerItemPtr, Common_token_offset))
            )

            // Set identifier located at offset of offerItem pointer as well.
            mstore(
                add(receivedItemPtr, 0x40),
                mload(add(offerItemPtr, Common_identifier_offset))
            )

            // Set amount on received item and additionaly place on the stack.
            let amountPtr := add(offerItemPtr, Common_amount_offset)
            amount := mload(amountPtr)

            // Set the caller as the recipient on the received item.
            mstore(
                add(receivedItemPtr, ReceivedItem_recipient_offset),
                caller()
            )

            // Zero out amount on original offerItem to indicate it is spent.
            mstore(amountPtr, 0)

            // Set the offerer on returned execution using order pointer.
            mstore(add(execution, Execution_offerer_offset), mload(orderPtr))

            // Set conduitKey on returned execution via offset of order pointer.
            mstore(
                add(execution, Execution_conduit_offset),
                mload(add(orderPtr, OrderParameters_conduit_offset))
            )
        }

        // Declare new assembly scope to avoid stack too deep errors.
        assembly {
            // Retrieve the received item pointer using the execution.
            let receivedItemPtr := mload(execution)

            // Iterate over offer components as long as fulfillment is valid.
            // prettier-ignore
            for {
                let i := add(startIndex, 1)
            } and(iszero(invalidFulfillment), lt(i, mload(offerComponents))) {
                i := add(i, 1)
            } {
                // Retrieve fulfillment pointer for the current offer component.
                let fulfillmentPtr := mload(
                    add(add(offerComponents, 0x20), mul(i, 0x20))
                )

                // Retrieve the order index using the fulfillment pointer.
                let orderIndex := mload(fulfillmentPtr)

                // Retrieve the item index using offset of fulfillment pointer.
                let itemIndex := mload(
                    add(fulfillmentPtr, Fulfillment_itemIndex_offset)
                )

                // Ensure that the order index is in range.
                invalidFulfillment := iszero(
                    lt(orderIndex, mload(advancedOrders))
                )

                // Exit iteration if it is out of range.
                if invalidFulfillment {
                    break
                }

                // Retrieve the order pointer using the order index. Note that
                // advancedOrders[orderIndex].OrderParameters pointer is first
                // word of AdvancedOrder struct, so mload again in a moment.
                let orderPtr := mload(
                    add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
                )

                // If the order is available (i.e. has a numerator != 0)...
                if mload(add(orderPtr, AdvancedOrder_numerator_offset)) {
                    // Retrieve the order pointer (i.e. the second mload).
                    orderPtr := mload(orderPtr)

                    // Load offer item array pointer.
                    let offerArrPtr := mload(
                        add(orderPtr, OrderParameters_offer_head_offset)
                    )

                    // Ensure that the offer item index is in range.
                    invalidFulfillment := iszero(
                        lt(itemIndex, mload(offerArrPtr))
                    )

                    // Exit iteration if it is out of range.
                    if invalidFulfillment {
                        break
                    }

                    // Retrieve the offer item pointer using the item index.
                    let offerItemPtr := mload(
                        add(
                            // Get pointer to beginning of OfferItem
                            add(offerArrPtr, 0x20),
                            // Calculate offset to pointer for desired order
                            mul(itemIndex, 0x20)
                        )
                    )

                    // Retrieve the amount using the offer item pointer.
                    let amountPtr := add(offerItemPtr, Common_amount_offset)

                    // Increment the amount.
                    amount := add(amount, mload(amountPtr))

                    // Zero out amount on original item to indicate it is spent.
                    mstore(amountPtr, 0)

                    // Ensure the indicated offer item matches original item.
                    invalidFulfillment := iszero(
                        and(
                            // The identifier must match on both items.
                            eq(
                                mload(
                                    add(offerItemPtr, Common_identifier_offset)
                                ),
                                mload(
                                    add(
                                        receivedItemPtr,
                                        Common_identifier_offset
                                    )
                                )
                            ),
                            and(
                                and(
                                    // The offerer must match on both items.
                                    eq(
                                        mload(orderPtr),
                                        mload(
                                            add(execution, Common_token_offset)
                                        )
                                    ),
                                    // The conduit key must match on both items.
                                    eq(
                                        mload(
                                            add(
                                                orderPtr,
                                                OrderParameters_conduit_offset
                                            )
                                        ),
                                        mload(
                                            add(
                                                execution,
                                                Execution_conduit_offset
                                            )
                                        )
                                    )
                                ),
                                and(
                                    // The item type must match on both items.
                                    eq(
                                        mload(offerItemPtr),
                                        mload(receivedItemPtr)
                                    ),
                                    // The token must match on both items.
                                    eq(
                                        mload(
                                            add(
                                                offerItemPtr,
                                                Common_token_offset
                                            )
                                        ),
                                        mload(
                                            add(
                                                receivedItemPtr,
                                                Common_token_offset
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                }
            }

            // Update the final amount on the returned received item.
            mstore(add(receivedItemPtr, Common_amount_offset), amount)
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
     * @param advancedOrders          The orders to aggregate.
     * @param considerationComponents An array designating consideration
     *                                components to aggregate if part of an
     *                                available order.
     * @param nextComponentIndex      The index of the next potential
     *                                consideration component.
     * @param fulfillerConduitKey     A bytes32 value indicating what conduit,
     *                                if any, to source the fulfiller's token
     *                                approvals from. The zero hash signifies
     *                                that no conduit should be used, with
     *                                approvals set directly on this contract.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateConsiderationItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory considerationComponents,
        uint256 nextComponentIndex,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Validate and aggregate consideration items on available orders and
        // store result as a ReceivedItem.
        ReceivedItem memory receiveConsiderationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                advancedOrders,
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
        // Declare a variable indicating whether the aggregation is invalid.
        bool invalidFulfillment;

        // Utilize assembly in order to efficiently aggregate the items.
        assembly {
            // Retrieve the length of the orders array.
            let totalOrders := mload(advancedOrders)

            // Begin iteration at the indicated start index.
            let i := startIndex

            // Get fulfillment ptr from consideration component & start index.
            let fulfillmentPtr := mload(
                add(add(considerationComponents, 0x20), mul(i, 0x20))
            )

            // Retrieve the order index using the fulfillment pointer.
            let orderIndex := mload(fulfillmentPtr)

            // Retrieve item index using an offset of the fulfillment pointer.
            let itemIndex := mload(add(fulfillmentPtr, 0x20))

            // Ensure that the order index is not out of range.
            invalidFulfillment := iszero(lt(orderIndex, totalOrders))

            // Only continue if the fulfillment is not invalid.
            if iszero(invalidFulfillment) {
                // Calculate pointer to AdvancedOrder element at
                // advancedOrders[orderIndex].OrderParameters pointer is first
                // word of AdvancedOrder struct, so we mload twice.
                let orderPtr := mload(
                    // Read the pointer to advancedOrders[orderIndex] from its
                    // head in the array.
                    mload(
                        // Calculate head position of advancedOrders[orderIndex]
                        add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
                    )
                )

                // Load consideration array pointer.
                let considerationArrPtr := mload(
                    add(orderPtr, OrderParameters_consideration_head_offset)
                )

                // Check if itemIndex is within the range of the array.
                invalidFulfillment := iszero(
                    lt(itemIndex, mload(considerationArrPtr))
                )

                // Only continue if the fulfillment is not invalid.
                if iszero(invalidFulfillment) {
                    // Retrieve consideration item pointer using the item index.
                    let considerationItemPtr := mload(
                        add(
                            // Get pointer to beginning of receivedItem.
                            add(considerationArrPtr, 0x20),
                            // Calculate offset to pointer for desired order.
                            mul(itemIndex, 0x20)
                        )
                    )

                    // Set the item type on the received item.
                    mstore(receivedItem, mload(considerationItemPtr))

                    // Set the token on the received item.
                    mstore(
                        add(receivedItem, Common_token_offset),
                        mload(add(considerationItemPtr, Common_token_offset))
                    )

                    // Set the identifier on the received item.
                    mstore(
                        add(receivedItem, Common_identifier_offset),
                        mload(
                            add(considerationItemPtr, Common_identifier_offset)
                        )
                    )

                    // Retrieve amount pointer using consideration item pointer.
                    let amountPtr := add(
                        considerationItemPtr,
                        Common_amount_offset
                    )
                    // Set the amount.
                    mstore(
                        add(receivedItem, Common_amount_offset),
                        mload(amountPtr)
                    )

                    // Zero out amount on item to indicate it is credited.
                    mstore(amountPtr, 0)

                    // Set the recipient.
                    mstore(
                        add(receivedItem, ReceivedItem_recipient_offset),
                        mload(
                            add(
                                considerationItemPtr,
                                ConsiderationItem_recipient_offset
                            )
                        )
                    )

                    // Increment the iterator.
                    i := add(i, 1)

                    // Iterate over remaining consideration components.
                    // prettier-ignore
                    for {} lt(i, mload(considerationComponents)) {
                        i := add(i, 1)
                    } {
                        // Retrieve the fulfillment pointer.
                        fulfillmentPtr := mload(
                            add(
                                add(considerationComponents, 0x20),
                                mul(i, 0x20)
                            )
                        )

                        // Get the order index using the fulfillment pointer.
                        orderIndex := mload(fulfillmentPtr)

                        // Get the item index using the fulfillment pointer.
                        itemIndex := mload(add(fulfillmentPtr, 0x20))

                        // Ensure the order index is in range.
                        invalidFulfillment := iszero(
                            lt(orderIndex, totalOrders)
                        )

                        // Exit iteration if order index is not in range.
                        if invalidFulfillment {
                            break
                        }
                        // Get pointer to AdvancedOrder element. The pointer
                        // will be reused as the pointer to OrderParameters.
                        orderPtr := mload(
                            add(
                                add(advancedOrders, 0x20),
                                mul(orderIndex, 0x20)
                            )
                        )

                        // Only continue if numerator is not zero.
                        if mload(
                            add(orderPtr, AdvancedOrder_numerator_offset)
                        ) {
                            // First word of AdvancedOrder is pointer to
                            // OrderParameters.
                            orderPtr := mload(orderPtr)

                            // Load consideration array pointer.
                            considerationArrPtr := mload(
                                add(
                                    orderPtr,
                                    OrderParameters_consideration_head_offset
                                )
                            )

                            // Check if itemIndex is within the range of array.
                            invalidFulfillment := iszero(
                                lt(itemIndex, mload(considerationArrPtr))
                            )

                            // Exit iteration if item index is not in range.
                            if invalidFulfillment {
                                break
                            }

                            // Retrieve consideration item pointer using index.
                            considerationItemPtr := mload(
                                add(
                                    // Get pointer to beginning of receivedItem.
                                    add(considerationArrPtr, 0x20),
                                    // Use offset to pointer for desired order.
                                    mul(itemIndex, 0x20)
                                )
                            )

                            // Retrieve amount pointer using consideration item
                            // pointer.
                            amountPtr := add(
                                considerationItemPtr,
                                Common_amount_offset
                            )

                            // Increment the amount on the received item.
                            mstore(
                                add(receivedItem, Common_amount_offset),
                                add(
                                    mload(
                                        add(receivedItem, Common_amount_offset)
                                    ),
                                    mload(amountPtr)
                                )
                            )

                            // Zero out amount on original item to indicate it
                            // is credited.
                            mstore(amountPtr, 0)

                            // Ensure the indicated item matches original item.
                            invalidFulfillment := iszero(
                                and(
                                    // Item recipients must match.
                                    eq(
                                        mload(
                                            add(
                                                considerationItemPtr,
                                                ConsiderItem_recipient_offset
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
                                        // Item types must match.
                                        eq(
                                            mload(considerationItemPtr),
                                            mload(receivedItem)
                                        ),
                                        and(
                                            // Item tokens must match.
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
                                            // Item identifiers must match.
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

                            // Exit iteration if items do not match.
                            if invalidFulfillment {
                                break
                            }
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
}
