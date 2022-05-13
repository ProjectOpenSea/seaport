// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { ConduitTransfer, ConduitItemType } from "contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "../utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "../utils/ERC1155Recipient.sol";

contract BaseConduitTest is
    BaseConsiderationTest,
    ERC1155Recipient,
    ERC721Recipient
{
    address[] erc20s;
    address[] erc721s;
    address[] erc1155s;

    modifier onlyERC1155Receiver(address to) {
        _;
    }

    function setUp() public override {
        super.setUp();
        conduitController.updateChannel(conduit, address(this), true);
        referenceConduitController.updateChannel(
            referenceConduit,
            address(this),
            true
        );
    }
}
