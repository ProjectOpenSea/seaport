// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { DifferentialTest } from "../utils/DifferentialTest.sol";
// import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ERC20Interface,
    ERC721Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    ContractOffererInterface
} from "../../../contracts/interfaces/ContractOffererInterface.sol";
import { ItemType } from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem
} from "../../../contracts/lib/ConsiderationStructs.sol";
import {
    TestContractOffererNativeToken
} from "../../../contracts/test/TestContractOffererNativeToken.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

contract ContractOffersNativeTokenOfferItems is
    DifferentialTest,
    BaseOrderTest
{
    struct FuzzArgs {
        uint256 ethAmount;
        uint256 nftId;
    }

    struct Context {
        ConsiderationInterface seaport;
        FuzzArgs args;
    }

    modifier validateInputs(FuzzArgs memory args) {
        vm.assume(args.ethAmount > 0);
        _;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    TestERC721 erc721;

    function setUp() public override {
        erc721 = new TestERC721();
    }

    function testGenerateOrder(
        FuzzArgs memory args
    ) public validateInputs(args) {
        test(
            this.generateOrder,
            Context({ seaport: consideration, args: args })
        );
        test(
            this.generateOrder,
            Context({ seaport: referenceConsideration, args: args })
        );
    }

    function generateOrder(Context memory context) public stateless {
        TestContractOffererNativeToken contractOfferer = new TestContractOffererNativeToken(
                address(context.seaport)
            );
        vm.deal(address(contractOfferer), 1000 ether);

        erc721.setApprovalForAll(address(contractOfferer), true);
        erc721.mint(address(this), context.args.nftId);

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: context.args.nftId,
            amount: 1
        });

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifier: 0,
            amount: context.args.ethAmount
        });

        contractOfferer.activate(maximumSpent[0], minimumReceived[0]);

        vm.prank(address(context.seaport));
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = contractOfferer.generateOrder(
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 1, "Spent items length should be 1");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.NATIVE),
            "Spent item type should be ETH"
        );
        assertEq(
            spentItems[0].token,
            address(0),
            "Spent item token address should be 0x0"
        );
        assertEq(
            spentItems[0].identifier,
            0,
            "Spent item token id should be 0"
        );
        assertEq(
            spentItems[0].amount,
            context.args.ethAmount,
            "Spent item amount should be fuzzed ethAmount"
        );
        assertEq(receivedItems.length, 1, "Received items length should be 1");
        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC721),
            "Received item type should be ERC721"
        );
        assertEq(
            receivedItems[0].token,
            address(erc721),
            "Received item token address should be address(erc721)"
        );
        assertEq(
            receivedItems[0].identifier,
            context.args.nftId,
            "Received item token id should be fuzzed nftId"
        );
        assertEq(
            receivedItems[0].amount,
            1,
            "Received item amount should be 1"
        );
    }
}
