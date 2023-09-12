// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    NavigatorCriteriaResolverLib
} from "./NavigatorCriteriaResolverLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract CriteriaHelper is HelperInterface {
    using NavigatorCriteriaResolverLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public pure returns (NavigatorContext memory) {
        return context.withCriteria();
    }
}
