// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorDetailsLib } from "./NavigatorDetailsLib.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract OrderDetailsHelper is HelperInterface {
    using NavigatorDetailsLib for NavigatorContext;

    /**
     * @notice Calculate `OrderDetails` structs for each order and add them to
     *         the response.
     *
     * @param context A NavigatorContext struct. In order to call this helper
     *                independently, context.response must be populated with
     *                orders.
     *
     * @return Unmodified NavigatorContext struct.
     */
    function prepare(
        NavigatorContext memory context
    ) public view returns (NavigatorContext memory) {
        return context.withDetails();
    }
}
