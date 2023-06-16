// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorExecutionsLib } from "./NavigatorExecutionsLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract ExecutionsHelper is HelperInterface {
    using NavigatorExecutionsLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public pure returns (NavigatorContext memory) {
        return context.withExecutions();
    }
}
