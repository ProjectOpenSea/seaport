// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";
import { ConduitTransfer, ConduitItemType, ConduitBatch1155Transfer } from "../../../contracts/conduit/lib/ConduitStructs.sol";
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
    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    struct ConduitTransferIntermediate {
        uint8 itemType;
        address from;
        address to;
        uint256 identifier;
        // uint128 so minting won't overflow if same erc1155 ids are minted
        uint128 amount;
    }

    struct IdAmount {
        uint256 id;
        uint128 amount;
    }

    struct BatchIntermediate {
        address from;
        address to;
        IdAmount[] idAmounts;
    }

    function setUp() public virtual override {
        super.setUp();
        conduitController.updateChannel(address(conduit), address(this), true);
        referenceConduitController.updateChannel(
            address(referenceConduit),
            address(this),
            true
        );
    }

    function isErc1155Receiver(address to) internal returns (bool success) {
        if (to == address(0)) {
            return false;
        } else if (to.code.length > 0) {
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
        } else {
            return true;
        }
    }

    ///@dev helper to make sure fuzzed addresses can receive erc1155s by changing it if it can't
    function receiver(address to) internal returns (address) {
        if (!isErc1155Receiver(to)) {
            if (uint160(to) == 2**160 - 1) {
                return address(uint160(to) - 1);
            }
            return address(uint160(to) + 1);
        }
        return to;
    }

    function createTokenAndConduitTransfer(
        ConduitTransferIntermediate memory intermediate,
        address currentConduit
    ) internal returns (ConduitTransfer memory) {
        ConduitItemType itemType = ConduitItemType(
            (intermediate.itemType % 3) + 1
        );
        address from = receiver(intermediate.from);
        address to = receiver(intermediate.to);
        if (itemType == ConduitItemType.ERC20) {
            TestERC20 erc20 = new TestERC20();
            erc20.mint(from, intermediate.amount);
            vm.prank(from);
            erc20.approve(currentConduit, 2**256 - 1);
            erc20s.push(erc20);
            return
                ConduitTransfer(
                    itemType,
                    address(erc20),
                    from,
                    to,
                    0,
                    intermediate.amount
                );
        } else if (itemType == ConduitItemType.ERC1155) {
            TestERC1155 erc1155 = new TestERC1155();
            erc1155.mint(from, intermediate.identifier, intermediate.amount);
            vm.prank(from);
            erc1155.setApprovalForAll(currentConduit, true);
            erc1155s.push(erc1155);
            return
                ConduitTransfer(
                    itemType,
                    address(erc1155),
                    from,
                    to,
                    intermediate.identifier,
                    intermediate.amount
                );
        } else {
            TestERC721 erc721 = new TestERC721();
            erc721.mint(from, intermediate.identifier);
            vm.prank(from);
            erc721.setApprovalForAll(currentConduit, true);
            erc721s.push(erc721);
            return
                ConduitTransfer(
                    itemType,
                    address(erc721),
                    from,
                    to,
                    intermediate.identifier,
                    1
                );
        }
    }

    function create1155sAndConduitBatch1155Transfer(
        BatchIntermediate memory intermediate,
        address currentConduit
    ) internal returns (ConduitBatch1155Transfer memory) {
        address from = receiver(intermediate.from);
        address to = receiver(intermediate.to);

        uint256[] memory ids = new uint256[](intermediate.idAmounts.length);
        uint256[] memory amounts = new uint256[](intermediate.idAmounts.length);

        TestERC1155 erc1155 = new TestERC1155();

        for (uint256 i = 0; i < intermediate.idAmounts.length; i++) {
            erc1155.mint(
                from,
                intermediate.idAmounts[i].id,
                intermediate.idAmounts[i].amount
            );
            vm.prank(from);
            erc1155.setApprovalForAll(currentConduit, true);
            erc1155s.push(erc1155);
            ids[i] = intermediate.idAmounts[i].id;
            amounts[i] = intermediate.idAmounts[i].amount;
        }
        return
            ConduitBatch1155Transfer(address(erc1155), from, to, ids, amounts);
    }
}
