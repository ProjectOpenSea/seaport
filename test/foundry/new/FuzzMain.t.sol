// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FuzzEngine } from "./helpers/FuzzEngine.sol";

import { FuzzParams } from "./helpers/FuzzTestContextLib.sol";

contract FuzzMainTest is FuzzEngine {
    /**
     * @dev FuzzEngine entry point. Generates a random order configuration,
     *      selects and calls a Seaport method, and runs all registered checks.
     *      This test should never revert. For more details on the lifecycle of
     *      this test, see `FuzzEngine.sol`.
     */
    function test_fuzz_generateOrders(
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
                ),
                seedInput: abi.encodePacked(
                    seed,
                    orders,
                    maxOfferItemsPerOrder,
                    maxConsiderationItemsPerOrder
                )
            })
        );
    }

    /**
     * @dev A helper to convert a fuzz test failure into a concrete test.
     *      Copy/paste fuzz run parameters into the tuple below and remove the
     *      leading "x" to run a fuzz failure as a concrete test.
     */
    function xtest_concrete() public {
        (
            uint256 seed,
            uint256 orders,
            uint256 maxOfferItemsPerOrder,
            uint256 maxConsiderationItemsPerOrder
        ) = (0, 0, 0, 0);
        bytes memory callData = abi.encodeCall(
            this.test_fuzz_generateOrders,
            (seed, orders, maxOfferItemsPerOrder, maxConsiderationItemsPerOrder)
        );
        (bool success, bytes memory result) = address(this).call(callData);
        if (!success) {
            if (result.length == 0) revert();
            assembly {
                revert(add(0x20, result), mload(result))
            }
        }
    }
}
