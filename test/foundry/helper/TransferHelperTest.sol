// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
// prettier-ignore
import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { ConduitItemType } from "../../../contracts/conduit/lib/ConduitEnums.sol";

import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";

import { TransferHelperItem } from "../../../contracts/helper/TransferHelperStructs.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

import { TransferHelperInterface } from "../../../contracts/interfaces/TransferHelperInterface.sol";

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;

    struct FromToBalance {
        // Balance of from address.
        uint256 from;
        // Balance of to address.
        uint256 to;
    }

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));

        // Mint initial tokens to alice for tests.
        token1.mint(alice, 20);
        // Mint ERC721 and ERC1155 with token IDs 0 to 9 to alice
        for (uint256 i = 0; i < 10; i++) {
            test721_1.mint(alice, i);
            test1155_1.mint(alice, i, 20);
        }

        // Allow transfer helper to perform transfers for these addresses.
        _setApprovals(alice);
        _setApprovals(bob);
        _setApprovals(cal);
    }

    // Helper functions

    function _setApprovals(address _owner) internal override {
        super._setApprovals(_owner);
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(address(transferHelper), MAX_INT);
        }
        for (uint256 i = 0; i < erc1155s.length; i++) {
            erc1155s[i].setApprovalForAll(address(transferHelper), true);
        }
        for (uint256 i = 0; i < erc721s.length; i++) {
            erc721s[i].setApprovalForAll(address(transferHelper), true);
        }
        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }

    function balanceOfTransferItemForAddress(
        TransferHelperItem memory item,
        address addr
    ) public returns (uint256) {
        if (item.itemType == ConduitItemType.ERC20) {
            return TestERC20(item.token).balanceOf(addr);
        } else if (item.itemType == ConduitItemType.ERC721) {
            return
                TestERC721(item.token).ownerOf(item.tokenIdentifier) == addr
                    ? 1
                    : 0;
        } else if (item.itemType == ConduitItemType.ERC1155) {
            return
                TestERC1155(item.token).balanceOf(addr, item.tokenIdentifier);
        }
        revert();
    }

    function balanceOfTransferItemForFromTo(
        TransferHelperItem memory item,
        address from,
        address to
    ) public returns (FromToBalance memory) {
        return
            FromToBalance(
                balanceOfTransferItemForAddress(item, from),
                balanceOfTransferItemForAddress(item, to)
            );
    }

    function performSingleItemTransferAndCheckBalances(
        TransferHelperItem memory item,
        address from,
        address to
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        performMultiItemTransferAndCheckBalances(items, from, to);
    }

    function performMultiItemTransferAndCheckBalances(
        TransferHelperItem[] memory items,
        address from,
        address to
    ) public {
        vm.startPrank(from);

        // Get balances before transfer
        FromToBalance[] memory beforeTransferBalances = new FromToBalance[](
            items.length
        );
        for (uint256 i = 0; i < items.length; i++) {
            beforeTransferBalances[i] = balanceOfTransferItemForFromTo(
                items[i],
                from,
                to
            );
        }

        // Perform transfer
        transferHelper.bulkTransfer(items, to, bytes32(0));

        // Get balances after transfer
        FromToBalance[] memory afterTransferBalances = new FromToBalance[](
            items.length
        );
        for (uint256 i = 0; i < items.length; i++) {
            afterTransferBalances[i] = balanceOfTransferItemForFromTo(
                items[i],
                from,
                to
            );
        }

        // Check after transfer balances are as expected by calculating difference against before transfer balances.
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(
                afterTransferBalances[i].from,
                beforeTransferBalances[i].from - items[i].amount
            );
            assertEq(
                afterTransferBalances[i].to,
                beforeTransferBalances[i].to + items[i].amount
            );
        }

        vm.stopPrank();
    }

    // Tests

    function testBulkTransferERC20() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            20
        );
        performSingleItemTransferAndCheckBalances(item, alice, bob);
    }

    function testBulkTransferERC721() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );
        address to = address(1);
        performSingleItemTransferAndCheckBalances(item, alice, bob);
    }

    function testBulkTransferERC721toBobThenCal() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );
        performSingleItemTransferAndCheckBalances(item, alice, bob);
        performSingleItemTransferAndCheckBalances(item, bob, cal);
    }

    function testBulkTransferERC1155() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC1155,
            address(test1155_1),
            1,
            20
        );
        performSingleItemTransferAndCheckBalances(item, alice, bob);
    }

    function testBulkTransferERC1155andERC721() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = TransferHelperItem(
            ConduitItemType.ERC1155,
            address(test1155_1),
            1,
            20
        );
        items[1] = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );

        performMultiItemTransferAndCheckBalances(items, alice, bob);
    }

    function testBulkTransferERC1155andERC721andERC20() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](3);
        items[0] = TransferHelperItem(
            ConduitItemType.ERC1155,
            address(test1155_1),
            1,
            20
        );
        items[1] = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );
        items[2] = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            8
        );

        performMultiItemTransferAndCheckBalances(items, alice, bob);
    }

    function testBulkTransferMultipleERC721() public {
        uint256 numItems = 3;
        TransferHelperItem[] memory items = new TransferHelperItem[](numItems);
        for (uint256 i = 0; i < numItems; i++) {
            items[i] = TransferHelperItem(
                ConduitItemType.ERC721,
                address(test721_1),
                i,
                1
            );
        }

        performMultiItemTransferAndCheckBalances(items, alice, bob);
    }

    function testRevertBulkTransferETH() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.NATIVE,
            address(0),
            1,
            20
        );

        // TODO check for custom error, I tried TransferHelperInterface.InvalidItemType.selector
        // but that didn't work
        vm.expectRevert();
        performSingleItemTransferAndCheckBalances(item, alice, bob);
    }
}
