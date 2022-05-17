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
        IdAmount[2] idAmounts;
    }

    modifier resetTokenBalancesBetweenRuns(ConduitTransfer[] memory transfers) {
        vm.record();
        _;
        resetTokenBalances(transfers);
    }

    modifier resetBatchTokenBalancesBetweenRuns(
        ConduitBatch1155Transfer[] memory batchTransfers
    ) {
        vm.record();
        _;
        resetTokenBalances(batchTransfers);
    }

    modifier resetTransferAndBatchTransferTokenBalancesBetweenRuns(
        ConduitTransfer[] memory transfers,
        ConduitBatch1155Transfer[] memory batchTransfers
    ) {
        vm.record();
        _;
        resetTokenBalances(transfers, batchTransfers);
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

    function isErc1155Receiver(address to) internal returns (bool) {
        if (to == address(0)) {
            return false;
        } else if (to.code.length > 0) {
            (bool success, bytes memory returnData) = to.call(
                abi.encodePacked(
                    ERC1155TokenReceiver.onERC1155Received.selector,
                    address(0),
                    address(0),
                    new uint256[](0),
                    new uint256[](0),
                    ""
                )
            );
            return
                success &&
                keccak256(returnData) ==
                keccak256(
                    abi.encode(ERC1155TokenReceiver.onERC1155Received.selector)
                );
        } else {
            return true;
        }
    }

    ///@dev helper to coerce a fuzzed address into one that can accept tokens if necessary
    function receiver(address addr, ConduitItemType itemType)
        internal
        returns (address)
    {
        // 0 address is not valid mint or origin address
        if (addr == address(0)) {
            return address(1);
        }
        if (itemType != ConduitItemType.ERC1155) {
            return addr;
        }
        if (!isErc1155Receiver(addr)) {
            return address(uint160(addr) + 1);
        }
        return addr;
    }

    /**
     * @dev
     */
    function createNumTokenIdsConduitTransfers(
        ConduitTransferIntermediate memory intermediate,
        address tokenAddress,
        ConduitItemType itemType,
        address from,
        address to
    ) internal pure returns (ConduitTransfer[] memory) {
        ConduitTransfer[] memory transfers;
        if (itemType == ConduitItemType.ERC20) {
            transfers = new ConduitTransfer[](1);
            transfers[0] = ConduitTransfer(
                itemType,
                tokenAddress,
                from,
                to,
                0,
                intermediate.amount
            );
            return transfers;
        }
        uint256 truncatedNumTokenIds = (intermediate.numTokenIds % 8) + 1;
        transfers = new ConduitTransfer[](truncatedNumTokenIds);
        for (uint256 i = 0; i < truncatedNumTokenIds; i++) {
            if (itemType == ConduitItemType.ERC1155) {
                transfers[i] = ConduitTransfer(
                    itemType,
                    tokenAddress,
                    from,
                    to,
                    intermediate.identifier + i,
                    intermediate.amount
                );
            } else if (itemType == ConduitItemType.ERC721) {
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
    ) internal pure returns (ConduitTransfer[] memory) {
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

    function extendConduitTransferArray(
        ConduitBatch1155Transfer[] memory original,
        ConduitBatch1155Transfer[] memory extension
    ) internal pure returns (ConduitBatch1155Transfer[] memory) {
        ConduitBatch1155Transfer[]
            memory transfers = new ConduitBatch1155Transfer[](
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

    /**
     * @dev given ConduitTransferIntermediate, return an array of 1-8 ConduitTransfers
     * specifying multiple tokenIds (when appropriate)
     */
    function deployTokenAndCreateConduitTransfers(
        ConduitTransferIntermediate memory intermediate
    ) internal returns (ConduitTransfer[] memory) {
        ConduitItemType itemType = ConduitItemType(
            (intermediate.itemType % 3) + 1
        );
        address token;
        if (itemType == ConduitItemType.ERC20) {
            token = address(new TestERC20());
        } else if (itemType == ConduitItemType.ERC1155) {
            token = address(new TestERC1155());
        } else {
            token = address(new TestERC721());
        }

        return
            createNumTokenIdsConduitTransfers(
                intermediate,
                token,
                itemType,
                intermediate.from,
                intermediate.to
            );
    }

    function deployTokenAndCreateConduitBatch1155Transfer(
        BatchIntermediate memory batchIntermediate
    ) internal returns (ConduitBatch1155Transfer[] memory) {
        ConduitBatch1155Transfer[] memory batchTransfers;

        TestERC1155 erc1155 = new TestERC1155();
        uint256[] memory ids = new uint256[](
            batchIntermediate.idAmounts.length
        );
        uint256[] memory amounts = new uint256[](
            batchIntermediate.idAmounts.length
        );
        for (uint256 n = 0; n < batchIntermediate.idAmounts.length; n++) {
            ids[n] = batchIntermediate.idAmounts[n].id;
            amounts[n] = uint256(batchIntermediate.idAmounts[n].amount) + 1;
        }
        address from = batchIntermediate.from;
        address to = batchIntermediate.to;

        batchTransfers = new ConduitBatch1155Transfer[](1);
        batchTransfers[0] = ConduitBatch1155Transfer(
            address(erc1155),
            from,
            to,
            ids,
            amounts
        );
        return batchTransfers;
    }

    /**
     * @dev Foundry will fuzz addresses on contracts - including contracts that haven't been created (yet)
     *      Make sure all recipients (including mint recipients) can receive erc1155 tokens by changing
     *      address if it can't
     */
    function makeRecipientsSafe(ConduitTransfer[] memory transfers) internal {
        for (uint256 i; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            address from = receiver(transfer.from, transfer.itemType);
            address to = receiver(transfer.to, transfer.itemType);
            transfer.from = from;
            transfer.to = to;
        }
    }

    function makeRecipientsSafe(
        ConduitBatch1155Transfer[] memory batchTransfers
    ) internal {
        for (uint256 i; i < batchTransfers.length; i++) {
            ConduitBatch1155Transfer memory batchTransfer = batchTransfers[i];
            address from = receiver(
                batchTransfer.from,
                ConduitItemType.ERC1155
            );
            address to = receiver(batchTransfer.to, ConduitItemType.ERC1155);
            batchTransfer.from = from;
            batchTransfer.to = to;
            assertEq(from, batchTransfers[i].from);
        }
    }

    function mintTokensAndSetTokenApprovalsForConduit(
        ConduitTransfer[] memory transfers,
        address conduitAddress
    ) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            ConduitItemType itemType = transfer.itemType;
            address from = transfer.from;
            address token = transfer.token;
            if (itemType == ConduitItemType.ERC20) {
                TestERC20 erc20 = TestERC20(token);
                erc20.mint(from, transfer.amount);
                vm.prank(from);
                erc20.approve(conduitAddress, 2**256 - 1);
            } else if (itemType == ConduitItemType.ERC1155) {
                TestERC1155 erc1155 = TestERC1155(token);
                erc1155.mint(from, transfer.identifier, transfer.amount);
                vm.prank(from);
                erc1155.setApprovalForAll(conduitAddress, true);
            } else {
                TestERC721 erc721 = TestERC721(token);
                erc721.mint(from, transfer.identifier);
                vm.prank(from);
                erc721.setApprovalForAll(conduitAddress, true);
            }
        }
    }

    function mintTokensAndSetTokenApprovalsForConduit(
        ConduitBatch1155Transfer[] memory batchTransfers,
        address conduitAddress
    ) internal {
        for (uint256 i = 0; i < batchTransfers.length; i++) {
            ConduitBatch1155Transfer memory batchTransfer = batchTransfers[i];
            address from = batchTransfer.from;
            address token = batchTransfer.token;
            TestERC1155 erc1155 = TestERC1155(token);
            for (uint256 n = 0; n < batchTransfer.ids.length; n++) {
                erc1155.mint(
                    from,
                    batchTransfer.ids[n],
                    batchTransfer.amounts[n]
                );
            }
            vm.prank(from);
            erc1155.setApprovalForAll(conduitAddress, true);
        }
    }

    function getExpectedTokenBalance(ConduitTransfer memory transfer)
        internal
        view
        returns (uint256)
    {
        return
            userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
                transfer.identifier
            ];
    }

    function getExpectedBatchTokenBalances(
        ConduitBatch1155Transfer memory batchTransfer
    ) internal view returns (uint256[] memory) {
        uint256[] memory batchTokenBalances = new uint256[](
            batchTransfer.ids.length
        );
        for (uint256 i = 0; i < batchTransfer.ids.length; i++) {
            batchTokenBalances[i] = userToExpectedTokenIdentifierBalance[
                batchTransfer.to
            ][batchTransfer.token][batchTransfer.ids[i]];
        }
        return batchTokenBalances;
    }

    function updateExpectedTokenBalances(ConduitTransfer[] memory transfers)
        internal
    {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            ConduitItemType itemType = transfer.itemType;
            if (itemType != ConduitItemType.ERC721) {
                updateExpectedBalance(transfers[i]);
            }
        }
    }

    function updateExpectedTokenBalances(
        ConduitBatch1155Transfer[] memory batchTransfers
    ) internal {
        for (uint256 i = 0; i < batchTransfers.length; i++) {
            updateExpectedBatchBalances(batchTransfers[i]);
        }
    }

    function updateExpectedBalance(ConduitTransfer memory transfer) internal {
        userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
            transfer.identifier
        ] += transfer.amount;
    }

    function updateExpectedBatchBalances(
        ConduitBatch1155Transfer memory batchTransfer
    ) internal {
        for (uint256 i = 0; i < batchTransfer.ids.length; i++) {
            userToExpectedTokenIdentifierBalance[batchTransfer.to][
                batchTransfer.token
            ][batchTransfer.ids[i]] += batchTransfer.amounts[i];
        }
    }

    /**
     * @dev reset all token contract storage changed since vm.record was started
     */
    function resetTokenBalances(ConduitTransfer[] memory transfers) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            _resetStorage(transfer.token);
        }
    }

    function resetTokenBalances(
        ConduitBatch1155Transfer[] memory batchTransfers
    ) internal {
        for (uint256 i = 0; i < batchTransfers.length; i++) {
            ConduitBatch1155Transfer memory batchTransfer = batchTransfers[i];
            _resetStorage(batchTransfer.token);
        }
    }

    function resetTokenBalances(
        ConduitTransfer[] memory transfers,
        ConduitBatch1155Transfer[] memory batchTransfers
    ) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            ConduitTransfer memory transfer = transfers[i];
            _resetStorage(transfer.token);
        }
        for (uint256 i = 0; i < batchTransfers.length; i++) {
            ConduitBatch1155Transfer memory batchTransfer = batchTransfers[i];
            _resetStorage(batchTransfer.token);
        }
    }
}
