// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import "seaport-sol/SeaportSol.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/StructSpace.sol";

import {
    Amount,
    BroadOrderType,
    Criteria,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    TokenIndex,
    Zone,
    ZoneHash,
    ConduitChoice
} from "seaport-sol/SpaceEnums.sol";

import {
    AdvancedOrdersSpaceGenerator,
    GeneratorContext,
    PRNGHelpers,
    TestLike,
    TestConduit
} from "./helpers/FuzzGenerators.sol";
import {
    HashValidationZoneOfferer
} from "../../../contracts/test/HashValidationZoneOfferer.sol";

contract FuzzGeneratorsTest is BaseOrderTest {
    using LibPRNG for LibPRNG.PRNG;
    using PRNGHelpers for GeneratorContext;

    /// @dev Note: the GeneratorContext must be a struct in *memory* in order
    ///      for the PRNG to work properly, so we can't declare it as a storage
    ///      variable in setUp. Instead, use this function to create a context.
    function createContext() internal returns (GeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        return
            GeneratorContext({
                vm: vm,
                testHelpers: TestLike(address(this)),
                prng: prng,
                timestamp: block.timestamp,
                seaport: seaport,
                conduitController: conduitController,
                validatorZone: new HashValidationZoneOfferer(address(0)),
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s,
                self: address(this),
                caller: address(this), // TODO: read recipient from TestContext
                offerer: makeAccount("offerer"),
                alice: makeAccount("alice"),
                bob: makeAccount("bob"),
                carol: makeAccount("carol"),
                dillon: makeAccount("dillon"),
                eve: makeAccount("eve"),
                frank: makeAccount("frank"),
                starting721offerIndex: 1,
                starting721considerationIndex: 1,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0),
                conduits: new TestConduit[](2)
            });
    }

    function test_emptySpace() public {
        GeneratorContext memory context = createContext();
        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: new OrderComponentsSpace[](0),
            isMatchable: false
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
            offerer: Offerer.ALICE,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA,
            conduit: ConduitChoice.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false
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
            offerer: Offerer.ALICE,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA,
            conduit: ConduitChoice.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false
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
            itemType: ItemType.ERC20,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.NONE,
            amount: Amount.ASCENDING,
            recipient: Recipient.OFFERER
        });

        OrderComponentsSpace memory component = OrderComponentsSpace({
            offerer: Offerer.ALICE,
            zone: Zone.NONE,
            offer: offer,
            consideration: consideration,
            orderType: BroadOrderType.FULL,
            time: Time.ONGOING,
            zoneHash: ZoneHash.NONE,
            signatureMethod: SignatureMethod.EOA,
            conduit: ConduitChoice.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false
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
            context.offerer.addr
        );

        assertEq(
            orders[0].parameters.consideration[0].itemType,
            ItemType.ERC20
        );
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
