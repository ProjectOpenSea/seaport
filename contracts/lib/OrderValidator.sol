// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderType, ItemType } from "./ConsiderationEnums.sol";

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
} from "./ConsiderationStructs.sol";

import "./ConsiderationErrors.sol";

import { Executor } from "./Executor.sol";

import { ZoneInteraction } from "./ZoneInteraction.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import {
    MemoryPointer,
    getFreeMemoryPointer
} from "../helpers/PointerLibraries.sol";

/**
 * @title OrderValidator
 * @author 0age
 * @notice OrderValidator contains functionality related to validating orders
 *         and updating their status.
 */
contract OrderValidator is Executor, ZoneInteraction {
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
    constructor(address conduitController) Executor(conduitController) {}

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
     * @param advancedOrder     The order to fulfill as well as the fraction to
     *                          fill. Note that all offer and consideration
     *                          amounts must divide with no remainder in order
     *                          for a partial fill to be valid.
     * @param revertOnInvalid   A boolean indicating whether to revert if the
     *                          order is invalid due to the time or status.
     *
     * @return orderHash      The order hash.
     * @return numerator      A value indicating the portion of the order that
     *                        will be filled.
     * @return denominator    A value indicating the total size of the order.
     */
    function _validateOrderAndUpdateStatus(
        AdvancedOrder memory advancedOrder,
        bool revertOnInvalid
    )
        internal
        returns (bytes32 orderHash, uint256 numerator, uint256 denominator)
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

        // Read numerator and denominator from memory and place on the stack.
        // Note that overflowed values are masked.
        assembly {
            numerator := and(
                mload(add(advancedOrder, AdvancedOrder_numerator_offset)),
                MaxUint120
            )

            denominator := and(
                mload(add(advancedOrder, AdvancedOrder_denominator_offset)),
                MaxUint120
            )
        }

        // Declare variable for tracking the validity of the supplied fraction.
        bool validFraction;

        // If the order is a contract order, return the generated order.
        if (orderParameters.orderType == OrderType.CONTRACT) {
            // Ensure that the numerator and denominator are both equal to 1.
            assembly {
                validFraction := and(eq(numerator, 1), eq(denominator, 1))
            }

            // Revert if the supplied numerator and denominator are not valid.
            if (!validFraction) {
                _revertBadFraction();
            }

            // Return the generated order based on the order params and the
            // provided extra data. If revertOnInvalid is true, the function
            // will revert if the input is invalid.
            return
                _getGeneratedOrder(
                    orderParameters,
                    advancedOrder.extraData,
                    revertOnInvalid
                );
        }

        // Ensure numerator does not exceed denominator and is not zero.
        assembly {
            validFraction := iszero(
                or(gt(numerator, denominator), eq(numerator, 0))
            )
        }

        // Revert if the supplied numerator and denominator are not valid.
        if (!validFraction) {
            _revertBadFraction();
        }

        // If attempting partial fill (n < d) check order type & ensure support.
        if (
            _doesNotSupportPartialFills(
                orderParameters.orderType,
                numerator,
                denominator
            )
        ) {
            // Revert if partial fill was attempted on an unsupported order.
            _revertPartialFillsNotEnabledForOrder();
        }

        // Retrieve current counter & use it w/ parameters to derive order hash.
        orderHash = _assertConsiderationLengthAndGetOrderHash(orderParameters);

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

        assembly {
            let orderStatusSlot := orderStatus.slot
            // Read filled amount as numerator and denominator and put on stack.
            let filledNumerator := sload(orderStatusSlot)
            let filledDenominator := shr(
                OrderStatus_filledDenominator_offset,
                filledNumerator
            )

            for {

            } 1 {

            } {
                if iszero(filledDenominator) {
                    filledNumerator := numerator

                    break
                }

                // shift and mask to calculate the the current filled numerator.
                filledNumerator := and(
                    shr(OrderStatus_filledNumerator_offset, filledNumerator),
                    MaxUint120
                )

                // If denominator of 1 supplied, fill entire remaining amount.
                if eq(denominator, 1) {
                    numerator := sub(filledDenominator, filledNumerator)
                    denominator := filledDenominator
                    filledNumerator := filledDenominator

                    break
                }

                // If supplied denominator equals to the current one:
                if eq(denominator, filledDenominator) {
                    // Increment the filled numerator by the new numerator.
                    filledNumerator := add(numerator, filledNumerator)

                    // Once adjusted, if current + supplied numerator exceeds
                    // the denominator:
                    let carry := mul(
                        sub(filledNumerator, denominator),
                        gt(filledNumerator, denominator)
                    )

                    numerator := sub(numerator, carry)

                    filledNumerator := sub(filledNumerator, carry)

                    break
                }

                // Otherwise, if supplied denominator differs from current one:
                filledNumerator := mul(filledNumerator, denominator)
                numerator := mul(numerator, filledDenominator)
                denominator := mul(denominator, filledDenominator)

                // Increment the filled numerator by the new numerator.
                filledNumerator := add(numerator, filledNumerator)

                // Once adjusted, if current + supplied numerator exceeds
                // denominator:
                let carry := mul(
                    sub(filledNumerator, denominator),
                    gt(filledNumerator, denominator)
                )

                numerator := sub(numerator, carry)

                filledNumerator := sub(filledNumerator, carry)

                // Check filledNumerator and denominator for uint120 overflow.
                if or(
                    gt(filledNumerator, MaxUint120),
                    gt(denominator, MaxUint120)
                ) {
                    // Derive greatest common divisor using euclidean algorithm.
                    function gcd(_a, _b) -> out {
                        for {

                        } _b {

                        } {
                            let _c := _b
                            _b := mod(_a, _c)
                            _a := _c
                        }
                        out := _a
                    }
                    let scaleDown := gcd(
                        numerator,
                        gcd(filledNumerator, denominator)
                    )

                    // Ensure that the divisor is at least one.
                    let safeScaleDown := add(scaleDown, iszero(scaleDown))

                    // Scale all fractional values down by gcd.
                    numerator := div(numerator, safeScaleDown)
                    filledNumerator := div(filledNumerator, safeScaleDown)
                    denominator := div(denominator, safeScaleDown)

                    // Perform the overflow check a second time.
                    if or(
                        gt(filledNumerator, MaxUint120),
                        gt(denominator, MaxUint120)
                    ) {
                        // Store the Panic error signature.
                        mstore(0, Panic_error_selector)
                        // Store the arithmetic (0x11) panic code.
                        mstore(Panic_error_code_ptr, Panic_arithmetic)

                        // revert(abi.encodeWithSignature(
                        //     "Panic(uint256)", 0x11
                        // ))
                        revert(Error_selector_offset, Panic_error_length)
                    }
                }

                break
            }

            // Update order status and fill amount, packing struct values.
            // [denominator: 15 bytes] [numerator: 15 bytes]
            // [isCancelled: 1 byte] [isValidated: 1 byte]
            sstore(
                orderStatusSlot,
                or(
                    OrderStatus_ValidatedAndNotCancelled,
                    or(
                        shl(
                            OrderStatus_filledNumerator_offset,
                            filledNumerator
                        ),
                        shl(OrderStatus_filledDenominator_offset, denominator)
                    )
                )
            )
        }
    }

    /**
     * @dev Internal pure function to check the compatibility of two offer
     *      or consideration items for contract orders.
     *
     * @param originalItem The original offer or consideration item.
     * @param newItem      The new offer or consideration item.
     *
     * @return isInvalid Error buffer indicating if items are incompatible.
     */
    function _compareItems(
        MemoryPointer originalItem,
        MemoryPointer newItem
    ) internal pure returns (uint256 isInvalid) {
        assembly {
            let itemType := mload(originalItem)
            let identifier := mload(add(originalItem, Common_identifier_offset))

            // Set returned identifier for criteria-based items w/ criteria = 0.
            if and(gt(itemType, 3), iszero(identifier)) {
                // replace item type
                itemType := sub(3, eq(itemType, 4))
                identifier := mload(add(newItem, Common_identifier_offset))
            }

            let originalAmount := mload(add(originalItem, Common_amount_offset))
            let newAmount := mload(add(newItem, Common_amount_offset))

            isInvalid := iszero(
                and(
                    // originalItem.token == newItem.token &&
                    // originalItem.itemType == newItem.itemType
                    and(
                        eq(
                            mload(add(originalItem, Common_token_offset)),
                            mload(add(newItem, Common_token_offset))
                        ),
                        eq(itemType, mload(newItem))
                    ),
                    // originalItem.identifier == newItem.identifier &&
                    // originalItem.startAmount == originalItem.endAmount
                    and(
                        eq(
                            identifier,
                            mload(add(newItem, Common_identifier_offset))
                        ),
                        eq(
                            originalAmount,
                            mload(add(originalItem, Common_endAmount_offset))
                        )
                    )
                )
            )
        }
    }

    /**
     * @dev Internal pure function to check the compatibility of two recipients
     *      on consideration items for contract orders. This check is skipped if
     *      no recipient is originally supplied.
     *
     * @param originalRecipient The original consideration item recipient.
     * @param newRecipient      The new consideration item recipient.
     *
     * @return isInvalid Error buffer indicating if recipients are incompatible.
     */
    function _checkRecipients(
        address originalRecipient,
        address newRecipient
    ) internal pure returns (uint256 isInvalid) {
        assembly {
            isInvalid := iszero(
                or(
                    iszero(originalRecipient),
                    eq(newRecipient, originalRecipient)
                )
            )
        }
    }

    /**
     * @dev Internal function to generate a contract order.
     *
     * @param orderParameters The parameters for the order.
     * @param context         The context for generating the order.
     * @param revertOnInvalid Whether to revert on invalid input.
     *
     * @return orderHash   The order hash.
     * @return numerator   The numerator.
     * @return denominator The denominator.
     */
    function _getGeneratedOrder(
        OrderParameters memory orderParameters,
        bytes memory context,
        bool revertOnInvalid
    )
        internal
        returns (bytes32 orderHash, uint256 numerator, uint256 denominator)
    {
        // Ensure that consideration array length is equal to the total original
        // consideration items value.
        if (
            orderParameters.consideration.length !=
            orderParameters.totalOriginalConsiderationItems
        ) {
            _revertConsiderationLengthNotEqualToTotalOriginal();
        }

        {
            address offerer = orderParameters.offerer;
            bool success;
            (MemoryPointer cdPtr, uint256 size) = _encodeGenerateOrder(
                orderParameters,
                context
            );
            assembly {
                success := call(gas(), offerer, 0, cdPtr, size, 0, 0)
            }

            {
                // Note: overflow impossible; nonce can't increment that high.
                uint256 contractNonce;
                unchecked {
                    // Note: nonce will be incremented even for skipped orders.
                    contractNonce = _contractNonces[offerer]++;
                }

                assembly {
                    // Shift offerer address up 96 bytes and combine with nonce.
                    orderHash := xor(
                        contractNonce,
                        shl(ContractOrder_orderHash_offerer_shift, offerer)
                    )
                }
            }

            // Revert or skip if the call to generate the contract order failed.
            if (!success) {
                return _revertOrReturnEmpty(revertOnInvalid, orderHash);
            }
        }

        // Decode the returned contract order and/or update the error buffer.
        (
            uint256 errorBuffer,
            OfferItem[] memory offer,
            ConsiderationItem[] memory consideration
        ) = _convertGetGeneratedOrderResult(_decodeGenerateOrderReturndata)();

        // Revert or skip if the returndata could not be decoded correctly.
        if (errorBuffer != 0) {
            return _revertOrReturnEmpty(revertOnInvalid, orderHash);
        }

        {
            // Designate lengths.
            uint256 originalOfferLength = orderParameters.offer.length;
            uint256 newOfferLength = offer.length;

            // Explicitly specified offer items cannot be removed.
            if (originalOfferLength > newOfferLength) {
                return _revertOrReturnEmpty(revertOnInvalid, orderHash);
            }

            // Iterate over each specified offer (e.g. minimumReceived) item.
            for (uint256 i = 0; i < originalOfferLength; ) {
                // Retrieve the pointer to the originally supplied item.
                MemoryPointer mPtrOriginal = orderParameters
                    .offer[i]
                    .toMemoryPointer();

                // Retrieve the pointer to the newly returned item.
                MemoryPointer mPtrNew = offer[i].toMemoryPointer();

                // Compare the items and update the error buffer accordingly.
                errorBuffer |=
                    _cast(
                        mPtrOriginal
                            .offset(Common_amount_offset)
                            .readUint256() >
                            mPtrNew.offset(Common_amount_offset).readUint256()
                    ) |
                    _compareItems(mPtrOriginal, mPtrNew);

                // Increment the array (cannot overflow as index starts at 0).
                unchecked {
                    ++i;
                }
            }

            // Assign the returned offer item in place of the original item.
            orderParameters.offer = offer;
        }

        {
            // Designate lengths & memory locations.
            ConsiderationItem[] memory originalConsiderationArray = (
                orderParameters.consideration
            );
            uint256 newConsiderationLength = consideration.length;

            // New consideration items cannot be created.
            if (newConsiderationLength > originalConsiderationArray.length) {
                return _revertOrReturnEmpty(revertOnInvalid, orderHash);
            }

            // Iterate over returned consideration & do not exceed maximumSpent.
            for (uint256 i = 0; i < newConsiderationLength; ) {
                // Retrieve the pointer to the originally supplied item.
                MemoryPointer mPtrOriginal = originalConsiderationArray[i]
                    .toMemoryPointer();

                // Retrieve the pointer to the newly returned item.
                MemoryPointer mPtrNew = consideration[i].toMemoryPointer();

                // Compare the items and update the error buffer accordingly
                // and ensure that the recipients are equal when provided.
                errorBuffer |=
                    _cast(
                        mPtrNew.offset(Common_amount_offset).readUint256() >
                            mPtrOriginal
                                .offset(Common_amount_offset)
                                .readUint256()
                    ) |
                    _compareItems(mPtrOriginal, mPtrNew) |
                    _checkRecipients(
                        mPtrOriginal
                            .offset(ConsiderItem_recipient_offset)
                            .readAddress(),
                        mPtrNew
                            .offset(ConsiderItem_recipient_offset)
                            .readAddress()
                    );

                // Increment the array (cannot overflow as index starts at 0).
                unchecked {
                    ++i;
                }
            }

            // Assign returned consideration item in place of the original item.
            orderParameters.consideration = consideration;
        }

        // Revert or skip if any item comparison failed.
        if (errorBuffer != 0) {
            return _revertOrReturnEmpty(revertOnInvalid, orderHash);
        }

        // Return order hash and full fill amount (numerator & denominator = 1).
        return (orderHash, 1, 1);
    }

    /**
     * @dev Internal function to cancel an arbitrary number of orders. Note that
     *      only the offerer or the zone of a given order may cancel it. Callers
     *      should ensure that the intended order was cancelled by calling
     *      `getOrderStatus` and confirming that `isCancelled` returns `true`.
     *
     * @param orders The orders to cancel.
     *
     * @return cancelled A boolean indicating whether the supplied orders were
     *                   successfully cancelled.
     */
    function _cancel(
        OrderComponents[] calldata orders
    ) internal returns (bool cancelled) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Declare variables outside of the loop.
        OrderStatus storage orderStatus;

        // Accumulator for invariant in each loop
        bool anyInvalidCaller;

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Read length of the orders array from memory and place on stack.
            uint256 totalOrders = orders.length;

            // Iterate over each order.
            for (uint256 i = 0; i < totalOrders; ) {
                // Retrieve the order.
                OrderComponents calldata order = orders[i];
                address offerer = order.offerer;
                address zone = order.zone;

                assembly {
                    // If caller is neither offerer nor zone of order, ensure
                    // that is flagged.
                    anyInvalidCaller := or(
                        anyInvalidCaller,
                        // !(caller == offerer || caller == zone)
                        iszero(or(eq(caller(), offerer), eq(caller(), zone)))
                    )
                }

                bytes32 orderHash = _deriveOrderHash(
                    _toOrderParametersReturnType(
                        _decodeOrderComponentsAsOrderParameters
                    )(order.toCalldataPointer()),
                    order.counter
                );

                // Retrieve the order status using the derived order hash.
                orderStatus = _orderStatus[orderHash];

                // Update the order status as not valid and cancelled.
                orderStatus.isValidated = false;
                orderStatus.isCancelled = true;

                // Emit an event signifying that the order has been cancelled.
                emit OrderCancelled(orderHash, offerer, zone);

                // Increment counter inside body of loop for gas efficiency.
                ++i;
            }
        }

        if (anyInvalidCaller) {
            _revertInvalidCanceller();
        }

        // Return a boolean indicating that orders were successfully cancelled.
        cancelled = true;
    }

    /**
     * @dev Internal function to validate an arbitrary number of orders, thereby
     *      registering their signatures as valid and allowing the fulfiller to
     *      skip signature verification on fulfillment. Note that validated
     *      orders may still be unfulfillable due to invalid item amounts or
     *      other factors; callers should determine whether validated orders are
     *      fulfillable by simulating the fulfillment call prior to execution.
     *      Also note that anyone can validate a signed order, but only the
     *      offerer can validate an order without supplying a signature.
     *
     * @param orders The orders to validate.
     *
     * @return validated A boolean indicating whether the supplied orders were
     *                   successfully validated.
     */
    function _validate(
        Order[] memory orders
    ) internal returns (bool validated) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Declare variables outside of the loop.
        OrderStatus storage orderStatus;
        bytes32 orderHash;
        address offerer;

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Read length of the orders array from memory and place on stack.
            uint256 totalOrders = orders.length;

            // Iterate over each order.
            for (uint256 i = 0; i < totalOrders; ++i) {
                // Retrieve the order.
                Order memory order = orders[i];

                // Retrieve the order parameters.
                OrderParameters memory orderParameters = order.parameters;

                // Skip contract orders.
                if (orderParameters.orderType == OrderType.CONTRACT) {
                    continue;
                }

                // Move offerer from memory to the stack.
                offerer = orderParameters.offerer;

                // Get current counter & use it w/ params to derive order hash.
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
                    // Ensure that consideration array length is equal to the
                    // total original consideration items value.
                    if (
                        orderParameters.consideration.length !=
                        orderParameters.totalOriginalConsiderationItems
                    ) {
                        _revertConsiderationLengthNotEqualToTotalOriginal();
                    }

                    // Verify the supplied signature.
                    _verifySignature(offerer, orderHash, order.signature);

                    // Update order status to mark the order as valid.
                    orderStatus.isValidated = true;

                    // Emit an event signifying the order has been validated.
                    emit OrderValidated(orderHash, orderParameters);
                }
            }
        }

        // Return a boolean indicating that orders were successfully validated.
        validated = true;
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
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    /**
     * @dev Internal pure function to either revert or return an empty tuple
     *      depending on the value of `revertOnInvalid`.
     *
     * @param revertOnInvalid   Whether to revert on invalid input.
     * @param contractOrderHash The contract order hash.
     *
     * @return orderHash   The order hash.
     * @return numerator   The numerator.
     * @return denominator The denominator.
     */
    function _revertOrReturnEmpty(
        bool revertOnInvalid,
        bytes32 contractOrderHash
    )
        internal
        pure
        returns (bytes32 orderHash, uint256 numerator, uint256 denominator)
    {
        if (!revertOnInvalid) {
            return (contractOrderHash, 0, 0);
        }

        _revertInvalidContractOrder(contractOrderHash);
    }

    /**
     * @dev Internal pure function to check whether a given order type indicates
     *      that partial fills are not supported (e.g. only "full fills" are
     *      allowed for the order in question).
     *
     * @param orderType   The order type in question.
     * @param numerator   The numerator in question.
     * @param denominator The denominator in question.
     *
     * @return isFullOrder A boolean indicating whether the order type only
     *                     supports full fills.
     */
    function _doesNotSupportPartialFills(
        OrderType orderType,
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (bool isFullOrder) {
        // The "full" order types are even, while "partial" order types are odd.
        // Bitwise and by 1 is equivalent to modulo by 2, but 2 gas cheaper. The
        // check is only necessary if numerator is less than denominator.
        assembly {
            // Equivalent to `uint256(orderType) & 1 == 0`.
            isFullOrder := and(
                lt(numerator, denominator),
                iszero(and(orderType, 1))
            )
        }
    }
}
