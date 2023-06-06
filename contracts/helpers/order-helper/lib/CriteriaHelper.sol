// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { OrderHelperCriteriaResolverLib } from "./OrderHelperLib.sol";

import {
    CriteriaConstraint,
    OrderHelperContext
} from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract CriteriaHelper is HelperInterface {
    using OrderHelperCriteriaResolverLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public pure returns (OrderHelperContext memory) {
        return context.withInferredCriteria();
    }
}
