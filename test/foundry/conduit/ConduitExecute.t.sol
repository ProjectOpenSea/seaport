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

    function testExecute(FuzzInputs memory inputs) public {}

    function _testExecute(Context memory context) internal {
        context.conduit.execute(context.transfers);
    }
}
