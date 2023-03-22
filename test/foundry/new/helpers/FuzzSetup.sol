// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";

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

abstract contract FuzzSetup is Test, AmountDeriver {
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
                    TestERC721(item.token).mint(
                        owner,
                        item.identifierOrCriteria
                    );
                    vm.prank(owner);
                    TestERC721(item.token).approve(
                        approveTo,
                        item.identifierOrCriteria
                    );
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
