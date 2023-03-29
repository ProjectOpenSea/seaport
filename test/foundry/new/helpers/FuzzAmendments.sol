// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "seaport-sol/SeaportSol.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import {
    OrderStatus as OrderStatusEnum
} from "../../../../contracts/helpers/sol/SpaceEnums.sol";

/**
 *  @dev Some documentation.
 */
abstract contract FuzzAmendments is Test {
    using AdvancedOrderLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;

    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;

    /**
     *  @dev Validate orders.
     *
     * @param context The test context.
     */
    function validateOrdersAndRegisterCheck(
        FuzzTestContext memory context
    ) public {
        // Placeholder logic. TODO: figure out how to gracefully handle the case
        // where we can't validate.

        emit log_named_uint(
            "targetOrderStatus",
            uint256(context.targetOrderStatus)
        );

        if (context.targetOrderStatus == OrderStatusEnum.VALIDATED) {
            bool shouldRegisterCheck = true;

            for (uint256 i = 0; i < context.orders.length; i++) {
                if (
                    context.orders[i].parameters.consideration.length ==
                    context.orders[i].parameters.totalOriginalConsiderationItems
                ) {
                    bool validated = context.seaport.validate(
                        SeaportArrays.Orders(context.orders[i].toOrder())
                    );

                    require(validated, "Failed to validate orders.");
                } else {
                    shouldRegisterCheck = false;
                }
            }

            if (shouldRegisterCheck) {
                context.registerCheck(
                    FuzzChecks.check_ordersValidated.selector
                );
            }
        }
    }
}
