// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import { FuzzMutations, MutationFilters } from "./FuzzMutations.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import {
    FailureEligibilityLib,
    OrderEligibilityLib,
    Failarray
} from "./FuzzMutationHelpers.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    SignatureVerificationErrors
} from "../../../../contracts/interfaces/SignatureVerificationErrors.sol";

import {
    ConsiderationEventsAndErrors
} from "../../../../contracts/interfaces/ConsiderationEventsAndErrors.sol";

import { Vm } from "forge-std/Vm.sol";

enum Failure {
    InvalidSignature, // EOA signature is incorrect length
    // InvalidSigner_BadSignature, // EOA signature has been tampered with
    // InvalidSigner_ModifiedOrder, // Order with no-code offerer has been tampered with
    BadSignatureV, // EOA signature has bad v value
    // BadContractSignature_BadSignature, // 1271 call to offerer, signature tampered with
    // BadContractSignature_ModifiedOrder, // Order with offerer with code tampered with
    // BadContractSignature_MissingMagic, // 1271 call to offerer, no magic value returned
    // ConsiderationLengthNotEqualToTotalOriginal, // Tips on contract order or validate
    // BadFraction_PartialContractOrder, // Contract order w/ numerator & denominator != 1
    BadFraction_NoFill, // Order where numerator = 0
    BadFraction_Overfill, // Order where numerator > denominator
    length // NOT A FAILURE; used to get the number of failures in the enum
}

library FuzzMutationSelectorLib {
    using Failarray for Failure;
    using FuzzEngineLib for FuzzTestContext;
    using FailureDetailsLib for FuzzTestContext;
    using FailureEligibilityLib for FuzzTestContext;
    using OrderEligibilityLib for FuzzTestContext;

    function selectMutation(
        FuzzTestContext memory context
    )
        public
        view
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        // Mark InvalidSignature as ineligible if no order supports it.
        if (
            context.hasNoEligibleOrders(
                MutationFilters.ineligibleForInvalidSignature
            )
        ) {
            context.setIneligibleFailure(Failure.InvalidSignature);
        }

        if (
            context.hasNoEligibleOrders(
                MutationFilters.ineligibleForBadSignatureV
            )
        ) {
            context.setIneligibleFailure(Failure.BadSignatureV);
        }

        if (
            context.hasNoEligibleOrders(
                MutationFilters.ineligibleForBadFraction
            )
        ) {
            context.setIneligibleFailures(
                Failure.BadFraction_NoFill.and(Failure.BadFraction_Overfill)
            );
        }

        // Choose one of the remaining eligible failures.
        return context.failureDetails(context.selectEligibleFailure());
    }
}

library FailureDetailsLib {
    function failureDetails(
        FuzzTestContext memory /* context */,
        Failure failure
    )
        internal
        pure
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        // TODO: more failures will go here
        if (failure == Failure.InvalidSignature) {
            return details_InvalidSignature();
        }

        if (failure == Failure.BadSignatureV) {
            return details_BadSignatureV();
        }

        if (failure == Failure.BadFraction_NoFill) {
            return details_BadFraction_NoFill();
        }

        if (failure == Failure.BadFraction_Overfill) {
            return details_BadFraction_Overfill();
        }

        revert("FailureDetailsLib: invalid failure");
    }

    function details_InvalidSignature()
        internal
        pure
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        name = "InvalidSignature";
        selector = FuzzMutations.mutation_invalidSignature.selector;
        expectedRevertReason = abi.encodePacked(
            SignatureVerificationErrors.InvalidSignature.selector
        );
    }

    function details_BadSignatureV()
        internal
        pure
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        name = "BadSignatureV";
        selector = FuzzMutations.mutation_badSignatureV.selector;
        expectedRevertReason = abi.encodeWithSelector(
            SignatureVerificationErrors.BadSignatureV.selector,
            0xff
        );
    }

    function details_BadFraction_NoFill()
        internal
        pure
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        name = "BadFraction_NoFill";
        selector = FuzzMutations.mutation_badFraction_NoFill.selector;
        expectedRevertReason = abi.encodePacked(
            ConsiderationEventsAndErrors.BadFraction.selector
        );
    }

    function details_BadFraction_Overfill()
        internal
        pure
        returns (
            string memory name,
            bytes4 selector,
            bytes memory expectedRevertReason
        )
    {
        name = "BadFraction_Overfill";
        selector = FuzzMutations.mutation_badFraction_Overfill.selector;
        expectedRevertReason = abi.encodePacked(
            ConsiderationEventsAndErrors.BadFraction.selector
        );
    }
}
