// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { FuzzEngine } from "./helpers/FuzzEngine.sol";

import { FuzzParams } from "./helpers/FuzzTestContextLib.sol";

contract FuzzMainTest is FuzzEngine {
    /**
     * @dev FuzzEngine test for valid orders. Generates a random valid order
     *      configuration, selects and calls a Seaport method, and runs all
     *      registered checks. This test should never revert.
     */
    function test_fuzz_validOrders(
        uint256 seed,
        uint256 orders,
        uint256 maxOfferItemsPerOrder,
        uint256 maxConsiderationItemsPerOrder
    ) public {
        run(
            FuzzParams({
                seed: seed,
                totalOrders: bound(orders, 1, 10),
                maxOfferItems: bound(maxOfferItemsPerOrder, 0, 10),
                maxConsiderationItems: bound(
                    maxConsiderationItemsPerOrder,
                    0,
                    10
                )
            })
        );
    }

    function fail() internal virtual override {
        revert("Assertion failed.");
    }
}
