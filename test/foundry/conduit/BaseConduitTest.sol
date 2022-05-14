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
    mapping(address => mapping(address => mapping(uint256 => uint256))) userToExpectedTokenIdentifierBalance;

    struct ConduitTransferIntermediate {
        uint8 itemType;
        address from;
        address to;
        uint128 identifier;
        // uint128 so minting won't overflow if same erc1155 ids are minted
        uint128 amount;
        uint8 numTokenIds;
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

    modifier resetTokenBalancesBetweenRuns(ConduitTransfer[] memory transfers) {
        vm.record();
        _;
        _resetTokenBalances(transfers);
    }

    function _resetTokenBalances(ConduitTransfer[] memory transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            _resetStorage(transfers[i].token);
        }
        _resetStorage(address(this));
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

    function createNumTokenIdsConduitTransfers(
        ConduitTransferIntermediate memory intermediate,
        address tokenAddress,
        ConduitItemType itemType,
        address from,
        address to
    ) internal returns (ConduitTransfer[] memory) {
        ConduitTransfer[] memory transfers;
        if (itemType == ConduitItemType.ERC20) {
            transfers = new ConduitTransfer[](1);
            TestERC20(tokenAddress).mint(from, intermediate.amount);
            transfers[0] = ConduitTransfer(
                itemType,
                tokenAddress,
                from,
                to,
                0,
                intermediate.amount
            );
        }
        uint256 truncatedNumTokenIds = (intermediate.numTokenIds % 8) + 1;
        transfers = new ConduitTransfer[](truncatedNumTokenIds);
        for (uint256 i = 0; i < truncatedNumTokenIds; i++) {
            if (itemType == ConduitItemType.ERC1155) {
                TestERC1155(tokenAddress).mint(
                    from,
                    intermediate.identifier + i,
                    intermediate.amount
                );
                transfers[i] = ConduitTransfer(
                    itemType,
                    tokenAddress,
                    from,
                    to,
                    intermediate.identifier + i,
                    intermediate.amount
                );
            } else if (itemType == ConduitItemType.ERC721) {
                TestERC721(tokenAddress).mint(
                    from,
                    intermediate.identifier + i
                );
                transfers[i] = ConduitTransfer(
                    itemType,
                    tokenAddress,
                    from,
                    to,
                    intermediate.identifier + i,
                    1
                );
            }
        }
        return transfers;
    }

    function extendConduitTransferArray(
        ConduitTransfer[] memory original,
        ConduitTransfer[] memory extension
    ) internal returns (ConduitTransfer[] memory) {
        ConduitTransfer[] memory transfers = new ConduitTransfer[](
            original.length + extension.length
        );
        for (uint256 i = 0; i < original.length; i++) {
            transfers[i] = original[i];
        }
        for (uint256 i = 0; i < extension.length; i++) {
            transfers[i + original.length] = extension[i];
        }
        return transfers;
    }

    function createTokenAndConduitTransfer(
        ConduitTransferIntermediate memory intermediate,
        address currentConduit
    ) internal returns (ConduitTransfer[] memory) {
        ConduitItemType itemType = ConduitItemType(
            (intermediate.itemType % 3) + 1
        );
        address from = receiver(intermediate.from);
        address to = receiver(intermediate.to);
        if (itemType == ConduitItemType.ERC20) {
            TestERC20 erc20 = new TestERC20();
            vm.prank(from);
            erc20.approve(currentConduit, 2**256 - 1);
            return
                createNumTokenIdsConduitTransfers(
                    intermediate,
                    address(erc20),
                    itemType,
                    from,
                    to
                );
        } else if (itemType == ConduitItemType.ERC1155) {
            TestERC1155 erc1155 = new TestERC1155();
            vm.prank(from);
            erc1155.setApprovalForAll(currentConduit, true);
            return
                createNumTokenIdsConduitTransfers(
                    intermediate,
                    address(erc1155),
                    itemType,
                    from,
                    to
                );
        } else {
            TestERC721 erc721 = new TestERC721();
            vm.prank(from);
            erc721.setApprovalForAll(currentConduit, true);
            return
                createNumTokenIdsConduitTransfers(
                    intermediate,
                    address(erc721),
                    itemType,
                    from,
                    to
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
            ids[i] = intermediate.idAmounts[i].id;
            amounts[i] = intermediate.idAmounts[i].amount;
        }
        return
            ConduitBatch1155Transfer(address(erc1155), from, to, ids, amounts);
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

    function preprocessTransfers(ConduitTransfer[] memory transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            ConduitItemType itemType = transfer.itemType;
            if (itemType != ConduitItemType.ERC721) {
                updateExpectedBalance(transfers[i]);
            }
        }
    }

    function updateExpectedBalance(ConduitTransfer memory transfer) internal {
        userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
            transfer.identifier
        ] += transfer.amount;
    }
}
