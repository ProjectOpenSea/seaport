// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FuzzTestContext } from "./FuzzTestContextLib.sol";
import { FuzzMutations, MutationFilters } from "./FuzzMutations.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    SignatureVerificationErrors
} from "../../../../contracts/interfaces/SignatureVerificationErrors.sol";

import { Vm } from "forge-std/Vm.sol";

enum Failure {
    InvalidSignature, // EOA signature is incorrect length
    // InvalidSigner_BadSignature, // EOA signature has been tampered with
    // InvalidSigner_ModifiedOrder, // Order with no-code offerer has been tampered with
    // BadSignatureV, // EOA signature has bad v value
    // BadContractSignature_BadSignature, // 1271 call to offerer, signature tampered with
    // BadContractSignature_ModifiedOrder, // Order with offerer with code tampered with
    // BadContractSignature_MissingMagic, // 1271 call to offerer, no magic value returned
    // ConsiderationLengthNotEqualToTotalOriginal, // Tips on contract order or validate
    // BadFraction_PartialContractOrder, // Contract order w/ numerator & denominator != 1
    // BadFraction_NoFill, // Order where numerator = 0
    // BadFraction_Overfill, // Order where numerator > denominator
    length // NOT A FAILURE; used to get the number of failures in the enum
}

library FuzzMutationSelectorLib {
    using FuzzEngineLib for FuzzTestContext;
    using FailureDetailsLib for FuzzTestContext;
    using FailureEligibilityLib for FuzzTestContext;

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
        // TODO: logic to set ineligible failures will go here
        bytes4 action = context.action();
        action;

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
}

library FailureEligibilityLib {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    using LibPRNG for LibPRNG.PRNG;

    function setIneligibleFailure(
        FuzzTestContext memory context,
        Failure ineligibleFailure
    ) internal pure {
        // Set the respective boolean for the ineligible failure.
        context.ineligibleFailures[uint256(ineligibleFailure)] = true;
    }

    function setIneligibleFailures(
        FuzzTestContext memory context,
        Failure[] memory ineligibleFailures
    ) internal pure {
        for (uint256 i = 0; i < ineligibleFailures.length; ++i) {
            // Set the respective boolean for each ineligible failure.
            context.ineligibleFailures[uint256(ineligibleFailures[i])] = true;
        }
    }

    function getEligibleFailures(
        FuzzTestContext memory context
    ) internal pure returns (Failure[] memory eligibleFailures) {
        eligibleFailures = new Failure[](uint256(Failure.length));

        uint256 totalEligibleFailures = 0;
        for (uint256 i = 0; i < context.ineligibleFailures.length; ++i) {
            // If the boolean is not set, the failure is still eligible.
            if (!context.ineligibleFailures[i]) {
                eligibleFailures[totalEligibleFailures++] = Failure(i);
            }
        }

        // Update the eligibleFailures array with the actual length.
        assembly {
            mstore(eligibleFailures, totalEligibleFailures)
        }
    }

    function selectEligibleFailure(
        FuzzTestContext memory context
    ) internal pure returns (Failure eligibleFailure) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed ^ 0xff);

        Failure[] memory eligibleFailures = getEligibleFailures(context);

        // TODO: remove this vm.assume as soon as at least one case is found
        // for any permutation of orders.
        vm.assume(eligibleFailures.length > 0);

        if (eligibleFailures.length == 0) {
            revert("FailureEligibilityLib: no eligible failure found");
        }

        return eligibleFailures[prng.next() % eligibleFailures.length];
    }
}
