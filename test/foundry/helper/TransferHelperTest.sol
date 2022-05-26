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

    function testBulkTransfer() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            20
        );
        transferHelper.bulkTransfer(items, address(1), bytes32(0));
    }
}
