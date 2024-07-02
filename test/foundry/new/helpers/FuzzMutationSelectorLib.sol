// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    ReceivedItem
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";
import { FuzzMutations, MutationFilters } from "./FuzzMutations.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import {
    FailureEligibilityLib,
    MutationEligibilityLib,
    Failarray,
    FailureDetails,
    FailureDetailsHelperLib,
    IneligibilityFilter,
    MutationContextDerivation,
    MutationContextDeriverLib
} from "./FuzzMutationHelpers.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    SignatureVerificationErrors
} from "seaport-types/src/interfaces/SignatureVerificationErrors.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    FulfillmentApplicationErrors
} from "seaport-types/src/interfaces/FulfillmentApplicationErrors.sol";

import {
    CriteriaResolutionErrors
} from "seaport-types/src/interfaces/CriteriaResolutionErrors.sol";

import {
    TokenTransferrerErrors
} from "seaport-types/src/interfaces/TokenTransferrerErrors.sol";

import {
    ZoneInteractionErrors
} from "seaport-types/src/interfaces/ZoneInteractionErrors.sol";

import {
    AmountDerivationErrors
} from "seaport-types/src/interfaces/AmountDerivationErrors.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

/////////////////////// UPDATE THIS TO ADD FAILURE TESTS ///////////////////////
enum Failure {
    InvalidSignature, // EOA signature is incorrect length
    InvalidSigner_BadSignature, // EOA signature has been tampered with
    InvalidSigner_ModifiedOrder, // Order with no-code offerer has been tampered with
    BadSignatureV, // EOA signature has bad v value
    BadContractSignature_BadSignature, // 1271 call to offerer, signature tampered with
    BadContractSignature_ModifiedOrder, // Order with offerer with code tampered with
    BadContractSignature_MissingMagic, // 1271 call to offerer, no magic value returned
    ConsiderationLengthNotEqualToTotalOriginal_ExtraItems, // Tips on contract order or validate
    ConsiderationLengthNotEqualToTotalOriginal_MissingItems, // Tips on contract order or validate
    MissingOriginalConsiderationItems, // Consideration array shorter than totalOriginalConsiderationItems
    InvalidTime_NotStarted, // Order with start time in the future
    InvalidTime_Expired, // Order with end time in the past
    InvalidConduit, // Order with invalid conduit
    BadFraction_PartialContractOrder, // Contract order w/ numerator & denominator != 1
    BadFraction_NoFill, // Order where numerator = 0
    BadFraction_Overfill, // Order where numerator > denominator
    CannotCancelOrder, // Caller cannot cancel order
    OrderIsCancelled, // Order is cancelled
    OrderAlreadyFilled, // Order is already filled
    InvalidFulfillmentComponentData, // Fulfillment component data is invalid
    MissingFulfillmentComponentOnAggregation, // Missing component
    OfferAndConsiderationRequiredOnFulfillment, // Fulfillment missing offer or consideration
    MismatchedFulfillmentOfferAndConsiderationComponents_Modified, // Fulfillment has mismatched offer and consideration components
    MismatchedFulfillmentOfferAndConsiderationComponents_Swapped, // Fulfillment has mismatched offer and consideration components
    Error_OfferItemMissingApproval, // Order has an offer item without sufficient approval
    Error_CallerMissingApproval, // Order has a consideration item where caller is not approved
    InvalidMsgValue, // Invalid msg.value amount
    InsufficientNativeTokensSupplied, // Caller does not supply sufficient native tokens
    NativeTokenTransferGenericFailure, // Insufficient native tokens with unspent offer items
    CriteriaNotEnabledForItem, // Criteria resolver applied to non-criteria-based item
    InvalidProof_Merkle, // Bad or missing proof for non-wildcard criteria item
    InvalidProof_Wildcard, // Non-empty proof supplied for wildcard criteria item
    OrderCriteriaResolverOutOfRange, // Criteria resolver refers to OOR order
    OfferCriteriaResolverOutOfRange, // Criteria resolver refers to OOR offer item
    ConsiderationCriteriaResolverOutOfRange, // Criteria resolver refers to OOR consideration item
    UnresolvedOfferCriteria, // Missing criteria resolution for an offer item
    UnresolvedConsiderationCriteria, // Missing criteria resolution for a consideration item
    MissingItemAmount_OfferItem_FulfillAvailable, // Zero amount for offer item in fulfillAvailable
    MissingItemAmount_OfferItem, // Zero amount for offer item in all other methods
    MissingItemAmount_ConsiderationItem, // Zero amount for consideration item
    InvalidContractOrder_generateReturnsInvalidEncoding, // Offerer generateOrder returns invalid data
    InvalidContractOrder_generateReverts, // Offerer generateOrder reverts
    InvalidContractOrder_ratifyReverts, // Offerer ratifyOrder reverts
    InvalidContractOrder_InsufficientMinimumReceived, // too few minimum received items
    InvalidContractOrder_IncorrectMinimumReceived, // incorrect (insufficient amount, wrong token, etc.) minimum received items
    InvalidContractOrder_ExcessMaximumSpent, // too many maximum spent items
    InvalidContractOrder_IncorrectMaximumSpent, // incorrect (too many, wrong token, etc.) maximum spent items
    InvalidContractOrder_InvalidMagicValue, // Offerer did not return correct magic value
    InvalidRestrictedOrder_authorizeReverts_matchReverts, // Zone authorizeOrder call reverts and triggers a top level match* revert
    InvalidRestrictedOrder_validateReverts, // Zone validateOrder call reverts
    InvalidRestrictedOrder_authorizeInvalidMagicValue, // Zone authorizeOrder call returns invalid magic value
    InvalidRestrictedOrder_validateInvalidMagicValue, // Zone validateOrder call returns invalid magic value
    NoContract, // Trying to transfer a token at an address that has no contract
    UnusedItemParameters_Token, // Native item with non-zero token
    UnusedItemParameters_Identifier, // Native or ERC20 item with non-zero identifier
    InvalidERC721TransferAmount, // ERC721 transfer amount is not 1
    ConsiderationNotMet, // Consideration item not fully credited (match case)
    PartialFillsNotEnabledForOrder, // Partial fill on non-partial order type
    InexactFraction, // numerator / denominator cannot be applied to item w/ no remainder
    Panic_PartialFillOverflow, // numerator / denominator overflow current fill fraction
    NoSpecifiedOrdersAvailable, // all fulfillAvailable executions are filtered
    length // NOT A FAILURE; used to get the number of failures in the enum
}

////////////////////////////////////////////////////////////////////////////////

library FuzzMutationSelectorLib {
    using Failarray for Failure;
    using Failarray for Failure[];
    using FuzzEngineLib for FuzzTestContext;
    using FailureDetailsLib for FuzzTestContext;
    using FailureEligibilityLib for FuzzTestContext;
    using MutationEligibilityLib for FuzzTestContext;
    using MutationEligibilityLib for Failure;
    using MutationEligibilityLib for Failure[];
    using FailureEligibilityLib for IneligibilityFilter[];

    function declareFilters()
        internal
        pure
        returns (IneligibilityFilter[] memory failuresAndFilters)
    {
        // Set failure conditions as ineligible when no orders support them.
        // Create abundantly long array to avoid potentially cryptic OOR errors.
        failuresAndFilters = new IneligibilityFilter[](256);
        uint256 i = 0;

        /////////////////// UPDATE THIS TO ADD FAILURE TESTS ///////////////////
        failuresAndFilters[i++] = Failure.InvalidSignature.withOrder(
            MutationFilters.ineligibleForInvalidSignature
        );

        failuresAndFilters[i++] = Failure
            .InvalidSigner_BadSignature
            .and(Failure.InvalidSigner_ModifiedOrder)
            .withOrder(MutationFilters.ineligibleForInvalidSigner);

        failuresAndFilters[i++] = Failure
            .InvalidTime_NotStarted
            .and(Failure.InvalidTime_Expired)
            .withOrder(MutationFilters.ineligibleForInvalidTime);

        failuresAndFilters[i++] = Failure.InvalidConduit.withOrder(
            MutationFilters.ineligibleForInvalidConduit
        );

        failuresAndFilters[i++] = Failure.BadSignatureV.withOrder(
            MutationFilters.ineligibleForBadSignatureV
        );

        failuresAndFilters[i++] = Failure
            .BadFraction_PartialContractOrder
            .withOrder(
                MutationFilters.ineligibleForBadFractionPartialContractOrder
            );

        failuresAndFilters[i++] = Failure.BadFraction_Overfill.withOrder(
            MutationFilters.ineligibleForBadFraction
        );

        failuresAndFilters[i++] = Failure.BadFraction_NoFill.withOrder(
            MutationFilters.ineligibleForBadFraction_noFill
        );

        failuresAndFilters[i++] = Failure.CannotCancelOrder.withOrder(
            MutationFilters.ineligibleForCannotCancelOrder
        );

        failuresAndFilters[i++] = Failure.OrderIsCancelled.withOrder(
            MutationFilters.ineligibleForOrderIsCancelled
        );

        failuresAndFilters[i++] = Failure.OrderAlreadyFilled.withOrder(
            MutationFilters.ineligibleForOrderAlreadyFilled
        );

        failuresAndFilters[i++] = Failure
            .BadContractSignature_BadSignature
            .and(Failure.BadContractSignature_ModifiedOrder)
            .and(Failure.BadContractSignature_MissingMagic)
            .withOrder(MutationFilters.ineligibleForBadContractSignature);

        failuresAndFilters[i++] = Failure
            .MissingOriginalConsiderationItems
            .withOrder(
                MutationFilters.ineligibleForMissingOriginalConsiderationItems
            );

        failuresAndFilters[i++] = Failure
            .ConsiderationLengthNotEqualToTotalOriginal_ExtraItems
            .withOrder(
                MutationFilters
                    .ineligibleForConsiderationLengthNotEqualToTotalOriginal
            );

        failuresAndFilters[i++] = Failure
            .ConsiderationLengthNotEqualToTotalOriginal_MissingItems
            .withOrder(
                MutationFilters
                    .ineligibleForConsiderationLengthNotEqualToTotalOriginal
            );

        failuresAndFilters[i++] = Failure
            .InvalidFulfillmentComponentData
            .withGeneric(
                MutationFilters.ineligibleForInvalidFulfillmentComponentData
            );

        failuresAndFilters[i++] = Failure
            .MissingFulfillmentComponentOnAggregation
            .withGeneric(
                MutationFilters
                    .ineligibleForMissingFulfillmentComponentOnAggregation
            );

        failuresAndFilters[i++] = Failure
            .OfferAndConsiderationRequiredOnFulfillment
            .withGeneric(
                MutationFilters
                    .ineligibleForOfferAndConsiderationRequiredOnFulfillment
            );

        failuresAndFilters[i++] = Failure
            .MismatchedFulfillmentOfferAndConsiderationComponents_Modified
            .withGeneric(
                MutationFilters
                    .ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents_Modified
            );

        failuresAndFilters[i++] = Failure
            .MismatchedFulfillmentOfferAndConsiderationComponents_Swapped
            .withGeneric(
                MutationFilters
                    .ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents_Swapped
            );

        failuresAndFilters[i++] = Failure
            .Error_OfferItemMissingApproval
            .withOrder(MutationFilters.ineligibleForOfferItemMissingApproval);

        failuresAndFilters[i++] = Failure.Error_CallerMissingApproval.withOrder(
            MutationFilters.ineligibleForCallerMissingApproval
        );

        failuresAndFilters[i++] = Failure.InvalidMsgValue.withGeneric(
            MutationFilters.ineligibleForInvalidMsgValue
        );

        failuresAndFilters[i++] = Failure
            .InsufficientNativeTokensSupplied
            .withGeneric(MutationFilters.ineligibleForInsufficientNativeTokens);

        failuresAndFilters[i++] = Failure
            .NativeTokenTransferGenericFailure
            .withGeneric(
                MutationFilters.ineligibleForNativeTokenTransferGenericFailure
            );

        failuresAndFilters[i++] = Failure.CriteriaNotEnabledForItem.withGeneric(
            MutationFilters.ineligibleForCriteriaNotEnabledForItem
        );

        failuresAndFilters[i++] = Failure.InvalidProof_Merkle.withCriteria(
            MutationFilters.ineligibleForInvalidProof_Merkle
        );

        failuresAndFilters[i++] = Failure.InvalidProof_Wildcard.withCriteria(
            MutationFilters.ineligibleForInvalidProof_Wildcard
        );

        failuresAndFilters[i++] = Failure
            .OrderCriteriaResolverOutOfRange
            .withGeneric(MutationFilters.ineligibleWhenNotAdvanced);

        failuresAndFilters[i++] = Failure
            .OfferCriteriaResolverOutOfRange
            .and(Failure.UnresolvedOfferCriteria)
            .withCriteria(
                MutationFilters.ineligibleForOfferCriteriaResolverFailure
            );

        failuresAndFilters[i++] = Failure
            .ConsiderationCriteriaResolverOutOfRange
            .and(Failure.UnresolvedConsiderationCriteria)
            .withCriteria(
                MutationFilters
                    .ineligibleForConsiderationCriteriaResolverFailure
            );

        failuresAndFilters[i++] = Failure
            .MissingItemAmount_OfferItem_FulfillAvailable
            .withGeneric(
                MutationFilters
                    .ineligibleForMissingItemAmount_OfferItem_FulfillAvailable
            );

        failuresAndFilters[i++] = Failure.MissingItemAmount_OfferItem.withOrder(
            MutationFilters.ineligibleForMissingItemAmount_OfferItem
        );

        failuresAndFilters[i++] = Failure
            .MissingItemAmount_ConsiderationItem
            .withOrder(
                MutationFilters.ineligibleForMissingItemAmount_ConsiderationItem
            );

        failuresAndFilters[i++] = Failure
            .InvalidContractOrder_generateReturnsInvalidEncoding
            .and(Failure.InvalidContractOrder_generateReverts)
            .withOrder(
                MutationFilters.ineligibleWhenNotContractOrderOrFulfillAvailable
            );

        failuresAndFilters[i++] = Failure
            .InvalidContractOrder_ratifyReverts
            .and(Failure.InvalidContractOrder_InvalidMagicValue)
            .withOrder(
                MutationFilters.ineligibleWhenNotAvailableOrNotContractOrder
            );

        failuresAndFilters[i++] = Failure
            .InvalidContractOrder_InsufficientMinimumReceived
            .and(Failure.InvalidContractOrder_IncorrectMinimumReceived)
            .withOrder(
                MutationFilters
                    .ineligibleWhenNotActiveTimeOrNotContractOrderOrNoOffer
            );

        failuresAndFilters[i++] = Failure
            .InvalidContractOrder_ExcessMaximumSpent
            .withOrder(
                MutationFilters.ineligibleWhenNotActiveTimeOrNotContractOrder
            );

        failuresAndFilters[i++] = Failure
            .InvalidContractOrder_IncorrectMaximumSpent
            .withOrder(
                MutationFilters
                    .ineligibleWhenNotActiveTimeOrNotContractOrderOrNoConsideration
            );

        failuresAndFilters[i++] = Failure
            .InvalidRestrictedOrder_authorizeReverts_matchReverts
            .withOrder(
                MutationFilters
                    .ineligibleWhenFulfillAvailableOrNotAvailableOrNotRestricted
            );

        failuresAndFilters[i++] = Failure
            .InvalidRestrictedOrder_authorizeInvalidMagicValue
            .and(Failure.InvalidRestrictedOrder_validateReverts)
            .and(Failure.InvalidRestrictedOrder_validateInvalidMagicValue)
            .withOrder(
                MutationFilters.ineligibleWhenNotAvailableOrNotRestrictedOrder
            );

        failuresAndFilters[i++] = Failure.NoContract.withGeneric(
            MutationFilters.ineligibleForNoContract
        );

        failuresAndFilters[i++] = Failure.UnusedItemParameters_Token.withOrder(
            MutationFilters.ineligibleForUnusedItemParameters_Token
        );

        failuresAndFilters[i++] = Failure
            .UnusedItemParameters_Identifier
            .withOrder(
                MutationFilters.ineligibleForUnusedItemParameters_Identifier
            );

        failuresAndFilters[i++] = Failure.InvalidERC721TransferAmount.withOrder(
            MutationFilters.ineligibleForInvalidERC721TransferAmount
        );

        failuresAndFilters[i++] = Failure.ConsiderationNotMet.withOrder(
            MutationFilters.ineligibleForConsiderationNotMet
        );

        failuresAndFilters[i++] = Failure
            .PartialFillsNotEnabledForOrder
            .withOrder(
                MutationFilters.ineligibleForPartialFillsNotEnabledForOrder
            );

        failuresAndFilters[i++] = Failure.InexactFraction.withOrder(
            MutationFilters.ineligibleForInexactFraction
        );

        failuresAndFilters[i++] = Failure.Panic_PartialFillOverflow.withOrder(
            MutationFilters.ineligibleForPanic_PartialFillOverflow
        );

        failuresAndFilters[i++] = Failure
            .NoSpecifiedOrdersAvailable
            .withGeneric(
                MutationFilters.ineligibleForNoSpecifiedOrdersAvailable
            );
        ////////////////////////////////////////////////////////////////////////

        // Set the actual length of the array.
        assembly {
            mstore(failuresAndFilters, i)
        }
    }

    function selectMutation(
        FuzzTestContext memory context
    )
        public
        returns (
            string memory name,
            bytes4 mutationSelector,
            bytes memory expectedRevertReason,
            MutationState memory mutationState
        )
    {
        // Mark each failure conditions as ineligible if no orders support them.
        IneligibilityFilter[] memory failuresAndFilters = declareFilters();

        // Ensure all failures have at least one associated filter.
        failuresAndFilters.ensureFilterSetForEachFailure();

        // Evaluate each filter and assign respective ineligible failures.
        context.setAllIneligibleFailures(failuresAndFilters);

        (name, mutationSelector, expectedRevertReason, mutationState) = context
            .failureDetails(
                context.selectEligibleFailure(),
                failuresAndFilters
            );
    }
}

library FailureDetailsLib {
    using FailureDetailsHelperLib for bytes4;
    using FailureDetailsHelperLib for FuzzTestContext;
    using MutationContextDeriverLib for FuzzTestContext;
    using FailureEligibilityLib for IneligibilityFilter[];

    bytes4 constant PANIC = bytes4(0x4e487b71);
    bytes4 constant ERROR_STRING = bytes4(0x08c379a0);

    function declareFailureDetails()
        internal
        pure
        returns (FailureDetails[] memory failureDetailsArray)
    {
        // Set details, including error selector, name, mutation selector, and
        // an optional function for deriving revert reasons, for each failure.
        // Create a longer array to avoid potentially cryptic OOR errors.
        failureDetailsArray = new FailureDetails[](uint256(Failure.length) + 9);
        uint256 i = 0;

        /////////////////// UPDATE THIS TO ADD FAILURE TESTS ///////////////////
        failureDetailsArray[i++] = SignatureVerificationErrors
            .InvalidSignature
            .selector
            .withOrder(
                "InvalidSignature",
                FuzzMutations.mutation_invalidSignature.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .InvalidSigner
            .selector
            .withOrder(
                "InvalidSigner_BadSignature",
                FuzzMutations.mutation_invalidSigner_BadSignature.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .InvalidSigner
            .selector
            .withOrder(
                "InvalidSigner_ModifiedOrder",
                FuzzMutations.mutation_invalidSigner_ModifiedOrder.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .BadSignatureV
            .selector
            .withOrder(
                "BadSignatureV",
                FuzzMutations.mutation_badSignatureV.selector,
                details_BadSignatureV
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .BadContractSignature
            .selector
            .withOrder(
                "BadContractSignature_BadSignature",
                FuzzMutations
                    .mutation_badContractSignature_BadSignature
                    .selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .BadContractSignature
            .selector
            .withOrder(
                "BadContractSignature_ModifiedOrder",
                FuzzMutations
                    .mutation_badContractSignature_ModifiedOrder
                    .selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .BadContractSignature
            .selector
            .withOrder(
                "BadContractSignature_MissingMagic",
                FuzzMutations
                    .mutation_badContractSignature_MissingMagic
                    .selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .ConsiderationLengthNotEqualToTotalOriginal
            .selector
            .withOrder(
                "ConsiderationLengthNotEqualToTotalOriginal_ExtraItems",
                FuzzMutations
                    .mutation_considerationLengthNotEqualToTotalOriginal_ExtraItems
                    .selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .ConsiderationLengthNotEqualToTotalOriginal
            .selector
            .withOrder(
                "ConsiderationLengthNotEqualToTotalOriginal_MissingItens",
                FuzzMutations
                    .mutation_considerationLengthNotEqualToTotalOriginal_MissingItems
                    .selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .MissingOriginalConsiderationItems
            .selector
            .withOrder(
                "MissingOriginalConsiderationItems",
                FuzzMutations
                    .mutation_missingOriginalConsiderationItems
                    .selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidTime
            .selector
            .withOrder(
                "InvalidTime_NotStarted",
                FuzzMutations.mutation_invalidTime_NotStarted.selector,
                details_InvalidTime_NotStarted
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidTime
            .selector
            .withOrder(
                "InvalidTime_Expired",
                FuzzMutations.mutation_invalidTime_Expired.selector,
                details_InvalidTime_Expired
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidConduit
            .selector
            .withOrder(
                "InvalidConduit",
                FuzzMutations.mutation_invalidConduit.selector,
                details_InvalidConduit
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .BadFraction
            .selector
            .withOrder(
                "BadFraction_PartialContractOrder",
                FuzzMutations.mutation_badFraction_partialContractOrder.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .BadFraction
            .selector
            .withOrder(
                "BadFraction_NoFill",
                FuzzMutations.mutation_badFraction_NoFill.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .BadFraction
            .selector
            .withOrder(
                "BadFraction_Overfill",
                FuzzMutations.mutation_badFraction_Overfill.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .CannotCancelOrder
            .selector
            .withOrder(
                "CannotCancelOrder",
                FuzzMutations.mutation_cannotCancelOrder.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .OrderIsCancelled
            .selector
            .withOrder(
                "OrderIsCancelled",
                FuzzMutations.mutation_orderIsCancelled.selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .OrderAlreadyFilled
            .selector
            .withOrder(
                "OrderAlreadyFilled",
                FuzzMutations.mutation_orderAlreadyFilled.selector,
                details_OrderAlreadyFilled
            );

        failureDetailsArray[i++] = FulfillmentApplicationErrors
            .InvalidFulfillmentComponentData
            .selector
            .withGeneric(
                "InvalidFulfillmentComponentData",
                FuzzMutations.mutation_invalidFulfillmentComponentData.selector
            );

        failureDetailsArray[i++] = FulfillmentApplicationErrors
            .MissingFulfillmentComponentOnAggregation
            .selector
            .withGeneric(
                "MissingFulfillmentComponentOnAggregation",
                FuzzMutations
                    .mutation_missingFulfillmentComponentOnAggregation
                    .selector,
                details_MissingFulfillmentComponentOnAggregation
            );

        failureDetailsArray[i++] = FulfillmentApplicationErrors
            .OfferAndConsiderationRequiredOnFulfillment
            .selector
            .withGeneric(
                "OfferAndConsiderationRequiredOnFulfillment",
                FuzzMutations
                    .mutation_offerAndConsiderationRequiredOnFulfillment
                    .selector
            );

        failureDetailsArray[i++] = FulfillmentApplicationErrors
            .MismatchedFulfillmentOfferAndConsiderationComponents
            .selector
            .withGeneric(
                "MismatchedFulfillmentOfferAndConsiderationComponents_Modified",
                FuzzMutations
                    .mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Modified
                    .selector,
                details_MismatchedFulfillmentOfferAndConsiderationComponents
            );

        failureDetailsArray[i++] = FulfillmentApplicationErrors
            .MismatchedFulfillmentOfferAndConsiderationComponents
            .selector
            .withGeneric(
                "MismatchedFulfillmentOfferAndConsiderationComponents_Swapped",
                FuzzMutations
                    .mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Swapped
                    .selector,
                details_MismatchedFulfillmentOfferAndConsiderationComponents
            );

        failureDetailsArray[i++] = ERROR_STRING.withOrder(
            "Error_OfferItemMissingApproval",
            FuzzMutations.mutation_offerItemMissingApproval.selector,
            errorString("NOT_AUTHORIZED")
        );

        failureDetailsArray[i++] = ERROR_STRING.withOrder(
            "Error_CallerMissingApproval",
            FuzzMutations.mutation_callerMissingApproval.selector,
            errorString("NOT_AUTHORIZED")
        );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidMsgValue
            .selector
            .withGeneric(
                "InvalidMsgValue",
                FuzzMutations.mutation_invalidMsgValue.selector,
                details_InvalidMsgValue
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InsufficientNativeTokensSupplied
            .selector
            .withGeneric(
                "InsufficientNativeTokensSupplied",
                FuzzMutations.mutation_insufficientNativeTokensSupplied.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .NativeTokenTransferGenericFailure
            .selector
            .withGeneric(
                "NativeTokenTransferGenericFailure",
                FuzzMutations
                    .mutation_insufficientNativeTokensSupplied
                    .selector,
                details_NativeTokenTransferGenericFailure
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .CriteriaNotEnabledForItem
            .selector
            .withGeneric(
                "CriteriaNotEnabledForItem",
                FuzzMutations.mutation_criteriaNotEnabledForItem.selector
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .InvalidProof
            .selector
            .withCriteria(
                "InvalidProof_Merkle",
                FuzzMutations.mutation_invalidMerkleProof.selector
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .InvalidProof
            .selector
            .withCriteria(
                "InvalidProof_Wildcard",
                FuzzMutations.mutation_invalidWildcardProof.selector
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .OrderCriteriaResolverOutOfRange
            .selector
            .withGeneric(
                "OrderCriteriaResolverOutOfRange",
                FuzzMutations.mutation_orderCriteriaResolverOutOfRange.selector,
                details_withZero
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .OfferCriteriaResolverOutOfRange
            .selector
            .withCriteria(
                "OfferCriteriaResolverOutOfRange",
                FuzzMutations.mutation_offerCriteriaResolverOutOfRange.selector
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .ConsiderationCriteriaResolverOutOfRange
            .selector
            .withCriteria(
                "ConsiderationCriteriaResolverOutOfRange",
                FuzzMutations
                    .mutation_considerationCriteriaResolverOutOfRange
                    .selector
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .UnresolvedOfferCriteria
            .selector
            .withCriteria(
                "UnresolvedOfferCriteria",
                FuzzMutations.mutation_unresolvedCriteria.selector,
                details_unresolvedCriteria
            );

        failureDetailsArray[i++] = CriteriaResolutionErrors
            .UnresolvedConsiderationCriteria
            .selector
            .withCriteria(
                "UnresolvedConsiderationCriteria",
                FuzzMutations.mutation_unresolvedCriteria.selector,
                details_unresolvedCriteria
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .MissingItemAmount
            .selector
            .withGeneric(
                "MissingItemAmount_OfferItem_FulfillAvailable",
                FuzzMutations
                    .mutation_missingItemAmount_OfferItem_FulfillAvailable
                    .selector
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .MissingItemAmount
            .selector
            .withOrder(
                "MissingItemAmount_OfferItem",
                FuzzMutations.mutation_missingItemAmount_OfferItem.selector
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .MissingItemAmount
            .selector
            .withOrder(
                "MissingItemAmount_ConsiderationItem",
                FuzzMutations
                    .mutation_missingItemAmount_ConsiderationItem
                    .selector
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_generateReturnsInvalidEncoding",
                FuzzMutations
                    .mutation_invalidContractOrderGenerateReturnsInvalidEncoding
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = HashCalldataContractOfferer
            .HashCalldataContractOffererGenerateOrderReverts
            .selector
            .withOrder(
                "InvalidContractOrder_generateReverts",
                FuzzMutations
                    .mutation_invalidContractOrderGenerateReverts
                    .selector
            );

        failureDetailsArray[i++] = HashCalldataContractOfferer
            .HashCalldataContractOffererRatifyOrderReverts
            .selector
            .withOrder(
                "InvalidContractOrder_ratifyReverts",
                FuzzMutations
                    .mutation_invalidContractOrderRatifyReverts
                    .selector
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_InsufficientMinimumReceived",
                FuzzMutations
                    .mutation_invalidContractOrderInsufficientMinimumReceived
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_IncorrectMinimumReceived",
                FuzzMutations
                    .mutation_invalidContractOrderIncorrectMinimumReceived
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_ExcessMaximumSpent",
                FuzzMutations
                    .mutation_invalidContractOrderExcessMaximumSpent
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_IncorrectMaximumSpent",
                FuzzMutations
                    .mutation_invalidContractOrderIncorrectMaximumSpent
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidContractOrder
            .selector
            .withOrder(
                "InvalidContractOrder_InvalidMagicValue",
                FuzzMutations
                    .mutation_invalidContractOrderInvalidMagicValue
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = HashValidationZoneOfferer
            .HashValidationZoneOffererAuthorizeOrderReverts
            .selector
            .withOrder(
                "InvalidRestrictedOrder_authorizeReverts_matchReverts",
                FuzzMutations
                    .mutation_invalidRestrictedOrderAuthorizeRevertsMatchReverts
                    .selector
            );

        failureDetailsArray[i++] = HashValidationZoneOfferer
            .HashValidationZoneOffererValidateOrderReverts
            .selector
            .withOrder(
                "InvalidRestrictedOrder_validateReverts",
                FuzzMutations.mutation_invalidRestrictedOrderReverts.selector
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidRestrictedOrder
            .selector
            .withOrder(
                "InvalidRestrictedOrder_authorizeInvalidMagicValue",
                FuzzMutations
                    .mutation_invalidRestrictedOrderAuthorizeInvalidMagicValue
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = ZoneInteractionErrors
            .InvalidRestrictedOrder
            .selector
            .withOrder(
                "InvalidRestrictedOrder_validateInvalidMagicValue",
                FuzzMutations
                    .mutation_invalidRestrictedOrderValidateInvalidMagicValue
                    .selector,
                details_withOrderHash
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .NoContract
            .selector
            .withGeneric(
                "NoContract",
                FuzzMutations.mutation_noContract.selector,
                details_NoContract
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .UnusedItemParameters
            .selector
            .withOrder(
                "UnusedItemParameters_Token",
                FuzzMutations.mutation_unusedItemParameters_Token.selector
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .UnusedItemParameters
            .selector
            .withOrder(
                "UnusedItemParameters_Identifier",
                FuzzMutations.mutation_unusedItemParameters_Identifier.selector
            );

        failureDetailsArray[i++] = TokenTransferrerErrors
            .InvalidERC721TransferAmount
            .selector
            .withOrder(
                "InvalidERC721TransferAmount",
                FuzzMutations.mutation_invalidERC721TransferAmount.selector,
                details_InvalidERC721TransferAmount
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .ConsiderationNotMet
            .selector
            .withOrder(
                "ConsiderationNotMet",
                FuzzMutations.mutation_considerationNotMet.selector,
                details_ConsiderationNotMet
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .PartialFillsNotEnabledForOrder
            .selector
            .withOrder(
                "PartialFillsNotEnabledForOrder",
                FuzzMutations.mutation_partialFillsNotEnabledForOrder.selector
            );

        failureDetailsArray[i++] = AmountDerivationErrors
            .InexactFraction
            .selector
            .withOrder(
                "InexactFraction",
                FuzzMutations.mutation_inexactFraction.selector
            );

        failureDetailsArray[i++] = PANIC.withOrder(
            "Panic_PartialFillOverflow",
            FuzzMutations.mutation_partialFillOverflow.selector,
            details_PanicOverflow
        );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .NoSpecifiedOrdersAvailable
            .selector
            .withGeneric(
                "NoSpecifiedOrderAvailable",
                FuzzMutations.mutation_noSpecifiedOrdersAvailable.selector
            );
        ////////////////////////////////////////////////////////////////////////

        if (i != uint256(Failure.length)) {
            revert("FailureDetailsLib: incorrect # failures specified");
        }

        // Set the actual length of the array.
        assembly {
            mstore(failureDetailsArray, i)
        }
    }

    //////////////////// ADD NEW FUNCTIONS HERE WHEN NEEDED ////////////////////
    function details_NotAuthorized(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            "NOT_AUTHORIZED"
        );
    }

    function details_PanicOverflow(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(errorSelector, 0x11);
    }

    function details_BadSignatureV(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(errorSelector, 0xff);
    }

    function details_InvalidTime_NotStarted(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal view returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            block.timestamp + 1,
            block.timestamp + 2
        );
    }

    function details_InvalidTime_Expired(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal view returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            block.timestamp - 1,
            block.timestamp
        );
    }

    function details_InvalidConduit(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal view returns (bytes memory expectedRevertReason) {
        bytes32 conduitKey = keccak256("invalid conduit");
        (address conduitAddr, ) = context.conduitController.getConduit(
            conduitKey
        );

        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            conduitKey,
            conduitAddr
        );
    }

    function details_withOrderHash(
        FuzzTestContext memory /* context */,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            mutationState.selectedOrderHash
        );
    }

    function details_OrderAlreadyFilled(
        FuzzTestContext memory context,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            context
                .executionState
                .orderDetails[mutationState.selectedOrderIndex]
                .orderHash
        );
    }

    function details_MissingFulfillmentComponentOnAggregation(
        FuzzTestContext memory /* context */,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            uint8(mutationState.side)
        );
    }

    function details_MismatchedFulfillmentOfferAndConsiderationComponents(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            uint256(0)
        );
    }

    function details_withZero(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            uint256(0)
        );
    }

    function details_InvalidMsgValue(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        uint256 value = context.executionState.value == 0 ? 1 : 0;
        expectedRevertReason = abi.encodeWithSelector(errorSelector, value);
    }

    function details_NativeTokenTransferGenericFailure(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        uint256 totalImplicitExecutions = (
            context.expectations.expectedImplicitPostExecutions.length
        );
        ReceivedItem memory item;
        if (context.expectations.expectedNativeTokensReturned == 0) {
            if (totalImplicitExecutions == 0) {
                revert(
                    "FailureDetailsLib: not enough implicit executions for unspent item return"
                );
            }

            bool foundNative;
            for (uint256 i = totalImplicitExecutions - 1; i >= 0; --i) {
                item = context
                    .expectations
                    .expectedImplicitPostExecutions[i]
                    .item;
                if (item.itemType == ItemType.NATIVE) {
                    foundNative = true;
                    break;
                }

                if (i == 0) {
                    break;
                }
            }

            if (!foundNative) {
                revert(
                    "FailureDetailsLib: no unspent native token item located with no returned native tokens"
                );
            }
        } else {
            if (totalImplicitExecutions > 2) {
                revert(
                    "FailureDetailsLib: not enough implicit executions for native token + unspent return"
                );
            }

            bool foundNative;
            for (uint256 i = totalImplicitExecutions - 1; i > 0; --i) {
                item = context
                    .expectations
                    .expectedImplicitPostExecutions[i - 1]
                    .item;

                if (item.itemType == ItemType.NATIVE) {
                    foundNative = true;
                    break;
                }
            }

            if (!foundNative) {
                revert(
                    "FailureDetailsLib: no unspent native token item located"
                );
            }
        }

        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            context.executionState.recipient == address(0)
                ? context.executionState.caller
                : context.executionState.recipient,
            item.amount
        );
    }

    function details_unresolvedCriteria(
        FuzzTestContext memory /* context */,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        CriteriaResolver memory resolver = mutationState
            .selectedCriteriaResolver;
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            resolver.orderIndex,
            resolver.index
        );
    }

    function details_InvalidERC721TransferAmount(
        FuzzTestContext memory /* context */,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(errorSelector, 2);
    }

    function details_ConsiderationNotMet(
        FuzzTestContext memory /* context */,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            mutationState.selectedOrderIndex,
            mutationState.selectedOrder.parameters.consideration.length,
            100
        );
    }

    function details_NoContract(
        FuzzTestContext memory /* context */,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            mutationState.selectedArbitraryAddress
        );
    }

    function errorString(
        string memory errorMessage
    )
        internal
        pure
        returns (
            function(FuzzTestContext memory, MutationState memory, bytes4)
                internal
                pure
                returns (bytes memory)
        )
    {
        if (
            keccak256(abi.encodePacked(errorMessage)) ==
            keccak256(abi.encodePacked("NOT_AUTHORIZED"))
        ) {
            return details_NotAuthorized;
        }

        revert("FailureDetailsLib: unsupported error string");
    }

    ////////////////////////////////////////////////////////////////////////////

    function failureDetails(
        FuzzTestContext memory context,
        Failure failure,
        IneligibilityFilter[] memory failuresAndFilters
    )
        internal
        view
        returns (
            string memory name,
            bytes4 mutationSelector,
            bytes memory revertReason,
            MutationState memory
        )
    {
        FailureDetails memory details = (
            declareFailureDetails()[uint256(failure)]
        );

        MutationState memory mutationState = context.deriveMutationContext(
            details.derivationMethod,
            failuresAndFilters.extractFirstFilterForFailure(failure)
        );

        return (
            details.name,
            details.mutationSelector,
            context.deriveRevertReason(
                mutationState,
                details.errorSelector,
                details.revertReasonDeriver
            ),
            mutationState
        );
    }
}
