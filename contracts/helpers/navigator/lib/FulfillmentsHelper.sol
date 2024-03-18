// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorFulfillmentsLib } from "./NavigatorFulfillmentsLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract FulfillmentsHelper is HelperInterface {
    using NavigatorFulfillmentsLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public pure returns (NavigatorContext memory) {
        return context.withFulfillments();
    }
}
