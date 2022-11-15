// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

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

struct TransferHelperItem {
    uint8 itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

struct TransferHelperItemsWithRecipient {
    TransferHelperItem[] items;
    address recipient;
    bool validateERC721Receiver;
}

interface TransferHelper {
    function bulkTransfer(
        TransferHelperItemsWithRecipient[] memory items,
        bytes32 conduitKey
    ) external returns (bytes4 magicValue);
}

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

    function testSellTwo() public {
        test721_1.mint(address(this), 106);
        test721_1.mint(address(this), 107);
        SpentItem[] memory maximumSpent = new SpentItem[](2);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 106,
            amount: 1
        });
        maximumSpent[1] = SpentItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 107,
            amount: 1
        });

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: 1000000
        });

        addConsiderationItem(payable(address(offerer)), ItemType.ERC721, 106, 1);
        addConsiderationItem(payable(address(offerer)), ItemType.ERC721, 107, 1);
        addOfferItem(ItemType.ERC20, 0, 286);

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

        assertEq(test721_1.balanceOf(address(offerer)), 7);
        assertEq(test721_1.ownerOf(106), address(offerer));
        assertEq(test721_1.ownerOf(107), address(offerer));
        assertEq(token1.balanceOf(address(offerer)), 714);
    }

    function testBuyOneWildCard() public {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(test721_1),
            identifier: 0,
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

    function testBuyTwoWildCard() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(test721_1),
            identifier: 0,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(test721_1),
            identifier: 0,
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

    function testBuyTwoHeterogenous() public {
        SpentItem[] memory minimumReceived = new SpentItem[](2);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(test721_1),
            identifier: 0,
            amount: 1
        });
        minimumReceived[1] = SpentItem({
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
        assertEq(test721_1.ownerOf(102), address(this));
        assertEq(token1.balanceOf(address(offerer)), 1666);
    }

    function testThing() public {
        vm.createSelectFork(stdChains.Mainnet.rpcUrl);
        address conduit = 0x1E0049783F008A0085193E00003D00cd54003c71;
        address token = 0x270488657c6724172372615eA8eb2802b233D41c;
        TransferHelper helper =
            TransferHelper(0x0000000000c2d145a2526bD8C716263bFeBe1A72);
        address tokenOwner = 0xC5D490889b5974ab6824330057896B26E5371B23;
        uint256 tokenId = 1076;

        vm.prank(tokenOwner);
        IERC721(token).setApprovalForAll(conduit, true);

        TransferHelperItem memory item = TransferHelperItem({
            itemType: 2,
            token: token,
            identifier: tokenId,
            amount: 1
        });
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        TransferHelperItemsWithRecipient memory itemsWithRecipient =
        TransferHelperItemsWithRecipient({
            items: items,
            recipient: address(this),
            validateERC721Receiver: false
        });

        TransferHelperItemsWithRecipient[] memory itemsWithRecipientArray =
            new TransferHelperItemsWithRecipient[](1);
        itemsWithRecipientArray[0] = itemsWithRecipient;
        helper.bulkTransfer(
            itemsWithRecipientArray,
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
    }

    function testThing() public {
        vm.createSelectFork(stdChains.Mainnet.rpcUrl);
        address conduit = 0x1E0049783F008A0085193E00003D00cd54003c71;
        address token = 0x270488657c6724172372615eA8eb2802b233D41c;
        TransferHelper helper =
            TransferHelper(0x0000000000c2d145a2526bD8C716263bFeBe1A72);
        address tokenOwner = 0xC5D490889b5974ab6824330057896B26E5371B23;
        uint256 tokenId = 1076;

        vm.prank(tokenOwner);
        IERC721(token).setApprovalForAll(conduit, true);

        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        items[0] = item;
        TransferHelperItemsWithRecipient memory itemsWithRecipient =
        TransferHelperItemsWithRecipient({
            items: items,
            recipient: address(this),
            validateERC721Receiver: false
        });

        TransferHelperItemsWithRecipient[] memory itemsWithRecipientArray =
            new TransferHelperItemsWithRecipient[](1);
        itemsWithRecipientArray[0] = itemsWithRecipient;
        helper.bulkTransfer(
            itemsWithRecipientArray,
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
    }

    function testOtherThing() public {
        address considerationToken = 0x0000000000000000000000000000000000000000;
        uint256 considerationIdentifier = 0;
        uint256 considerationAmount = 27750000000000000;
        address offerer = 0xd92eFBf6bb77E3fa31F9dF960b6E683aFED0eF1b;
        address zone = 0x004C00500000aD104D7DBd00e3ae0A5C00560C00;
        address offerToken = 0x270488657c6724172372615eA8eb2802b233D41c;
        uint256 offerIdentifier = 471;
        uint256 offerAmount = 1;
        uint8 basicOrderType = 2;
        uint256 startTime = 1667508198;
        uint256 endTime = 1669826783;
        bytes32 zoneHash =
            0x0000000000000000000000000000000000000000000000000000000000000000;
        uint256 salt =
            24446860302761739304752683030156737591518664810215442929809810156620239778730;
        bytes32 offererConduitKey =
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
        bytes32 fulfillerConduitKey =
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
        uint256 totalOriginalAdditionalRecipients = 2;
        uint256 addlAmount1 = 750000000000000;
        address addlRecip1 = 0x0000a26b00c1F0DF003000390027140000fAa719;
        uint256 addlAmount2 = 1500000000000000;
        address addlRecip2 = 0xac9d54ca08740A608B6C474e5CA07d51cA8117Fa;
        bytes memory signature =
            hex"9416901301dca2051116c279ba9aa6df239a5992b44a38fc7f3af6ab35895e1d17769efdab6fc0c75b6465bf09a65f6684031ea57cdb8349a121e95c2586a5df1c";
    }
}
