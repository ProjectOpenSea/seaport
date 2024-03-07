// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    ExecutionLib,
    ZoneParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    Execution,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/src/SeaportStructs.sol";

import { OrderDetails } from "seaport-sol/src/fulfillments/lib/Structs.sol";

import { ItemType, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CriteriaResolverHelper } from "./CriteriaResolverHelper.sol";

import {
    AmountDeriverHelper
} from "seaport-sol/src/lib/fulfillment/AmountDeriverHelper.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

import { ExecutionsFlattener } from "./event-utils/ExecutionsFlattener.sol";

import { ExpectedBalances } from "./ExpectedBalances.sol";

import { dumpExecutions } from "./DebugUtil.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

interface TestERC20 {
    function mint(address to, uint256 amount) external;

    function increaseAllowance(address spender, uint256 amount) external;
}

interface TestERC721 {
    function mint(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;
}

interface TestERC1155 {
    function mint(address to, uint256 tokenId, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;
}

/**
 *  @dev Stateless helpers related to fuzz checks.
 */
library CheckHelpers {
    /**
     *  @dev Register a check to be run after the test is executed.
     *
     * @param context The test context.
     * @param check   The check to register.
     *
     * @return The updated test context.
     */
    function registerCheck(
        FuzzTestContext memory context,
        bytes4 check
    ) internal pure returns (FuzzTestContext memory) {
        bytes4[] memory checks = context.checks;
        bytes4[] memory newChecks = new bytes4[](checks.length + 1);
        for (uint256 i; i < checks.length; ++i) {
            newChecks[i] = checks[i];
        }
        newChecks[checks.length] = check;
        context.checks = newChecks;
        return context;
    }

    /**
     *  @dev Get the address to approve to for a given test context.
     *
     * @param context The test context.
     */
    function getApproveTo(
        FuzzTestContext memory context
    ) internal view returns (address) {
        if (context.executionState.fulfillerConduitKey == bytes32(0)) {
            return address(context.seaport);
        } else {
            (address conduit, bool exists) = context
                .conduitController
                .getConduit(context.executionState.fulfillerConduitKey);
            if (exists) {
                return conduit;
            } else {
                revert("CheckHelpers: Conduit not found");
            }
        }
    }

    /**
     *  @dev Get the address to approve to for a given test context and order.
     *
     * @param context The test context.
     * @param orderParams The order parameters.
     */
    function getApproveTo(
        FuzzTestContext memory context,
        OrderParameters memory orderParams
    ) internal view returns (address) {
        if (orderParams.conduitKey == bytes32(0)) {
            return address(context.seaport);
        } else {
            (address conduit, bool exists) = context
                .conduitController
                .getConduit(orderParams.conduitKey);
            if (exists) {
                return conduit;
            } else {
                revert("CheckHelpers: Conduit not found");
            }
        }
    }

    /**
     *  @dev Get the address to approve to for a given test context and order.
     *
     * @param context The test context.
     * @param orderDetails The order details.
     */
    function getApproveTo(
        FuzzTestContext memory context,
        OrderDetails memory orderDetails
    ) internal view returns (address) {
        if (orderDetails.conduitKey == bytes32(0)) {
            return address(context.seaport);
        } else {
            (address conduit, bool exists) = context
                .conduitController
                .getConduit(orderDetails.conduitKey);
            if (exists) {
                return conduit;
            } else {
                revert("CheckHelpers: Conduit not found");
            }
        }
    }
}

/**
 *  @dev Setup functions perform the stateful setup steps necessary to run a
 *       FuzzEngine test, like minting test tokens and setting approvals.
 *       Currently, we also register checks in the setup step, but we might
 *       want to move this to a separate step. Setup happens after generation,
 *       amendment, and derivation, but before execution.
 */
abstract contract FuzzSetup is Test, AmountDeriverHelper {
    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for FuzzTestContext;

    using FuzzHelpers for AdvancedOrder[];
    using ZoneParametersLib for AdvancedOrder[];

    using ExecutionLib for Execution;

    using ExpectedEventsUtil for FuzzTestContext;

    /**
     *  @dev Set up the zone params on a test context.
     *
     * @param context The test context.
     */
    function setUpZoneParameters(FuzzTestContext memory context) public view {
        UnavailableReason[] memory unavailableReasons = new UnavailableReason[](
            context.advancedOrdersSpace.orders.length
        );

        for (uint256 i; i < context.executionState.orderDetails.length; ++i) {
            unavailableReasons[i] = context
                .executionState
                .orderDetails[i]
                .unavailableReason;
        }

        // Get the expected zone calldata hashes for each order.
        bytes32[] memory authorizeCalldataHashes = context
            .executionState
            .orders
            .getExpectedZoneAuthorizeCalldataHash(
                address(context.seaport),
                context.executionState.caller,
                context.executionState.criteriaResolvers,
                context.executionState.maximumFulfilled,
                unavailableReasons
            );

        bytes32[] memory validateCalldataHashes = context
            .executionState
            .orders
            .getExpectedZoneValidateCalldataHash(
                address(context.seaport),
                context.executionState.caller,
                context.executionState.criteriaResolvers,
                context.executionState.maximumFulfilled,
                unavailableReasons
            );

        // Provision the expected zone calldata hash arrays.
        bytes32[] memory expectedZoneAuthorizeCalldataHashes = new bytes32[](
            context.executionState.orders.length
        );
        bytes32[] memory expectedZoneValidateCalldataHashes = new bytes32[](
            context.executionState.orders.length
        );

        bool registerChecks;

        // Iterate over the orders and for each restricted order, set up the
        // expected zone calldata hash. If any of the orders is restricted,
        // flip the flag to register the hash validation check.
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = context
                .executionState
                .orders[i]
                .parameters;
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE &&
                (order.orderType == OrderType.FULL_RESTRICTED ||
                    order.orderType == OrderType.PARTIAL_RESTRICTED)
            ) {
                registerChecks = true;
                expectedZoneAuthorizeCalldataHashes[
                    i
                ] = authorizeCalldataHashes[i];
                expectedZoneValidateCalldataHashes[i] = validateCalldataHashes[
                    i
                ];
            }
        }

        context
            .expectations
            .expectedZoneAuthorizeCalldataHashes = expectedZoneAuthorizeCalldataHashes;
        context
            .expectations
            .expectedZoneValidateCalldataHashes = expectedZoneValidateCalldataHashes;

        if (registerChecks) {
            context.registerCheck(
                FuzzChecks.check_authorizeOrderExpectedDataHash.selector
            );
            context.registerCheck(
                FuzzChecks.check_validateOrderExpectedDataHash.selector
            );
        }
    }

    function setUpContractOfferers(FuzzTestContext memory context) public pure {
        bytes32[2][] memory contractOrderCalldataHashes = context
            .getExpectedContractOffererCalldataHashes();

        bytes32[2][]
            memory expectedContractOrderCalldataHashes = new bytes32[2][](
                context.executionState.orders.length
            );

        bool registerChecks;

        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            OrderParameters memory order = context
                .executionState
                .orders[i]
                .parameters;
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE &&
                order.orderType == OrderType.CONTRACT
            ) {
                registerChecks = true;
                expectedContractOrderCalldataHashes[i][
                    0
                ] = contractOrderCalldataHashes[i][0];
                expectedContractOrderCalldataHashes[i][
                    1
                ] = contractOrderCalldataHashes[i][1];
            }
        }

        context
            .expectations
            .expectedContractOrderCalldataHashes = expectedContractOrderCalldataHashes;

        if (registerChecks) {
            context.registerCheck(
                FuzzChecks.check_contractOrderExpectedDataHashes.selector
            );
        }
    }

    /**
     *  @dev Set up the offer items on a test context. Mints test tokens and
     *       sets necessary approvals.
     *
     * @param context The test context.
     */
    function setUpOfferItems(FuzzTestContext memory context) public {
        bool isMatchable = context.action() ==
            context.seaport.matchAdvancedOrders.selector ||
            context.action() == context.seaport.matchOrders.selector;

        // Iterate over orders and mint/approve as necessary.
        for (uint256 i; i < context.executionState.orderDetails.length; ++i) {
            OrderDetails memory order = context.executionState.orderDetails[i];

            if (order.unavailableReason != UnavailableReason.AVAILABLE) {
                continue;
            }

            SpentItem[] memory items = order.offer;
            address offerer = order.offerer;
            address approveTo = context.getApproveTo(order);
            for (uint256 j = 0; j < items.length; j++) {
                SpentItem memory item = items[j];

                if (item.itemType == ItemType.NATIVE) {
                    if (
                        context.executionState.orders[i].parameters.orderType ==
                        OrderType.CONTRACT
                    ) {
                        vm.deal(offerer, offerer.balance + item.amount);
                    } else if (isMatchable) {
                        vm.deal(
                            context.executionState.caller,
                            context.executionState.caller.balance + item.amount
                        );
                    }
                }

                if (item.itemType == ItemType.ERC20) {
                    TestERC20(item.token).mint(offerer, item.amount);
                    vm.prank(offerer);
                    TestERC20(item.token).increaseAllowance(
                        approveTo,
                        item.amount
                    );
                }

                if (item.itemType == ItemType.ERC721) {
                    TestERC721(item.token).mint(offerer, item.identifier);
                    vm.prank(offerer);
                    TestERC721(item.token).setApprovalForAll(approveTo, true);
                }

                if (item.itemType == ItemType.ERC1155) {
                    TestERC1155(item.token).mint(
                        offerer,
                        item.identifier,
                        item.amount
                    );
                    vm.prank(offerer);
                    TestERC1155(item.token).setApprovalForAll(approveTo, true);
                }
            }
        }
    }

    /**
     *  @dev Set up the consideration items on a test context. Mints test tokens
     *       and sets necessary approvals.
     *
     * @param context The test context.
     */
    function setUpConsiderationItems(FuzzTestContext memory context) public {
        // Skip creating consideration items if we're calling a match function
        if (
            context.action() == context.seaport.matchAdvancedOrders.selector ||
            context.action() == context.seaport.matchOrders.selector
        ) return;

        // In all cases, deal balance to caller if consideration item is native
        for (uint256 i; i < context.executionState.orderDetails.length; ++i) {
            OrderDetails memory order = context.executionState.orderDetails[i];
            ReceivedItem[] memory items = order.consideration;

            for (uint256 j = 0; j < items.length; j++) {
                if (items[j].itemType == ItemType.NATIVE) {
                    vm.deal(
                        context.executionState.caller,
                        context.executionState.caller.balance + items[j].amount
                    );
                }
            }
        }

        // Special handling for basic orders that are bids; only first item
        // needs to be approved
        if (
            (context.action() == context.seaport.fulfillBasicOrder.selector ||
                context.action() ==
                context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector) &&
            context.executionState.orders[0].parameters.offer[0].itemType ==
            ItemType.ERC20
        ) {
            ConsiderationItem memory item = context
                .executionState
                .orders[0]
                .parameters
                .consideration[0];

            address approveTo = context.getApproveTo();

            if (item.itemType == ItemType.ERC721) {
                TestERC721(item.token).mint(
                    context.executionState.caller,
                    item.identifierOrCriteria
                );
                vm.prank(context.executionState.caller);
                TestERC721(item.token).setApprovalForAll(approveTo, true);
            } else {
                TestERC1155(item.token).mint(
                    context.executionState.caller,
                    item.identifierOrCriteria,
                    item.startAmount
                );
                vm.prank(context.executionState.caller);
                TestERC1155(item.token).setApprovalForAll(approveTo, true);
            }

            return;
        }

        // Iterate over orders and mint/approve as necessary.
        for (uint256 i; i < context.executionState.orderDetails.length; ++i) {
            OrderDetails memory order = context.executionState.orderDetails[i];
            ReceivedItem[] memory items = order.consideration;

            if (order.unavailableReason != UnavailableReason.AVAILABLE) {
                continue;
            }

            address owner = context.executionState.caller;
            address approveTo = context.getApproveTo();

            for (uint256 j = 0; j < items.length; j++) {
                ReceivedItem memory item = items[j];

                if (item.itemType == ItemType.ERC20) {
                    TestERC20(item.token).mint(owner, item.amount);
                    vm.prank(owner);
                    TestERC20(item.token).increaseAllowance(
                        approveTo,
                        item.amount
                    );
                }

                if (item.itemType == ItemType.ERC721) {
                    bool shouldMint = true;
                    if (
                        context.executionState.caller ==
                        context.executionState.recipient ||
                        context.executionState.recipient == address(0)
                    ) {
                        for (
                            uint256 k;
                            k < context.executionState.orderDetails.length;
                            ++k
                        ) {
                            if (
                                context
                                    .executionState
                                    .orderDetails[k]
                                    .unavailableReason !=
                                UnavailableReason.AVAILABLE
                            ) {
                                continue;
                            }

                            SpentItem[] memory spentItems = context
                                .executionState
                                .orderDetails[k]
                                .offer;
                            for (uint256 l; l < spentItems.length; ++l) {
                                if (
                                    spentItems[l].itemType == ItemType.ERC721 &&
                                    spentItems[l].token == item.token &&
                                    spentItems[l].identifier == item.identifier
                                ) {
                                    shouldMint = false;
                                    break;
                                }
                            }
                            if (!shouldMint) break;
                        }
                    }
                    if (shouldMint) {
                        TestERC721(item.token).mint(owner, item.identifier);
                    }
                    vm.prank(owner);
                    TestERC721(item.token).setApprovalForAll(approveTo, true);
                }

                if (item.itemType == ItemType.ERC1155) {
                    TestERC1155(item.token).mint(
                        owner,
                        item.identifier,
                        item.amount
                    );
                    vm.prank(owner);
                    TestERC1155(item.token).setApprovalForAll(approveTo, true);
                }
            }
        }
    }

    function registerExpectedEventsAndBalances(
        FuzzTestContext memory context
    ) public {
        ExecutionsFlattener.flattenExecutions(context);
        context.registerCheck(FuzzChecks.check_expectedBalances.selector);
        ExpectedBalances balanceChecker = context.testHelpers.balanceChecker();

        Execution[] memory _executions = context
            .expectations
            .allExpectedExecutions;
        Execution[] memory executions = _executions;

        try balanceChecker.addTransfers(executions) {} catch (
            bytes memory reason
        ) {
            context.expectations.allExpectedExecutions = executions;
            dumpExecutions(context);
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        }
        context.registerCheck(FuzzChecks.check_executions.selector);
        context.setExpectedTransferEventHashes();
        context.registerCheck(
            FuzzChecks.check_expectedTransferEventsEmitted.selector
        );
        ExpectedEventsUtil.startRecordingLogs();
    }

    /**
     * @dev Set up the checks that will always be run. Note that this must be
     *      run after registerExpectedEventsAndBalances at the moment.
     *
     * @param context The test context.
     */
    function registerCommonChecks(FuzzTestContext memory context) public {
        context.setExpectedSeaportEventHashes();
        context.registerCheck(
            FuzzChecks.check_expectedSeaportEventsEmitted.selector
        );
        context.registerCheck(FuzzChecks.check_orderStatusFullyFilled.selector);
    }

    /**
     *  @dev Set up the function-specific checks.
     *
     * @param context The test context.
     */
    function registerFunctionSpecificChecks(
        FuzzTestContext memory context
    ) public view {
        bytes4 _action = context.action();
        if (_action == context.seaport.fulfillOrder.selector) {
            context.registerCheck(FuzzChecks.check_orderFulfilled.selector);
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            context.registerCheck(FuzzChecks.check_orderFulfilled.selector);
        } else if (_action == context.seaport.fulfillBasicOrder.selector) {
            context.registerCheck(FuzzChecks.check_orderFulfilled.selector);
        } else if (
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            context.registerCheck(FuzzChecks.check_orderFulfilled.selector);
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            context.registerCheck(FuzzChecks.check_allOrdersFilled.selector);
        } else if (
            _action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            context.registerCheck(FuzzChecks.check_allOrdersFilled.selector);
        } else if (_action == context.seaport.matchOrders.selector) {
            // Add match-specific checks
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            // Add match-specific checks
        } else if (_action == context.seaport.cancel.selector) {
            context.registerCheck(FuzzChecks.check_orderCancelled.selector);
        } else if (_action == context.seaport.validate.selector) {
            context.registerCheck(FuzzChecks.check_orderValidated.selector);
        } else {
            revert("FuzzEngine: Action not implemented");
        }
    }
}
