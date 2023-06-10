// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorDetailsLib } from "./NavigatorDetailsLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract OrderDetailsHelper is HelperInterface {
    using NavigatorDetailsLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public view returns (NavigatorContext memory) {
        return context.withDetails();
    }
}
