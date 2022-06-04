// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { ConduitTransfer, ConduitItemType } from "../../../contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "../utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "../utils/ERC1155Recipient.sol";
import { BaseConduitTest } from "./BaseConduitTest.sol";
import { Conduit } from "../../../contracts/conduit/Conduit.sol";

contract ConduitExecuteTest is BaseConduitTest {
    struct FuzzInputs {
        ConduitTransferIntermediate[20] intermediates;
    }

    struct Context {
        Conduit conduit;
        ConduitTransfer[] transfers;
    }

    function testExecute(FuzzInputs memory inputs) public {
        ConduitTransfer[] memory transfers = new ConduitTransfer[](0);
        for (uint8 i; i < inputs.intermediates.length; i++) {
            transfers = extendConduitTransferArray(
                transfers,
                deployTokenAndCreateConduitTransfers(inputs.intermediates[i])
            );
        }
        makeRecipientsSafe(transfers);
        mintTokensAndSetTokenApprovalsForConduit(
            transfers,
            address(referenceConduit)
        );
        updateExpectedTokenBalances(transfers);
        _testExecute(Context(referenceConduit, transfers));
        mintTokensAndSetTokenApprovalsForConduit(transfers, address(conduit));
        _testExecute(Context(conduit, transfers));
    }

    function _testExecute(Context memory context)
        internal
        resetTokenBalancesBetweenRuns(context.transfers)
    {
        bytes4 magicValue = context.conduit.execute(context.transfers);
        assertEq(magicValue, Conduit.execute.selector);

        for (uint256 i; i < context.transfers.length; i++) {
            ConduitTransfer memory transfer = context.transfers[i];
            ConduitItemType itemType = transfer.itemType;
            if (itemType == ConduitItemType.ERC20) {
                assertEq(
                    TestERC20(transfer.token).balanceOf(transfer.to),
                    getExpectedTokenBalance(transfer)
                );
            } else if (itemType == ConduitItemType.ERC1155) {
                assertEq(
                    TestERC1155(transfer.token).balanceOf(
                        transfer.to,
                        transfer.identifier
                    ),
                    getExpectedTokenBalance(transfer)
                );
            } else if (itemType == ConduitItemType.ERC721) {
                assertEq(
                    TestERC721(transfer.token).ownerOf(transfer.identifier),
                    transfer.to
                );
            }
        }
    }
}
