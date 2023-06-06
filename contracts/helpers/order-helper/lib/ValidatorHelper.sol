// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperSeaportValidatorLib } from "./OrderHelperLib.sol";

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract ValidatorHelper is HelperInterface {
    using OrderHelperSeaportValidatorLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.withErrors();
    }
}
