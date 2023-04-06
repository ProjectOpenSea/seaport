// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "seaport-sol/SeaportSol.sol";

import { FuzzChecks } from "./FuzzChecks.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { CriteriaResolverHelper } from "./CriteriaResolverHelper.sol";
import {
    AmountDeriverHelper
} from "../../../../contracts/helpers/sol/lib/fulfillment/AmountDeriverHelper.sol";

import { ExpectedEventsUtil } from "./event-utils/ExpectedEventsUtil.sol";

import { ExecutionsFlattener } from "./event-utils/ExecutionsFlattener.sol";

import { ExpectedBalances } from "./ExpectedBalances.sol";

import { dumpExecutions } from "./DebugUtil.sol";

interface TestERC20 {
    function mint(address to, uint256 amount) external;

    function increaseAllowance(address spender, uint256 amount) external;
}

interface TestERC721 {
    function mint(address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;
}

interface TestERC1155 {
    function mint(address to, uint256 tokenId, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;
}

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
}

/**
 *  @dev Setup functions perform the stateful setup steps necessary to run a
 *       FuzzEngine test, like minting test tokens and setting approvals.
 *       Currently, we also register checks in the setup step, but we might
 *       want to move this to a separate step. Setup happens after derivation,
 *       but before execution.
 */
abstract contract FuzzSetup is Test, AmountDeriverHelper {
    using CheckHelpers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;

    using FuzzHelpers for AdvancedOrder[];
    using ZoneParametersLib for AdvancedOrder[];

    using ExecutionLib for Execution;

    /**
     *  @dev Set up the zone params on a test context.
     *
     * @param context The test context.
     */
    function setUpZoneParameters(FuzzTestContext memory context) public view {
        // Get the expected zone calldata hashes for each order.
        bytes32[] memory calldataHashes = context
            .orders
            .getExpectedZoneCalldataHash(
                address(context.seaport),
                context.caller,
                context.criteriaResolvers,
                context.maximumFulfilled
            );

        // Provision the expected zone calldata hash array.
        bytes32[] memory expectedZoneCalldataHash = new bytes32[](
            context.orders.length
        );

        bool registerChecks;

        // Iterate over the orders and for each restricted order, set up the
        // expected zone calldata hash. If any of the orders is restricted,
        // flip the flag to register the hash validation check.
        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory order = context.orders[i].parameters;
            if (
                context.expectedAvailableOrders[i] && (
                order.orderType == OrderType.FULL_RESTRICTED ||
                order.orderType == OrderType.PARTIAL_RESTRICTED )
            ) {
                registerChecks = true;
                expectedZoneCalldataHash[i] = calldataHashes[i];
            }
        }

        context.expectedZoneCalldataHash = expectedZoneCalldataHash;

        if (registerChecks) {
            context.registerCheck(
                FuzzChecks.check_validateOrderExpectedDataHash.selector
            );
        }
    }

    /**
     *  @dev Set up the offer items on a test context.
     *
     * @param context The test context.
     */
    function setUpOfferItems(FuzzTestContext memory context) public {
        OrderDetails[] memory orderDetails = toOrderDetails(
            context.orders,
            context.criteriaResolvers
        );

        // Iterate over orders and mint/approve as necessary.
        for (uint256 i; i < orderDetails.length; ++i) {
            if (!context.expectedAvailableOrders[i]) continue;

            OrderDetails memory order = orderDetails[i];
            SpentItem[] memory items = order.offer;
            address offerer = order.offerer;
            address approveTo = _getApproveTo(context, order);
            for (uint256 j = 0; j < items.length; j++) {
                SpentItem memory item = items[j];

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
                    TestERC721(item.token).approve(approveTo, item.identifier);
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
     *  @dev Set up the consideration items on a test context.
     *
     * @param context The test context.
     */
    function setUpConsiderationItems(FuzzTestContext memory context) public {
        // Skip creating consideration items if we're calling a match function
        if (
            context.action() == context.seaport.matchAdvancedOrders.selector ||
            context.action() == context.seaport.matchOrders.selector
        ) return;

        // Special handling for basic orders that are bids; only first item
        // needs to be approved
        if (
            (context.action() == context.seaport.fulfillBasicOrder.selector ||
                context.action() ==
                context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector) &&
            context.orders[0].parameters.offer[0].itemType == ItemType.ERC20
        ) {
            ConsiderationItem memory item = context
                .orders[0]
                .parameters
                .consideration[0];

            if (item.itemType == ItemType.ERC721) {
                TestERC721(item.token).mint(
                    context.caller,
                    item.identifierOrCriteria
                );
                vm.prank(context.caller);
                TestERC721(item.token).setApprovalForAll(
                    _getApproveTo(context),
                    true
                );
            } else {
                TestERC1155(item.token).mint(
                    context.caller,
                    item.identifierOrCriteria,
                    item.startAmount
                );
                vm.prank(context.caller);
                TestERC1155(item.token).setApprovalForAll(
                    _getApproveTo(context),
                    true
                );
            }

            return;
        }

        OrderDetails[] memory orderDetails = toOrderDetails(
            context.orders,
            context.criteriaResolvers
        );

        // Naive implementation for now
        // TODO: - If recipient is not caller, we need to mint everything
        //       - For matchOrders, we don't need to do any setup
        // Iterate over orders and mint/approve as necessary.
        for (uint256 i; i < orderDetails.length; ++i) {
            if (!context.expectedAvailableOrders[i]) continue;

            OrderDetails memory order = orderDetails[i];
            ReceivedItem[] memory items = order.consideration;

            address owner = context.caller;
            address approveTo = _getApproveTo(context);

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
                        context.caller == context.recipient ||
                        context.recipient == address(0)
                    ) {
                        for (uint256 k; k < orderDetails.length; ++k) {
                            if (!context.expectedAvailableOrders[k]) continue;

                            SpentItem[] memory spentItems = orderDetails[k]
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

        // Note: fewer (or occcasionally greater) native tokens need to be
        // supplied when orders are unavailable; however, this is generally
        // not known at the time of submission. Consider adding a fuzz param
        // for supplying the minimum possible native token value.
        uint256 callValue = context.getNativeTokensToSupply();

        Execution[] memory _executions = context.allExpectedExecutions;
        Execution[] memory executions = _executions;

        if (callValue > 0) {
            address caller = context.caller;
            if (caller == address(0)) caller = address(this);
            address seaport = address(context.seaport);
            executions = new Execution[](_executions.length + 1);
            executions[0] = ExecutionLib.empty().withOfferer(caller);
            executions[0].item.amount = callValue;
            executions[0].item.recipient = payable(seaport);
            for (uint256 i; i < _executions.length; i++) {
                Execution memory execution = _executions[i].copy();
                executions[i + 1] = execution;
                if (execution.item.itemType == ItemType.NATIVE) {
                    execution.offerer = seaport;
                }
            }
        }

        try balanceChecker.addTransfers(executions) {} catch (
            bytes memory reason
        ) {
            context.allExpectedExecutions = executions;
            dumpExecutions(context);
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        }
        context.registerCheck(FuzzChecks.check_executions.selector);
        ExpectedEventsUtil.setExpectedEventHashes(context);
        context.registerCheck(FuzzChecks.check_expectedEventsEmitted.selector);
        ExpectedEventsUtil.startRecordingLogs();
    }

    /**
     *  @dev Set up the checks that will always be run.
     *
     * @param context The test context.
     */
    function registerCommonChecks(FuzzTestContext memory context) public pure {
        context.registerCheck(FuzzChecks.check_orderStatusFullyFilled.selector);
    }

    /**
     *  @dev Set up the function-specific checks.
     *
     * @param context The test context.
     */
    function registerFunctionSpecificChecks(
        FuzzTestContext memory context
    ) public {
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

    /**
     *  @dev Get the address to approve to for a given test context.
     *
     * @param context The test context.
     */
    function _getApproveTo(
        FuzzTestContext memory context
    ) internal view returns (address) {
        if (context.fulfillerConduitKey == bytes32(0)) {
            return address(context.seaport);
        } else {
            (address conduit, bool exists) = context
                .conduitController
                .getConduit(context.fulfillerConduitKey);
            if (exists) {
                return conduit;
            } else {
                revert("FuzzSetup: Conduit not found");
            }
        }
    }

    /**
     *  @dev Get the address to approve to for a given test context and order.
     *
     * @param context The test context.
     * @param orderParams The order parameters.
     */
    function _getApproveTo(
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
                revert("FuzzSetup: Conduit not found");
            }
        }
    }

    /**
     *  @dev Get the address to approve to for a given test context and order.
     *
     * @param context The test context.
     * @param orderDetails The order details.
     */
    function _getApproveTo(
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
                revert("FuzzSetup: Conduit not found");
            }
        }
    }
}
