// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    OrderType,
    ItemType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    OrderStatus,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ReferenceExecutor } from "./ReferenceExecutor.sol";

import { ReferenceZoneInteraction } from "./ReferenceZoneInteraction.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    ReferenceGenerateOrderReturndataDecoder
} from "./ReferenceGenerateOrderReturndataDecoder.sol";

import {
    OrderToExecute,
    OrderValidation
} from "./ReferenceConsiderationStructs.sol";

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

    // Track nonces for contract offerers.
    mapping(address => uint256) internal _contractNonces;

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
    ) ReferenceExecutor(conduitController) {}

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
     * @dev Internal function to validate an order and determine what portion to
     *      fill. The desired fill amount is supplied as a fraction, as is the
     *      returned amount to fill.
     *
     * @param advancedOrder   The order to fulfill as well as the fraction to
     *                        fill. Note that all offer and consideration
     *                        amounts must divide with no remainder in order for
     *                        a partial fill to be valid.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order is invalid due to the time or order status.
     *
     * @return orderValidation The order validation details, including the fill
     *                         amount.
     */
    function _validateOrder(
        AdvancedOrder memory advancedOrder,
        bool revertOnInvalid
    ) internal view returns (OrderValidation memory orderValidation) {
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
            return
                OrderValidation(
                    bytes32(0),
                    0,
                    0,
                    _convertAdvancedToOrder(orderParameters, 0)
                );
        }

        // Read numerator and denominator from memory and place on the stack.
        uint256 numerator = uint256(advancedOrder.numerator);
        uint256 denominator = uint256(advancedOrder.denominator);

        // If the order is a contract order, return the generated order.
        if (orderParameters.orderType == OrderType.CONTRACT) {
            // Ensure that numerator and denominator are both equal to 1.
            if (numerator != 1 || denominator != 1) {
                revert BadFraction();
            }

            return
                OrderValidation(
                    bytes32(uint256(1)),
                    1,
                    1,
                    _convertAdvancedToOrder(orderParameters, 1)
                );
        }

        // Ensure that the supplied numerator and denominator are valid.  The
        // numerator should not exceed denominator and should not be zero.
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
        orderValidation.orderHash = (
            _assertConsiderationLengthAndGetOrderHash(orderParameters)
        );

        // Retrieve the order status using the derived order hash.
        OrderStatus storage orderStatus = (
            _orderStatus[orderValidation.orderHash]
        );

        // Ensure order is fillable and is not cancelled.
        if (
            // Allow partially used orders to be filled.
            !_verifyOrderStatus(
                orderValidation.orderHash,
                orderStatus,
                false,
                revertOnInvalid
            )
        ) {
            // Assuming an invalid order status and no revert, return zero fill.
            return
                OrderValidation(
                    orderValidation.orderHash,
                    0,
                    0,
                    _convertAdvancedToOrder(orderParameters, 0)
                );
        }

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                orderParameters.offerer,
                orderValidation.orderHash,
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

                // Scale all fractional values down by gcd.
                numerator = numerator / scaleDown;
                filledNumerator = filledNumerator / scaleDown;
                denominator = denominator / scaleDown;

                // Perform the overflow check a second time.
                uint256 maxOverhead = type(uint256).max - type(uint120).max;
                ((filledNumerator + maxOverhead) & (denominator + maxOverhead));
            }
        }

        // Return order hash, new numerator and denominator.
        return
            OrderValidation(
                orderValidation.orderHash,
                uint120(numerator),
                uint120(denominator),
                _convertAdvancedToOrder(orderParameters, uint120(numerator))
            );
    }

    /**
     * @dev Internal function to update an order's status.
     *
     * @param orderHash       The hash of the order.
     * @param numerator       The numerator of the fraction to fill.
     * @param denominator     The denominator of the fraction to fill.
     * @param revertOnInvalid Whether to revert on invalid input.
     *
     * @return valid A boolean indicating whether the order is valid.
     */
    function _updateStatus(
        bytes32 orderHash,
        uint256 numerator,
        uint256 denominator,
        bool revertOnInvalid
    ) internal returns (bool valid) {
        if (numerator == 0) {
            return false;
        }

        // Retrieve the order status using the provided order hash.
        OrderStatus storage orderStatus = _orderStatus[orderHash];

        // Read filled amount as numerator and denominator and put on the stack.
        uint256 filledNumerator = uint256(orderStatus.numerator);
        uint256 filledDenominator = uint256(orderStatus.denominator);

        // If order currently has a non-zero denominator it is partially filled.
        if (filledDenominator != 0) {
            // if supplied denominator differs from current one...
            if (filledDenominator != denominator) {
                // scale current numerator by the supplied denominator, then...
                filledNumerator *= denominator;

                // the supplied numerator & denominator by current denominator.
                numerator *= filledDenominator;
                denominator *= filledDenominator;
            }

            // Once adjusted, if current+supplied numerator exceeds
            // denominator...
            if (filledNumerator + numerator > denominator) {
                // Revert or return false, which indicates that the order is
                // invalid.
                if (revertOnInvalid) {
                    revert OrderAlreadyFilled(orderHash);
                } else {
                    return false;
                }
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
                    filledNumerator,
                    denominator
                );

                // Scale new filled fractional values down by gcd.
                filledNumerator = filledNumerator / scaleDown;
                denominator = denominator / scaleDown;

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
            // If the order currently has a zero denominator, it is not
            // partially filled. Update the order status and fill amount,
            // packing struct values.
            orderStatus.isValidated = true;
            orderStatus.isCancelled = false;
            orderStatus.numerator = uint120(numerator);
            orderStatus.denominator = uint120(denominator);
        }

        return true;
    }

    function _callGenerateOrder(
        OrderParameters memory orderParameters,
        bytes memory context,
        SpentItem[] memory originalOfferItems,
        SpentItem[] memory originalConsiderationItems
    ) internal returns (bool success, bytes memory returnData) {
        return
            orderParameters.offerer.call(
                abi.encodeWithSelector(
                    ContractOffererInterface.generateOrder.selector,
                    msg.sender,
                    originalOfferItems,
                    originalConsiderationItems,
                    context
                )
            );
    }

    /**
     * @dev Internal function to generate a contract order. When a
     *      collection-wide criteria-based item (criteria = 0) is provided as an
     *      input to a contract order, the contract offerer has full latitude to
     *      choose any identifier it wants mid-flight, which differs from the
     *      usual behavior.  For regular criteria-based orders with
     *      identifierOrCriteria = 0, the fulfiller can pick which identifier to
     *      receive by providing a CriteriaResolver. For contract offers with
     *      identifierOrCriteria = 0, Seaport does not expect a corresponding
     *      CriteriaResolver, and will revert if one is provided.
     *
     * @param orderToExecute  The order to execute.
     * @param orderParameters The parameters for the order.
     * @param context         The context for generating the order.
     * @param revertOnInvalid Whether to revert on invalid input.
     *
     * @return orderHash   The order hash.
     */
    function _getGeneratedOrder(
        OrderToExecute memory orderToExecute,
        OrderParameters memory orderParameters,
        bytes memory context,
        bool revertOnInvalid
    ) internal returns (bytes32 orderHash) {
        // Ensure that consideration array length is equal to the total original
        // consideration items value.
        if (
            orderParameters.consideration.length !=
            orderParameters.totalOriginalConsiderationItems
        ) {
            revert ConsiderationLengthNotEqualToTotalOriginal();
        }

        // Convert offer and consideration to spent and received items.
        SpentItem[] memory originalOfferItems = orderToExecute.spentItems;
        SpentItem[] memory originalConsiderationItems = _convertToSpent(
            orderToExecute.receivedItems
        );

        // Create arrays for returned offer and consideration items.
        SpentItem[] memory offer;
        ReceivedItem[] memory consideration;

        {
            // Do a low-level call to get success status and any return data.
            (bool success, bytes memory returnData) = _callGenerateOrder(
                orderParameters,
                context,
                originalOfferItems,
                originalConsiderationItems
            );

            {
                // Increment contract nonce and use it to derive order hash.
                // Note: nonce will be incremented even for skipped orders, and
                // even if generateOrder's return data doesn't meet constraints.
                uint256 contractNonce = (
                    _contractNonces[orderParameters.offerer]++
                );

                // Derive order hash from contract nonce and offerer address.
                orderHash = bytes32(
                    contractNonce ^
                        (uint256(uint160(orderParameters.offerer)) << 96)
                );
            }

            //  If call succeeds, try to decode offer and consideration items.
            if (success) {
                // Try to decode offer and consideration items from returndata.
                try
                    (new ReferenceGenerateOrderReturndataDecoder()).decode(
                        returnData
                    )
                returns (
                    SpentItem[] memory _offer,
                    ReceivedItem[] memory _consideration
                ) {
                    offer = _offer;
                    consideration = _consideration;
                } catch {
                    // If decoding fails, revert.
                    revert InvalidContractOrder(orderHash);
                }
            } else {
                // If the call fails, revert or return empty.
                (orderHash, orderToExecute) = _revertOrReturnEmpty(
                    revertOnInvalid,
                    orderHash
                );
                return orderHash;
            }
        }

        {
            // Designate lengths.
            uint256 originalOfferLength = orderParameters.offer.length;
            uint256 newOfferLength = offer.length;

            // Explicitly specified offer items cannot be removed.
            if (originalOfferLength > newOfferLength) {
                revert InvalidContractOrder(orderHash);
            }

            // Loop through each new offer and ensure the new amounts are at
            // least as much as the respective original amounts.
            for (uint256 i = 0; i < originalOfferLength; ++i) {
                // Designate original and new offer items.
                SpentItem memory originalOffer = orderToExecute.spentItems[i];
                SpentItem memory newOffer = offer[i];

                // Set returned identifier for criteria-based items with
                // criteria = 0. Note that this reset means that a contract
                // offerer has full latitude to choose any identifier it wants
                // mid-flight, in contrast to the normal behavior, where the
                // fulfiller can pick which identifier to receive by providing a
                // CriteriaResolver.
                if (
                    uint256(originalOffer.itemType) > 3 &&
                    originalOffer.identifier == 0
                ) {
                    originalOffer.itemType = ItemType(
                        uint256(originalOffer.itemType) - 2
                    );
                    originalOffer.identifier = newOffer.identifier;
                }

                // Ensure the original and generated items are compatible.
                if (
                    originalOffer.amount > newOffer.amount ||
                    originalOffer.itemType != newOffer.itemType ||
                    originalOffer.token != newOffer.token ||
                    originalOffer.identifier != newOffer.identifier
                ) {
                    revert InvalidContractOrder(orderHash);
                }
            }

            orderToExecute.spentItems = offer;
            orderToExecute.spentItemOriginalAmounts = new uint256[](
                offer.length
            );

            // Add new offer items if there are more than original.
            for (uint256 i = 0; i < offer.length; ++i) {
                orderToExecute.spentItemOriginalAmounts[i] = offer[i].amount;
            }
        }

        {
            // Designate lengths & memory locations.
            ReceivedItem[] memory originalConsiderationArray = (
                orderToExecute.receivedItems
            );
            uint256 newConsiderationLength = consideration.length;

            // New consideration items cannot be created.
            if (newConsiderationLength > originalConsiderationArray.length) {
                revert InvalidContractOrder(orderHash);
            }

            // Loop through and check consideration.
            for (uint256 i = 0; i < newConsiderationLength; ++i) {
                ReceivedItem memory newConsideration = consideration[i];
                ReceivedItem memory originalConsideration = (
                    originalConsiderationArray[i]
                );

                if (
                    uint256(originalConsideration.itemType) > 3 &&
                    originalConsideration.identifier == 0
                ) {
                    originalConsideration.itemType = ItemType(
                        uint256(originalConsideration.itemType) - 2
                    );
                    originalConsideration.identifier = (
                        newConsideration.identifier
                    );
                }

                // All fields must match the originally supplied fields except
                // for the amount (which may be reduced by the contract offerer)
                // and the recipient if some non-zero address has been provided.
                if (
                    newConsideration.amount > originalConsideration.amount ||
                    originalConsideration.itemType !=
                    newConsideration.itemType ||
                    originalConsideration.token != newConsideration.token ||
                    originalConsideration.identifier !=
                    newConsideration.identifier ||
                    (originalConsideration.recipient != address(0) &&
                        originalConsideration.recipient !=
                        (newConsideration.recipient))
                ) {
                    revert InvalidContractOrder(orderHash);
                }
            }

            orderToExecute.receivedItems = consideration;
            orderToExecute.receivedItemOriginalAmounts = new uint256[](
                consideration.length
            );

            // Iterate over original consideration array and copy to new.
            for (uint256 i = 0; i < consideration.length; ++i) {
                orderToExecute.receivedItemOriginalAmounts[i] = (
                    consideration[i].amount
                );
            }
        }

        // Return the order hash.
        return orderHash;
    }

    /**
     * @dev Internal function to cancel an arbitrary number of orders. Note that
     *      only the offerer or the zone of a given order may cancel it. Callers
     *      should ensure that the intended order was cancelled by calling
     *      `getOrderStatus` and confirming that `isCancelled` returns `true`.
     *      Also note that contract orders are not cancellable.
     *
     * @param orders The orders to cancel.
     *
     * @return A boolean indicating whether the supplied orders were
     *         successfully cancelled.
     */
    function _cancel(
        OrderComponents[] calldata orders
    ) internal returns (bool) {
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

            // Ensure caller is either offerer or zone of the order and that the
            // order is not a contract order.
            if (
                order.orderType == OrderType.CONTRACT ||
                (msg.sender != offerer && msg.sender != zone)
            ) {
                revert CannotCancelOrder();
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
    function _validate(Order[] calldata orders) internal returns (bool) {
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

            // Skip contract orders.
            if (orderParameters.orderType == OrderType.CONTRACT) {
                continue;
            }

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
                // Ensure that consideration array length is equal to the total
                // original consideration items value.
                if (
                    orderParameters.consideration.length !=
                    orderParameters.totalOriginalConsiderationItems
                ) {
                    revert ConsiderationLengthNotEqualToTotalOriginal();
                }

                // Verify the supplied signature.
                _verifySignature(offerer, orderHash, order.signature);

                // Update order status to mark the order as valid.
                orderStatus.isValidated = true;

                // Emit an event signifying the order has been validated.
                emit OrderValidated(orderHash, orderParameters);
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
    function _getOrderStatus(
        bytes32 orderHash
    )
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
     * @dev Internal pure function to either revert or return an empty tuple
     *      depending on the value of `revertOnInvalid`.
     *
     * @param revertOnInvalid   Whether to revert on invalid input.
     * @param contractOrderHash The contract order hash.
     *
     * @return orderHash   The order hash.
     */
    function _revertOrReturnEmpty(
        bool revertOnInvalid,
        bytes32 contractOrderHash
    )
        internal
        pure
        returns (bytes32 orderHash, OrderToExecute memory emptyOrder)
    {
        // If invalid input should not revert...
        if (!revertOnInvalid) {
            // Return no contract order hash and zero values for the numerator
            // and denominator.
            return (bytes32(0), emptyOrder);
        }

        // Otherwise, revert.
        revert InvalidContractOrder(contractOrderHash);
    }

    /**
     * @dev Internal pure function to convert received items to spent items.
     *
     * @param consideration  The consideration items to convert.
     *
     * @return receivedItems The converted received items.
     */
    function _convertToSpent(
        ReceivedItem[] memory consideration
    ) internal pure returns (SpentItem[] memory receivedItems) {
        // Create an array of received items equal to the consideration length.
        receivedItems = new SpentItem[](consideration.length);

        // Iterate over each received item on the order.
        for (uint256 i = 0; i < consideration.length; ++i) {
            // Retrieve the consideration item.
            ReceivedItem memory considerationItem = (consideration[i]);

            // Create spent item for event based on the consideration item.
            SpentItem memory receivedItem = SpentItem(
                considerationItem.itemType,
                considerationItem.token,
                considerationItem.identifier,
                considerationItem.amount
            );

            // Add to array of received items.
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
    function _greatestCommonDivisor(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256 greatestCommonDivisor) {
        while (b > 0) {
            uint256 c = b;
            b = a % c;
            a = c;
        }

        greatestCommonDivisor = a;
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
    function _doesNotSupportPartialFills(
        OrderType orderType
    ) internal pure returns (bool isFullOrder) {
        // The "full" order types are even, while "partial" order types are odd.
        isFullOrder = uint256(orderType) & 1 == 0;
    }

    /**
     * @dev Internal pure function to convert an advanced order to an order
     *      to execute.
     *
     * @param orderParameters The order to convert.
     *
     * @return orderToExecute The new order to execute.
     */
    function _convertAdvancedToOrder(
        OrderParameters memory orderParameters,
        uint120 numerator
    ) internal pure returns (OrderToExecute memory orderToExecute) {
        // Retrieve the advanced orders offers.
        OfferItem[] memory offer = orderParameters.offer;

        // Create an array of spent items equal to the offer length.
        SpentItem[] memory spentItems = new SpentItem[](offer.length);
        uint256[] memory spentItemOriginalAmounts = new uint256[](offer.length);

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

            // Add to array of spent items.
            spentItems[i] = spentItem;
            spentItemOriginalAmounts[i] = offerItem.startAmount;
        }

        // Retrieve the consideration array from the advanced order.
        ConsiderationItem[] memory consideration = orderParameters
            .consideration;

        // Create an array of received items equal to the consideration length.
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            consideration.length
        );
        // Create an array of uint256 values equal in length to the
        // consideration length containing the amounts of each item.
        uint256[] memory receivedItemOriginalAmounts = new uint256[](
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

            // Add to array of received items.
            receivedItems[i] = receivedItem;

            // Add to array of received item amounts.
            receivedItemOriginalAmounts[i] = considerationItem.startAmount;
        }

        // Create the order to execute from the advanced order data.
        orderToExecute = OrderToExecute(
            orderParameters.offerer,
            spentItems,
            receivedItems,
            orderParameters.conduitKey,
            numerator,
            spentItemOriginalAmounts,
            receivedItemOriginalAmounts
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
            ordersToExecute[i] = _convertAdvancedToOrder(
                advancedOrders[i].parameters,
                advancedOrders[i].numerator
            );
        }

        // Return the array of orders to execute
        return ordersToExecute;
    }
}
