// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";
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
    bytes expectedRevert;

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

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testTokenTransferrer() public {
        ConduitItemType[3] memory itemTypes;
        itemTypes = [
            ConduitItemType.ERC20,
            ConduitItemType.ERC721,
            ConduitItemType.ERC1155
        ];
        ConduitItemType itemType;

        address noCodeTokenAddress;
        noCodeTokenAddress = makeAddr("noCodeTokenAddress");

        address alice;
        address bob;
        alice = makeAddr("alice");
        bob = makeAddr("bob");

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
                address(alice),
                address(bob),
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
            address(noCodeTokenAddress),
            address(alice),
            address(bob),
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

        // Test the generic failure case where the token contract reverts.
        ConduitTransfer[] memory revertTransfer;
        revertTransfer = new ConduitTransfer[](1);

        TestERC20Revert tokenRevert;
        tokenRevert = new TestERC20Revert();
        vm.label(address(tokenRevert), "tokenRevert");

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC20,
            address(tokenRevert),
            address(alice),
            address(bob),
            0,
            1
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

        expectedRevert = bytes("Some ERC20 revert message");

        test(
            this.execute,
            Context(
                conduit,
                expectedRevert,
                revertTransfer,
                noCodeBatchTransfer
            )
        );

        // Test the generic failure case where the token contract returns not OK but does not revert.
        ConduitTransfer[] memory notOkTransfer;
        notOkTransfer = new ConduitTransfer[](1);

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

        // Test the ERC721 revert case.
        TestERC721Revert nonfungibleTokenRevert;
        nonfungibleTokenRevert = new TestERC721Revert();
        vm.label(address(nonfungibleTokenRevert), "nonfungibleTokenRevert");

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC721,
            address(nonfungibleTokenRevert),
            address(alice),
            address(bob),
            0,
            1
        );

        expectedRevert = bytes("Some ERC721 revert message");

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

        // Test the ERC1155 revert case.
        TestERC1155Revert semifungibleTokenRevert;
        semifungibleTokenRevert = new TestERC1155Revert();
        vm.label(address(semifungibleTokenRevert), "semifungibleTokenRevert");

        revertTransfer[0] = ConduitTransfer(
            ConduitItemType.ERC1155,
            address(semifungibleTokenRevert),
            address(alice),
            address(bob),
            0,
            1
        );

        expectedRevert = bytes("Some ERC1155 revert message");

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

        // Test the ERC1155 batch transfer revert case.
        ConduitBatch1155Transfer[] memory revertBatchTransfer;
        revertBatchTransfer = new ConduitBatch1155Transfer[](1);

        revertBatchTransfer[0] = ConduitBatch1155Transfer(
            address(semifungibleTokenRevert),
            address(alice),
            address(bob),
            new uint256[](0),
            new uint256[](0)
        );

        expectedRevert = bytes(
            "Some ERC1155 revert message for batch transfers"
        );

        test(
            this.executeBatch,
            Context(
                referenceConduit,
                expectedRevert,
                revertTransfer,
                revertBatchTransfer
            )
        );
        test(
            this.executeBatch,
            Context(
                conduit,
                expectedRevert,
                revertTransfer,
                revertBatchTransfer
            )
        );
    }
}
