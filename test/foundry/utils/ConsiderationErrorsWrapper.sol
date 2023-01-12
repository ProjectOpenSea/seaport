// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../contracts/lib/ConsiderationErrors.sol";

contract ConsiderationErrorsWrapper {
    /**
     * @dev Reverts the current transaction with a "BadFraction" error message.
     */
    function __revertBadFraction() external pure {
        _revertBadFraction();
    }

    /**
     * @dev Reverts the current transaction with a "ConsiderationNotMet" error
     *      message, including the provided order index, consideration index,
     * and
     *      shortfall amount.
     *
     * @param orderIndex         The index of the order that did not meet the
     *                           consideration criteria.
     * @param considerationIndex The index of the consideration item that did
     * not
     *                           meet its criteria.
     * @param shortfallAmount    The amount by which the consideration criteria
     * were
     *                           not met.
     */
    function __revertConsiderationNotMet(
        uint256 orderIndex,
        uint256 considerationIndex,
        uint256 shortfallAmount
    ) external pure {
        _revertConsiderationNotMet(
            orderIndex, considerationIndex, shortfallAmount
        );
    }

    /**
     * @dev Reverts the current transaction with a "CriteriaNotEnabledForItem"
     * error
     *      message.
     */
    function __revertCriteriaNotEnabledForItem() external pure {
        _revertCriteriaNotEnabledForItem();
    }

    /**
     * @dev Reverts the current transaction with an "InsufficientEtherSupplied"
     *      error message.
     */
    function __revertInsufficientEtherSupplied() external pure {
        _revertInsufficientEtherSupplied();
    }

    /**
     * @dev Reverts the current transaction with an
     *      "InvalidBasicOrderParameterEncoding" error message.
     */
    function __revertInvalidBasicOrderParameterEncoding() external pure {
        _revertInvalidBasicOrderParameterEncoding();
    }

    /**
     * @dev Reverts the current transaction with an "InvalidCallToConduit" error
     *      message, including the provided address of the conduit that was
     * called
     *      improperly.
     *
     * @param conduit The address of the conduit that was called improperly.
     */
    function __revertInvalidCallToConduit(address conduit) external pure {
        _revertInvalidCallToConduit(conduit);
    }

    /**
     * @dev Reverts the current transaction with an "InvalidCanceller" error
     *      message.
     */
    function __revertInvalidCanceller() external pure {
        _revertInvalidCanceller();
    }

    /**
     * @dev Reverts the current transaction with an "InvalidConduit" error
     * message,
     *      including the provided key and address of the invalid conduit.
     *
     * @param conduitKey    The key of the invalid conduit.
     * @param conduit       The address of the invalid conduit.
     */
    function __revertInvalidConduit(
        bytes32 conduitKey,
        address conduit
    ) external pure {
        _revertInvalidConduit(conduitKey, conduit);
    }

    /**
     * @dev Reverts the current transaction with an
     * "InvalidERC721TransferAmount"
     *      error message.
     *
     * @param amount The invalid amount.
     */
    function __revertInvalidERC721TransferAmount(uint256 amount)
        external
        pure
    {
        _revertInvalidERC721TransferAmount(amount);
    }

    /**
     * @dev Reverts the current transaction with an "InvalidMsgValue" error
     * message,
     *      including the invalid value that was sent in the transaction's
     *      `msg.value` field.
     *
     * @param value The invalid value that was sent in the transaction's
     * `msg.value`
     *              field.
     */
    function __revertInvalidMsgValue(uint256 value) external pure {
        _revertInvalidMsgValue(value);
    }

    /**
     * @dev Reverts the current transaction with an "InvalidNativeOfferItem"
     * error
     *      message.
     */
    function __revertInvalidNativeOfferItem() external pure {
        _revertInvalidNativeOfferItem();
    }

    /**
     * @dev Reverts the current transaction with an "InvalidProof" error
     * message.
     */
    function __revertInvalidProof() external pure {
        _revertInvalidProof();
    }

    /**
     * @dev Reverts the current transaction with an "InvalidContractOrder" error
     *      message.
     *
     * @param orderHash The hash of the contract order that caused the error.
     */
    function __revertInvalidContractOrder(bytes32 orderHash) external pure {
        _revertInvalidContractOrder(orderHash);
    }

    /**
     * @dev Reverts the current transaction with an "InvalidTime" error message.
     *
     * @param startTime       The time at which the order becomes active.
     * @param endTime         The time at which the order becomes inactive.
     */
    function __revertInvalidTime(
        uint256 startTime,
        uint256 endTime
    ) external pure {
        _revertInvalidTime(startTime, endTime);
    }

    /**
     * @dev Reverts execution with a
     *      "MismatchedFulfillmentOfferAndConsiderationComponents" error
     * message.
     *
     * @param fulfillmentIndex         The index of the fulfillment that caused
     * the
     *                                 error.
     */
    function __revertMismatchedFulfillmentOfferAndConsiderationComponents(
        uint256 fulfillmentIndex
    ) external pure {
        _revertMismatchedFulfillmentOfferAndConsiderationComponents(
            fulfillmentIndex
        );
    }

    /**
     * @dev Reverts execution with a "MissingFulfillmentComponentOnAggregation"
     *       error message.
     *
     * @param side The side of the fulfillment component that is missing (0 for
     *             offer, 1 for consideration).
     *
     */
    function __revertMissingFulfillmentComponentOnAggregation(Side side)
        external
        pure
    {
        _revertMissingFulfillmentComponentOnAggregation(side);
    }

    /**
     * @dev Reverts execution with a "MissingOriginalConsiderationItems" error
     *      message.
     */
    function __revertMissingOriginalConsiderationItems() external pure {
        _revertMissingOriginalConsiderationItems();
    }

    /**
     * @dev Reverts execution with a "NoReentrantCalls" error message.
     */
    function __revertNoReentrantCalls() external pure {
        _revertNoReentrantCalls();
    }

    /**
     * @dev Reverts execution with a "NoSpecifiedOrdersAvailable" error message.
     */
    function __revertNoSpecifiedOrdersAvailable() external pure {
        _revertNoSpecifiedOrdersAvailable();
    }

    /**
     * @dev Reverts execution with a
     * "OfferAndConsiderationRequiredOnFulfillment"
     *      error message.
     */
    function __revertOfferAndConsiderationRequiredOnFulfillment()
        external
        pure
    {
        _revertOfferAndConsiderationRequiredOnFulfillment();
    }

    /**
     * @dev Reverts execution with an "OrderAlreadyFilled" error message.
     *
     * @param orderHash The hash of the order that has already been filled.
     */
    function __revertOrderAlreadyFilled(bytes32 orderHash) external pure {
        _revertOrderAlreadyFilled(orderHash);
    }

    /**
     * @dev Reverts execution with an "OrderCriteriaResolverOutOfRange" error
     *      message.
     *
     * @param side The side of the criteria that is missing (0 for offer, 1 for
     *             consideration).
     *
     */
    function __revertOrderCriteriaResolverOutOfRange(Side side) external pure {
        _revertOrderCriteriaResolverOutOfRange(side);
    }

    /**
     * @dev Reverts execution with an "OrderIsCancelled" error message.
     *
     * @param orderHash The hash of the order that has already been cancelled.
     */
    function __revertOrderIsCancelled(bytes32 orderHash) external pure {
        _revertOrderIsCancelled(orderHash);
    }

    /**
     * @dev Reverts execution with an "OrderPartiallyFilled" error message.
     *
     * @param orderHash The hash of the order that has already been partially
     *                  filled.
     */
    function __revertOrderPartiallyFilled(bytes32 orderHash) external pure {
        _revertOrderPartiallyFilled(orderHash);
    }

    /**
     * @dev Reverts execution with a "PartialFillsNotEnabledForOrder" error
     * message.
     */
    function __revertPartialFillsNotEnabledForOrder() external pure {
        _revertPartialFillsNotEnabledForOrder();
    }

    /**
     * @dev Reverts execution with an "UnresolvedConsiderationCriteria" error
     *      message.
     */
    function __revertUnresolvedConsiderationCriteria(
        uint256 orderIndex,
        uint256 considerationIndex
    ) external pure {
        _revertUnresolvedConsiderationCriteria(orderIndex, considerationIndex);
    }

    /**
     * @dev Reverts execution with an "UnresolvedOfferCriteria" error message.
     */
    function __revertUnresolvedOfferCriteria(
        uint256 orderIndex,
        uint256 offerIndex
    ) external pure {
        _revertUnresolvedOfferCriteria(orderIndex, offerIndex);
    }

    /**
     * @dev Reverts execution with an "UnusedItemParameters" error message.
     */
    function __revertUnusedItemParameters() external pure {
        _revertUnusedItemParameters();
    }

    /**
     * @dev Reverts execution with a
     * "ConsiderationLengthNotEqualToTotalOriginal"
     *      error message.
     */
    function __revertConsiderationLengthNotEqualToTotalOriginal()
        external
        pure
    {
        _revertConsiderationLengthNotEqualToTotalOriginal();
    }
}
