// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-sol/SeaportSol.sol";
import { Response } from "./OrderHelperLib.sol";

interface SeaportOrderHelperInterface {
    function run(
        AdvancedOrder[] memory orders,
        address recipient,
        address caller,
        uint256 nativeTokensSupplied
    ) external returns (Response memory);
}
