// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

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
    Recipient,
    SignatureMethod
} from "seaport-sol/SpaceEnums.sol";

import {
    TestStateGenerator,
    AdvancedOrdersSpaceGenerator,
    GeneratorContext,
    PRNGHelpers
} from "./helpers/FuzzGenerators.sol";

contract FuzzGeneratorsTest is BaseOrderTest {
    using LibPRNG for LibPRNG.PRNG;
    using PRNGHelpers for GeneratorContext;

    /// @dev Note: the GeneratorContext must be a struct in *memory* in order
    ///      for the PRNG to work properly, so we can't declare it as a storage
    ///      variable in setUp. Instead, use this function to create a context.
    function createContext() internal view returns (GeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        return
            GeneratorContext({
                vm: vm,
                prng: prng,
                timestamp: block.timestamp,
                seaport: seaport,
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s,
                self: address(this),
                offerer: offerer1.addr,
                recipient: address(0), // TODO: read recipient from TestContext
                alice: offerer1.addr,
                bob: offerer2.addr,
                dillon: dillon.addr,
                eve: eve.addr,
                frank: frank.addr,
                offererPk: offerer1.key,
                alicePk: offerer1.key,
                bobPk: offerer2.key,
                dillonPk: dillon.key,
                frankPk: frank.key,
                evePk: eve.key,
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

    function test_emptySpace() public {
        GeneratorContext memory context = createContext();
        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: new OrderComponentsSpace[](0)
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 0);
    }

    function test_emptyOfferConsideration() public {
        GeneratorContext memory context = createContext();
        OfferItemSpace[] memory offer = new OfferItemSpace[](0);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](0);

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.TEST_CONTRACT,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 0);
        assertEq(orders[0].parameters.consideration.length, 0);
    }

    function test_singleOffer_emptyConsideration() public {
        GeneratorContext memory context = createContext();
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
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 1);

        assertEq(orders[0].parameters.offer[0].itemType, ItemType.ERC20);
        assertEq(orders[0].parameters.offer[0].token, address(erc20s[0]));
        assertGt(orders[0].parameters.offer[0].startAmount, 0);

        assertEq(
            orders[0].parameters.offer[0].startAmount,
            orders[0].parameters.offer[0].endAmount
        );

        assertEq(orders[0].parameters.consideration.length, 0);
    }

    function test_emptyOffer_singleConsideration() public {
        GeneratorContext memory context = createContext();
        OfferItemSpace[] memory offer = new OfferItemSpace[](0);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](1);
        consideration[0] = ConsiderationItemSpace({
            itemType: ItemType.ERC721,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.NONE,
            amount: Amount.ASCENDING,
            recipient: Recipient.OFFERER
        });

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.TEST_CONTRACT,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 0);
        assertEq(orders[0].parameters.consideration.length, 1);

        assertGt(orders[0].parameters.consideration[0].startAmount, 0);
        assertGt(
            orders[0].parameters.consideration[0].endAmount,
            orders[0].parameters.consideration[0].startAmount
        );
        assertEq(
            orders[0].parameters.consideration[0].recipient,
            offerer1.addr
        );

        assertEq(
            orders[0].parameters.consideration[0].itemType,
            ItemType.ERC721
        );
    }

    function test_stateGenerator() public {
        GeneratorContext memory context = createContext();
        AdvancedOrdersSpace memory space = TestStateGenerator.generate(
            3, // total orders
            10, // max offer items/order
            5, // max consideration items/order
            context
        );

        // Note: the following values are all based on PRNG seed uint256(0)
        assertEq(space.orders.length, 3);

        assertEq(space.orders[0].offerer, 1);
        assertEq(space.orders[0].zone, 1);

        assertEq(space.orders[0].offer.length, 8);
        assertEq(space.orders[0].offer[0].itemType, 1);
        assertEq(space.orders[0].offer[0].tokenIndex, 2);
        assertEq(space.orders[0].offer[0].criteria, 1);
        assertEq(space.orders[0].offer[0].amount, 2);

        assertEq(space.orders[0].offer[1].itemType, 2);
        assertEq(space.orders[0].offer[1].tokenIndex, 1);
        assertEq(space.orders[0].offer[1].criteria, 1);
        assertEq(space.orders[0].offer[1].amount, 2);

        assertEq(space.orders[0].offer[2].itemType, 3);
        assertEq(space.orders[0].offer[2].tokenIndex, 0);
        assertEq(space.orders[0].offer[2].criteria, 1);
        assertEq(space.orders[0].offer[2].amount, 2);

        assertEq(space.orders[0].consideration.length, 3);
        assertEq(space.orders[0].consideration[0].itemType, 2);
        assertEq(space.orders[0].consideration[0].tokenIndex, 0);
        assertEq(space.orders[0].consideration[0].criteria, 2);
        assertEq(space.orders[0].consideration[0].amount, 2);
        assertEq(space.orders[0].consideration[0].recipient, 4);

        assertEq(space.orders[0].consideration[1].itemType, 3);
        assertEq(space.orders[0].consideration[1].tokenIndex, 2);
        assertEq(space.orders[0].consideration[1].criteria, 2);
        assertEq(space.orders[0].consideration[1].amount, 2);
        assertEq(space.orders[0].consideration[1].recipient, 0);

        assertEq(space.orders[0].consideration[2].itemType, 4);
        assertEq(space.orders[0].consideration[2].tokenIndex, 2);
        assertEq(space.orders[0].consideration[2].criteria, 1);
        assertEq(space.orders[0].consideration[2].amount, 0);
        assertEq(space.orders[0].consideration[2].recipient, 2);

        assertEq(space.orders[0].orderType, 1);
        assertEq(space.orders[0].time, 0);
        assertEq(space.orders[0].zoneHash, 2);

        assertEq(space.orders[1].offerer, 1);
        assertEq(space.orders[1].zone, 0);
        assertEq(space.orders[1].offer.length, 1);
        assertEq(space.orders[1].consideration.length, 1);
        assertEq(space.orders[1].orderType, 0);
        assertEq(space.orders[1].time, 2);
        assertEq(space.orders[1].zoneHash, 2);

        assertEq(space.orders[2].offerer, 1);
        assertEq(space.orders[2].zone, 1);
        assertEq(space.orders[2].offer.length, 0);
        assertEq(space.orders[2].consideration.length, 1);
        assertEq(space.orders[2].orderType, 0);
        assertEq(space.orders[2].time, 3);
        assertEq(space.orders[2].zoneHash, 2);
    }

    function assertEq(ItemType a, ItemType b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(ItemType a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Offerer a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Zone a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(BroadOrderType a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Time a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(ZoneHash a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(TokenIndex a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Criteria a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Amount a, uint8 b) internal {
        assertEq(uint8(a), b);
    }

    function assertEq(Recipient a, uint8 b) internal {
        assertEq(uint8(a), b);
    }
}
