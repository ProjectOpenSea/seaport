// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

interface HelperInterface {
    function prepare(
        NavigatorContext memory context
    ) external view returns (NavigatorContext memory);
}
