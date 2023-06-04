// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperFulfillmentsLib } from "./OrderHelperLib.sol";

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract FulfillmentsHelper is HelperInterface {
    using OrderHelperFulfillmentsLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.withFulfillments();
    }
}
