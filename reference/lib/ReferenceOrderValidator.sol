// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { OrderType, ItemType } from "contracts/lib/ConsiderationEnums.sol";

import {
    OrderParameters,
    Order,
    AdvancedOrder,
    OrderComponents,
    OrderStatus,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "contracts/lib/ConsiderationStructs.sol";

import { ReferenceExecutor } from "./ReferenceExecutor.sol";

import { ReferenceZoneInteraction } from "./ReferenceZoneInteraction.sol";

import {
    ContractOffererInterface
} from "contracts/interfaces/ContractOffererInterface.sol";

/**
 * @title OrderValidator
 * @author 0age
 * @notice OrderValidator contains functionality related to validating orders
 *         and updating their status.
 */
contract ReferenceOrderValidator is
    ReferenceExecutor,
    ReferenceZoneInteraction
{
    // Track status of each order (validated, cancelled, and fraction filled).
    mapping(bytes32 => OrderStatus) private _orderStatus;

    mapping(address => uint256) internal _contractNonces;

    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController)
        ReferenceExecutor(conduitController)
    {}

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
        OrderStatus storage orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        _verifyOrderStatus(
            orderHash,
            orderStatus,
            true, // Only allow unused orders when fulfilling basic orders.
            true // Signifies to revert if the order is invalid.
        );

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(offerer, orderHash, signature);
        }

        // Update order status as fully filled, packing struct values.
        orderStatus.isValidated = true;
        orderStatus.isCancelled = false;
        orderStatus.numerator = 1;
        orderStatus.denominator = 1;
    }

    /**
     * @dev Internal function to validate an order, determine what portion to
     *      fill, and update its status. The desired fill amount is supplied as
     *      a fraction, as is the returned amount to fill.
     *
     * @param advancedOrder    The order to fulfill as well as the fraction to
     *                         fill. Note that all offer and consideration
     *                         amounts must divide with no remainder in order
     *                         for a partial fill to be valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the order's merkle
     *                          root. Note that a criteria of zero indicates
     *                          that any (transferable) token identifier is
     *                          valid and that no proof needs to be supplied.
     * @param revertOnInvalid  A boolean indicating whether to revert if the
     *                         order is invalid due to the time or order status.
     * @param priorOrderHashes The order hashes of each order supplied prior to
     *                         the current order as part of a "match" variety of
     *                         order fulfillment (e.g. this array will be empty
     *                         for single or "fulfill available").
     *
     * @return orderHash      The order hash.
     * @return newNumerator   A value indicating the portion of the order that
     *                        will be filled.
     * @return newDenominator A value indicating the total size of the order.
     */
    function _validateOrderAndUpdateStatus(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid,
        bytes32[] memory priorOrderHashes
    )
        internal
        returns (
            bytes32 orderHash,
            uint256 newNumerator,
            uint256 newDenominator
        )
    {
        // Retrieve the parameters for the order.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Ensure current timestamp falls between order start time and end time.
        if (
            !_verifyTime(
                orderParameters.startTime,
                orderParameters.endTime,
                revertOnInvalid
            )
        ) {
            // Assuming an invalid time and no revert, return zeroed out values.
            return (bytes32(0), 0, 0);
        }

        if (orderParameters.orderType == OrderType.CONTRACT) {
            return
                _getGeneratedOrder(
                    orderParameters,
                    advancedOrder.extraData,
                    revertOnInvalid
                );
        }

        // Read numerator and denominator from memory and place on the stack.
        uint256 numerator = uint256(advancedOrder.numerator);
        uint256 denominator = uint256(advancedOrder.denominator);

        // Ensure that the supplied numerator and denominator are valid.
        if (numerator > denominator || numerator == 0) {
            revert BadFraction();
        }

        // If attempting partial fill (n < d) check order type & ensure support.
        if (
            numerator < denominator &&
            _doesNotSupportPartialFills(orderParameters.orderType)
        ) {
            // Revert if partial fill was attempted on an unsupported order.
            revert PartialFillsNotEnabledForOrder();
        }

        // Retrieve current counter and use it w/ parameters to get order hash.
        orderHash = _assertConsiderationLengthAndGetOrderHash(orderParameters);

        // Ensure a valid submitter.
        _assertRestrictedAdvancedOrderValidity(
            advancedOrder,
            criteriaResolvers,
            priorOrderHashes,
            orderHash,
            orderParameters.zoneHash,
            orderParameters.orderType,
            orderParameters.offerer,
            orderParameters.zone
        );

        // Retrieve the order status using the derived order hash.
        OrderStatus storage orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        if (
            !_verifyOrderStatus(
                orderHash,
                orderStatus,
                false, // Allow partially used orders to be filled.
                revertOnInvalid
            )
        ) {
            // Assuming an invalid order status and no revert, return zero fill.
            return (orderHash, 0, 0);
        }

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                orderParameters.offerer,
                orderHash,
                advancedOrder.signature
            );
        }

        // Read filled amount as numerator and denominator and put on the stack.
        uint256 filledNumerator = uint256(orderStatus.numerator);
        uint256 filledDenominator = uint256(orderStatus.denominator);

        // If order currently has a non-zero denominator it is partially filled.
        if (filledDenominator != 0) {
            // If denominator of 1 supplied, fill all remaining amount on order.
            if (denominator == 1) {
                // Scale numerator & denominator to match current denominator.
                numerator = filledDenominator;
                denominator = filledDenominator;
            }
            // Otherwise, if supplied denominator differs from current one...
            else if (filledDenominator != denominator) {
                // scale current numerator by the supplied denominator, then...
                filledNumerator *= denominator;

                // the supplied numerator & denominator by current denominator.
                numerator *= filledDenominator;
                denominator *= filledDenominator;
            }

            // Once adjusted, if current+supplied numerator exceeds denominator:
            if (filledNumerator + numerator > denominator) {
                // Reduce current numerator so it + supplied = denominator.
                numerator = denominator - filledNumerator;
            }

            // Increment the filled numerator by the new numerator.
            filledNumerator += numerator;

            // Ensure fractional amounts are below max uint120.
            if (
                filledNumerator > type(uint120).max ||
                denominator > type(uint120).max
            ) {
                // Derive greatest common divisor using euclidean algorithm.
                uint256 scaleDown = _greatestCommonDivisor(
                    numerator,
                    _greatestCommonDivisor(filledNumerator, denominator)
                );

                // Note: this may not be necessary — need to validate.
                uint256 safeScaleDown = scaleDown == 0 ? 1 : scaleDown;

                // Scale all fractional values down by gcd.
                numerator = numerator / safeScaleDown;
                filledNumerator = filledNumerator / safeScaleDown;
                denominator = denominator / safeScaleDown;

                // Perform the overflow check a second time.
                uint256 maxOverhead = type(uint256).max - type(uint120).max;
                ((filledNumerator + maxOverhead) & (denominator + maxOverhead));
            }

            // Update order status and fill amount, packing struct values.
            orderStatus.isValidated = true;
            orderStatus.isCancelled = false;
            orderStatus.numerator = uint120(filledNumerator);
            orderStatus.denominator = uint120(denominator);
        } else {
            // Update order status and fill amount, packing struct values.
            orderStatus.isValidated = true;
            orderStatus.isCancelled = false;
            orderStatus.numerator = uint120(numerator);
            orderStatus.denominator = uint120(denominator);
        }

        // Return order hash, new numerator and denominator.
        return (orderHash, uint120(numerator), uint120(denominator));
    }

    function _getGeneratedOrder(
        OrderParameters memory orderParameters,
        bytes memory context,
        bool revertOnInvalid
    )
        internal
        returns (
            bytes32 orderHash,
            uint256 numerator,
            uint256 denominator
        )
    {
        // TODO: reuse an existing memory region or relocate this functionality
        (
            SpentItem[] memory originalOfferItems,
            SpentItem[] memory originalConsiderationItems
        ) = _convertToSpent(
                orderParameters.offer,
                orderParameters.consideration
            );

        SpentItem[] memory offer;
        ReceivedItem[] memory consideration;
        try
            ContractOffererInterface(orderParameters.offerer).generateOrder(
                originalOfferItems,
                originalConsiderationItems,
                context
            )
        returns (
            SpentItem[] memory returnedOffer,
            ReceivedItem[] memory ReturnedConsideration
        ) {
            offer = returnedOffer;
            consideration = ReturnedConsideration;
        } catch {
            return _revertOrReturnEmpty(revertOnInvalid);
        }

        {
            uint256 originalOfferLength = orderParameters.offer.length;
            uint256 newOfferLength = offer.length;

            // Explicitly specified offer items cannot be removed.
            if (originalOfferLength > newOfferLength) {
                return _revertOrReturnEmpty(revertOnInvalid);
            } else if (offer.length > originalOfferLength) {
                OfferItem[] memory extendedOffer = new OfferItem[](
                    newOfferLength
                );
                for (uint256 i = 0; i < originalOfferLength; ++i) {
                    extendedOffer[i] = orderParameters.offer[i];
                }
                orderParameters.offer = extendedOffer;
            }

            // Loop through each offer and ensure at least as much on returned offer
            for (uint256 i = 0; i < originalOfferLength; ++i) {
                OfferItem memory originalOffer = orderParameters.offer[i];
                SpentItem memory newOffer = offer[i];

                if (
                    uint256(originalOffer.itemType) > 3 &&
                    originalOffer.identifierOrCriteria == 0
                ) {
                    originalOffer.itemType = ItemType(
                        uint256(originalOffer.itemType) - 2
                    );
                    originalOffer.identifierOrCriteria = newOffer.identifier;
                }

                if (
                    originalOffer.startAmount != originalOffer.endAmount ||
                    originalOffer.endAmount > newOffer.amount ||
                    originalOffer.itemType != newOffer.itemType ||
                    originalOffer.token != newOffer.token ||
                    originalOffer.identifierOrCriteria != newOffer.identifier
                ) {
                    return _revertOrReturnEmpty(revertOnInvalid);
                }

                originalOffer.startAmount = newOffer.amount;
                originalOffer.endAmount = newOffer.amount;
            }

            // add new offer items if there are more than original
            for (uint256 i = originalOfferLength; i < newOfferLength; ++i) {
                OfferItem memory originalOffer = orderParameters.offer[i];
                SpentItem memory newOffer = offer[i];

                originalOffer.itemType = newOffer.itemType;
                originalOffer.token = newOffer.token;
                originalOffer.identifierOrCriteria = newOffer.identifier;
                originalOffer.startAmount = newOffer.amount;
                originalOffer.endAmount = newOffer.amount;
            }
        }

        {
            ConsiderationItem[] memory originalConsiderationArray = (
                orderParameters.consideration
            );
            uint256 originalConsiderationLength = originalConsiderationArray
                .length;
            uint256 newConsiderationLength = consideration.length;

            if (originalConsiderationLength != 0) {
                // Consideration items that are not explicitly specified cannot be
                // created. Note that this constraint could be relaxed if specified
                // consideration items can be split.
                if (newConsiderationLength > originalConsiderationLength) {
                    return _revertOrReturnEmpty(revertOnInvalid);
                }

                // Loop through returned consideration, ensure existing not exceeded
                for (uint256 i = 0; i < newConsiderationLength; ++i) {
                    ReceivedItem memory newConsideration = consideration[i];
                    ConsiderationItem memory originalConsideration = (
                        originalConsiderationArray[i]
                    );

                    if (
                        uint256(originalConsideration.itemType) > 3 &&
                        originalConsideration.identifierOrCriteria == 0
                    ) {
                        originalConsideration.itemType = ItemType(
                            uint256(originalConsideration.itemType) - 2
                        );
                        originalConsideration
                            .identifierOrCriteria = newConsideration.identifier;
                    }

                    if (
                        originalConsideration.startAmount !=
                        originalConsideration.endAmount ||
                        newConsideration.amount >
                        originalConsideration.endAmount ||
                        originalConsideration.itemType !=
                        newConsideration.itemType ||
                        originalConsideration.token != newConsideration.token ||
                        originalConsideration.identifierOrCriteria !=
                        newConsideration.identifier
                        // TODO: should we check recipient if supplied by fulfiller?
                        // Should we allow empty args to be skipped in other cases?
                    ) {
                        return _revertOrReturnEmpty(revertOnInvalid);
                    }

                    originalConsideration.startAmount = newConsideration.amount;
                    originalConsideration.endAmount = newConsideration.amount;
                    originalConsideration.recipient = newConsideration
                        .recipient;
                }

                // Shorten original consideration array if longer than new array.
                ConsiderationItem[] memory shortenedConsiderationArray = (
                    new ConsiderationItem[](newConsiderationLength)
                );

                for (uint256 i = 0; i < newConsiderationLength; ++i) {
                    shortenedConsiderationArray[i] = originalConsiderationArray[
                        i
                    ];
                }

                orderParameters.consideration = shortenedConsiderationArray;
            } else {
                // TODO: optimize this
                orderParameters.consideration = new ConsiderationItem[](
                    newConsiderationLength
                );

                for (uint256 i = 0; i < newConsiderationLength; ++i) {
                    ReceivedItem memory newConsideration = consideration[i];
                    ConsiderationItem memory originalConsideration = (
                        orderParameters.consideration[i]
                    );

                    originalConsideration.itemType = newConsideration.itemType;
                    originalConsideration.token = newConsideration.token;
                    originalConsideration
                        .identifierOrCriteria = newConsideration.identifier;
                    originalConsideration.startAmount = newConsideration.amount;
                    originalConsideration.endAmount = newConsideration.amount;
                    originalConsideration.recipient = newConsideration
                        .recipient;
                }
            }
        }

        address offerer = orderParameters.offerer;
        uint256 contractNonce = _contractNonces[offerer]++;

        orderHash = bytes32(contractNonce | (uint256(uint160(offerer)) << 96));

        return (orderHash, 1, 1);
    }

    function _revertOrReturnEmpty(bool revertOnInvalid)
        internal
        pure
        returns (
            bytes32 orderHash,
            uint256 numerator,
            uint256 denominator
        )
    {
        if (!revertOnInvalid) {
            return (bytes32(0), 0, 0);
        }

        revert NoSpecifiedOrdersAvailable(); // TODO: return a better error msg
    }

    /**
     * @dev Internal pure function to convert both offer and consideration items
     *      to spent items.
     */
    function _convertToSpent(
        OfferItem[] memory offer,
        ConsiderationItem[] memory consideration
    )
        internal
        pure
        returns (
            SpentItem[] memory spentItems,
            SpentItem[] memory receivedItems
        )
    {
        // Create an array of spent items equal to the offer length.
        spentItems = new SpentItem[](offer.length);

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

        // Create an array of received items equal to the consideration length.
        receivedItems = new SpentItem[](consideration.length);

        // Iterate over each consideration item on the order.
        for (uint256 i = 0; i < consideration.length; ++i) {
            // Retrieve the consideration item.
            ConsiderationItem memory considerationItem = (consideration[i]);

            // Create spent item for event based on the consideration item.
            SpentItem memory receivedItem = SpentItem(
                considerationItem.itemType,
                considerationItem.token,
                considerationItem.identifierOrCriteria,
                considerationItem.startAmount
            );

            // Add to array of received items
            receivedItems[i] = receivedItem;
        }
    }

    /**
     * @dev Internal function to derive the greatest common divisor of two
     *      values using the classical euclidian algorithm.
     *
     * @param a The first value.
     * @param b The second value.
     *
     * @return greatestCommonDivisor The greatest common divisor.
     */
    function _greatestCommonDivisor(uint256 a, uint256 b)
        internal
        pure
        returns (uint256 greatestCommonDivisor)
    {
        while (b > 0) {
            uint256 c = b;
            b = a % c;
            a = c;
        }

        greatestCommonDivisor = a;
    }

    /**
     * @dev Internal function to cancel an arbitrary number of orders. Note that
     *      only the offerer or the zone of a given order may cancel it.
     *
     * @param orders The orders to cancel.
     *
     * @return A boolean indicating whether the supplied orders were
     *         successfully cancelled.
     */
    function _cancel(OrderComponents[] calldata orders)
        internal
        notEntered
        returns (bool)
    {
        // Declare variables outside of the loop.
        OrderStatus storage orderStatus;
        address offerer;
        address zone;

        // Read length of the orders array from memory and place on stack.
        uint256 totalOrders = orders.length;

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order.
            OrderComponents calldata order = orders[i];

            offerer = order.offerer;
            zone = order.zone;

            // Ensure caller is either offerer or zone of the order.
            if (msg.sender != offerer && msg.sender != zone) {
                revert InvalidCanceller();
            }

            // Derive order hash using the order parameters and the counter.
            bytes32 orderHash = _deriveOrderHash(
                OrderParameters(
                    offerer,
                    zone,
                    order.offer,
                    order.consideration,
                    order.orderType,
                    order.startTime,
                    order.endTime,
                    order.zoneHash,
                    order.salt,
                    order.conduitKey,
                    order.consideration.length
                ),
                order.counter
            );

            // Retrieve the order status using the derived order hash.
            orderStatus = _orderStatus[orderHash];

            // Update the order status as not valid and cancelled.
            orderStatus.isValidated = false;
            orderStatus.isCancelled = true;

            // Emit an event signifying that the order has been cancelled.
            emit OrderCancelled(orderHash, offerer, zone);
        }
        return true;
    }

    /**
     * @dev Internal function to validate an arbitrary number of orders, thereby
     *      registering them as valid and allowing the fulfiller to skip
     *      verification. Note that anyone can validate a signed order but only
     *      the offerer can validate an order without supplying a signature.
     *
     * @param orders The orders to validate.
     *
     * @return A boolean indicating whether the supplied orders were
     *         successfully validated.
     */
    function _validate(Order[] calldata orders)
        internal
        notEntered
        returns (bool)
    {
        // Declare variables outside of the loop.
        OrderStatus storage orderStatus;
        bytes32 orderHash;
        address offerer;

        // Read length of the orders array from memory and place on stack.
        uint256 totalOrders = orders.length;

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order.
            Order calldata order = orders[i];

            // Retrieve the order parameters.
            OrderParameters calldata orderParameters = order.parameters;

            // Move offerer from memory to the stack.
            offerer = orderParameters.offerer;

            // Get current counter and use it w/ params to derive order hash.
            orderHash = _assertConsiderationLengthAndGetOrderHash(
                orderParameters
            );

            // Retrieve the order status using the derived order hash.
            orderStatus = _orderStatus[orderHash];

            // Ensure order is fillable and retrieve the filled amount.
            _verifyOrderStatus(
                orderHash,
                orderStatus,
                false, // Signifies that partially filled orders are valid.
                true // Signifies to revert if the order is invalid.
            );

            // If the order has not already been validated...
            if (!orderStatus.isValidated) {
                // Verify the supplied signature.
                _verifySignature(offerer, orderHash, order.signature);

                // Update order status to mark the order as valid.
                orderStatus.isValidated = true;

                // Emit an event signifying the order has been validated.
                emit OrderValidated(orderHash, offerer, orderParameters.zone);
            }
        }

        return true;
    }

    /**
     * @dev Internal view function to retrieve the status of a given order by
     *      hash, including whether the order has been cancelled or validated
     *      and the fraction of the order that has been filled.
     *
     * @param orderHash The order hash in question.
     *
     * @return isValidated A boolean indicating whether the order in question
     *                     has been validated (i.e. previously approved or
     *                     partially filled).
     * @return isCancelled A boolean indicating whether the order in question
     *                     has been cancelled.
     * @return totalFilled The total portion of the order that has been filled
     *                     (i.e. the "numerator").
     * @return totalSize   The total size of the order that is either filled or
     *                     unfilled (i.e. the "denominator").
     */
    function _getOrderStatus(bytes32 orderHash)
        internal
        view
        returns (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        )
    {
        // Retrieve the order status using the order hash.
        OrderStatus storage orderStatus = _orderStatus[orderHash];

        // Return the fields on the order status.
        return (
            orderStatus.isValidated,
            orderStatus.isCancelled,
            orderStatus.numerator,
            orderStatus.denominator
        );
    }

    /**
     * @dev Internal pure function to check whether a given order type indicates
     *      that partial fills are not supported (e.g. only "full fills" are
     *      allowed for the order in question).
     *
     * @param orderType The order type in question.
     *
     * @return isFullOrder A boolean indicating whether the order type only
     *                     supports full fills.
     */
    function _doesNotSupportPartialFills(OrderType orderType)
        internal
        pure
        returns (bool isFullOrder)
    {
        // The "full" order types are even, while "partial" order types are odd.
        isFullOrder = uint256(orderType) & 1 == 0;
    }
}
