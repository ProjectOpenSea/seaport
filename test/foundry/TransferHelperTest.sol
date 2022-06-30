// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// prettier-ignore
import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { ConduitInterface } from "../../contracts/interfaces/ConduitInterface.sol";

import { ConduitItemType } from "../../contracts/conduit/lib/ConduitEnums.sol";

import { TransferHelper } from "../../contracts/helpers/TransferHelper.sol";

import { TransferHelperItem } from "../../contracts/helpers/TransferHelperStructs.sol";

import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";

import { TokenTransferrerErrors } from "../../contracts/interfaces/TokenTransferrerErrors.sol";

import { TransferHelperInterface } from "../../contracts/interfaces/TransferHelperInterface.sol";

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    // Total supply of fungible tokens to be used in tests for all fungible tokens.
    uint256 constant TOTAL_FUNGIBLE_TOKENS = 1e6;
    // Total number of token identifiers to mint tokens for for ERC721s and ERC1155s.
    uint256 constant TOTAL_TOKEN_IDENTIFERS = 10;
    // Constant bytes used for expecting revert with no message.
    bytes constant REVERT_DATA_NO_MSG = "revert no message";

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
        // Identifiers that can be used for the identifier field on TransferHelperItem
        uint256[10] identifiers;
        // Indexes that can be used to select tokens from the arrays erc20s/erc721s/erc1155s
        uint256[10] tokenIndex;
    }

    function setUp() public override {
        super.setUp();
        _deployAndConfigurePrecompiledTransferHelper();
        vm.label(address(transferHelper), "transferHelper");

        // Mint initial tokens to alice for tests.
        for (uint256 tokenIdx = 0; tokenIdx < erc20s.length; tokenIdx++) {
            erc20s[tokenIdx].mint(alice, TOTAL_FUNGIBLE_TOKENS);
        }

        // Mint ERC721 and ERC1155 with token IDs 0 to TOTAL_TOKEN_IDENTIFERS - 1 to alice
        for (
            uint256 identifier = 0;
            identifier < TOTAL_TOKEN_IDENTIFERS;
            identifier++
        ) {
            for (uint256 tokenIdx = 0; tokenIdx < erc721s.length; tokenIdx++) {
                erc721s[tokenIdx].mint(alice, identifier);
            }
            for (uint256 tokenIdx = 0; tokenIdx < erc1155s.length; tokenIdx++) {
                erc1155s[tokenIdx].mint(
                    alice,
                    identifier,
                    TOTAL_FUNGIBLE_TOKENS
                );
            }
        }

        // Allow transfer helper to perform transfers for these addresses.
        _setApprovals(alice);
        _setApprovals(bob);
        _setApprovals(cal);

        // Open a channel for transfer helper on the conduit
        _updateConduitChannel(true);
    }

    /**
     * @dev TransferHelper depends on precomputed Conduit creation code hash, which will differ
     * if tests are run with different compiler settings (which they are by default)
     */
    function _deployAndConfigurePrecompiledTransferHelper() public {
        transferHelper = TransferHelper(
            deployCode(
                "optimized-out/TransferHelper.sol/TransferHelper.json",
                abi.encode(address(conduitController))
            )
        );
    }

    // Helper functions

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

    function _updateConduitChannel(bool open) internal {
        (address _conduit, ) = conduitController.getConduit(conduitKeyOne);
        vm.prank(address(conduitController));
        ConduitInterface(_conduit).updateChannel(address(transferHelper), open);
    }

    function _balanceOfTransferItemForAddress(
        TransferHelperItem memory item,
        address addr
    ) internal view returns (uint256) {
        if (item.itemType == ConduitItemType.ERC20) {
            return TestERC20(item.token).balanceOf(addr);
        } else if (item.itemType == ConduitItemType.ERC721) {
            return
                TestERC721(item.token).ownerOf(item.identifier) == addr ? 1 : 0;
        } else if (item.itemType == ConduitItemType.ERC1155) {
            return TestERC1155(item.token).balanceOf(addr, item.identifier);
        } else if (item.itemType == ConduitItemType.NATIVE) {
            // Balance for native does not matter as don't support native transfers so just return dummy value.
            return 0;
        }
        // Revert on unsupported ConduitItemType.
        revert();
    }

    function _balanceOfTransferItemForFromTo(
        TransferHelperItem memory item,
        address from,
        address to
    ) internal view returns (FromToBalance memory) {
        return
            FromToBalance(
                _balanceOfTransferItemForAddress(item, from),
                _balanceOfTransferItemForAddress(item, to)
            );
    }

    function _performSingleItemTransferAndCheckBalances(
        TransferHelperItem memory item,
        address from,
        address to,
        bool useConduit,
        bytes memory expectRevertData
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        _performMultiItemTransferAndCheckBalances(
            items,
            from,
            to,
            useConduit,
            expectRevertData
        );
    }

    function _performMultiItemTransferAndCheckBalances(
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
            beforeTransferBalances[i] = _balanceOfTransferItemForFromTo(
                items[i],
                from,
                to
            );
        }

        // Register expected revert if present.
        if (
            // Compare hashes as we cannot directly compare bytes memory with bytes storage.
            keccak256(expectRevertData) == keccak256(REVERT_DATA_NO_MSG)
        ) {
            vm.expectRevert();
        } else if (expectRevertData.length > 0) {
            vm.expectRevert(expectRevertData);
        }
        // Perform transfer.
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
            afterTransferBalances[i] = _balanceOfTransferItemForFromTo(
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
            // ERC721 balance should only ever change by amount 1.
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

    function _getFuzzedTransferItem(
        ConduitItemType itemType,
        uint256 fuzzAmount,
        uint256 fuzzIndex,
        uint256 fuzzIdentifier
    ) internal view returns (TransferHelperItem memory) {
        uint256 amount = fuzzAmount % TOTAL_FUNGIBLE_TOKENS;
        uint256 identifier = fuzzIdentifier % TOTAL_TOKEN_IDENTIFERS;
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

    function _getFuzzedERC721TransferItemWithAmountGreaterThan1(
        uint256 fuzzAmount,
        uint256 fuzzIndex,
        uint256 fuzzIdentifier
    ) internal view returns (TransferHelperItem memory) {
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            fuzzAmount,
            fuzzIndex,
            fuzzIdentifier
        );
        item.amount = 2 + (fuzzAmount % TOTAL_FUNGIBLE_TOKENS);
        return item;
    }

    // Test successful transfers

    function testBulkTransferERC20(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        _performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC721(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        _performSingleItemTransferAndCheckBalances(
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
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        _performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
        _performSingleItemTransferAndCheckBalances(
            item,
            bob,
            cal,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC1155(FuzzInputsCommon memory inputs) public {
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        _performSingleItemTransferAndCheckBalances(
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
        items[0] = _getFuzzedTransferItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        _performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferERC1155andERC721andERC20(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](3);
        items[0] = _getFuzzedTransferItem(
            ConduitItemType.ERC1155,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );
        items[2] = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[2],
            inputs.tokenIndex[2],
            inputs.identifiers[2]
        );

        _performMultiItemTransferAndCheckBalances(
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
            items[i] = _getFuzzedTransferItem(
                ConduitItemType.ERC721,
                inputs.amounts[i],
                // Same token index for all items since this is testing from same contract
                inputs.tokenIndex[0],
                // Each item has a different token identifier as alice only owns one ERC721 token
                // for each identifier for this particular contract
                i
            );
        }

        _performMultiItemTransferAndCheckBalances(
            items,
            alice,
            bob,
            inputs.useConduit,
            ""
        );
    }

    function testBulkTransferMultipleERC721DifferentContracts(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](3);
        items[0] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[0],
            // Different token index for all items since this is testing from different contracts
            0,
            inputs.identifiers[0]
        );
        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            1,
            inputs.identifiers[1]
        );
        items[2] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[2],
            2,
            inputs.identifiers[2]
        );

        _performMultiItemTransferAndCheckBalances(
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
                items[i] = _getFuzzedTransferItem(
                    ConduitItemType.ERC1155,
                    inputs.amounts[i],
                    // Ensure each item is from a different contract
                    i,
                    inputs.identifiers[i]
                );
            } else {
                items[i] = _getFuzzedTransferItem(
                    ConduitItemType.ERC721,
                    inputs.amounts[i],
                    i,
                    inputs.identifiers[i]
                );
            }
        }

        _performMultiItemTransferAndCheckBalances(
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
        TransferHelperItem
            memory item = _getFuzzedERC721TransferItemWithAmountGreaterThan1(
                inputs.amounts[0],
                inputs.tokenIndex[0],
                inputs.identifiers[0]
            );

        _performSingleItemTransferAndCheckBalances(item, alice, bob, false, "");
    }

    function testBulkTransferERC721AmountMoreThan1AndERC20NotUsingConduit(
        FuzzInputsCommon memory inputs
    ) public {
        TransferHelperItem[] memory items = new TransferHelperItem[](2);
        items[0] = _getFuzzedERC721TransferItemWithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        _performMultiItemTransferAndCheckBalances(items, alice, bob, false, "");
    }

    // Test reverts

    function testRevertBulkTransferETHonly(FuzzInputsCommon memory inputs)
        public
    {
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.NATIVE,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        _performSingleItemTransferAndCheckBalances(
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
        items[0] = _getFuzzedTransferItem(
            ConduitItemType.NATIVE,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC721,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        _performMultiItemTransferAndCheckBalances(
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
        TransferHelperItem
            memory item = _getFuzzedERC721TransferItemWithAmountGreaterThan1(
                inputs.amounts[0],
                inputs.tokenIndex[0],
                inputs.identifiers[0]
            );

        _performSingleItemTransferAndCheckBalances(
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
        items[0] = _getFuzzedERC721TransferItemWithAmountGreaterThan1(
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );

        items[1] = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[1],
            inputs.tokenIndex[1],
            inputs.identifiers[1]
        );

        _performMultiItemTransferAndCheckBalances(
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
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        _updateConduitChannel(false);
        _performSingleItemTransferAndCheckBalances(
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

    function testRevertBulkTransferUnknownConduit(
        FuzzInputsCommon memory inputs,
        bytes32 fuzzConduitKey
    ) public {
        // Assume fuzzConduitKey is not equal to TransferHelper's value for "no conduit".
        vm.assume(
            fuzzConduitKey != bytes32(0) && fuzzConduitKey != conduitKeyOne
        );
        TransferHelperItem memory item = _getFuzzedTransferItem(
            ConduitItemType.ERC20,
            inputs.amounts[0],
            inputs.tokenIndex[0],
            inputs.identifiers[0]
        );
        // Reassign the conduit key that gets passed into TransferHelper to fuzzConduitKey.
        conduitKeyOne = fuzzConduitKey;
        _performSingleItemTransferAndCheckBalances(
            item,
            alice,
            bob,
            true,
            REVERT_DATA_NO_MSG
        );
    }
}
