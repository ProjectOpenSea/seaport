// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConduitTransfer,
    ConduitBatch1155Transfer,
    ConduitItemType
} from "../../contracts/conduit/lib/ConduitStructs.sol";

import { TestERC20Revert } from "../../contracts/test/TestERC20Revert.sol";

import { TestERC20NotOk } from "../../contracts/test/TestERC20NotOk.sol";

import { TestERC721Revert } from "../../contracts/test/TestERC721Revert.sol";

import { TestERC1155Revert } from "../../contracts/test/TestERC1155Revert.sol";

import { BaseConduitTest } from "./conduit/BaseConduitTest.sol";

import { Conduit } from "../../contracts/conduit/Conduit.sol";

import {
    TokenTransferrerErrors
} from "../../contracts/interfaces/TokenTransferrerErrors.sol";

contract TokenTransferrerTest is BaseConduitTest, TokenTransferrerErrors {
    bytes expectedRevert =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address noCodeTokenAddress = makeAddr("noCodeTokenAddress");

    struct Context {
        Conduit conduit;
        bytes expectedRevert;
        ConduitTransfer[] transfers;
        ConduitBatch1155Transfer[] batchTransfers;
    }

    function execute(Context memory context) external stateless {
        vm.expectRevert(context.expectedRevert);
        context.conduit.execute(context.transfers);
    }

    function executeBatch(Context memory context) external stateless {
        vm.expectRevert(context.expectedRevert);
        context.conduit.executeBatch1155(context.batchTransfers);
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testRevertErc1155Transfer() public {
        // Test the ERC1155 revert case.
        TestERC1155Revert semifungibleTokenRevert;
        semifungibleTokenRevert = new TestERC1155Revert();

        ConduitTransfer[] memory revertTransfer;
        revertTransfer = new ConduitTransfer[](1);

        ConduitTransfer[] memory noCodeTransfer;
        noCodeTransfer = new ConduitTransfer[](1);
        ConduitBatch1155Transfer[] memory noCodeBatchTransfer;
        noCodeBatchTransfer = new ConduitBatch1155Transfer[](1);

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC1155,
            address(semifungibleTokenRevert),
            alice,
            bob,
            0,
            1
        );

        test(
            this.execute,
            Context(
                conduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );
        test(
            this.execute,
            Context(
                referenceConduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );
    }

    function testRevertErc721Transfer() public {
        TestERC721Revert nonfungibleTokenRevert;
        nonfungibleTokenRevert = new TestERC721Revert();
        vm.label(address(nonfungibleTokenRevert), "nonfungibleTokenRevert");

        ConduitTransfer[] memory revertTransfer;
        revertTransfer = new ConduitTransfer[](1);

        ConduitTransfer[] memory noCodeTransfer;
        noCodeTransfer = new ConduitTransfer[](1);
        ConduitBatch1155Transfer[] memory noCodeBatchTransfer;
        noCodeBatchTransfer = new ConduitBatch1155Transfer[](1);

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC721,
            address(nonfungibleTokenRevert),
            alice,
            bob,
            0,
            1
        );

        test(
            this.execute,
            Context(
                referenceConduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );
        test(
            this.execute,
            Context(
                conduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );
    }

    function testRevertErc20Transfer() public {
        // Test the generic failure case where the token contract reverts.
        ConduitTransfer[] memory revertTransfer;
        revertTransfer = new ConduitTransfer[](1);

        ConduitBatch1155Transfer[] memory noCodeBatchTransfer;
        noCodeBatchTransfer = new ConduitBatch1155Transfer[](1);

        TestERC20Revert tokenRevert;
        tokenRevert = new TestERC20Revert();
        vm.label(address(tokenRevert), "tokenRevert");

        noCodeBatchTransfer[0] = ConduitBatch1155Transfer(
            address(noCodeTokenAddress),
            address(alice),
            address(bob),
            new uint256[](0),
            new uint256[](0)
        );

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC20,
            address(tokenRevert),
            address(alice),
            address(bob),
            0,
            1
        );

        test(
            this.execute,
            Context(
                conduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );

        expectedRevert = abi.encodeWithSelector(
            TokenTransferGenericFailure.selector,
            address(tokenRevert),
            address(alice),
            address(bob),
            0,
            1
        );

        test(
            this.execute,
            Context(
                referenceConduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );
    }

    function testRevertNoCodeTransfer() public {
        ConduitItemType[3] memory itemTypes;
        itemTypes = [
            ConduitItemType.ERC20,
            ConduitItemType.ERC721,
            ConduitItemType.ERC1155
        ];
        ConduitItemType itemType;

        ConduitTransfer[] memory noCodeTransfer;
        noCodeTransfer = new ConduitTransfer[](1);
        ConduitBatch1155Transfer[] memory noCodeBatchTransfer;
        noCodeBatchTransfer = new ConduitBatch1155Transfer[](1);

        // Iterate over each item type and test the revert case where there's no code.
        for (uint256 i = 0; i < itemTypes.length; ++i) {
            itemType = itemTypes[i];

            noCodeTransfer[0] = ConduitTransfer(
                itemType,
                address(noCodeTokenAddress),
                alice,
                bob,
                0,
                1
            );

            expectedRevert = abi.encodeWithSelector(
                NoContract.selector,
                noCodeTokenAddress
            );

            test(
                this.execute,
                Context(
                    referenceConduit,
                    expectedRevert,
                    noCodeTransfer,
                    noCodeBatchTransfer
                )
            );
            test(
                this.execute,
                Context(
                    conduit,
                    expectedRevert,
                    noCodeTransfer,
                    noCodeBatchTransfer
                )
            );
        }

        // Test the 1155 batch transfer no code revert.
        noCodeBatchTransfer[0] = ConduitBatch1155Transfer(
            noCodeTokenAddress,
            alice,
            bob,
            new uint256[](0),
            new uint256[](0)
        );

        test(
            this.executeBatch,
            Context(
                referenceConduit,
                expectedRevert,
                noCodeTransfer,
                noCodeBatchTransfer
            )
        );
        test(
            this.executeBatch,
            Context(
                conduit,
                expectedRevert,
                noCodeTransfer,
                noCodeBatchTransfer
            )
        );
    }

    function testRevertNotOk() public {
        // Test the generic failure case where the token contract returns not OK but does not revert.
        ConduitTransfer[] memory notOkTransfer;
        notOkTransfer = new ConduitTransfer[](1);

        ConduitBatch1155Transfer[] memory noCodeBatchTransfer;
        noCodeBatchTransfer = new ConduitBatch1155Transfer[](1);

        noCodeBatchTransfer[0] = ConduitBatch1155Transfer(
            noCodeTokenAddress,
            alice,
            bob,
            new uint256[](0),
            new uint256[](0)
        );

        TestERC20NotOk tokenNotOk;
        tokenNotOk = new TestERC20NotOk();
        vm.label(address(tokenNotOk), "tokenNotOk");

        vm.startPrank(alice);
        tokenNotOk.mint(alice, 100);
        tokenNotOk.approve(address(consideration), uint256(100));
        tokenNotOk.approve(address(referenceConsideration), uint256(100));
        tokenNotOk.approve(address(conduit), uint256(100));
        tokenNotOk.approve(address(referenceConduit), uint256(100));
        vm.stopPrank();

        notOkTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC20,
            address(tokenNotOk),
            address(alice),
            address(bob),
            0,
            1
        );

        expectedRevert = abi.encodeWithSelector(
            BadReturnValueFromERC20OnTransfer.selector,
            address(tokenNotOk),
            address(alice),
            address(bob),
            1
        );

        test(
            this.execute,
            Context(
                referenceConduit,
                expectedRevert,
                notOkTransfer,
                noCodeBatchTransfer
            )
        );
        test(
            this.execute,
            Context(conduit, expectedRevert, notOkTransfer, noCodeBatchTransfer)
        );
    }
}
