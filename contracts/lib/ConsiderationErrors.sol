// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Side } from "./ConsiderationEnums.sol";

import "./ConsiderationConstants.sol";

/**
 * @dev Reverts the current transaction with a "BadFraction" error message.
 */
function _revertBadFraction() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, BadFraction_error_selector)

        // revert(abi.encodeWithSignature("BadFraction()"))
        revert(Error_selector_offset, BadFraction_error_length)
    }
}

/**
 * @dev Reverts the current transaction with a "ConsiderationNotMet" error
 *      message, including the provided order index, consideration index, and
 *      shortfall amount.
 *
 * @param orderIndex         The index of the order that did not meet the
 *                           consideration criteria.
 * @param considerationIndex The index of the consideration item that did not
 *                           meet its criteria.
 * @param shortfallAmount    The amount by which the consideration criteria were
 *                           not met.
 */
function _revertConsiderationNotMet(
    uint256 orderIndex,
    uint256 considerationIndex,
    uint256 shortfallAmount
) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, ConsiderationNotMet_error_selector)

        // Store arguments.
        mstore(ConsiderationNotMet_error_orderIndex_ptr, orderIndex)
        mstore(
            ConsiderationNotMet_error_considerationIndex_ptr,
            considerationIndex
        )
        mstore(ConsiderationNotMet_error_shortfallAmount_ptr, shortfallAmount)

        // revert(abi.encodeWithSignature(
        //     "ConsiderationNotMet(uint256,uint256,uint256)",
        //     orderIndex,
        //     considerationIndex,
        //     shortfallAmount
        // ))
        revert(Error_selector_offset, ConsiderationNotMet_error_length)
    }
}

/**
 * @dev Reverts the current transaction with a "CriteriaNotEnabledForItem" error
 *      message.
 */
function _revertCriteriaNotEnabledForItem() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, CriteriaNotEnabledForItem_error_selector)

        // revert(abi.encodeWithSignature("CriteriaNotEnabledForItem()"))
        revert(Error_selector_offset, CriteriaNotEnabledForItem_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InsufficientNativeTokenSupplied"
 *      error message.
 */
function _revertInsufficientNativeTokenSupplied() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InsufficientNativeTokenSupplied_error_selector)

        // revert(abi.encodeWithSignature("InsufficientNativeTokenSupplied()"))
        revert(Error_selector_offset, InsufficientNativeTokenSupplied_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an
 *      "InvalidBasicOrderParameterEncoding" error message.
 */
function _revertInvalidBasicOrderParameterEncoding() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidBasicOrderParameterEncoding_error_selector)

        // revert(abi.encodeWithSignature(
        //     "InvalidBasicOrderParameterEncoding()"
        // ))
        revert(
            Error_selector_offset,
            InvalidBasicOrderParameterEncoding_error_length
        )
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidCallToConduit" error
 *      message, including the provided address of the conduit that was called
 *      improperly.
 *
 * @param conduit The address of the conduit that was called improperly.
 */
function _revertInvalidCallToConduit(address conduit) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidCallToConduit_error_selector)

        // Store argument.
        mstore(InvalidCallToConduit_error_conduit_ptr, conduit)

        // revert(abi.encodeWithSignature(
        //     "InvalidCallToConduit(address)",
        //     conduit
        // ))
        revert(Error_selector_offset, InvalidCallToConduit_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "CannotCancelOrder" error
 *      message.
 */
function _revertCannotCancelOrder() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, CannotCancelOrder_error_selector)

        // revert(abi.encodeWithSignature("CannotCancelOrder()"))
        revert(Error_selector_offset, CannotCancelOrder_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidConduit" error message,
 *      including the provided key and address of the invalid conduit.
 *
 * @param conduitKey    The key of the invalid conduit.
 * @param conduit       The address of the invalid conduit.
 */
function _revertInvalidConduit(bytes32 conduitKey, address conduit) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidConduit_error_selector)

        // Store arguments.
        mstore(InvalidConduit_error_conduitKey_ptr, conduitKey)
        mstore(InvalidConduit_error_conduit_ptr, conduit)

        // revert(abi.encodeWithSignature(
        //     "InvalidConduit(bytes32,address)",
        //     conduitKey,
        //     conduit
        // ))
        revert(Error_selector_offset, InvalidConduit_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidERC721TransferAmount"
 *      error message.
 *
 * @param amount The invalid amount.
 */
function _revertInvalidERC721TransferAmount(uint256 amount) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidERC721TransferAmount_error_selector)

        // Store argument.
        mstore(InvalidERC721TransferAmount_error_amount_ptr, amount)

        // revert(abi.encodeWithSignature(
        //     "InvalidERC721TransferAmount(uint256)",
        //     amount
        // ))
        revert(Error_selector_offset, InvalidERC721TransferAmount_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidMsgValue" error message,
 *      including the invalid value that was sent in the transaction's
 *      `msg.value` field.
 *
 * @param value The invalid value that was sent in the transaction's `msg.value`
 *              field.
 */
function _revertInvalidMsgValue(uint256 value) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidMsgValue_error_selector)

        // Store argument.
        mstore(InvalidMsgValue_error_value_ptr, value)

        // revert(abi.encodeWithSignature("InvalidMsgValue(uint256)", value))
        revert(Error_selector_offset, InvalidMsgValue_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidNativeOfferItem" error
 *      message.
 */
function _revertInvalidNativeOfferItem() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidNativeOfferItem_error_selector)

        // revert(abi.encodeWithSignature("InvalidNativeOfferItem()"))
        revert(Error_selector_offset, InvalidNativeOfferItem_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidProof" error message.
 */
function _revertInvalidProof() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidProof_error_selector)

        // revert(abi.encodeWithSignature("InvalidProof()"))
        revert(Error_selector_offset, InvalidProof_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidContractOrder" error
 *      message.
 *
 * @param orderHash The hash of the contract order that caused the error.
 */
function _revertInvalidContractOrder(bytes32 orderHash) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidContractOrder_error_selector)

        // Store arguments.
        mstore(InvalidContractOrder_error_orderHash_ptr, orderHash)

        // revert(abi.encodeWithSignature(
        //     "InvalidContractOrder(bytes32)",
        //     orderHash
        // ))
        revert(Error_selector_offset, InvalidContractOrder_error_length)
    }
}

/**
 * @dev Reverts the current transaction with an "InvalidTime" error message.
 *
 * @param startTime       The time at which the order becomes active.
 * @param endTime         The time at which the order becomes inactive.
 */
function _revertInvalidTime(uint256 startTime, uint256 endTime) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, InvalidTime_error_selector)

        // Store arguments.
        mstore(InvalidTime_error_startTime_ptr, startTime)
        mstore(InvalidTime_error_endTime_ptr, endTime)

        // revert(abi.encodeWithSignature(
        //     "InvalidTime(uint256,uint256)",
        //     startTime,
        //     endTime
        // ))
        revert(Error_selector_offset, InvalidTime_error_length)
    }
}

/**
 * @dev Reverts execution with a
 *      "MismatchedFulfillmentOfferAndConsiderationComponents" error message.
 *
 * @param fulfillmentIndex         The index of the fulfillment that caused the
 *                                 error.
 */
function _revertMismatchedFulfillmentOfferAndConsiderationComponents(
    uint256 fulfillmentIndex
) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(
            0,
            MismatchedFulfillmentOfferAndConsiderationComponents_error_selector
        )

        // Store argument.
        mstore(
            MismatchedFulfillmentOfferAndConsiderationComponents_error_fulfillmentIndex_ptr,
            fulfillmentIndex
        )

        // revert(abi.encodeWithSignature(
        //     "MismatchedFulfillmentOfferAndConsiderationComponents(uint256)",
        //     fulfillmentIndex
        // ))
        revert(
            Error_selector_offset,
            MismatchedFulfillmentOfferAndConsiderationComponents_error_length
        )
    }
}

/**
 * @dev Reverts execution with a "MissingFulfillmentComponentOnAggregation"
 *       error message.
 *
 * @param side The side of the fulfillment component that is missing (0 for
 *             offer, 1 for consideration).
 *
 */
function _revertMissingFulfillmentComponentOnAggregation(Side side) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, MissingFulfillmentComponentOnAggregation_error_selector)

        // Store argument.
        mstore(MissingFulfillmentComponentOnAggregation_error_side_ptr, side)

        // revert(abi.encodeWithSignature(
        //     "MissingFulfillmentComponentOnAggregation(uint8)",
        //     side
        // ))
        revert(
            Error_selector_offset,
            MissingFulfillmentComponentOnAggregation_error_length
        )
    }
}

/**
 * @dev Reverts execution with a "MissingOriginalConsiderationItems" error
 *      message.
 */
function _revertMissingOriginalConsiderationItems() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, MissingOriginalConsiderationItems_error_selector)

        // revert(abi.encodeWithSignature(
        //     "MissingOriginalConsiderationItems()"
        // ))
        revert(
            Error_selector_offset,
            MissingOriginalConsiderationItems_error_length
        )
    }
}

/**
 * @dev Reverts execution with a "NoReentrantCalls" error message.
 */
function _revertNoReentrantCalls() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, NoReentrantCalls_error_selector)

        // revert(abi.encodeWithSignature("NoReentrantCalls()"))
        revert(Error_selector_offset, NoReentrantCalls_error_length)
    }
}

/**
 * @dev Reverts execution with a "NoSpecifiedOrdersAvailable" error message.
 */
function _revertNoSpecifiedOrdersAvailable() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, NoSpecifiedOrdersAvailable_error_selector)

        // revert(abi.encodeWithSignature("NoSpecifiedOrdersAvailable()"))
        revert(Error_selector_offset, NoSpecifiedOrdersAvailable_error_length)
    }
}

/**
 * @dev Reverts execution with a "OfferAndConsiderationRequiredOnFulfillment"
 *      error message.
 */
function _revertOfferAndConsiderationRequiredOnFulfillment() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, OfferAndConsiderationRequiredOnFulfillment_error_selector)

        // revert(abi.encodeWithSignature(
        //     "OfferAndConsiderationRequiredOnFulfillment()"
        // ))
        revert(
            Error_selector_offset,
            OfferAndConsiderationRequiredOnFulfillment_error_length
        )
    }
}

/**
 * @dev Reverts execution with an "OrderAlreadyFilled" error message.
 *
 * @param orderHash The hash of the order that has already been filled.
 */
function _revertOrderAlreadyFilled(bytes32 orderHash) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, OrderAlreadyFilled_error_selector)

        // Store argument.
        mstore(OrderAlreadyFilled_error_orderHash_ptr, orderHash)

        // revert(abi.encodeWithSignature(
        //     "OrderAlreadyFilled(bytes32)",
        //     orderHash
        // ))
        revert(Error_selector_offset, OrderAlreadyFilled_error_length)
    }
}

/**
 * @dev Reverts execution with an "OrderCriteriaResolverOutOfRange" error
 *      message.
 *
 * @param side The side of the criteria that is missing (0 for offer, 1 for
 *             consideration).
 *
 */
function _revertOrderCriteriaResolverOutOfRange(Side side) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, OrderCriteriaResolverOutOfRange_error_selector)

        // Store argument.
        mstore(OrderCriteriaResolverOutOfRange_error_side_ptr, side)

        // revert(abi.encodeWithSignature(
        //     "OrderCriteriaResolverOutOfRange(uint8)",
        //     side
        // ))
        revert(
            Error_selector_offset,
            OrderCriteriaResolverOutOfRange_error_length
        )
    }
}

/**
 * @dev Reverts execution with an "OrderIsCancelled" error message.
 *
 * @param orderHash The hash of the order that has already been cancelled.
 */
function _revertOrderIsCancelled(bytes32 orderHash) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, OrderIsCancelled_error_selector)

        // Store argument.
        mstore(OrderIsCancelled_error_orderHash_ptr, orderHash)

        // revert(abi.encodeWithSignature(
        //     "OrderIsCancelled(bytes32)",
        //     orderHash
        // ))
        revert(Error_selector_offset, OrderIsCancelled_error_length)
    }
}

/**
 * @dev Reverts execution with an "OrderPartiallyFilled" error message.
 *
 * @param orderHash The hash of the order that has already been partially
 *                  filled.
 */
function _revertOrderPartiallyFilled(bytes32 orderHash) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, OrderPartiallyFilled_error_selector)

        // Store argument.
        mstore(OrderPartiallyFilled_error_orderHash_ptr, orderHash)

        // revert(abi.encodeWithSignature(
        //     "OrderPartiallyFilled(bytes32)",
        //     orderHash
        // ))
        revert(Error_selector_offset, OrderPartiallyFilled_error_length)
    }
}

/**
 * @dev Reverts execution with a "PartialFillsNotEnabledForOrder" error message.
 */
function _revertPartialFillsNotEnabledForOrder() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, PartialFillsNotEnabledForOrder_error_selector)

        // revert(abi.encodeWithSignature("PartialFillsNotEnabledForOrder()"))
        revert(
            Error_selector_offset,
            PartialFillsNotEnabledForOrder_error_length
        )
    }
}

/**
 * @dev Reverts execution with an "UnresolvedConsiderationCriteria" error
 *      message.
 */
function _revertUnresolvedConsiderationCriteria(
    uint256 orderIndex,
    uint256 considerationIndex
) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, UnresolvedConsiderationCriteria_error_selector)

        // Store arguments.
        mstore(UnresolvedConsiderationCriteria_error_orderIndex_ptr, orderIndex)
        mstore(
            UnresolvedConsiderationCriteria_error_considerationIndex_ptr,
            considerationIndex
        )

        // revert(abi.encodeWithSignature(
        //     "UnresolvedConsiderationCriteria(uint256, uint256)",
        //     orderIndex,
        //     considerationIndex
        // ))
        revert(
            Error_selector_offset,
            UnresolvedConsiderationCriteria_error_length
        )
    }
}

/**
 * @dev Reverts execution with an "UnresolvedOfferCriteria" error message.
 */
function _revertUnresolvedOfferCriteria(
    uint256 orderIndex,
    uint256 offerIndex
) pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, UnresolvedOfferCriteria_error_selector)

        // Store arguments.
        mstore(UnresolvedOfferCriteria_error_orderIndex_ptr, orderIndex)
        mstore(UnresolvedOfferCriteria_error_offerIndex_ptr, offerIndex)

        // revert(abi.encodeWithSignature(
        //     "UnresolvedOfferCriteria(uint256, uint256)",
        //     orderIndex,
        //     offerIndex
        // ))
        revert(Error_selector_offset, UnresolvedOfferCriteria_error_length)
    }
}

/**
 * @dev Reverts execution with an "UnusedItemParameters" error message.
 */
function _revertUnusedItemParameters() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, UnusedItemParameters_error_selector)

        // revert(abi.encodeWithSignature("UnusedItemParameters()"))
        revert(Error_selector_offset, UnusedItemParameters_error_length)
    }
}

/**
 * @dev Reverts execution with a "ConsiderationLengthNotEqualToTotalOriginal"
 *      error message.
 */
function _revertConsiderationLengthNotEqualToTotalOriginal() pure {
    assembly {
        // Store left-padded selector with push4 (reduces bytecode),
        // mem[28:32] = selector
        mstore(0, ConsiderationLengthNotEqualToTotalOriginal_error_selector)

        // revert(abi.encodeWithSignature(
        //     "ConsiderationLengthNotEqualToTotalOriginal()"
        // ))
        revert(
            Error_selector_offset,
            ConsiderationLengthNotEqualToTotalOriginal_error_length
        )
    }
}
