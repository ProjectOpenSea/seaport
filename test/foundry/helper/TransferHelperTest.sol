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

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));

        address thisAddress = address(this);
        token1.mint(thisAddress, 20);
        test721_1.mint(thisAddress, 1);
        test1155_1.mint(thisAddress, 1, 20);
        _setApprovals(thisAddress);
    }

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
    ) public returns (uint256 fromBalance, uint256 toBalance) {
        return (
            balanceOfTransferItemForAddress(item, from),
            balanceOfTransferItemForAddress(item, to)
        );
    }

    function performSingleTransferFromThisAndCheckBalances(
        // TODO allow specifying an arbitrary number of items
        TransferHelperItem memory item,
        address to
    ) public {
        // TODO make more flexible to allow passing in a from and using prank
        // to get the msg.sender/tx.origin to be the from
        address from = address(this);

        // Get initial balances
        (
            uint256 fromBalanceBeforeTransfer,
            uint256 toBalanceBeforeTransfer
        ) = balanceOfTransferItemForFromTo(item, from, to);

        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        transferHelper.bulkTransfer(items, to, bytes32(0));

        (
            uint256 fromBalanceAfterTransfer,
            uint256 toBalanceAfterTransfer
        ) = balanceOfTransferItemForFromTo(item, from, to);
        // Check final balances by calculating difference against initial
        assertEq(
            fromBalanceAfterTransfer,
            fromBalanceBeforeTransfer - item.amount
        );
        assertEq(toBalanceAfterTransfer, toBalanceBeforeTransfer + item.amount);
    }

    function testBulkTransferERC20() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            20
        );
        address to = address(1);
        performSingleTransferFromThisAndCheckBalances(item, to);
    }

    function testBulkTransferERC721() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );
        address to = address(1);
        performSingleTransferFromThisAndCheckBalances(item, to);
    }

    function testBulkTransferERC1155() public {
        TransferHelperItem memory item = TransferHelperItem(
            ConduitItemType.ERC1155,
            address(test1155_1),
            1,
            20
        );
        address to = address(1);
        performSingleTransferFromThisAndCheckBalances(item, to);
    }
}
