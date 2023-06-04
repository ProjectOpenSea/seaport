// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperDetailsLib } from "./OrderHelperLib.sol";

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract OrderDetailsHelper is HelperInterface {
    using OrderHelperDetailsLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.withDetails();
    }
}
