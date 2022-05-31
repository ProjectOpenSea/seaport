// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
// prettier-ignore
import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { ConduitItemType } from "../../../contracts/conduit/lib/ConduitEnums.sol";

import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";

import { TransferHelperItem } from "../../../contracts/helper/TransferHelperStructs.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));
        token1.mint(address(this), 20);
        _setApprovals(address(this));
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

    function testBulkTransferERC20() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        uint256 amount = 20;
        items[0] = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            amount
        );
        address from = address(this);
        address to = address(1);

        // Get initial balances
        // TODO create helper fn that takes in an arbitrary token ID
        // and list of addresses and returns a list of balances
        uint256 fromBalanceBeforeTransfer = token1.balanceOf(from);
        uint256 toBalanceBeforeTransfer = token1.balanceOf(to);

        transferHelper.bulkTransfer(items, to, bytes32(0));

        // Check final balances
        assertEq(token1.balanceOf(from), fromBalanceBeforeTransfer - amount);
        assertEq(token1.balanceOf(to), toBalanceBeforeTransfer + amount);
    }
}
