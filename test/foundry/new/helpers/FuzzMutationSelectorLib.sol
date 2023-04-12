// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

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

library OrderEligibilityLib {
    using LibPRNG for LibPRNG.PRNG;

    error NoEligibleOrderFound();

    function hasNoEligibleOrders(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibleCondition
    ) internal view returns (bool) {
        for (uint256 i; i < context.orders.length; i++) {
            // Once an eligible order is found, return false.
            if (!ineligibleCondition(context.orders[i], i, context)) {
                return false;
            }
        }

        return true;
    }

    function setIneligibleOrders(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) condition
    ) internal view {
        for (uint256 i; i < context.orders.length; i++) {
            if (condition(context.orders[i], i, context)) {
                setIneligibleOrder(context, i);
            }
        }
    }

    function setIneligibleOrder(
        FuzzTestContext memory context,
        uint256 ineligibleOrderIndex
    ) internal pure {
        // Set the respective boolean for the ineligible order.
        context.ineligibleOrders[ineligibleOrderIndex] = true;
    }

    function getEligibleOrders(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder[] memory eligibleOrders) {
        eligibleOrders = new AdvancedOrder[](context.orders.length);

        uint256 totalEligibleOrders = 0;
        for (uint256 i = 0; i < context.ineligibleOrders.length; ++i) {
            // If the boolean is not set, the order is still eligible.
            if (!context.ineligibleOrders[i]) {
                eligibleOrders[totalEligibleOrders++] = context.orders[i];
            }
        }

        // Update the eligibleOrders array with the actual length.
        assembly {
            mstore(eligibleOrders, totalEligibleOrders)
        }
    }

    // TODO: may also want to return the order index for backing out to e.g.
    // orderIndex in fulfillments or criteria resolvers
    function selectEligibleOrder(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder memory eligibleOrder) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed ^ 0xff);

        AdvancedOrder[] memory eligibleOrders = getEligibleOrders(context);

        if (eligibleOrders.length == 0) {
            revert NoEligibleOrderFound();
        }

        return eligibleOrders[prng.next() % eligibleOrders.length];
    }
}
