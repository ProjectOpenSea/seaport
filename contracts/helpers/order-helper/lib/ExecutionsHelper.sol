// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperExecutionsLib } from "./OrderHelperLib.sol";

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract ExecutionsHelper is HelperInterface {
    using OrderHelperExecutionsLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.withSuggestedAction().withExecutions();
    }
}
