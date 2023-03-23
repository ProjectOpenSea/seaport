// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "seaport-sol/SeaportSol.sol";

import "forge-std/console.sol";

import { FuzzChecks } from "./FuzzChecks.sol";
import { FuzzEngineLib } from "./FuzzEngine.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";
import { AmountDeriver } from "../../../../contracts/lib/AmountDeriver.sol";

import { TestContext } from "./TestContextLib.sol";

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
    function registerCheck(
        TestContext memory context,
        bytes4 check
    ) internal pure returns (TestContext memory) {
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

abstract contract FuzzSetup is Test, AmountDeriver {
    using FuzzEngineLib for TestContext;
    using CheckHelpers for TestContext;

    using FuzzHelpers for AdvancedOrder[];
    using ZoneParametersLib for AdvancedOrder[];

    function setUpZoneParameters(TestContext memory context) public view {
        // TODO: This doesn't take maximumFulfilled: should pass it through.
        bytes32[] memory calldataHashes = context
            .orders
            .getExpectedZoneCalldataHash(
                address(context.seaport),
                context.caller
            );

        bytes32[] memory expectedZoneCalldataHash = new bytes32[](
            context.orders.length
        );

        bool registerChecks;

        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory order = context.orders[i].parameters;
            if (
                order.orderType == OrderType.FULL_RESTRICTED ||
                order.orderType == OrderType.PARTIAL_RESTRICTED
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

    function setUpOfferItems(TestContext memory context) public {
        for (uint256 i; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            OfferItem[] memory items = orderParams.offer;
            address offerer = orderParams.offerer;
            address approveTo = _getApproveTo(context, orderParams);
            for (uint256 j = 0; j < items.length; j++) {
                OfferItem memory item = items[j];

                if (item.itemType == ItemType.ERC20) {
                    uint256 amount = _locateCurrentAmount(
                        item.startAmount,
                        item.endAmount,
                        orderParams.startTime,
                        orderParams.endTime,
                        false
                    );
                    TestERC20(item.token).mint(offerer, amount);
                    vm.prank(offerer);
                    TestERC20(item.token).increaseAllowance(approveTo, amount);
                }

                if (item.itemType == ItemType.ERC721) {
                    TestERC721(item.token).mint(
                        offerer,
                        item.identifierOrCriteria
                    );
                    vm.prank(offerer);
                    TestERC721(item.token).approve(
                        approveTo,
                        item.identifierOrCriteria
                    );
                }

                if (item.itemType == ItemType.ERC1155) {
                    uint256 amount = _locateCurrentAmount(
                        item.startAmount,
                        item.endAmount,
                        orderParams.startTime,
                        orderParams.endTime,
                        false
                    );
                    TestERC1155(item.token).mint(
                        offerer,
                        item.identifierOrCriteria,
                        amount
                    );
                    vm.prank(offerer);
                    TestERC1155(item.token).setApprovalForAll(approveTo, true);
                }
            }
        }
    }

    function setUpConsiderationItems(TestContext memory context) public {
        // Skip creating consideration items if we're calling a match function
        if (
            context.action() == context.seaport.matchAdvancedOrders.selector ||
            context.action() == context.seaport.matchOrders.selector
        ) return;

        // Naive implementation for now
        // TODO: - If recipient is not caller, we need to mint everything
        //       - For matchOrders, we don't need to do any setup
        for (uint256 i; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            ConsiderationItem[] memory items = orderParams.consideration;

            address owner = context.caller;
            address approveTo = _getApproveTo(context);

            for (uint256 j = 0; j < items.length; j++) {
                ConsiderationItem memory item = items[j];

                if (item.itemType == ItemType.ERC20) {
                    TestERC20(item.token).mint(owner, item.startAmount);
                    vm.prank(owner);
                    TestERC20(item.token).increaseAllowance(
                        approveTo,
                        item.startAmount
                    );
                }

                if (item.itemType == ItemType.ERC721) {
                    bool shouldMint = true;
                    if (
                        context.caller == context.recipient ||
                        context.recipient == address(0)
                    ) {
                        for (uint256 k; k < context.orders.length; ++k) {
                            OfferItem[] memory offerItems = context
                                .orders[k]
                                .parameters
                                .offer;
                            for (uint256 l; l < offerItems.length; ++l) {
                                if (
                                    offerItems[l].itemType == ItemType.ERC721 &&
                                    offerItems[l].token == item.token &&
                                    offerItems[l].identifierOrCriteria ==
                                    item.identifierOrCriteria
                                ) {
                                    shouldMint = false;
                                    break;
                                }
                            }
                            if (!shouldMint) break;
                        }
                    }
                    if (shouldMint) {
                        TestERC721(item.token).mint(
                            owner,
                            item.identifierOrCriteria
                        );
                    }
                    vm.prank(owner);
                    TestERC721(item.token).setApprovalForAll(approveTo, true);
                }

                if (item.itemType == ItemType.ERC1155) {
                    TestERC1155(item.token).mint(
                        owner,
                        item.identifierOrCriteria,
                        item.startAmount
                    );
                    vm.prank(owner);
                    TestERC1155(item.token).setApprovalForAll(approveTo, true);
                }
            }
        }
    }

    function _getApproveTo(
        TestContext memory context
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

    function _getApproveTo(
        TestContext memory context,
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
}
