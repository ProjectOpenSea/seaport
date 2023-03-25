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
                // TODO: the lower bound on these should be zero (especially
                // if a subsequent bound ensures that they're not both zero)
                maxOfferItems: bound(maxOfferItemsPerOrder, 1, 10),
                maxConsiderationItems: bound(
                    maxConsiderationItemsPerOrder,
                    1,
                    10
                )
            })
        );
    }
}
