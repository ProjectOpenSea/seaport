// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    NavigatorCriteriaResolverLib
} from "./NavigatorCriteriaResolverLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract CriteriaHelper is HelperInterface {
    using NavigatorCriteriaResolverLib for NavigatorContext;

    /**
     * @notice Derive criteria resolvers, merkle proofs, and criteria merkle
     *         roots for the provided orders, or add explicit criteria resolvers
     *         to the response. Converts ordersfrom `NavigatorAdvancedOrder` to
     *         `AdvancedOrder` and modifies orders in place to add criteria
     *         merkle roots to the appropriate offer/consideration items.
     *
     * @param context A NavigatorContext struct including a NavigatorRequest.
     *
     * @return Unmodified NavigatorContext struct.
     */
    function prepare(
        NavigatorContext memory context
    ) public pure returns (NavigatorContext memory) {
        return context.withCriteria();
    }
}
