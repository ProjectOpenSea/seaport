// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    NavigatorRequestValidatorLib
} from "./NavigatorRequestValidatorLib.sol";

import {
    NavigatorContext,
    NavigatorResponse
} from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract RequestValidator is HelperInterface {
    using NavigatorRequestValidatorLib for NavigatorContext;

    function prepare(
        NavigatorContext memory context
    ) public pure returns (NavigatorContext memory) {
        return context.validate();
    }
}
