// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import {
    TestPoolFactory,
    TestPoolOfferer
} from "../../../offerers/TestPoolFactory.sol";
import {
    SpentItem,
    ReceivedItem,
    InventoryUpdate,
    OrderComponents,
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver,
    OrderType
} from "seaport/lib/ConsiderationStructs.sol";
import { ItemType } from "seaport/lib/ConsiderationEnums.sol";

contract TestPoolOfferrerTest is BaseOrderTest {
    TestPoolFactory factory;
    TestPoolOfferer offerer;

    function setUp() public override {
        super.setUp();
        factory = new TestPoolFactory(address(referenceConsideration));
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 101;
        tokenIds[1] = 102;
        tokenIds[2] = 103;
        tokenIds[3] = 104;
        tokenIds[4] = 105;
        for (uint256 i; i < tokenIds.length; i++) {
            test721_1.mint(address(this), tokenIds[i]);
        }

        token1.approve(address(factory), 1000);
        test721_1.setApprovalForAll(address(factory), true);
        offerer = factory.createPoolOfferer(
            address(test721_1), tokenIds, address(token1), 1000
        );

        vm.label(address(factory), "factory");
        vm.label(address(offerer), "offerer");
    }

    function testBuyOne() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 101,
            amount: 1
        });

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: 300 // will not spend entire amount
        });

        addOfferItem(ItemType.ERC721, 101, 1);
        addConsiderationItem(payable(address(offerer)), ItemType.ERC20, 0, 250);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        _configureOrderComponents(
            referenceConsideration.getCounter(address(offerer))
        );

        bytes32 orderHash =
            referenceConsideration.getOrderHash(baseOrderComponents);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        referenceConsideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(test721_1.balanceOf(address(this)), 1);
        assertEq(test721_1.ownerOf(101), address(this));
        assertEq(token1.balanceOf(address(offerer)), 1250);
    }

    function testBuyTwo() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 101,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 102,
            amount: 1
        });

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: 1000000
        });

        addOfferItem(ItemType.ERC721, 101, 1);
        addOfferItem(ItemType.ERC721, 102, 1);
        addConsiderationItem(payable(address(offerer)), ItemType.ERC20, 0, 666);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        _configureOrderComponents(
            referenceConsideration.getCounter(address(offerer))
        );

        bytes32 orderHash =
            referenceConsideration.getOrderHash(baseOrderComponents);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        referenceConsideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(test721_1.balanceOf(address(this)), 2);
        assertEq(test721_1.ownerOf(101), address(this));
        assertEq(token1.balanceOf(address(offerer)), 1666);
    }

    function testSellOne() public {
        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 101,
            amount: 1
        });

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: 300 // will not spend entire amount
        });

        test721_1.mint(address(this), 106);

        addConsiderationItem(payable(address(offerer)), ItemType.ERC721, 106, 1);
        addOfferItem(ItemType.ERC20, 0, 166);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        _configureOrderComponents(
            referenceConsideration.getCounter(address(offerer))
        );

        bytes32 orderHash =
            referenceConsideration.getOrderHash(baseOrderComponents);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        referenceConsideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(test721_1.balanceOf(address(offerer)), 6);
        assertEq(test721_1.ownerOf(106), address(offerer));
        assertEq(token1.balanceOf(address(offerer)), 833);
    }
}
