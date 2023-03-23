// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { FuzzParams } from "./helpers/FuzzTestContextLib.sol";
import { FuzzEngine } from "./helpers/FuzzEngine.sol";

contract FuzzMainTest is FuzzEngine {
    /**
     * @dev FuzzEngine test for valid orders. Generates a random valid order
     *      configuration, selects and calls a Seaport method, and runs all
     *      registered checks. This test should never revert.
     */
    function test_fuzz_validOrders(
        uint256 seed,
        uint256 orders,
        uint256 offers,
        uint256 considerations
    ) public {
        run(
            FuzzParams({
                seed: seed,
                totalOrders: bound(orders, 1, 10),
                maxOfferItems: bound(offers, 1, 25),
                maxConsiderationItems: bound(considerations, 1, 25)
            })
        );
    }
}
