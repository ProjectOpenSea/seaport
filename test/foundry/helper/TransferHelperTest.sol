// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";

contract TransferHelperTest is BaseConsiderationTest {
    TransferHelper transferHelper;

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper();
    }

    function testBulkTransfer() public {
        transferHelper.bulkTransfer();
    }
}
