// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorSuggestedActionLib } from "./NavigatorSuggestedActionLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract SuggestedActionHelper is HelperInterface {
    using NavigatorSuggestedActionLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public view returns (NavigatorContext memory) {
        return context.withSuggestedAction();
    }
}
