// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

interface HelperInterface {
    function prepare(
        OrderHelperContext memory context
    ) external view returns (OrderHelperContext memory);
}
