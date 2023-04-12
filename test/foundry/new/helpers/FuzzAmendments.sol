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
        for (
            uint256 i = 0;
            i < context.executionState.preExecOrderStatuses.length;
            ++i
        ) {
            if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.VALIDATED
            ) {
                bool validated = context
                    .executionState
                    .orders[i]
                    .validateTipNeutralizedOrder(context);

                require(validated, "Failed to validate orders.");
            }
        }

        context.registerCheck(FuzzChecks.check_ordersValidated.selector);
    }

    function conformOnChainStatusToExpected(
        FuzzTestContext memory context
    ) public {
        for (
            uint256 i = 0;
            i < context.executionState.preExecOrderStatuses.length;
            ++i
        ) {
            if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.VALIDATED
            ) {
                validateOrdersAndRegisterCheck(context);
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.CANCELLED_EXPLICIT
            ) {
                context.executionState.orders[i].inscribeOrderStatusCancelled(
                    true,
                    context.seaport
                );
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.FULFILLED
            ) {
                context
                    .executionState
                    .orders[i]
                    .inscribeOrderStatusNumeratorAndDenominator(
                        1,
                        1,
                        context.seaport
                    );
            } else if (
                context.executionState.preExecOrderStatuses[i] ==
                OrderStatusEnum.AVAILABLE
            ) {
                context
                    .executionState
                    .orders[i]
                    .inscribeOrderStatusNumeratorAndDenominator(
                        0,
                        0,
                        context.seaport
                    );
                context.executionState.orders[i].inscribeOrderStatusCancelled(
                    false,
                    context.seaport
                );
            }
        }
    }

    function setCounter(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (
                context.executionState.orders[i].parameters.orderType ==
                OrderType.CONTRACT
            ) {
                continue;
            }

            uint256 offererSpecificCounter = context.executionState.counter +
                uint256(
                    uint160(context.executionState.orders[i].parameters.offerer)
                );

            FuzzInscribers.inscribeCounter(
                context.executionState.orders[i].parameters.offerer,
                offererSpecificCounter,
                context.seaport
            );
        }
    }

    function setContractOffererNonce(FuzzTestContext memory context) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (
                context.executionState.orders[i].parameters.orderType !=
                OrderType.CONTRACT
            ) {
                continue;
            }

            uint256 contractOffererSpecificContractNonce = context
                .executionState
                .contractOffererNonce +
                uint256(
                    uint160(context.executionState.orders[i].parameters.offerer)
                );

            FuzzInscribers.inscribeContractOffererNonce(
                context.executionState.orders[i].parameters.offerer,
                contractOffererSpecificContractNonce,
                context.seaport
            );
        }
    }
}
