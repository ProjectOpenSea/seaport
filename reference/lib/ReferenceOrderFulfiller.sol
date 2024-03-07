// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    AccumulatorStruct,
    FractionData,
    OrderToExecute,
    OrderValidation
} from "./ReferenceConsiderationStructs.sol";

import {
    ReferenceBasicOrderFulfiller
} from "./ReferenceBasicOrderFulfiller.sol";

import { ReferenceCriteriaResolution } from "./ReferenceCriteriaResolution.sol";

import { ReferenceAmountDeriver } from "./ReferenceAmountDeriver.sol";

/**
 * @title OrderFulfiller
 * @author 0age
 * @notice OrderFulfiller contains logic related to order fulfillment.
 */
contract ReferenceOrderFulfiller is
    ReferenceBasicOrderFulfiller,
    ReferenceCriteriaResolution,
    ReferenceAmountDeriver
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
    ) ReferenceBasicOrderFulfiller(conduitController) {}

    /**
     * @dev Internal function to validate an order and update its status, adjust
     *      prices based on current time, apply criteria resolvers, determine
     *      what portion to fill, and transfer relevant tokens.
     *
     * @param advancedOrder       The order to fulfill as well as the fraction
     *                            to fill. Note that all offer and consideration
     *                            components must divide with no remainder for
     *                            the partial fill to be valid.
     * @param criteriaResolvers   An array where each element contains a
     *                            reference to a specific offer or
     *                            consideration, a token identifier, and a proof
     *                            that the supplied token identifier is
     *                            contained in the order's merkle root. Note
     *                            that a criteria of zero indicates that any
     *                            (transferable) token identifier is valid and
     *                            that no proof needs to be supplied.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration).
     * @param recipient           The intended recipient for all received items.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) internal returns (bool) {
        // Validate the order and revert if it's invalid.
        OrderValidation memory orderValidation = _validateOrder(
            advancedOrder,
            true
        );

        // Apply criteria resolvers using generated orders and details arrays.
        _applyCriteriaResolversAdvanced(advancedOrder, criteriaResolvers);

        // Retrieve the order parameters after applying criteria resolvers.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Perform each item transfer with the appropriate fractional amount.
        orderValidation.orderToExecute = _applyFractions(
            orderParameters,
            orderValidation.newNumerator,
            orderValidation.newDenominator
        );

        // Declare empty bytes32 array.
        bytes32[] memory priorOrderHashes = new bytes32[](0);

        if (orderParameters.orderType != OrderType.CONTRACT) {
            // Ensure restricted orders have valid submitter or pass zone check.
            _assertRestrictedAdvancedOrderAuthorization(
                advancedOrder,
                orderValidation.orderToExecute,
                priorOrderHashes,
                orderValidation.orderHash,
                orderParameters.zoneHash,
                orderParameters.orderType,
                orderParameters.offerer,
                orderParameters.zone
            );

            // Update the order status to reflect the new numerator and denominator.
            // Revert if the order is not valid.
            _updateStatus(
                orderValidation.orderHash,
                orderValidation.newNumerator,
                orderValidation.newDenominator,
                true
            );
        } else {
            bytes32 orderHash = _getGeneratedOrder(
                orderValidation.orderToExecute,
                advancedOrder.parameters,
                advancedOrder.extraData,
                true
            );

            orderValidation.orderHash = orderHash;
        }

        // Transfer each item contained in the order.
        _transferEach(
            orderParameters,
            orderValidation.orderToExecute,
            fulfillerConduitKey,
            recipient
        );

        // Declare bytes32 array with this order's hash
        priorOrderHashes = new bytes32[](1);
        priorOrderHashes[0] = orderValidation.orderHash;

        // Ensure restricted orders have valid submitter or pass zone check.
        _assertRestrictedAdvancedOrderValidity(
            advancedOrder,
            orderValidation.orderToExecute,
            priorOrderHashes,
            orderValidation.orderHash,
            orderParameters.zoneHash,
            orderParameters.orderType,
            orderParameters.offerer,
            orderParameters.zone
        );

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderValidation.orderHash,
            orderParameters.offerer,
            orderParameters.zone,
            recipient,
            orderValidation.orderToExecute.spentItems,
            orderValidation.orderToExecute.receivedItems
        );

        return true;
    }

    /**
     * @dev Internal view function to apply a respective fraction to the
     *      amount being transferred on each item of an order.
     *
     * @param orderParameters     The parameters for the fulfilled order.
     * @param numerator           A value indicating the portion of the order
     *                            that should be filled.
     * @param denominator         A value indicating the total order size.
     * @return orderToExecute     Returns the order with items that are being
     *                            transferred. This will be used for the
     *                            OrderFulfilled Event.
     */
    function _applyFractions(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (OrderToExecute memory orderToExecute) {
        // Derive order duration, time elapsed, and time remaining.
        // Store in memory to avoid stack too deep issues.
        FractionData memory fractionData = FractionData(
            numerator,
            denominator,
            0, // fulfillerConduitKey is not used here.
            orderParameters.startTime,
            orderParameters.endTime
        );

        // Create the array to store the spent items for event.
        orderToExecute.spentItems = (
            new SpentItem[](orderParameters.offer.length)
        );

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each offer on the order.
            for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
                // Retrieve the offer item.
                OfferItem memory offerItem = orderParameters.offer[i];

                // Offer items for the native token can not be received outside
                // of a match order function except as part of a contract order.
                if (
                    offerItem.itemType == ItemType.NATIVE &&
                    orderParameters.orderType != OrderType.CONTRACT
                ) {
                    revert InvalidNativeOfferItem();
                }

                // Apply fill fraction to derive offer item amount to transfer.
                uint256 amount = _applyFraction(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    fractionData,
                    false
                );

                // Create Spent Item for the OrderFulfilled event.
                orderToExecute.spentItems[i] = SpentItem(
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    amount
                );
            }
        }

        // Create the array to store the received items for event.
        orderToExecute.receivedItems = (
            new ReceivedItem[](orderParameters.consideration.length)
        );

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < orderParameters.consideration.length; ++i) {
                // Retrieve the consideration item.
                ConsiderationItem memory considerationItem = (
                    orderParameters.consideration[i]
                );

                // Apply fraction & derive considerationItem amount to transfer.
                uint256 amount = _applyFraction(
                    considerationItem.startAmount,
                    considerationItem.endAmount,
                    fractionData,
                    true
                );

                // Create Received Item from Offer item & add to structs array.
                orderToExecute.receivedItems[i] = ReceivedItem(
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    amount,
                    considerationItem.recipient
                );
            }
        }

        // Return the order to execute.
        return orderToExecute;
    }

    /**
     * @dev Internal function to transfer each item contained in a given single
     *      order fulfillment.
     *
     * @param orderParameters     The parameters for the fulfilled order.
     * @param orderToExecute      The items that are being transferred.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration).
     * @param recipient           The intended recipient for all received items.
     */
    function _transferEach(
        OrderParameters memory orderParameters,
        OrderToExecute memory orderToExecute,
        bytes32 fulfillerConduitKey,
        address recipient
    ) internal {
        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        // Get the offerer of the order.
        address offerer = orderParameters.offerer;

        // Get the conduitKey of the order
        bytes32 conduitKey = orderParameters.conduitKey;

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each spent item on the order.
            for (uint256 i = 0; i < orderToExecute.spentItems.length; ++i) {
                // Retrieve the spent item.
                SpentItem memory spentItem = orderToExecute.spentItems[i];

                // Create Received Item from Spent Item for transfer.
                ReceivedItem memory receivedItem = ReceivedItem(
                    spentItem.itemType,
                    spentItem.token,
                    spentItem.identifier,
                    spentItem.amount,
                    payable(recipient)
                );

                // Transfer the item from the offerer to the recipient.
                _transfer(receivedItem, offerer, conduitKey, accumulatorStruct);
            }
        }

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each received item on the order.
            for (uint256 i = 0; i < orderToExecute.receivedItems.length; ++i) {
                // Retrieve the received item.
                ReceivedItem memory receivedItem = (
                    orderToExecute.receivedItems[i]
                );

                if (receivedItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (receivedItem.amount > address(this).balance) {
                        revert InsufficientNativeTokensSupplied();
                    }
                }

                // Transfer item from caller to recipient specified by the item.
                _transfer(
                    receivedItem,
                    msg.sender,
                    fulfillerConduitKey,
                    accumulatorStruct
                );
            }
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // If any native tokens remain after applying fulfillments...
        if (address(this).balance != 0) {
            // return them to the caller.
            _transferNativeTokens(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @dev Internal pure function to convert an order to an advanced order with
     *      numerator and denominator of 1 and empty extraData.
     *
     * @param order The order to convert.
     *
     * @return advancedOrder The new advanced order.
     */
    function _convertOrderToAdvanced(
        Order calldata order
    ) internal pure returns (AdvancedOrder memory advancedOrder) {
        // Convert to partial order (1/1 or full fill) and return new value.
        advancedOrder = AdvancedOrder(
            order.parameters,
            1,
            1,
            order.signature,
            ""
        );
    }

    /**
     * @dev Internal pure function to convert an array of orders to an array of
     *      advanced orders with numerator and denominator of 1.
     *
     * @param orders The orders to convert.
     *
     * @return advancedOrders The new array of partial orders.
     */
    function _convertOrdersToAdvanced(
        Order[] calldata orders
    ) internal pure returns (AdvancedOrder[] memory advancedOrders) {
        // Read the number of orders from calldata and place on the stack.
        uint256 totalOrders = orders.length;

        // Allocate new empty array for each partial order in memory.
        advancedOrders = new AdvancedOrder[](totalOrders);

        // Iterate over the given orders.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Convert to partial order (1/1 or full fill) and update array.
            advancedOrders[i] = _convertOrderToAdvanced(orders[i]);
        }

        // Return the array of advanced orders.
        return advancedOrders;
    }
}
