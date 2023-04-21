// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { AdvancedOrderLib } from "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    OrderParameters,
    ReceivedItem
} from "seaport-sol/SeaportStructs.sol";

import { ItemType, OrderType, Side } from "seaport-sol/SeaportEnums.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import { OrderStatusEnum, ContractOrderRebate } from "seaport-sol/SpaceEnums.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

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

    // TODO: make it so it adds / removes / modifies more than a single thing
    // and create arbitrary new items.
    function prepareRebates(
        FuzzTestContext memory context
    ) public {
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory orderParams = (
                context.executionState.orders[i].parameters
            );

            if (orderParams.orderType == OrderType.CONTRACT) {
                HashCalldataContractOfferer offerer = (
                    HashCalldataContractOfferer(payable(orderParams.offerer))
                );

                bytes32 orderHash = context.executionState.orderHashes[i];
                ContractOrderRebate rebate = (
                    context.advancedOrdersSpace.orders[i].rebate
                );

                if (rebate == ContractOrderRebate.MORE_OFFER_ITEMS) {
                    offerer.addExtraItemMutation(
                        Side.OFFER,
                        ReceivedItem({
                            itemType: ItemType.NATIVE,
                            token: address(0),
                            identifier: 0,
                            amount: 1,
                            recipient: payable(orderParams.offerer)
                        }),
                        orderHash
                    );
                } else if (
                    rebate == ContractOrderRebate.MORE_OFFER_ITEM_AMOUNTS
                ) {
                    offerer.addItemAmountMutation(
                        Side.OFFER,
                        0,
                        orderParams.offer[0].startAmount + 1,
                        orderHash
                    );
                } else if (
                    rebate == ContractOrderRebate.LESS_CONSIDERATION_ITEMS
                ) {
                    offerer.addDropItemMutation(
                        Side.CONSIDERATION,
                        orderParams.consideration.length - 1,
                        orderHash
                    );
                } else if (
                    rebate == ContractOrderRebate.LESS_CONSIDERATION_ITEM_AMOUNTS
                ) {
                    offerer.addItemAmountMutation(
                        Side.CONSIDERATION,
                        0,
                        orderParams.consideration[0].startAmount - 1,
                        orderHash
                    );
                }
            }
        }
    }

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
