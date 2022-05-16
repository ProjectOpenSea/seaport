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

        Execution memory considerationExecution;
        // Validate & aggregate consideration items to Execution object.
        _aggregateValidFulfillmentConsiderationItems(
            advancedOrders,
            considerationComponents,
            considerationExecution
        );
        ReceivedItem memory considerationItem = considerationExecution.item;

        // Validate & aggregate offer items to Execution object.
        _aggregateValidFulfillmentOfferItems(
            advancedOrders,
            offerComponents,
            execution
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
            // Retrieve fulfillment components array length and place on stack.
            // Ensure at least one fulfillment component has been supplied.
            if (fulfillmentComponents.length == 0) {
                revert MissingFulfillmentComponentOnAggregation(side);
            }

            // If the fulfillment components are offer components...
            if (side == Side.OFFER) {
                // Return execution for aggregated items provided by offerer.
                // prettier-ignore
                _aggregateValidFulfillmentOfferItems(
                    advancedOrders,
                    fulfillmentComponents,
                    execution
                );
            } else {
                // Otherwise, fulfillment components are consideration
                // components. Return execution for aggregated items provided by
                // the fulfiller.
                // prettier-ignore
                _aggregateValidFulfillmentConsiderationItems(
                    advancedOrders,
                    fulfillmentComponents,
                    execution
                );
                execution.offerer = msg.sender;
                execution.conduitKey = fulfillerConduitKey;
            }
            if (execution.item.amount == 0) {
                execution.item.recipient = payable(execution.offerer);
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
     * @param execution       The execution to apply the aggregation to.
     */
    function _aggregateValidFulfillmentOfferItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory offerComponents,
        Execution memory execution
    ) internal view {
        // Declare a variable for the final aggregated item amount.
        uint256 amount;
        // uint g1 = gasleft();

        // Declare a variable indicating whether the aggregation is invalid.
        // bool invalidFulfillment;

        assembly {
            function throwInvalidFulfillmentComponentData() {
                mstore(0, InvalidFulfillmentComponentData_error_signature)
                revert(0x1c, InvalidFulfillmentComponentData_error_len)
            }

            // Get position in offerComponents head
            let fulfillmentHeadPtr := add(offerComponents, 0x20)

            // Retrieve the order index using the fulfillment pointer.
            let orderIndex := mload(mload(fulfillmentHeadPtr))

            // Ensure that the order index is not out of range.
            if iszero(lt(orderIndex, mload(advancedOrders))) {
                throwInvalidFulfillmentComponentData()
            }

            // Read the pointer to advancedOrders[orderIndex] from its
            // head in the array.
            let orderPtr := mload(
                // Calculate head position of advancedOrders[orderIndex]
                add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
            )

            // Read the pointer to OrderParameters from the AdvancedOrder
            let paramsPtr := mload(orderPtr)

            // Load offer array pointer.
            let offerArrPtr := mload(
                add(paramsPtr, OrderParameters_offer_head_offset)
            )

            // Retrieve item index using an offset of the fulfillment pointer.
            let itemIndex := mload(
                add(mload(fulfillmentHeadPtr), Fulfillment_itemIndex_offset)
            )

            // Only continue if the fulfillment is not invalid.
            if iszero(lt(itemIndex, mload(offerArrPtr))) {
                throwInvalidFulfillmentComponentData()
            }
            // Retrieve consideration item pointer using the item index.
            let offerItemPtr := mload(
                add(
                    // Get pointer to beginning of receivedItem.
                    add(offerArrPtr, 0x20),
                    // Calculate offset to pointer for desired order.
                    mul(itemIndex, 0x20)
                )
            )

            // Only add offer amount to execution amount if numerator
            // is greater than zero
            if mload(add(orderPtr, AdvancedOrder_numerator_offset)) {
                // Retrieve amount pointer using consideration item pointer.
                let amountPtr := add(offerItemPtr, Common_amount_offset)
                // Set the amount.
                amount := mload(amountPtr)
                // Zero out amount on item to indicate it is credited.
                mstore(amountPtr, 0)
            }

            // Retrieve the received item pointer.
            let receivedItemPtr := mload(execution)

            // Set the caller as the recipient on the received item.
            mstore(
                add(receivedItemPtr, ReceivedItem_recipient_offset),
                caller()
            )

            // Set the item type on the received item.
            mstore(receivedItemPtr, mload(offerItemPtr))

            // Set the token on the received item.
            mstore(
                add(receivedItemPtr, Common_token_offset),
                mload(add(offerItemPtr, Common_token_offset))
            )

            // Set the identifier on the received item.
            mstore(
                add(receivedItemPtr, Common_identifier_offset),
                mload(add(offerItemPtr, Common_identifier_offset))
            )

            // Set the offerer on returned execution using order pointer.
            mstore(add(execution, Execution_offerer_offset), mload(paramsPtr))

            // Set conduitKey on returned execution via offset of order pointer.
            mstore(
                add(execution, Execution_conduit_offset),
                mload(add(paramsPtr, OrderParameters_conduit_offset))
            )

            // Calculate the hash of (itemType, token, identifier)
            let dataHash := keccak256(
                receivedItemPtr,
                ReceivedItem_CommonParams_size
            )

            // Get position one word past last element in head of array
            let endPtr := add(
                offerComponents,
                mul(mload(offerComponents), 0x20)
            )

            // Buffer indicating whether issues were found
            let errorBuffer := iszero(amount)

            // Iterate over remaining offer components.
            // prettier-ignore
            for {} lt(fulfillmentHeadPtr,  endPtr) {} {
                fulfillmentHeadPtr := add(fulfillmentHeadPtr, 0x20)

                // Get the order index using the fulfillment pointer.
                orderIndex := mload(mload(fulfillmentHeadPtr))

                // Ensure the order index is in range.
                if iszero(lt(orderIndex, mload(advancedOrders))) {
                  throwInvalidFulfillmentComponentData()
                }

                // Get pointer to AdvancedOrder element.
                orderPtr := mload(
                    add(
                        add(advancedOrders, 0x20),
                        mul(orderIndex, 0x20)
                    )
                )

                // Only continue if numerator is not zero.
                if iszero(mload(
                    add(orderPtr, AdvancedOrder_numerator_offset)
                )) {
                  continue
                }

                // Read the pointer to OrderParameters from the AdvancedOrder
                paramsPtr := mload(orderPtr)

                // Load offer array pointer.
                offerArrPtr := mload(
                    add(
                        paramsPtr,
                        OrderParameters_offer_head_offset
                    )
                )

                // Get the item index using the fulfillment pointer.
                itemIndex := mload(add(mload(fulfillmentHeadPtr), 0x20))

                // Throw if itemIndex is out of the range of array.
                if iszero(
                    lt(itemIndex, mload(offerArrPtr))
                ) {
                    throwInvalidFulfillmentComponentData()
                }

                // Retrieve offer item pointer using index.
                offerItemPtr := mload(
                    add(
                        // Get pointer to beginning of receivedItem.
                        add(offerArrPtr, 0x20),
                        // Use offset to pointer for desired order.
                        mul(itemIndex, 0x20)
                    )
                )

                // Retrieve amount pointer using offer item pointer.
                let amountPtr := add(
                      offerItemPtr,
                      Common_amount_offset
                )

                // Add offer amount to execution amount
                let newAmount := add(amount, mload(amountPtr))

                // Update error buffer. 1 = zero amount, 2 = overflow
                errorBuffer := or(
                  errorBuffer,
                  or(
                    shl(1, lt(newAmount, amount)),
                    iszero(mload(amountPtr))
                  )
                )

                // Update sum
                amount := newAmount

                // Zero out amount on original item to indicate it
                // is credited.
                mstore(amountPtr, 0)

                // Ensure the indicated item matches original item.
                if iszero(
                    and(
                        and(
                          // The offerer must match on both items.
                          eq(
                              mload(paramsPtr),
                              mload(
                                  add(execution, Execution_offerer_offset)
                              )
                          ),
                          // The conduit key must match on both items.
                          eq(
                              mload(
                                  add(
                                      paramsPtr,
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
                        // itemType, token, identifier must match
                        eq(
                          dataHash,
                          keccak256(offerItemPtr, ReceivedItem_CommonParams_size)
                        )
                    )
                ) {
                  throwInvalidFulfillmentComponentData()
                }
            }
            // Write final amount to execution
            mstore(add(mload(execution), Common_amount_offset), amount)

            switch errorBuffer
            case 1 {
              // change to MissingItemAmount
              throwInvalidFulfillmentComponentData()
            }
            case 2 {
            // If the sum overflowed, panic
              mstore(0, 0x11)
              revert(0, 0x20)
            }
        }
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
     * @param execution       The execution to apply the aggregation to.
     */
    function _aggregateValidFulfillmentConsiderationItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory considerationComponents,
        Execution memory execution
    ) internal pure {
        // Utilize assembly in order to efficiently aggregate the items.
        assembly {
            function throwInvalidFulfillmentComponentData() {
                mstore(0, InvalidFulfillmentComponentData_error_signature)
                revert(0x1c, InvalidFulfillmentComponentData_error_len)
            }

            let amount := 0

            // Get position in considerationComponents head
            let fulfillmentHeadPtr := add(considerationComponents, 0x20)

            // Retrieve the order index using the fulfillment pointer.
            let orderIndex := mload(mload(fulfillmentHeadPtr))

            // Ensure that the order index is not out of range.
            if iszero(lt(orderIndex, mload(advancedOrders))) {
                throwInvalidFulfillmentComponentData()
            }

            // Read the pointer to advancedOrders[orderIndex] from its
            // head in the array.
            let orderPtr := mload(
                // Calculate head position of advancedOrders[orderIndex]
                add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
            )

            // Load consideration array pointer.
            let considerationArrPtr := mload(
                add(
                  // Read the pointer to OrderParameters from the AdvancedOrder
                  mload(orderPtr),
                  OrderParameters_consideration_head_offset
                )
            )

            // Retrieve item index using an offset of the fulfillment pointer.
            let itemIndex := mload(
                add(mload(fulfillmentHeadPtr), Fulfillment_itemIndex_offset)
            )

            // Ensure that the order index is not out of range.
            if iszero(lt(itemIndex, mload(considerationArrPtr))) {
                throwInvalidFulfillmentComponentData()
            }

            // Retrieve consideration item pointer using the item index.
            let considerationItemPtr := mload(
                add(
                    // Get pointer to beginning of receivedItem.
                    add(considerationArrPtr, 0x20),
                    // Calculate offset to pointer for desired order.
                    mul(itemIndex, 0x20)
                )
            )

            // Only add consideration amount to execution amount if numerator
            // is greater than zero
            if mload(add(orderPtr, AdvancedOrder_numerator_offset)) {
                // Retrieve amount pointer using consideration item pointer.
                let amountPtr := add(considerationItemPtr, Common_amount_offset)
                // Set the amount.
                amount := mload(amountPtr)
                // Zero out amount on item to indicate it is credited.
                mstore(amountPtr, 0)
            }

            // Retrieve ReceivedItem pointer from Execution
            let receivedItem := mload(execution)

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
                mload(add(considerationItemPtr, Common_identifier_offset))
            )

            // Set the recipient on the received item.
            mstore(
                add(receivedItem, ReceivedItem_recipient_offset),
                mload(
                    add(
                        considerationItemPtr,
                        ConsiderationItem_recipient_offset
                    )
                )
            )

            // Calculate the hash of (itemType, token, identifier)
            let dataHash := keccak256(
                receivedItem,
                ReceivedItem_CommonParams_size
            )

            // Get position one word past last element in head of array
            let endPtr := add(
                considerationComponents,
                mul(mload(considerationComponents), 0x20)
            )

            let errorBuffer := iszero(amount)

            // Iterate over remaining offer components.
            // prettier-ignore
            for {} lt(fulfillmentHeadPtr,  endPtr) {} {
                // Increment position in considerationComponents head
                fulfillmentHeadPtr := add(fulfillmentHeadPtr, 0x20)

                // Get the order index using the fulfillment pointer.
                orderIndex := mload(mload(fulfillmentHeadPtr))

                // Ensure the order index is in range.
                if iszero(lt(orderIndex, mload(advancedOrders))) {
                  throwInvalidFulfillmentComponentData()
                }

                // Get pointer to AdvancedOrder element.
                orderPtr := mload(
                    add(
                        add(advancedOrders, 0x20),
                        mul(orderIndex, 0x20)
                    )
                )

                // Don't handle fulfillment if numerator is 0
                if iszero(mload(add(orderPtr, AdvancedOrder_numerator_offset))) {
                  continue
                }

                // Load consideration array pointer from OrderParameters.
                considerationArrPtr := mload(
                    add(
                        // Get pointer to OrderParameters from AdvancedOrder.
                        mload(orderPtr),
                        OrderParameters_consideration_head_offset
                    )
                )

                // Get the item index using the fulfillment pointer.
                itemIndex := mload(add(mload(fulfillmentHeadPtr), 0x20))

                // Check if itemIndex is within the range of array.
                if iszero(lt(itemIndex, mload(considerationArrPtr))) {
                    throwInvalidFulfillmentComponentData()
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

                // Retrieve amount pointer using consideration item pointer.
                let amountPtr := add(
                      considerationItemPtr,
                      Common_amount_offset
                )

                // Add offer amount to execution amount
                let newAmount := add(amount, mload(amountPtr))

                // Zero out amount on original item to indicate it
                // is credited.
                mstore(amountPtr, 0)

                // Check if addition overflows
                errorBuffer := or(
                  errorBuffer,
                  or(
                    shl(1, lt(newAmount, amount)),
                    iszero(mload(amountPtr))
                  )
                )

                // Update sum
                amount := newAmount

                // Ensure the indicated item matches original item.
                if iszero(
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
                        // itemType, token, identifier must match
                        eq(
                          dataHash,
                          keccak256(considerationItemPtr, ReceivedItem_CommonParams_size)
                        )
                    )
                ) {
                    throwInvalidFulfillmentComponentData()
                }
            }
            // Write final amount to execution
            mstore(add(receivedItem, Common_amount_offset), amount)

            switch errorBuffer
            case 1 {
              // change to MissingItemAmount
              throwInvalidFulfillmentComponentData()
            }
            case 2 {
            // If the sum overflowed, panic
              mstore(0, 0x11)
              revert(0, 0x20)
            }
        }
    }
}
