// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";
import { FuzzMutations, MutationFilters } from "./FuzzMutations.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import {
    FailureEligibilityLib,
    OrderEligibilityLib,
    Failarray,
    FailureDetailsHelperLib,
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
    // BadContractSignature_BadSignature, // 1271 call to offerer, signature tampered with
    // BadContractSignature_ModifiedOrder, // Order with offerer with code tampered with
    // BadContractSignature_MissingMagic, // 1271 call to offerer, no magic value returned
    // ConsiderationLengthNotEqualToTotalOriginal, // Tips on contract order or validate
    InvalidTime_NotStarted, // Order with start time in the future
    InvalidTime_Expired, // Order with end time in the past
    // BadFraction_PartialContractOrder, // Contract order w/ numerator & denominator != 1
    BadFraction_NoFill, // Order where numerator = 0
    BadFraction_Overfill, // Order where numerator > denominator
    OrderIsCancelled, // Order is cancelled
    length // NOT A FAILURE; used to get the number of failures in the enum
}
////////////////////////////////////////////////////////////////////////////////

enum MutationContextDerivation {
    ORDER // Selecting an order
}

struct IneligibilityFilter {
    Failure[] failures;
    bytes32 ineligibleMutationFilter; // stores a function pointer
}

struct FailureDetails {
    string name;
    bytes4 mutationSelector;
    bytes4 errorSelector;
    MutationContextDerivation derivationMethod;
    bytes32 revertReasonDeriver; // stores a function pointer
}

library FuzzMutationSelectorLib {
    using Failarray for Failure;
    using FuzzEngineLib for FuzzTestContext;
    using FailureDetailsLib for FuzzTestContext;
    using FailureEligibilityLib for FuzzTestContext;
    using OrderEligibilityLib for FuzzTestContext;
    using OrderEligibilityLib for Failure;
    using OrderEligibilityLib for Failure[];
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
        failuresAndFilters[i++] = Failure.InvalidSignature.with(
            MutationFilters.ineligibleForInvalidSignature
        );

        failuresAndFilters[i++] = Failure
            .InvalidSigner_BadSignature
            .and(Failure.InvalidSigner_ModifiedOrder)
            .with(MutationFilters.ineligibleForInvalidSigner);

        failuresAndFilters[i++] = Failure
            .InvalidTime_NotStarted
            .and(Failure.InvalidTime_Expired)
            .with(MutationFilters.ineligibleForInvalidTime);

        failuresAndFilters[i++] = Failure.BadSignatureV.with(
            MutationFilters.ineligibleForBadSignatureV
        );

        failuresAndFilters[i++] = Failure.BadFraction_Overfill.with(
            MutationFilters.ineligibleForBadFraction
        );

        failuresAndFilters[i++] = Failure.BadFraction_NoFill.with(
            MutationFilters.ineligibleForBadFraction_noFill
        );

        failuresAndFilters[i++] = Failure.OrderIsCancelled.with(
            MutationFilters.ineligibleForOrderIsCancelled
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
        view
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
            .with(
                "InvalidSignature",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_invalidSignature.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .InvalidSigner
            .selector
            .with(
                "InvalidSigner_BadSignature",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_invalidSigner_BadSignature.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .InvalidSigner
            .selector
            .with(
                "InvalidSigner_ModifiedOrder",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_invalidSigner_ModifiedOrder.selector
            );

        failureDetailsArray[i++] = SignatureVerificationErrors
            .BadSignatureV
            .selector
            .with(
                "BadSignatureV",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_badSignatureV.selector,
                details_BadSignatureV
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidTime
            .selector
            .with(
                "InvalidTime_NotStarted",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_invalidTime_NotStarted.selector,
                details_InvalidTime_NotStarted
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .InvalidTime
            .selector
            .with(
                "InvalidTime_Expired",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_invalidTime_Expired.selector,
                details_InvalidTime_Expired
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .BadFraction
            .selector
            .with(
                "BadFraction_NoFill",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_badFraction_NoFill.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .BadFraction
            .selector
            .with(
                "BadFraction_Overfill",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_badFraction_Overfill.selector
            );

        failureDetailsArray[i++] = ConsiderationEventsAndErrors
            .OrderIsCancelled
            .selector
            .with(
                "OrderIsCancelled",
                MutationContextDerivation.ORDER,
                FuzzMutations.mutation_orderIsCancelled.selector,
                details_OrderIsCancelled
            );
        ////////////////////////////////////////////////////////////////////////

        if (i != uint256(Failure.length)) {
            revert("FuzzMutationSelectorLib: incorrect # failures specified");
        }

        // Set the actual length of the array.
        assembly {
            mstore(failureDetailsArray, i)
        }
    }

    //////////////////// ADD NEW FUNCTIONS HERE WHEN NEEDED ////////////////////
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
