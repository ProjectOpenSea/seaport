// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { ConduitItemType } from "../../../contracts/conduit/lib/ConduitEnums.sol";
import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";
import { TransferHelperItem } from "../../../contracts/helper/TransferHelperStructs.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

contract TransferHelperTest is BaseConsiderationTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));
        testErc20 = new TestERC20();
        testErc20.mint(msg.sender, 20);
    }

    function testBulkTransfer() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = TransferHelperItem(
            ConduitItemType.ERC20,
            address(testErc20),
            1,
            20
        );
        transferHelper.bulkTransfer(items, address(1), bytes32(0));
    }
}
