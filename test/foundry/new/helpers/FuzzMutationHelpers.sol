// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { Vm } from "forge-std/Vm.sol";

import { Failure } from "./FuzzMutationSelectorLib.sol";

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

library Failarray {
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
