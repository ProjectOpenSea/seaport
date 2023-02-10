// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    GenericAdapterSidecar,
    Call
} from "../../../contracts/contractOfferers/GenericAdapterSidecar.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

contract GenericAdapterSidecarTest is Test {
    GenericAdapterSidecar test;
    TestERC721 testERC721;
    TestERC1155 testERC1155;
    bool rejectReceive;

    function setUp() public {
        test = new GenericAdapterSidecar();
        testERC721 = new TestERC721();
        testERC1155 = new TestERC1155();
    }

    function testReceive() public {
        (bool succ, ) = address(test).call{ value: 1 ether }("");
        require(succ);
        assertEq(address(test).balance, 1 ether);

        testERC1155.mint(address(test), 1, 1);
        // testERC721.mint(address(this), 1);
        // testERC721.safeTransferFrom(address(this), address(test), 1);
    }

    function testExecuteReturnsNativeBalance() public {
        Call[] memory calls;
        test.execute(calls);

        (bool succ, ) = address(test).call{ value: 1 ether }("");
        require(succ);
        assertEq(address(test).balance, 1 ether);

        test.execute(calls);
        assertEq(address(test).balance, 0);

        rejectReceive = true;
        (succ, ) = address(test).call{ value: 1 ether }("");
        vm.expectRevert(
            abi.encodeWithSelector(
                GenericAdapterSidecar.ExcessNativeTokenReturnFailed.selector,
                1 ether
            )
        );
        test.execute(calls);
    }

    function testExecuteNotDesignatedCaller() public {
        vm.prank(makeAddr("not designated caller"));
        vm.expectRevert(GenericAdapterSidecar.InvalidEncodingOrCaller.selector);
        Call[] memory calls;
        test.execute(calls);
    }

    receive() external payable {
        if (rejectReceive) {
            revert("rejectReceive");
        }
    }
}
