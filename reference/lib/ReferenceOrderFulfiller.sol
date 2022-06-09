// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { OrderType, ItemType } from "contracts/lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Order,
    AdvancedOrder,
    CriteriaResolver
} from "contracts/lib/ConsiderationStructs.sol";

// prettier-ignore
import { 
    AccumulatorStruct,
    FractionData, 
    OrderToExecute
} from "./ReferenceConsiderationStructs.sol";

import { ReferenceBasicOrderFulfiller } from "./ReferenceBasicOrderFulfiller.sol";

import { ReferenceCriteriaResolution } from "./ReferenceCriteriaResolution.sol";

import { ReferenceAmountDeriver } from "./ReferenceAmountDeriver.sol";

import "contracts/lib/ConsiderationConstants.sol";

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
    constructor(address conduitController)
        ReferenceBasicOrderFulfiller(conduitController)
    {}

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
        // Declare empty bytes32 array (unused, will remain empty).
        bytes32[] memory priorOrderHashes;

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint256 fillNumerator,
            uint256 fillDenominator
        ) = _validateOrderAndUpdateStatus(
                advancedOrder,
                criteriaResolvers,
                true,
                priorOrderHashes
            );

        // Apply criteria resolvers using generated orders and details arrays.
        _applyCriteriaResolversAdvanced(advancedOrder, criteriaResolvers);

        // Retrieve the order parameters after applying criteria resolvers.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Perform each item transfer with the appropriate fractional amount.
        OrderToExecute memory orderToExecute = _applyFractionsAndTransferEach(
            orderParameters,
            fillNumerator,
            fillDenominator,
            fulfillerConduitKey,
            recipient
        );

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderHash,
            orderParameters.offerer,
            orderParameters.zone,
            recipient,
            orderToExecute.spentItems,
            orderToExecute.receivedItems
        );

        return true;
    }

    /**
     * @dev Internal function to transfer each item contained in a given single
     *      order fulfillment after applying a respective fraction to the amount
     *      being transferred.
     *
     * @param orderParameters     The parameters for the fulfilled order.
     * @param numerator           A value indicating the portion of the order
     *                            that should be filled.
     * @param denominator         A value indicating the total order size.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration).
     * @param recipient           The intended recipient for all received items.
     * @return orderToExecute     Returns the order of items that are being
     *                            transferred. This will be used for the
     *                            OrderFulfilled Event.
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        bytes32 fulfillerConduitKey,
        address recipient
    ) internal returns (OrderToExecute memory orderToExecute) {
        // Derive order duration, time elapsed, and time remaining.
        // Store in memory to avoid stack too deep issues.
        FractionData memory fractionData = FractionData(
            numerator,
            denominator,
            fulfillerConduitKey,
            orderParameters.startTime,
            orderParameters.endTime
        );

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        // Get the offerer of the order.
        address offerer = orderParameters.offerer;

        // Get the conduitKey of the order
        bytes32 conduitKey = orderParameters.conduitKey;

        // Create the array to store the spent items for event.
        orderToExecute.spentItems = new SpentItem[](
            orderParameters.offer.length
        );

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each offer on the order.
            for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
                // Retrieve the offer item.
                OfferItem memory offerItem = orderParameters.offer[i];

                // Apply fill fraction to derive offer item amount to transfer.
                uint256 amount = _applyFraction(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    fractionData,
                    false
                );

                // Create Received Item from Offer Item for transfer.
                ReceivedItem memory receivedItem = ReceivedItem(
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    amount,
                    payable(recipient)
                );

                // Create Spent Item for the OrderFulfilled event.
                orderToExecute.spentItems[i] = SpentItem(
                    receivedItem.itemType,
                    receivedItem.token,
                    receivedItem.identifier,
                    amount
                );

                // Reduce available value if offer spent ETH or a native token.
                if (receivedItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }
                    // Reduce ether remaining by amount.
                    etherRemaining -= amount;
                }

                // Transfer the item from the offerer to the recipient.
                _transfer(receivedItem, offerer, conduitKey, accumulatorStruct);
            }
        }

        // Create the array to store the received items for event.
        orderToExecute.receivedItems = new ReceivedItem[](
            orderParameters.consideration.length
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

                // Create Received Item from Offer item.
                ReceivedItem memory receivedItem = ReceivedItem(
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    amount,
                    considerationItem.recipient
                );
                // Add ReceivedItem to structs array.
                orderToExecute.receivedItems[i] = receivedItem;

                // Reduce available value if offer spent ETH or a native token.
                if (receivedItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }
                    // Reduce ether remaining by amount.
                    etherRemaining -= amount;
                }

                // Transfer item from caller to recipient specified by the item.
                _transfer(
                    receivedItem,
                    msg.sender,
                    fractionData.fulfillerConduitKey,
                    accumulatorStruct
                );
            }
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // If any ether remains after fulfillments...
        if (etherRemaining != 0) {
            // return it to the caller.
            _transferEth(payable(msg.sender), etherRemaining);
        }
        // Return the order to execute.
        return orderToExecute;
    }

    /**
     * @dev Internal pure function to convert an order to an advanced order with
     *      numerator and denominator of 1 and empty extraData.
     *
     * @param order The order to convert.
     *
     * @return advancedOrder The new advanced order.
     */
    function _convertOrderToAdvanced(Order calldata order)
        internal
        pure
        returns (AdvancedOrder memory advancedOrder)
    {
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
    function _convertOrdersToAdvanced(Order[] calldata orders)
        internal
        pure
        returns (AdvancedOrder[] memory advancedOrders)
    {
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

    /**
     * @dev Internal pure function to convert an advanced order to an order
     *      to execute with numerator of 1.
     *
     * @param advancedOrder The advanced order to convert.
     *
     * @return orderToExecute The new order to execute.
     */
    function _convertAdvancedToOrder(AdvancedOrder memory advancedOrder)
        internal
        pure
        returns (OrderToExecute memory orderToExecute)
    {
        // Retrieve the advanced orders offers.
        OfferItem[] memory offer = advancedOrder.parameters.offer;

        // Create an array of spent items equal to the offer length.
        SpentItem[] memory spentItems = new SpentItem[](offer.length);

        // Iterate over each offer item on the order.
        for (uint256 i = 0; i < offer.length; ++i) {
            // Retrieve the offer item.
            OfferItem memory offerItem = offer[i];

            // Create spent item for event based on the offer item.
            SpentItem memory spentItem = SpentItem(
                offerItem.itemType,
                offerItem.token,
                offerItem.identifierOrCriteria,
                offerItem.startAmount
            );

            // Add to array of spent items
            spentItems[i] = spentItem;
        }

        // Retrieve the advanced orders considerations.
        ConsiderationItem[] memory consideration = advancedOrder
            .parameters
            .consideration;

        // Create an array of received items equal to the consideration length.
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            consideration.length
        );

        // Iterate over each consideration item on the order.
        for (uint256 i = 0; i < consideration.length; ++i) {
            // Retrieve the consideration item.
            ConsiderationItem memory considerationItem = (consideration[i]);

            // Create received item for event based on the consideration item.
            ReceivedItem memory receivedItem = ReceivedItem(
                considerationItem.itemType,
                considerationItem.token,
                considerationItem.identifierOrCriteria,
                considerationItem.startAmount,
                considerationItem.recipient
            );

            // Add to array of received items
            receivedItems[i] = receivedItem;
        }

        // Create the order to execute from the advanced order data.
        orderToExecute = OrderToExecute(
            advancedOrder.parameters.offerer,
            spentItems,
            receivedItems,
            advancedOrder.parameters.conduitKey,
            advancedOrder.numerator
        );
        // Return the order.
        return orderToExecute;
    }

    /**
     * @dev Internal pure function to convert an array of advanced orders to
     *      an array of orders to execute.
     *
     * @param advancedOrders The advanced orders to convert.
     *
     * @return ordersToExecute The new array of orders.
     */
    function _convertAdvancedToOrdersToExecute(
        AdvancedOrder[] memory advancedOrders
    ) internal pure returns (OrderToExecute[] memory ordersToExecute) {
        // Read the number of orders from memory and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Allocate new empty array for each advanced order in memory.
        ordersToExecute = new OrderToExecute[](totalOrders);

        // Iterate over the given orders.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Convert and update array.
            ordersToExecute[i] = _convertAdvancedToOrder(advancedOrders[i]);
        }

        // Return the array of orders to execute
        return ordersToExecute;
    }
}
