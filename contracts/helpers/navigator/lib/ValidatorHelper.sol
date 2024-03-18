// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    NavigatorSeaportValidatorLib
} from "./NavigatorSeaportValidatorLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract ValidatorHelper is HelperInterface {
    using NavigatorSeaportValidatorLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public view returns (NavigatorContext memory) {
        return context.withErrors();
    }
}
