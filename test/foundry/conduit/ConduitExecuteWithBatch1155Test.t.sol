// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { Conduit } from "../../../contracts/conduit/Conduit.sol";
import { ConduitController } from "../../../contracts/conduit/ConduitController.sol";
import { BaseConduitTest } from "./BaseConduitTest.sol";
import { ConduitTransfer, ConduitBatch1155Transfer } from "../../../contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "../utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "../utils/ERC1155Recipient.sol";

contract ConduitExecuteWithBatch1155Test is BaseConduitTest {
    struct FuzzInputs {
        ConduitTransferIntermediate[64] transferIntermediates;
        BatchIntermediate[64] batchIntermediates;
    }

    struct Context {
        Conduit conduit;
        FuzzInputs args;
    }

    function testExecuteWithBatch1155(FuzzInputs memory args) public {
        _testExecuteWithBatch1155(Context(referenceConduit));
    }

    function _testExecuteWithBatch1155(Context memory context) internal {
        ConduitTransfer[] memory transfers = new ConduitTransfer[](
            context.args.transferIntermediates.length
        );
        ConduitBatch1155Transfer[]
            memory batchTransfers = new ConduitBatch1155Transfer[](
                context.args.batchIntermediates.length
            );

        for (
            uint256 i = 0;
            i < context.args.transferIntermediates.length;
            i++
        ) {
            transfers[i] = createTokenAndConduitTransfer(
                context.args.transferIntermediates[i],
                address(this)
            );
        }
        for (uint256 i = 0; i < context.args.batchIntermediates.length; i++) {
            batchTransfers[i] = create1155sAndConduitBatch1155Transfer(
                context.args.batchIntermediates[i],
                address(this)
            );
        }
    }
}
