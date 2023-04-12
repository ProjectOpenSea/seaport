// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { OrderType } from "seaport-sol/SeaportEnums.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import { OrderStatusEnum } from "seaport-sol/SpaceEnums.sol";

/**
 *  @dev Make amendments to state based on the fuzz test context.
 */
abstract contract FuzzAmendments is Test {
    using AdvancedOrderLib for AdvancedOrder[];
    using AdvancedOrderLib for AdvancedOrder;

    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzInscribers for AdvancedOrder;
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

    function conformOnChainStatusToExpected(
        FuzzTestContext memory context
    ) public {
        for (uint256 i = 0; i < context.preExecOrderStatuses.length; ++i) {
            if (context.preExecOrderStatuses[i] == OrderStatusEnum.VALIDATED) {
                validateOrdersAndRegisterCheck(context);
            } else if (
                context.preExecOrderStatuses[i] ==
                OrderStatusEnum.CANCELLED_EXPLICIT
            ) {
                context.orders[i].inscribeOrderStatusCancelled(
                    true,
                    context.seaport
                );
            } else if (
                context.preExecOrderStatuses[i] == OrderStatusEnum.FULFILLED
            ) {
                context.orders[i].inscribeOrderStatusNumeratorAndDenominator(
                    1,
                    1,
                    context.seaport
                );
            } else if (
                context.preExecOrderStatuses[i] == OrderStatusEnum.AVAILABLE
            ) {
                context.orders[i].inscribeOrderStatusNumeratorAndDenominator(
                    0,
                    0,
                    context.seaport
                );
                context.orders[i].inscribeOrderStatusCancelled(
                    false,
                    context.seaport
                );
            }
        }
    }

    function setCounter(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.orders.length; ++i) {
            if (context.orders[i].parameters.orderType == OrderType.CONTRACT) {
                continue;
            }

            uint256 offererSpecificCounter = context.counter +
                uint256(uint160(context.orders[i].parameters.offerer));

            FuzzInscribers.inscribeCounter(
                context.orders[i].parameters.offerer,
                offererSpecificCounter,
                context.seaport
            );
        }
    }

    function setContractOffererNonce(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.orders.length; ++i) {
            if (context.orders[i].parameters.orderType != OrderType.CONTRACT) {
                continue;
            }

            uint256 contractOffererSpecificContractNonce = context
                .contractOffererNonce +
                uint256(uint160(context.orders[i].parameters.offerer));

            FuzzInscribers.inscribeContractOffererNonce(
                context.orders[i].parameters.offerer,
                contractOffererSpecificContractNonce,
                context.seaport
            );
        }
    }
}
