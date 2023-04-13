// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { Vm } from "forge-std/Vm.sol";

import {
    Failure,
    FailureDetails,
    IneligibilityFilter
} from "./FuzzMutationSelectorLib.sol";

library FailureEligibilityLib {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    using LibPRNG for LibPRNG.PRNG;

    function setIneligibleFailure(
        FuzzTestContext memory context,
        Failure ineligibleFailure
    ) internal pure {
        // Set the respective boolean for the ineligible failure.
        context.expectations.ineligibleFailures[
            uint256(ineligibleFailure)
        ] = true;
    }

    function setIneligibleFailures(
        FuzzTestContext memory context,
        Failure[] memory ineligibleFailures
    ) internal pure {
        for (uint256 i = 0; i < ineligibleFailures.length; ++i) {
            // Set the respective boolean for each ineligible failure.
            context.expectations.ineligibleFailures[
                uint256(ineligibleFailures[i])
            ] = true;
        }
    }

    function getEligibleFailures(
        FuzzTestContext memory context
    ) internal pure returns (Failure[] memory eligibleFailures) {
        eligibleFailures = new Failure[](uint256(Failure.length));

        uint256 totalEligibleFailures = 0;
        for (
            uint256 i = 0;
            i < context.expectations.ineligibleFailures.length;
            ++i
        ) {
            // If the boolean is not set, the failure is still eligible.
            if (!context.expectations.ineligibleFailures[i]) {
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
    using Failarray for Failure;
    using LibPRNG for LibPRNG.PRNG;
    using FailureEligibilityLib for FuzzTestContext;

    error NoEligibleOrderFound();

    function with(
        Failure failure,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibilityFilter
    ) internal pure returns (IneligibilityFilter memory) {
        return IneligibilityFilter(failure.one(), fn(ineligibilityFilter));
    }

    function with(
        Failure[] memory failures,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibilityFilter
    ) internal pure returns (IneligibilityFilter memory) {
        return IneligibilityFilter(failures, fn(ineligibilityFilter));
    }

    function ensureFilterSetForEachFailure(
        IneligibilityFilter[] memory failuresAndFilters
    ) internal pure {
        for (uint256 i = 0; i < uint256(Failure.length); ++i) {
            Failure failure = Failure(i);

            bool foundFailure = false;

            for (uint256 j = 0; j < failuresAndFilters.length; ++j) {
                Failure[] memory failures = failuresAndFilters[j].failures;

                for (uint256 k = 0; k < failures.length; ++k) {
                    foundFailure = (failure == failures[k]);

                    if (foundFailure) {
                        break;
                    }
                }

                if (foundFailure) {
                    break;
                }
            }

            if (!foundFailure) {
                revert(
                    string.concat(
                        "OrderEligibilityLib: no filter located for failure #",
                        _toString(i)
                    )
                );
            }
        }
    }

    function setAllIneligibleFailures(
        FuzzTestContext memory context,
        IneligibilityFilter[] memory failuresAndFilters
    ) internal view {
        for (uint256 i = 0; i < failuresAndFilters.length; ++i) {
            IneligibilityFilter memory failuresAndFilter = (
                failuresAndFilters[i]
            );

            setIneligibleFailures(
                context,
                _asIneligibleMutationFilter(
                    failuresAndFilter.ineligibleMutationFilter
                ),
                failuresAndFilter.failures
            );
        }
    }

    function setIneligibleFailures(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibleMutationFilter,
        Failure[] memory ineligibleFailures
    ) internal view {
        if (hasNoEligibleOrders(context, ineligibleMutationFilter)) {
            context.setIneligibleFailures(ineligibleFailures);
        }
    }

    function hasNoEligibleOrders(
        FuzzTestContext memory context,
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibleCondition
    ) internal view returns (bool) {
        for (uint256 i; i < context.executionState.orders.length; i++) {
            // Once an eligible order is found, return false.
            if (
                !ineligibleCondition(
                    context.executionState.orders[i],
                    i,
                    context
                )
            ) {
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
        for (uint256 i; i < context.executionState.orders.length; i++) {
            if (condition(context.executionState.orders[i], i, context)) {
                setIneligibleOrder(context, i);
            }
        }
    }

    function setIneligibleOrder(
        FuzzTestContext memory context,
        uint256 ineligibleOrderIndex
    ) internal pure {
        // Set the respective boolean for the ineligible order.
        context.expectations.ineligibleOrders[ineligibleOrderIndex] = true;
    }

    function getEligibleOrders(
        FuzzTestContext memory context
    ) internal pure returns (AdvancedOrder[] memory eligibleOrders) {
        eligibleOrders = new AdvancedOrder[](
            context.executionState.orders.length
        );

        uint256 totalEligibleOrders = 0;
        for (
            uint256 i = 0;
            i < context.expectations.ineligibleOrders.length;
            ++i
        ) {
            // If the boolean is not set, the order is still eligible.
            if (!context.expectations.ineligibleOrders[i]) {
                eligibleOrders[totalEligibleOrders++] = context
                    .executionState
                    .orders[i];
            }
        }

        // Update the eligibleOrders array with the actual length.
        assembly {
            mstore(eligibleOrders, totalEligibleOrders)
        }
    }

    function selectEligibleOrder(
        FuzzTestContext memory context
    )
        internal
        pure
        returns (AdvancedOrder memory eligibleOrder, uint256 orderIndex)
    {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed ^ 0xff);

        AdvancedOrder[] memory eligibleOrders = getEligibleOrders(context);

        if (eligibleOrders.length == 0) {
            revert NoEligibleOrderFound();
        }

        orderIndex = prng.next() % eligibleOrders.length;
        eligibleOrder = eligibleOrders[orderIndex];
    }

    function fn(
        function(AdvancedOrder memory, uint256, FuzzTestContext memory)
            internal
            view
            returns (bool) ineligibleMutationFilter
    ) internal pure returns (bytes32 ptr) {
        assembly {
            ptr := ineligibleMutationFilter
        }
    }

    function _asIneligibleMutationFilter(
        bytes32 ptr
    )
        private
        pure
        returns (
            function(AdvancedOrder memory, uint256, FuzzTestContext memory)
                internal
                view
                returns (bool) ineligibleMutationFilter
        )
    {
        assembly {
            ineligibleMutationFilter := ptr
        }
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 tempValue = value;
        uint256 length;

        while (tempValue != 0) {
            length++;
            tempValue /= 10;
        }

        bytes memory strBytes = new bytes(length);
        while (value != 0) {
            strBytes[--length] = bytes1(uint8(48) + uint8(value % 10));
            value /= 10;
        }

        return string(strBytes);
    }
}

library FailureDetailsHelperLib {
    function with(
        bytes4 errorSelector,
        string memory name,
        bytes4 mutationSelector
    ) internal pure returns (FailureDetails memory details) {
        return
            FailureDetails(
                name,
                mutationSelector,
                errorSelector,
                fn(defaultReason)
            );
    }

    function with(
        bytes4 errorSelector,
        string memory name,
        bytes4 mutationSelector,
        function(FuzzTestContext memory, bytes4)
            internal
            view
            returns (bytes memory) revertReasonDeriver
    ) internal pure returns (FailureDetails memory details) {
        return
            FailureDetails(
                name,
                mutationSelector,
                errorSelector,
                fn(revertReasonDeriver)
            );
    }

    function fn(
        function(FuzzTestContext memory, bytes4)
            internal
            view
            returns (bytes memory) revertReasonGenerator
    ) internal pure returns (bytes32 ptr) {
        assembly {
            ptr := revertReasonGenerator
        }
    }

    function deriveRevertReason(
        FuzzTestContext memory context,
        bytes4 errorSelector,
        bytes32 revertReasonDeriver
    ) internal view returns (bytes memory) {
        return
            asRevertReasonGenerator(revertReasonDeriver)(
                context,
                errorSelector
            );
    }

    function asRevertReasonGenerator(
        bytes32 ptr
    )
        private
        pure
        returns (
            function(FuzzTestContext memory, bytes4)
                internal
                view
                returns (bytes memory) revertReasonGenerator
        )
    {
        assembly {
            revertReasonGenerator := ptr
        }
    }

    function defaultReason(
        FuzzTestContext memory /* context */,
        bytes4 errorSelector
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(errorSelector);
    }
}

library Failarray {
    function one(Failure a) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](1);
        arr[0] = a;
        return arr;
    }

    function and(
        Failure a,
        Failure b
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](2);
        arr[0] = a;
        arr[1] = b;
        return arr;
    }

    function and(
        Failure a,
        Failure b,
        Failure c
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        return arr;
    }

    function and(
        Failure a,
        Failure b,
        Failure c,
        Failure d
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        return arr;
    }

    function and(
        Failure a,
        Failure b,
        Failure c,
        Failure d,
        Failure e
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](5);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        arr[4] = e;
        return arr;
    }

    function and(
        Failure a,
        Failure b,
        Failure c,
        Failure d,
        Failure e,
        Failure f
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](6);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        arr[4] = e;
        arr[5] = f;
        return arr;
    }

    function and(
        Failure a,
        Failure b,
        Failure c,
        Failure d,
        Failure e,
        Failure f,
        Failure g
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](7);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        arr[4] = e;
        arr[5] = f;
        arr[6] = g;
        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 1);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;

        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a,
        Failure b
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 2);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;
        arr[originalArr.length + 1] = b;

        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a,
        Failure b,
        Failure c
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 3);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;
        arr[originalArr.length + 1] = b;
        arr[originalArr.length + 2] = c;

        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a,
        Failure b,
        Failure c,
        Failure d
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 4);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;
        arr[originalArr.length + 1] = b;
        arr[originalArr.length + 2] = c;
        arr[originalArr.length + 3] = d;

        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a,
        Failure b,
        Failure c,
        Failure d,
        Failure e
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 5);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;
        arr[originalArr.length + 1] = b;
        arr[originalArr.length + 2] = c;
        arr[originalArr.length + 3] = d;
        arr[originalArr.length + 4] = e;

        return arr;
    }

    function and(
        Failure[] memory originalArr,
        Failure a,
        Failure b,
        Failure c,
        Failure d,
        Failure e,
        Failure f
    ) internal pure returns (Failure[] memory) {
        Failure[] memory arr = new Failure[](originalArr.length + 6);

        for (uint256 i = 0; i < originalArr.length; ++i) {
            arr[i] = originalArr[i];
        }

        arr[originalArr.length] = a;
        arr[originalArr.length + 1] = b;
        arr[originalArr.length + 2] = c;
        arr[originalArr.length + 3] = d;
        arr[originalArr.length + 4] = e;
        arr[originalArr.length + 5] = f;

        return arr;
    }
}
