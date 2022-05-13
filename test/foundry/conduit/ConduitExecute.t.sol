// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

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
        ConduitTransferIntermediate[64] intermediates;
    }

    struct Context {
        Conduit conduit;
        ConduitTransfer[] transfers;
    }

    mapping(address => mapping(address => mapping(uint256 => uint256))) userToExpectedTokenIdentifierBalance;

    function updateExpectedBalance(ConduitTransfer memory transfer) internal {
        userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
            transfer.identifier
        ] += transfer.amount;
    }

    function preprocessTransfers(ConduitTransfer[] memory transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            ConduitItemType itemType = transfer.itemType;
            if (itemType != ConduitItemType.ERC721) {
                updateExpectedBalance(transfers[i]);
            }
        }
    }

    function testExecute(FuzzInputs memory inputs) public {
        ConduitTransfer[] memory transfers = new ConduitTransfer[](
            inputs.intermediates.length
        );
        for (uint8 i; i < inputs.intermediates.length; i++) {
            transfers[i] = createTokenAndConduitTransfer(
                inputs.intermediates[i],
                address(referenceConduit)
            );
        }
        preprocessTransfers(transfers);
        _testExecute(Context(referenceConduit, transfers));
    }

    function _expectedBalance(ConduitTransfer memory transfer)
        internal
        view
        returns (uint256)
    {
        return
            userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
                transfer.identifier
            ];
    }

    function _testExecute(Context memory context) internal {
        bytes4 magicValue = context.conduit.execute(context.transfers);
        assertEq(magicValue, Conduit.execute.selector);

        for (uint256 i; i < context.transfers.length; i++) {
            ConduitTransfer memory transfer = context.transfers[i];
            ConduitItemType itemType = transfer.itemType;
            if (itemType == ConduitItemType.ERC20) {
                assertEq(
                    TestERC20(transfer.token).balanceOf(transfer.to),
                    _expectedBalance(transfer)
                );
            } else if (itemType == ConduitItemType.ERC1155) {
                assertEq(
                    TestERC1155(transfer.token).balanceOf(
                        transfer.to,
                        transfer.identifier
                    ),
                    _expectedBalance(transfer)
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
