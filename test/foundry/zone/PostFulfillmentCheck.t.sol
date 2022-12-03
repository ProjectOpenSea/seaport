// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { TestZone } from "./impl/TestZone.sol";
import {
    PostFulfillmentStatefulTestZone
} from "./impl/PostFullfillmentStatefulTestZone.sol";
import {
    ConsiderationItem,
    OfferItem,
    ItemType,
    AdvancedOrder,
    CriteriaResolver,
    BasicOrderParameters,
    Order
} from "seaport/lib/ConsiderationStructs.sol";
import {
    OrderType,
    Side,
    BasicOrderType
} from "seaport/lib/ConsiderationEnums.sol";

contract PostFulfillmentCheckTest is BaseOrderTest {
    TestZone zone = new TestZone();
    PostFulfillmentStatefulTestZone statefulZone =
        new PostFulfillmentStatefulTestZone();

    struct EthConsideration {
        address payable recipient;
        uint256 amount;
    }

    function setUp() public override {
        super.setUp();
        vm.label(address(zone), "TestZone");
    }

    function testNormalOrder() public {
        vm.warp(0x696969696969);
        // create and label offerer who can sign an order
        (address offerer, uint256 pkey) = makeAddrAndKey("offerer");
        // mint an nft to the offerer
        uint256 tokenId = 0x6969;
        uint256 tokenIdAmt = 0x16969;
        uint256 tokenIdAmtEnd = 0x26969;
        test1155_1.mint(offerer, tokenId, tokenIdAmt);
        vm.prank(offerer);
        test1155_1.setApprovalForAll(address(consideration), true);
        addOfferItem(ItemType.ERC1155, tokenId, tokenIdAmt, tokenIdAmtEnd);

        // add typical 3 consideration items
        EthConsideration[] memory considerations = new EthConsideration[](3);
        considerations[0] = EthConsideration(
            payable(address(0x56969)),
            0x66969
        );
        considerations[1] = EthConsideration(
            payable(address(0x76969)),
            0x86969
        );
        considerations[2] = EthConsideration(
            payable(address(0x96969)),
            0xa6969
        );
        addEthConsiderationItem(
            considerations[0].recipient,
            considerations[0].amount
        );
        addEthConsiderationItem(
            considerations[1].recipient,
            considerations[1].amount
        );
        addEthConsiderationItem(
            considerations[2].recipient,
            considerations[2].amount
        );

        _configureOrderParameters({
            offerer: offerer,
            zone: address(zone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        _configureOrderComponents(0);
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, pkey, orderHash);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers;

        consideration.fulfillAdvancedOrder{
            value: _sumConsiderationAmounts()
        }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testAscendingAmount() public {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 42);
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        _configureOrderComponents(0);
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, alicePk, orderHash);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers;
        vm.warp(50);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testResolvedCriteria() public {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 0);
        considerationItems[0].itemType = ItemType.ERC721_WITH_CRITERIA;
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        _configureOrderComponents(0);
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, alicePk, orderHash);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        criteriaResolvers[0] = CriteriaResolver({
            orderIndex: 0,
            side: Side.CONSIDERATION,
            index: 0,
            identifier: 42,
            criteriaProof: new bytes32[](0)
        });
        vm.warp(50);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testStateChange() public {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 0);
        considerationItems[0].itemType = ItemType.ERC721_WITH_CRITERIA;
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        _configureOrderComponents(0);
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, alicePk, orderHash);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        criteriaResolvers[0] = CriteriaResolver({
            orderIndex: 0,
            side: Side.CONSIDERATION,
            index: 0,
            identifier: 42,
            criteriaProof: new bytes32[](0)
        });
        vm.warp(50);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(statefulZone.called());
    }

    function testBasicStateful() public {
        addErc20OfferItem(50);
        addErc721ConsiderationItem(alice, 42);
        test721_1.mint(address(this), 42);

        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        _configureOrderComponents(0);
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, alicePk, orderHash);

        BasicOrderParameters
            memory basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED,
                signature
            );
        vm.warp(50);
        consideration.fulfillBasicOrder({ parameters: basicOrderParameters });
    }

    function _sumConsiderationAmounts() internal returns (uint256 sum) {
        for (uint256 i = 0; i < considerationItems.length; i++) {
            sum += considerationItems[i].startAmount;
        }
    }
}
