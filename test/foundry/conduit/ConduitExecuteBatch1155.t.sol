// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { ConduitTransfer, ConduitBatch1155Transfer, ConduitItemType } from "../../../contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "../utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "../utils/ERC1155Recipient.sol";
import { BaseConduitTest } from "./BaseConduitTest.sol";
import { Conduit } from "../../../contracts/conduit/Conduit.sol";

contract ConduitExecuteBatch1155Test is BaseConduitTest {
    struct FuzzInputs {
        BatchIntermediate[10] batchIntermediates;
    }

    struct Context {
        Conduit conduit;
        ConduitBatch1155Transfer[] batchTransfers;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testExecuteBatch1155(FuzzInputs memory inputs) public {
        ConduitBatch1155Transfer[]
            memory batchTransfers = new ConduitBatch1155Transfer[](0);
        for (uint8 j = 0; j < inputs.batchIntermediates.length; ++j) {
            batchTransfers = extendConduitTransferArray(
                batchTransfers,
                deployTokenAndCreateConduitBatch1155Transfer(
                    inputs.batchIntermediates[j]
                )
            );
        }
        makeRecipientsSafe(batchTransfers);
        mintTokensAndSetTokenApprovalsForConduit(batchTransfers);
        updateExpectedTokenBalances(batchTransfers);
        test(this.executeBatch1155, Context(referenceConduit, batchTransfers));
        test(this.executeBatch1155, Context(conduit, batchTransfers));
    }

    function executeBatch1155(Context memory context) external stateless {
        bytes4 magicValue = context.conduit.executeBatch1155(
            context.batchTransfers
        );
        assertEq(magicValue, Conduit.executeBatch1155.selector);

        for (uint256 i = 0; i < context.batchTransfers.length; ++i) {
            ConduitBatch1155Transfer memory batchTransfer = context
                .batchTransfers[i];

            address[] memory toAddresses = new address[](
                batchTransfer.ids.length
            );
            for (uint256 j = 0; j < batchTransfer.ids.length; ++j) {
                toAddresses[j] = batchTransfer.to;
            }
            uint256[] memory actualBatchBalances = TestERC1155(
                batchTransfer.token
            ).balanceOfBatch(toAddresses, batchTransfer.ids);
            uint256[]
                memory expectedBatchBalances = getExpectedBatchTokenBalances(
                    batchTransfer
                );
            assertTrue(
                actualBatchBalances.length == expectedBatchBalances.length
            );

            for (uint256 j = 0; j < actualBatchBalances.length; ++j) {
                assertEq(actualBatchBalances[j], expectedBatchBalances[j]);
            }
        }
    }
}
