// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
// prettier-ignore
import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { ConduitInterface } from "../../../contracts/interfaces/ConduitInterface.sol";

import { ConduitItemType } from "../../../contracts/conduit/lib/ConduitEnums.sol";

import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";

import { TransferHelperItem } from "../../../contracts/helper/TransferHelperStructs.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

import { TokenTransferrerErrors } from "../../../contracts/interfaces/TokenTransferrerErrors.sol";

import { TransferHelperInterface } from "../../../contracts/interfaces/TransferHelperInterface.sol";

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;
    uint256 numFungibleTokens;
    uint256 numTokenIdentifiers;

    struct FromToBalance {
        // Balance of from address.
        uint256 from;
        // Balance of to address.
        uint256 to;
    }

    struct FuzzInputsCommon {
        // Indicates if a conduit should be used for the transfer
        bool useConduit;
        // Amounts that can be used for the amount field on TransferHelperItem
        uint256[10] amounts;
        // Identifiers that can be used for the tokenIdentifier field on TransferHelperItem
        uint256[10] identifiers;
        // Indexes that can be used to select tokens from erc20s/erc721s/erc1155s
        uint256[10] tokenIndex;
    }

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));

        // Mint initial tokens to alice for tests.
        numFungibleTokens = 1e6;
        numTokenIdentifiers = 10;
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].mint(alice, numFungibleTokens);
        }

        // Mint ERC721 and ERC1155 with token IDs 0 to numTokenIdentifiers - 1 to alice
        for (
            uint256 tokenIdentifier = 0;
            tokenIdentifier < numTokenIdentifiers;
            tokenIdentifier++
        ) {
            for (uint256 j = 0; j < erc721s.length; j++) {
                erc721s[j].mint(alice, tokenIdentifier);
            }
            for (uint256 j = 0; j < erc1155s.length; j++) {
                erc1155s[j].mint(alice, tokenIdentifier, numFungibleTokens);
            }
        }

        // Allow transfer helper to perform transfers for these addresses.
        _setApprovals(alice);
        _setApprovals(bob);
        _setApprovals(cal);

        // Open a channel for transfer helper on the conduit
        updateConduitChannel(true);
    }

    // Helper functions

    function updateConduitChannel(bool open) internal {
        (address conduit, ) = conduitController.getConduit(conduitKeyOne);
        vm.prank(address(conduitController));
        ConduitInterface(conduit).updateChannel(address(transferHelper), open);
    }

    function _setApprovals(address _owner) internal override {
        super._setApprovals(_owner);
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(address(transferHelper), MAX_INT);
        }
        for (uint256 i = 0; i < erc1155s.length; i++) {
            erc1155s[i].setApprovalForAll(address(transferHelper), true);
        }
        for (uint256 i = 0; i < erc721s.length; i++) {
            erc721s[i].setApprovalForAll(address(transferHelper), true);
        }
        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }

    function balanceOfTransferItemForAddress(
        TransferHelperItem memory item,
        address addr
    ) internal view returns (uint256) {
        if (item.itemType == ConduitItemType.ERC20) {
            return TestERC20(item.token).balanceOf(addr);
        } else if (item.itemType == ConduitItemType.ERC721) {
            return
                TestERC721(item.token).ownerOf(item.tokenIdentifier) == addr
                    ? 1
                    : 0;
        } else if (item.itemType == ConduitItemType.ERC1155) {
            return
                TestERC1155(item.token).balanceOf(addr, item.tokenIdentifier);
        } else if (item.itemType == ConduitItemType.NATIVE) {
            // Balance for native does not matter as don't support native transfers so just return dummy value.
            return 0;
        }
        revert();
    }

    function balanceOfTransferItemForFromTo(
        TransferHelperItem memory item,
        address from,
        address to
    ) internal view returns (FromToBalance memory) {
        return
            FromToBalance(
                balanceOfTransferItemForAddress(item, from),
                balanceOfTransferItemForAddress(item, to)
            );
    }

    function performSingleItemTransferAndCheckBalances(
        TransferHelperItem memory item,
        address from,
        address to,
        bool useConduit,
        bytes memory expectRevertData
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        performMultiItemTransferAndCheckBalances(
            items,
            from,
            to,
            useConduit,
            expectRevertData
        );
    }

    function performMultiItemTransferAndCheckBalances(
        TransferHelperItem[] memory items,
        address from,
        address to,
        bool useConduit,
        bytes memory expectRevertData
    ) public {
        vm.startPrank(from);

        // Get balances before transfer
        FromToBalance[] memory beforeTransferBalances = new FromToBalance[](
            items.length
        );
        for (uint256 i = 0; i < items.length; i++) {
            beforeTransferBalances[i] = balanceOfTransferItemForFromTo(
                items[i],
                from,
                to
            );
        }

        // Perform transfer
        if (expectRevertData.length > 0) {
            vm.expectRevert(expectRevertData);
        }
        transferHelper.bulkTransfer(
            items,
            to,
            useConduit ? conduitKeyOne : bytes32(0)
        );

        // Get balances after transfer
        FromToBalance[] memory afterTransferBalances = new FromToBalance[](
            items.length
        );
        for (uint256 i = 0; i < items.length; i++) {
            afterTransferBalances[i] = balanceOfTransferItemForFromTo(
                items[i],
                from,
                to
            );
        }

        if (expectRevertData.length > 0) {
            // If revert is expected, balances should not have changed.
            for (uint256 i = 0; i < items.length; i++) {
                assert(
                    beforeTransferBalances[i].from ==
                        afterTransferBalances[i].from
                );
                assert(
                    beforeTransferBalances[i].to == afterTransferBalances[i].to
                );
            }
            return;
        }

        // Check after transfer balances are as expected by calculating difference against before transfer balances.
        for (uint256 i = 0; i < items.length; i++) {
            // ERC721 should only ever change by amount 1
            uint256 amount = items[i].itemType == ConduitItemType.ERC721
                ? 1
                : items[i].amount;
            assertEq(
                afterTransferBalances[i].from,
                beforeTransferBalances[i].from - amount
            );
            assertEq(
                afterTransferBalances[i].to,
                beforeTransferBalances[i].to + amount
            );
        }

        vm.stopPrank();
    }

    function getFuzzedItem(
        ConduitItemType itemType,
        uint256 fuzzAmount,
        uint256 fuzzIndex,
        uint256 fuzzIdentifier
    ) internal view returns (TransferHelperItem memory) {
        uint256 amount = fuzzAmount % numFungibleTokens;
        uint256 identifier = fuzzIdentifier % numTokenIdentifiers;
        if (itemType == ConduitItemType.ERC20) {
            uint256 index = fuzzIndex % erc20s.length;
            TestERC20 erc20 = erc20s[index];
            return
                TransferHelperItem(
                    itemType,
                    address(erc20),
                    identifier,
                    amount
                );
        } else if (itemType == ConduitItemType.ERC1155) {
            uint256 index = fuzzIndex % erc1155s.length;
            TestERC1155 erc1155 = erc1155s[index];
            return
                TransferHelperItem(
                    itemType,
                    address(erc1155),
                    identifier,
                    amount
                );
        } else if (itemType == ConduitItemType.NATIVE) {
            return TransferHelperItem(itemType, address(0), identifier, amount);
        } else if (itemType == ConduitItemType.ERC721) {
            uint256 index = fuzzIndex % erc721s.length;
            return
                TransferHelperItem(
                    itemType,
                    address(erc721s[index]),
                    identifier,
                    1
                );
        }
        revert();
    }

    function getFuzzedERC721WithAmountGreaterThan1(
        uint256 fuzzAmount,
        uint256 fuzzIndex,
        uint256 fuzzIdentifier
    ) internal view returns (TransferHelperItem memory) {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC721,
            fuzzAmount,
            fuzzIndex,
            fuzzIdentifier
        );
        item.amount = 2 + (fuzzAmount % numFungibleTokens);
        return item;
    }

    // Test successful transfers

    function testBulkTransferERC20(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC20,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC721(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC721toBobThenCal(FuzzInputsCommon memory inputs)
        public
    {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
        performSingleItemTransferAndCheckBalances(
            item,
            bob,
            cal,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC1155(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC1155andERC721(FuzzInputsCommon memory inputs)
        public
    {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = getFuzzedItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC1155andERC721andERC20(
        FuzzInputsCommon memory inputs
    ) public resetTokenBalancesBetweenRuns {
        TransferHelperItem[] memory items = new TransferHelperItem[](3);
        items[0] = getFuzzedItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );
        items[2] = getFuzzedItem(
            ConduitItemType.ERC20,
            inputs.amounts[2],
            inputs.tokenIndex[2],
            inputs.identifiers[2]
        );

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferMultipleERC721SameContract(
        FuzzInputsCommon memory inputs
    ) public {
        uint256 numItems = 3;
        TransferHelperItem[] memory items = new TransferHelperItem[](numItems);
        for (uint256 i = 0; i < numItems; i++) {
            items[i] = getFuzzedItem(
                ConduitItemType.ERC721,
                inputs.amounts[i],
                // Same token index for all items since this is testing from same contract
                inputs.tokenIndex[0],
                // Each item has a different token identifier as alice only owns one ERC721 token
                // for each identifier for this particular contract
                i
            );
        }

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferMultipleERC721DifferentContracts(
        FuzzInputsCommon memory inputs
    ) public resetTokenBalancesBetweenRuns {
        TransferHelperItem[] memory items = new TransferHelperItem[](3);
        items[0] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            // Different token index for all items since this is testing from different contracts
            0,
            inputs.identifiers[0]
        );
        items[1] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            1,
            inputs.identifiers[1]
        );
        items[2] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[2],
            2,
            inputs.identifiers[2]
        );

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferMultipleERC721andMultipleERC1155(
        FuzzInputsCommon memory inputs
    ) public {
        uint256 numItems = 6;
        TransferHelperItem[] memory items = new TransferHelperItem[](numItems);

        // Fill items such that the first floor(numItems / 2) items are ERC1155 and the remaining
        // items are ERC721
        for (uint256 i = 0; i < numItems; i++) {
            if (i < numItems / 2) {
                items[i] = getFuzzedItem(
                    ConduitItemType.ERC1155,
                    inputs.amounts[i],
                    // Ensure each item is from a different contract
                    i,
                    inputs.identifiers[i]
                );
            } else {
                items[i] = getFuzzedItem(
                    ConduitItemType.ERC721,
                    inputs.amounts[i],
                    i,
                    inputs.identifiers[i]
                );
            }
        }

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC721AmountMoreThan1NotUsingConduit(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem memory item = getFuzzedERC721WithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(item, alice, bob, false, "");
    }

    function testBulkTransferERC721AmountMoreThan1AndERC20NotUsingConduit(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = getFuzzedERC721WithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        items[1] = getFuzzedItem(
            ConduitItemType.ERC20,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        performMultiItemTransferAndCheckBalances(items, alice, bob, false, "");
    }

    // Test reverts

    function testRevertBulkTransferETHonly(FuzzInputsCommon memory inputs)
        public
    {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.NATIVE,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            abi.encodePacked(TransferHelperInterface.InvalidItemType.selector)
        );
    }

    function testRevertBulkTransferETHandERC721(FuzzInputsCommon memory inputs)
        public
    {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = getFuzzedItem(
            ConduitItemType.NATIVE,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = getFuzzedItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            abi.encodePacked(TransferHelperInterface.InvalidItemType.selector)
        );
    }

    function testRevertBulkTransferERC721AmountMoreThan1UsingConduit(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem memory item = getFuzzedERC721WithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            true,
            abi.encodePacked(
                TokenTransferrerErrors.InvalidERC721TransferAmount.selector
            )
        );
    }

    function testRevertBulkTransferERC721AmountMoreThan1AndERC20UsingConduit(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = getFuzzedERC721WithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        items[1] = getFuzzedItem(
            ConduitItemType.ERC20,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            true,
            abi.encodePacked(
                TokenTransferrerErrors.InvalidERC721TransferAmount.selector
            )
        );
    }

    function testRevertBulkTransferNotOpenConduitChannel(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem memory item = getFuzzedItem(
            ConduitItemType.ERC20,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        updateConduitChannel(false);
        performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            true,
            abi.encodeWithSelector(
                ConduitInterface.ChannelClosed.selector,
                address(transferHelper)
            )
        );
    }
}
