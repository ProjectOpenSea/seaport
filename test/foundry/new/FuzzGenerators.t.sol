// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";
import {
    AdvancedOrdersSpace,
    OrderComponentsSpace,
    OfferItemSpace,
    ConsiderationItemSpace
} from "seaport-sol/StructSpace.sol";
import {
    Offerer,
    Zone,
    BroadOrderType,
    Time,
    ZoneHash,
    TokenIndex,
    Criteria,
    Amount,
    Recipient
} from "seaport-sol/SpaceEnums.sol";

import { AdvancedOrdersSpaceGenerator } from "./helpers/FuzzGenerators.sol";

contract FuzzGeneratorsTest is BaseOrderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_emptySpace() public {
        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: new OrderComponentsSpace[](0)
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space
        );
        assertEq(orders.length, 0);
    }

    function test_emptyOfferConsideration() public {
        OfferItemSpace[] memory offer = new OfferItemSpace[](0);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](0);

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.TEST_CONTRACT,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.START,
            zoneHash: ZoneHash.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 0);
        assertEq(orders[0].parameters.consideration.length, 0);
    }

    function test_singleOffer_emptyConsideration() public {
        OfferItemSpace[] memory offer = new OfferItemSpace[](1);
        offer[0] = OfferItemSpace({
            itemType: ItemType.ERC20,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.NONE,
            amount: Amount.FIXED
        });
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](0);

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.TEST_CONTRACT,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.START,
            zoneHash: ZoneHash.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 1);
        assertEq(orders[0].parameters.offer[0].itemType, ItemType.ERC20);
        assertEq(orders[0].parameters.consideration.length, 0);
    }

    function test_emptyOffer_singleConsideration() public {
        OfferItemSpace[] memory offer = new OfferItemSpace[](0);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](1);
        consideration[0] = ConsiderationItemSpace({
            itemType: ItemType.ERC721,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.NONE,
            amount: Amount.FIXED,
            recipient: Recipient.OFFERER
        });

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.TEST_CONTRACT,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.START,
            zoneHash: ZoneHash.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 0);
        assertEq(orders[0].parameters.consideration.length, 1);
        assertEq(
            orders[0].parameters.consideration[0].itemType,
            ItemType.ERC721
        );
    }

    function assertEq(ItemType a, ItemType b) internal {
        assertEq(uint8(a), uint8(b));
    }
}
