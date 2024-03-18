// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    AdvancedOrdersSpace,
    ConsiderationItemSpace,
    OfferItemSpace,
    OrderComponentsSpace
} from "seaport-sol/src/StructSpace.sol";

import { AdvancedOrder, ItemType } from "seaport-sol/src/SeaportStructs.sol";

import {
    Amount,
    BasicOrderCategory,
    BroadOrderType,
    Caller,
    ConduitChoice,
    ContractOrderRebate,
    Criteria,
    EOASignature,
    ExtraData,
    FulfillmentRecipient,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    Tips,
    TokenIndex,
    UnavailableReason,
    Zone,
    ZoneHash
} from "seaport-sol/src/SpaceEnums.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

import {
    AdvancedOrdersSpaceGenerator,
    FuzzGeneratorContext,
    PRNGHelpers,
    TestConduit
} from "./helpers/FuzzGenerators.sol";

import { TestHelpers } from "./helpers/FuzzTestContextLib.sol";

import { EIP1271Offerer } from "../new/helpers/EIP1271Offerer.sol";

import {
    HashValidationZoneOfferer
} from "../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    HashCalldataContractOfferer
} from "../../../contracts/test/HashCalldataContractOfferer.sol";

import {
    DefaultFulfillmentGeneratorLib,
    FulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

contract FuzzGeneratorsTest is BaseOrderTest {
    using LibPRNG for LibPRNG.PRNG;
    using PRNGHelpers for FuzzGeneratorContext;

    /// @dev Note: the FuzzGeneratorContext must be a struct in *memory* in order
    ///      for the PRNG to work properly, so we can't declare it as a storage
    ///      variable in setUp. Instead, use this function to create a context.
    function createContext() internal returns (FuzzGeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        return
            FuzzGeneratorContext({
                vm: vm,
                testHelpers: TestHelpers(address(this)),
                prng: prng,
                timestamp: block.timestamp,
                seaport: getSeaport(),
                conduitController: getConduitController(),
                validatorZone: new HashValidationZoneOfferer(address(0)),
                contractOfferer: new HashCalldataContractOfferer(address(0)),
                eip1271Offerer: new EIP1271Offerer(),
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s,
                self: address(this),
                caller: address(this),
                alice: makeAccountWrapper("alice"),
                bob: makeAccountWrapper("bob"),
                carol: makeAccountWrapper("carol"),
                dillon: makeAccountWrapper("dillon"),
                eve: makeAccountWrapper("eve"),
                frank: makeAccountWrapper("frank"),
                starting721offerIndex: 1,
                starting721considerationIndex: 1,
                potential1155TokenIds: potential1155TokenIds,
                conduits: new TestConduit[](2),
                basicOrderCategory: BasicOrderCategory.NONE,
                basicOfferSpace: OfferItemSpace(
                    ItemType.NATIVE,
                    TokenIndex.ONE,
                    Criteria.MERKLE,
                    Amount.FIXED
                ),
                counter: 0,
                contractOffererNonce: 0
            });
    }

    // NOTE: empty order space is not supported for now
    function xtest_emptySpace() public {
        FuzzGeneratorContext memory context = createContext();
        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: new OrderComponentsSpace[](0),
            isMatchable: false,
            maximumFulfilled: 0,
            recipient: FulfillmentRecipient.ZERO,
            conduit: ConduitChoice.NONE,
            caller: Caller.TEST_CONTRACT,
            strategy: DefaultFulfillmentGeneratorLib
                .getDefaultFulfillmentStrategy()
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 0);
    }

    function test_emptyOfferConsideration() public {
        FuzzGeneratorContext memory context = createContext();
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
            eoaSignatureType: EOASignature.STANDARD,
            bulkSigHeight: 0,
            bulkSigIndex: 0,
            conduit: ConduitChoice.NONE,
            tips: Tips.NONE,
            unavailableReason: UnavailableReason.AVAILABLE,
            extraData: ExtraData.NONE,
            rebate: ContractOrderRebate.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false,
            maximumFulfilled: 1,
            recipient: FulfillmentRecipient.ZERO,
            conduit: ConduitChoice.NONE,
            caller: Caller.TEST_CONTRACT,
            strategy: DefaultFulfillmentGeneratorLib
                .getDefaultFulfillmentStrategy()
        });
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            context
        );
        assertEq(orders.length, 1);
        assertEq(orders[0].parameters.offer.length, 0);
        // Empty order groups have a consideration item inserted on some order
        assertEq(orders[0].parameters.consideration.length, 1);
    }

    function test_singleOffer_emptyConsideration() public {
        FuzzGeneratorContext memory context = createContext();
        OfferItemSpace[] memory offer = new OfferItemSpace[](1);
        offer[0] = OfferItemSpace({
            itemType: ItemType.ERC20,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.MERKLE,
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
            eoaSignatureType: EOASignature.STANDARD,
            bulkSigHeight: 0,
            bulkSigIndex: 0,
            conduit: ConduitChoice.NONE,
            tips: Tips.NONE,
            unavailableReason: UnavailableReason.AVAILABLE,
            extraData: ExtraData.NONE,
            rebate: ContractOrderRebate.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false,
            maximumFulfilled: 1,
            recipient: FulfillmentRecipient.ZERO,
            conduit: ConduitChoice.NONE,
            caller: Caller.TEST_CONTRACT,
            strategy: DefaultFulfillmentGeneratorLib
                .getDefaultFulfillmentStrategy()
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

        // Empty order groups have a consideration item inserted on some order
        assertEq(orders[0].parameters.consideration.length, 1);
    }

    function test_emptyOffer_singleConsideration() public {
        FuzzGeneratorContext memory context = createContext();
        OfferItemSpace[] memory offer = new OfferItemSpace[](0);
        ConsiderationItemSpace[]
            memory consideration = new ConsiderationItemSpace[](1);
        consideration[0] = ConsiderationItemSpace({
            itemType: ItemType.ERC20,
            tokenIndex: TokenIndex.ONE,
            criteria: Criteria.MERKLE,
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
            eoaSignatureType: EOASignature.STANDARD,
            bulkSigHeight: 0,
            bulkSigIndex: 0,
            conduit: ConduitChoice.NONE,
            tips: Tips.NONE,
            unavailableReason: UnavailableReason.AVAILABLE,
            extraData: ExtraData.NONE,
            rebate: ContractOrderRebate.NONE
        });

        OrderComponentsSpace[] memory components = new OrderComponentsSpace[](
            1
        );
        components[0] = component;

        AdvancedOrdersSpace memory space = AdvancedOrdersSpace({
            orders: components,
            isMatchable: false,
            maximumFulfilled: 1,
            recipient: FulfillmentRecipient.ZERO,
            conduit: ConduitChoice.NONE,
            caller: Caller.TEST_CONTRACT,
            strategy: DefaultFulfillmentGeneratorLib
                .getDefaultFulfillmentStrategy()
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
            orders[0].parameters.offerer
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
