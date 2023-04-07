// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import { OrderStatus as OrderStatusEnum } from "seaport-sol/SpaceEnums.sol";

/**
 *  @dev Make amendments to state based on the fuzz test context.
 */
abstract contract FuzzAmendments is Test {
    using AdvancedOrderLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;

    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;

    /**
     *  @dev Validate orders.
     *
     * @param context The test context.
     */
    function validateOrdersAndRegisterCheck(
        FuzzTestContext memory context
    ) public {
        for (uint256 i = 0; i < context.preExecOrderStatuses.length; ++i) {
            if (context.preExecOrderStatuses[i] == OrderStatusEnum.VALIDATED) {
                bool validated = context.orders[i].validateTipNeutralizedOrder(
                    context
                );

                require(validated, "Failed to validate orders.");
            }
        }

        context.registerCheck(FuzzChecks.check_ordersValidated.selector);
    }
}
