// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Test } from "forge-std/Test.sol";

import { ItemType } from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem
} from "../../../contracts/lib/ConsiderationStructs.sol";

import {
    EnumerableSet
} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {
    IERC20
} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {
    ContractOffererInterface
} from "../../../contracts/interfaces/ContractOffererInterface.sol";

import { ERC165 } from "../../../contracts/interfaces/ERC165.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestPoolOfferer } from "./impl/TestPoolOfferer.sol";

contract TestPoolFactoryImpl {
    address immutable seaport;

    constructor(address _seaport) {
        seaport = _seaport;
    }

    function createPoolOfferer(
        address erc721,
        uint256[] calldata tokenIds,
        address erc20,
        uint256 amount
    ) external returns (address newPool) {
        newPool = address(
            new TestPoolImpl(
                seaport,
                erc721,
                tokenIds,
                erc20,
                amount,
                msg.sender
            )
        );
        IERC20(erc20).transferFrom(msg.sender, newPool, amount);
        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(erc721).transferFrom(msg.sender, newPool, tokenIds[i]);
        }
    }
}

contract TestPoolImpl is ERC165, TestPoolOfferer {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(
        address seaport,
        address _token,
        uint256[] memory _tokenIds,
        address _payment,
        uint256 amount,
        address owner
    ) TestPoolOfferer(seaport, _token, _tokenIds, _payment, amount, owner) {}

    function getInternalBalance() external view returns (uint256) {
        return balance;
    }

    function getInternalTokenBalance() external view returns (uint256) {
        return tokenIds.length();
    }

    function inTokenIds(uint256 id) external view returns (bool) {
        return tokenIds.contains(id);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, TestPoolOfferer) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract TestPoolOffererImpl is Test {
    TestPoolFactoryImpl factory;
    TestPoolImpl test;
    TestERC20 erc20;
    TestERC721 erc721;
    address seaport;

    function setUp() public {
        seaport = makeAddr("seaport");
        erc20 = new TestERC20();
        erc721 = new TestERC721();

        factory = new TestPoolFactoryImpl(seaport);

        erc20.mint(address(this), 2e18);
        erc721.mint(address(this), 0);
        erc721.mint(address(this), 1);
        erc721.mint(address(this), 2);
        erc721.mint(address(this), 3);
        erc721.mint(address(this), 4);

        erc20.approve(seaport, type(uint256).max);
        erc20.approve(address(factory), type(uint256).max);
        erc721.setApprovalForAll(seaport, true);
        erc721.setApprovalForAll(address(factory), true);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        test = TestPoolImpl(
            factory.createPoolOfferer(
                address(erc721),
                tokenIds,
                address(erc20),
                1e18
            )
        );
    }

    function testInitialized() public {
        assertEq(erc20.balanceOf(address(test)), 1e18);
        assertEq(erc721.balanceOf(address(test)), 3);
        assertEq(erc721.ownerOf(0), address(test));
        assertEq(erc721.ownerOf(1), address(test));
        assertEq(erc721.ownerOf(2), address(test));
    }

    function testPreviewOrder() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 0,
            amount: 1
        });
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.previewOrder(
                address(0),
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 1, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[0].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[0].identifier, 0, "wrong spentitem identifier");
        assertEq(spentItems[0].token, address(erc721), "wrong spentitem token");
        assertEq(receivedItems.length, 1, "wrong receivedItems length");
        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(receivedItems[0].identifier, 0, "wrong identifier");
        assertEq(receivedItems[0].amount, 5e17, "wrong amount");
        assertEq(receivedItems[0].token, address(erc20), "wrong token");
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");
    }

    function testPreviewOrder_wildcard() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc721),
            identifier: 0,
            amount: 1
        });
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.previewOrder(
                address(0),
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 1, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[0].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[0].identifier, 0, "wrong spentitem identifier");
        assertEq(spentItems[0].token, address(erc721), "wrong spentitem token");
        assertEq(receivedItems.length, 1, "wrong receivedItems length");
        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(receivedItems[0].identifier, 0, "wrong identifier");
        assertEq(receivedItems[0].amount, 5e17, "wrong amount");
        assertEq(receivedItems[0].token, address(erc20), "wrong token");
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");
    }

    function testPreviewOrder2() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 0,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 1,
            amount: 1
        });
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.previewOrder(
                address(0),
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );
        assertEq(spentItems.length, 2, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[0].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[0].identifier, 0, "wrong spentitem identifier");
        assertEq(spentItems[0].token, address(erc721), "wrong spentitem token");
        assertEq(
            uint8(spentItems[1].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[1].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[1].identifier, 1, "wrong spentitem identifier");
        assertEq(spentItems[1].token, address(erc721), "wrong spentitem token");
        assertEq(receivedItems.length, 1, "wrong receivedItems length");

        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(receivedItems[0].identifier, 0, "wrong identifier");
        assertEq(receivedItems[0].amount, 2e18, "wrong amount");
        assertEq(receivedItems[0].token, address(erc20), "wrong token");
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");
    }

    function testPreviewOrder3() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);

        SpentItem[] memory maximumSpent = new SpentItem[](2);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 3,
            amount: 1
        });
        maximumSpent[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 4,
            amount: 1
        });
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.previewOrder(
                address(0),
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 1, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(spentItems[0].identifier, 0, "wrong identifier");
        assertEq(spentItems[0].amount, 4e17, "wrong amount");
        assertEq(spentItems[0].token, address(erc20), "wrong token");

        assertEq(receivedItems.length, 2, "wrong receivedItems length");
        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(receivedItems[0].amount, 1, "wrong spentitem amount");
        assertEq(receivedItems[0].identifier, 3, "wrong spentitem identifier");
        assertEq(
            receivedItems[0].token,
            address(erc721),
            "wrong spentitem token"
        );
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");

        assertEq(
            uint8(receivedItems[1].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(receivedItems[1].amount, 1, "wrong spentitem amount");
        assertEq(receivedItems[1].identifier, 4, "wrong spentitem identifier");
        assertEq(
            receivedItems[1].token,
            address(erc721),
            "wrong spentitem token"
        );
        assertEq(receivedItems[1].recipient, address(test), "wrong receiver");
    }

    function testGenerateOrder() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);

        SpentItem[] memory maximumSpent = new SpentItem[](2);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 3,
            amount: 1
        });
        maximumSpent[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 4,
            amount: 1
        });
        vm.prank(seaport);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.generateOrder(
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 1, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(spentItems[0].identifier, 0, "wrong identifier");
        assertEq(spentItems[0].amount, 4e17, "wrong amount");
        assertEq(spentItems[0].token, address(erc20), "wrong token");

        assertEq(receivedItems.length, 2, "wrong receivedItems length");
        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(receivedItems[0].amount, 1, "wrong spentitem amount");
        assertEq(receivedItems[0].identifier, 3, "wrong spentitem identifier");
        assertEq(
            receivedItems[0].token,
            address(erc721),
            "wrong spentitem token"
        );
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");

        assertEq(
            uint8(receivedItems[1].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(receivedItems[1].amount, 1, "wrong spentitem amount");
        assertEq(receivedItems[1].identifier, 4, "wrong spentitem identifier");
        assertEq(
            receivedItems[1].token,
            address(erc721),
            "wrong spentitem token"
        );
        assertEq(receivedItems[1].recipient, address(test), "wrong receiver");

        assertEq(
            test.getInternalBalance(),
            1e18 - 4e17,
            "wrong internal balance"
        );
        assertEq(
            test.getInternalTokenBalance(),
            5,
            "wrong internal token balance"
        );
        assertTrue(test.inTokenIds(3), "id not in tokenIds");
        assertTrue(test.inTokenIds(4), "id not in tokenIds");
    }

    function testGenerateOrder2() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 0,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(erc721),
            identifier: 1,
            amount: 1
        });
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);
        vm.prank(seaport);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.generateOrder(
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 2, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[0].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[0].identifier, 0, "wrong spentitem identifier");
        assertEq(spentItems[0].token, address(erc721), "wrong spentitem token");
        assertEq(
            uint8(spentItems[1].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[1].amount, 1, "wrong spentitem amount");
        assertEq(spentItems[1].identifier, 1, "wrong spentitem identifier");
        assertEq(spentItems[1].token, address(erc721), "wrong spentitem token");
        assertEq(receivedItems.length, 1, "wrong receivedItems length");

        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(receivedItems[0].identifier, 0, "wrong identifier");
        assertEq(receivedItems[0].amount, 2e18, "wrong amount");
        assertEq(receivedItems[0].token, address(erc20), "wrong token");
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");

        assertEq(
            test.getInternalBalance(),
            1e18 + 2e18,
            "wrong internal balance"
        );
        assertEq(
            test.getInternalTokenBalance(),
            1,
            "wrong internal token balance"
        );
        assertFalse(test.inTokenIds(0), "id  in tokenIds");
        assertFalse(test.inTokenIds(1), "id in tokenIds");
    }

    function testGenerateOrder_wildcard1() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc721),
            identifier: 101,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc721),
            identifier: 10,
            amount: 1
        });
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);
        vm.prank(seaport);
        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = test.generateOrder(
                address(this),
                minimumReceived,
                maximumSpent,
                ""
            );

        assertEq(spentItems.length, 2, "wrong spentItems length");
        assertEq(
            uint8(spentItems[0].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[0].amount, 1, "wrong spentitem amount");
        assertLt(spentItems[0].identifier, 3, "wrong spentitem identifier");
        assertEq(spentItems[0].token, address(erc721), "wrong spentitem token");
        assertEq(
            uint8(spentItems[1].itemType),
            uint8(ItemType.ERC721),
            "wrong spentitem type"
        );
        assertEq(spentItems[1].amount, 1, "wrong spentitem amount");
        assertLt(spentItems[1].identifier, 3, "wrong spentitem identifier");
        assertEq(spentItems[1].token, address(erc721), "wrong spentitem token");
        assertEq(receivedItems.length, 1, "wrong receivedItems length");

        assertEq(
            uint8(receivedItems[0].itemType),
            uint8(ItemType.ERC20),
            "wrong receiveditem type"
        );
        assertEq(receivedItems[0].identifier, 0, "wrong identifier");
        assertEq(receivedItems[0].amount, 2e18, "wrong amount");
        assertEq(receivedItems[0].token, address(erc20), "wrong token");
        assertEq(receivedItems[0].recipient, address(test), "wrong receiver");

        assertEq(
            test.getInternalBalance(),
            1e18 + 2e18,
            "wrong internal balance"
        );
        assertEq(
            test.getInternalTokenBalance(),
            1,
            "wrong internal token balance"
        );
        assertFalse(
            test.inTokenIds(spentItems[0].identifier),
            "id not in tokenIds"
        );
        assertFalse(
            test.inTokenIds(spentItems[1].identifier),
            "id not in tokenIds"
        );

        assertTrue(
            spentItems[0].identifier != spentItems[1].identifier,
            "same id"
        );
    }

    function testGenerateOrder_wildcard_rejectWildcardSpent() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem(ItemType.ERC20, address(erc20), 6e17, 1);

        SpentItem[] memory maximumSpent = new SpentItem[](2);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc721),
            identifier: 3,
            amount: 1
        });
        maximumSpent[1] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc721),
            identifier: 4,
            amount: 1
        });
        vm.startPrank(seaport);
        vm.expectRevert(TestPoolOfferer.InvalidItemType.selector);
        test.generateOrder(address(this), minimumReceived, maximumSpent, "");
    }
}
