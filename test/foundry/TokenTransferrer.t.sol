// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";
import {
    ConduitTransfer,
    ConduitItemType
} from "../../contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "./utils/ERC1155Recipient.sol";
import { BaseConduitTest } from "./conduit/BaseConduitTest.sol";
import { Conduit } from "../../contracts/conduit/Conduit.sol";

contract TokenTransferrerTest is BaseConduitTest {
    struct Context {
        Conduit conduit;
        ConduitTransfer[] transfers;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testTokenTransferrer() public {
        // struct ConduitTransfer {
        //     ConduitItemType itemType;
        //     address token;
        //     address from;
        //     address to;
        //     uint256 identifier;
        //     uint256 amount;
        // }

        // struct ConduitBatch1155Transfer {
        //     address token;
        //     address from;
        //     address to;
        //     uint256[] ids;
        //     uint256[] amounts;
        // }

        ConduitItemType[3] memory itemTypes;
        itemTypes = [ConduitItemType.ERC20, ConduitItemType.ERC721, ConduitItemType.ERC1155];
        ConduitItemType itemType;

        address noCodeTokenAddress;
        noCodeTokenAddress = address(0xabc);

        uint256 alicePk = 0xa11ce;
        uint256 bobPk = 0xb0b;
        address payable alice = payable(vm.addr(alicePk));
        address payable bob = payable(vm.addr(bobPk));

        // Iterate over each order.
        for (uint256 i = 0; i < itemTypes.length; ++i) {
            itemType = itemTypes[i];

            ConduitTransfer[] memory noCodeTransfer;
            noCodeTransfer = new ConduitTransfer[](1);
            noCodeTransfer[0] = ConduitTransfer(
                itemType,
                address(noCodeTokenAddress),
                address(alice),
                address(bob),
                0,
                1
            );

            
            vm.expectRevert(abi.encodeWithSignature("NoContract(address)", noCodeTokenAddress));
            test(this.execute, Context(referenceConduit, noCodeTransfer));
            vm.expectRevert(abi.encodeWithSignature("NoContract(address)", noCodeTokenAddress));
            test(this.execute, Context(conduit, noCodeTransfer));
        }
    }

    function execute(Context memory context) external stateless {
        context.conduit.execute(context.transfers);
    }
}
