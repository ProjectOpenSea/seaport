// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder, ReceivedItem } from "seaport-sol/SeaportStructs.sol";

import { ItemType } from "seaport-sol/SeaportEnums.sol";

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
    MutationContextDeriverLib
} from "./FuzzMutationHelpers.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    SignatureVerificationErrors
} from "../../../../contracts/interfaces/SignatureVerificationErrors.sol";

import {
    ConsiderationEventsAndErrors
} from "../../../../contracts/interfaces/ConsiderationEventsAndErrors.sol";

import { Vm } from "forge-std/Vm.sol";

/////////////////////// UPDATE THIS TO ADD FAILURE TESTS ///////////////////////
enum Failure {
    InvalidSignature, // EOA signature is incorrect length
    InvalidSigner_BadSignature, // EOA signature has been tampered with
    InvalidSigner_ModifiedOrder, // Order with no-code offerer has been tampered with
    BadSignatureV, // EOA signature has bad v value
    BadContractSignature_BadSignature, // 1271 call to offerer, signature tampered with
    BadContractSignature_ModifiedOrder, // Order with offerer with code tampered with
    BadContractSignature_MissingMagic, // 1271 call to offerer, no magic value returned
    // ConsiderationLengthNotEqualToTotalOriginal, // Tips on contract order or validate
    InvalidTime_NotStarted, // Order with start time in the future
    InvalidTime_Expired, // Order with end time in the past
    InvalidConduit, // Order with invalid conduit
    BadFraction_PartialContractOrder, // Contract order w/ numerator & denominator != 1
    BadFraction_NoFill, // Order where numerator = 0
    BadFraction_Overfill, // Order where numerator > denominator
    CannotCancelOrder, // Caller cannot cancel order
    OrderIsCancelled, // Order is cancelled
    OrderAlreadyFilled, // Order is already filled
    Error_OfferItemMissingApproval, // Order has an offer item without sufficient approval
    Error_CallerMissingApproval, // Order has a consideration item where caller is not approved
    InsufficientNativeTokensSupplied, // Caller does not supply sufficient native tokens
    NativeTokenTransferGenericFailure, // Insufficient native tokens with unspent offer items
    // CriteriaNotEnabledForItem, // Criteria resolver applied to non-criteria-based item
    // InvalidProof_Merkle, // Bad or missing proof for non-wildcard criteria item
    // InvalidProof_Wildcard, // Non-empty proof supplied for wildcard criteria item
    // OrderCriteriaResolverOutOfRange, // Criteria resolver refers to OOR order
    // OfferCriteriaResolverOutOfRange, // Criteria resolver refers to OOR offer item
    // ConsiderationCriteriaResolverOutOfRange, // Criteria resolver refers to OOR consideration item
    // UnresolvedConsiderationCriteria, // Missing criteria resolution for a consideration item
    // UnresolvedOfferCriteria, // Missing criteria resolution for an offer item
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
            .Error_OfferItemMissingApproval
            .withOrder(MutationFilters.ineligibleForOfferItemMissingApproval);

        failuresAndFilters[i++] = Failure.Error_CallerMissingApproval.withOrder(
            MutationFilters.ineligibleForCallerMissingApproval
        );

        failuresAndFilters[i++] = Failure
            .InsufficientNativeTokensSupplied
            .withGeneric(MutationFilters.ineligibleForInsufficientNativeTokens);

        failuresAndFilters[i++] = Failure
            .NativeTokenTransferGenericFailure
            .withGeneric(MutationFilters.ineligibleForNativeTokenTransferGenericFailure);
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
                details_OrderIsCancelled
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .OrderAlreadyFilled
            .selector
            .withOrder(
                "OrderAlreadyFilled",
                FuzzMutations.mutation_orderAlreadyFilled.selector,
                details_OrderAlreadyFilled
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
                FuzzMutations.mutation_insufficientNativeTokensSupplied.selector,
                details_NativeTokenTransferGenericFailure
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

    function details_PanicUnderflow(
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

    function details_OrderIsCancelled(
        FuzzTestContext memory context,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            context.executionState.orderHashes[mutationState.selectedOrderIndex]
        );
    }

    function details_OrderAlreadyFilled(
        FuzzTestContext memory context,
        MutationState memory mutationState,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            context.executionState.orderHashes[mutationState.selectedOrderIndex]
        );
    }

    function details_NativeTokenTransferGenericFailure(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory expectedRevertReason) {
        uint256 totalImplicitExecutions = (
            context.expectations.expectedImplicitExecutions.length
        );
        ReceivedItem memory item;
        if (context.expectations.expectedNativeTokensReturned == 0) {
            if (totalImplicitExecutions == 0) {
                revert("FailureDetailsLib: not enough implicit executions for unspent item return");
            }

            bool foundNative;
            for (uint256 i = totalImplicitExecutions - 1; i >= 0; --i) {
                item = context.expectations.expectedImplicitExecutions[i].item;
                if (item.itemType == ItemType.NATIVE) {
                    foundNative = true;
                    break;
                }

                if (i == 0) {
                    break;
                }
            }

            if (!foundNative) {
                revert("FailureDetailsLib: no unspent native token item located with no returned native tokens");
            }
        } else {
            if (totalImplicitExecutions > 2) {
                revert("FailureDetailsLib: not enough implicit executions for native token + unspent return");
            }

            bool foundNative;
            for (uint256 i = totalImplicitExecutions - 1; i > 0; --i) {
                item = context.expectations.expectedImplicitExecutions[i - 1].item;
                if (item.itemType == ItemType.NATIVE) {
                    foundNative = true;
                    break;
                }
            }

            if (!foundNative) {
                revert("FailureDetailsLib: no unspent native token item located");
            }
        }



        expectedRevertReason = abi.encodeWithSelector(
            errorSelector,
            context.executionState.recipient == address(0) ? context.executionState.caller : context.executionState.recipient,
            item.amount
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
