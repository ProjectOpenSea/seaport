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
        resetTokenBalances(transfers);
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

    ///@dev helper to make sure fuzzed addresses can receive tokens by changing it if it can't
    function receiver(address addr) internal returns (address) {
        // 0 address is not valid mint or origin address
        if (addr == address(0)) {
            return address(1);
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

        // re-calculate from+to after constructing token because forge fuzzer
        // is apparently smart enough to know where the tokens will be deployed
        // leading to issues with onERC1155Received
        // note: might have to pre-deploy all tokens first if issue persists
        address from = receiver(intermediate.from);
        address to = receiver(intermediate.to);

        return
            createNumTokenIdsConduitTransfers(
                intermediate,
                token,
                itemType,
                from,
                to
            );
    }

    function deploy1155TokensAndCreateConduitBatch1155Transfers(
        BatchIntermediate[] memory batchIntermediates
    ) internal returns (ConduitBatch1155Transfer[] memory) {
        ConduitBatch1155Transfer[]
            memory batchTransfers = new ConduitBatch1155Transfer[](
                batchIntermediates.length
            );

        address[] memory tokenAddresses = new address[](5);
        TestERC1155 erc1155_1 = new TestERC1155();
        TestERC1155 erc1155_2 = new TestERC1155();
        TestERC1155 erc1155_3 = new TestERC1155();
        TestERC1155 erc1155_4 = new TestERC1155();
        TestERC1155 erc1155_5 = new TestERC1155();

        tokenAddresses[0] = address(erc1155_1);
        tokenAddresses[1] = address(erc1155_2);
        tokenAddresses[2] = address(erc1155_3);
        tokenAddresses[3] = address(erc1155_4);
        tokenAddresses[4] = address(erc1155_5);

        for (uint256 i = 0; i < batchIntermediates.length; i++) {
            uint256 intermediateIndex = i;
            uint256[] memory ids = new uint256[](
                batchIntermediates[i].idAmounts.length
            );
            uint256[] memory amounts = new uint256[](
                batchIntermediates[i].idAmounts.length
            );
            for (
                uint256 n = 0;
                n < batchIntermediates[intermediateIndex].idAmounts.length;
                n++
            ) {
                ids[n] = batchIntermediates[intermediateIndex].idAmounts[n].id;
                amounts[n] = batchIntermediates[intermediateIndex]
                    .idAmounts[n]
                    .amount;
            }
            batchTransfers[i] = ConduitBatch1155Transfer(
                tokenAddresses[i % 5],
                batchIntermediates[i].from,
                batchIntermediates[i].to,
                ids,
                amounts
            );
        }
        return batchTransfers;
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

    function updateExpectedBalance(ConduitTransfer memory transfer) internal {
        userToExpectedTokenIdentifierBalance[transfer.to][transfer.token][
            transfer.identifier
        ] += transfer.amount;
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
}
