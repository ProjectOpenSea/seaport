// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { DifferentialTest } from "../utils/DifferentialTest.sol";
import {
    ERC20Interface,
    ERC721Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import {
    ItemType,
    OrderType
} from "../../../contracts/lib/ConsiderationEnums.sol";

import { ItemType } from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    OrderParameters,
    OrderComponents,
    CriteriaResolver,
    SpentItem,
    ReceivedItem
} from "../../../contracts/lib/ConsiderationStructs.sol";

import {
    ContractOffererInterface
} from "../../../contracts/interfaces/ContractOffererInterface.sol";

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
        vm.assume(args.ethAmount > 0 && args.ethAmount < 100000);
        _;
    }

    TestERC721 erc721;

    function setUp() public override {
        super.setUp();
        erc721 = new TestERC721();
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testEthForErc721(FuzzArgs memory args)
        public
        validateInputs(args)
    {
        test(
            this.ethForErc721,
            Context({
                seaport: consideration,
                args: FuzzArgs({ ethAmount: 1, nftId: 1 })
            })
        );
        test(
            this.ethForErc721,
            Context({ seaport: referenceConsideration, args: args })
        );
    }

    function ethForErc721(Context memory context) public stateless {
        TestContractOffererNativeToken contractOfferer = new TestContractOffererNativeToken(
                address(context.seaport)
            );
        vm.deal(address(contractOfferer), UINT256_MAX);

        test721_1.setApprovalForAll(address(contractOfferer), true);
        test721_1.mint(address(this), context.args.nftId);

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: context.args.nftId,
            amount: 1
        });

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifier: 0,
            amount: context.args.ethAmount
        });

        addEthOfferItem(context.args.ethAmount);
        addErc721ConsiderationItem(
            payable(address(contractOfferer)),
            context.args.nftId
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(contractOfferer),
            address(0),
            offerItems,
            considerationItems,
            OrderType.CONTRACT,
            block.timestamp,
            block.timestamp + 1000,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        AdvancedOrder memory advancedOrder = AdvancedOrder(
            orderParameters,
            1,
            1,
            "",
            ""
        );

        uint256 originalBalance = address(this).balance;

        context.seaport.fulfillAdvancedOrder(
            advancedOrder,
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );

        assertEq(
            context.args.ethAmount,
            address(this).balance - originalBalance
        );
        assertEq(
            address(contractOfferer),
            test721_1.ownerOf(context.args.nftId)
        );
    }
}
