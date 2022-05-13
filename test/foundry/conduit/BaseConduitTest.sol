// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { ConduitTransfer, ConduitItemType } from "contracts/conduit/lib/ConduitStructs.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "../utils/ERC721Recipient.sol";
import { ERC1155Recipient } from "../utils/ERC1155Recipient.sol";
import { ERC1155TokenReceiver } from "@rari-capital/solmate/src/tokens/ERC1155.sol";

contract BaseConduitTest is
    BaseConsiderationTest,
    ERC1155Recipient,
    ERC721Recipient
{
    address[] erc20s;
    address[] erc721s;
    address[] erc1155s;

    function isErc1155Receiver(address to) internal returns (bool success) {
        success = true;
        if (to.code.length > 0) {
            (success, ) = to.call(
                abi.encodePacked(
                    ERC1155TokenReceiver.onERC1155Received.selector,
                    address(0),
                    address(0),
                    new uint256[](0),
                    new uint256[](0),
                    ""
                )
            );
        }
    }

    ///@dev helper to turn a fuzzed address
    function receiver(address to) internal returns (address) {
        if (!isErc1155Receiver(to)) {
            if (uint160(to) == 2**160 - 1) {
                return address(uint160(to) - 1);
            }
            return address(uint160(to) + 1);
        }
        return to;
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
