// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Account, BaseOrderTest } from "./BaseOrderTest.sol";
import { ValidationOffererZone } from "./zones/ValidationOffererZone.sol";
import "seaport-sol/SeaportSol.sol";

contract SelfRestrictedTest is BaseOrderTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using AdvancedOrderLib for AdvancedOrder;
    using FulfillmentLib for Fulfillment;
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];

    ValidationOffererZone zone;

    struct ContextOverride {
        SeaportInterface seaport;
        bytes32 conduitKey;
        bool exactAmount;
        Account offerer;
    }

    function setUp() public virtual override {
        super.setUp();
    }

    function test(
        function(ContextOverride memory) external fn,
        ContextOverride memory context
    ) internal {
        try fn(context) {
            fail("Differential tests should revert with failure status");
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testSelfFulfillRestrictedNoConduitExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                exactAmount: true,
                offerer: offerer1
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: true,
                offerer: offerer1
            })
        );
    }

    function testSelfFulfillRestrictedWithConduitExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: conduitKey,
                exactAmount: true,
                offerer: offerer1
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: conduitKey,
                exactAmount: true,
                offerer: offerer1
            })
        );
    }

    function testSelfFulfillRestrictedNoConduitNotExactAmount420() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                exactAmount: false,
                offerer: offerer1
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: false,
                offerer: offerer1
            })
        );
    }

    function testSelfFulfillRestrictedWithConduitNotExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: conduitKey,
                exactAmount: false,
                offerer: offerer1
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: false,
                offerer: offerer1
            })
        );
    }

    function testSuite() public {
        for (uint256 i; i < 2; i++) {
            SeaportInterface _seaport = i == 0 ? seaport : referenceSeaport;
            for (uint256 j; j < 2; j++) {
                bytes32 _conduitKey = j == 0 ? conduitKey : bytes32(0);
                for (uint256 k; k < 2; k++) {
                    bool _exactAmount = k == 0 ? true : false;
                    for (uint256 m; m < 2; m++) {
                        Account memory _offerer = m == 0 ? offerer1 : offerer2;
                        test(
                            this.execSelfFulfillRestricted,
                            ContextOverride({
                                seaport: _seaport,
                                conduitKey: _conduitKey,
                                exactAmount: _exactAmount,
                                offerer: _offerer
                            })
                        );
                    }
                }
            }
        }
    }

    function testMultiOffer() public {
        test(
            this.execMultiOffer,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                exactAmount: false,
                offerer: offerer2
            })
        );
    }

    function setUpSelfFulfillRestricted(
        ContextOverride memory context
    )
        internal
        returns (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory resolvers,
            Fulfillment[] memory fulfillments
        )
    {
        erc721s[0].mint(offerer1.addr, 1);

        AdvancedOrder memory advancedOrder;
        AdvancedOrder memory advancedOrder2;

        uint256 considerAmount = 10;
        zone = new ValidationOffererZone(considerAmount + 1);

        uint256 matchAmount = context.exactAmount
            ? considerAmount
            : considerAmount + 1;

        advancedOrder = createOpenConsiderErc20(
            context,
            offerer1,
            considerAmount
        );
        advancedOrder2 = createRestrictedOfferErc20(context, matchAmount);

        fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib.fromDefault(FF_SF),
            FulfillmentLib.fromDefault(SF_FF)
        );
        orders = SeaportArrays.AdvancedOrders(advancedOrder, advancedOrder2);

        return (orders, resolvers, fulfillments);
    }

    function createOpenConsiderErc20(
        ContextOverride memory context,
        Account memory account,
        uint256 considerAmount
    ) internal view returns (AdvancedOrder memory advancedOrder) {
        // create the first order
        // offer: 1 ERC721
        // consider: 10 ERC20

        OfferItem[] memory offer = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_ERC721)
                .withToken(address(erc721s[0]))
                .withIdentifierOrCriteria(1)
        );
        ConsiderationItem[] memory consideration = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[0]))
                    .withRecipient(account.addr)
                    .withStartAmount(considerAmount)
                    .withEndAmount(considerAmount)
            );

        OrderComponents memory components = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(account.addr)
            .withOffer(offer)
            .withConsideration(consideration)
            .withCounter(context.seaport.getCounter(account.addr))
            .withConduitKey(context.conduitKey);

        bytes32 orderHash = seaport.getOrderHash(components);
        bytes memory signature = signOrder(
            context.seaport,
            account.key,
            orderHash
        );
        advancedOrder = AdvancedOrderLib
            .fromDefault(FULL)
            .withParameters(components.toOrderParameters())
            .withSignature(signature);
    }

    function createRestrictedOfferErc20(
        ContextOverride memory context,
        uint256 amount
    ) internal view returns (AdvancedOrder memory advancedOrder) {
        OfferItem[] memory offer = SeaportArrays.OfferItems(
            OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(amount)
                .withEndAmount(amount)
        );
        ConsiderationItem[] memory consideration = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withRecipient(context.offerer.addr)
                    .withIdentifierOrCriteria(1)
            );
        Account memory _offerer = context.offerer;
        OrderComponents memory components = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(_offerer.addr)
            .withOffer(offer)
            .withConsideration(consideration)
            .withCounter(context.seaport.getCounter(_offerer.addr))
            .withConduitKey(context.conduitKey)
            .withOrderType(OrderType.FULL_RESTRICTED)
            .withZone(address(zone));

        bytes32 orderHash = seaport.getOrderHash(components);
        bytes memory signature = signOrder(
            context.seaport,
            _offerer.key,
            orderHash
        );
        advancedOrder = AdvancedOrderLib
            .fromDefault(FULL)
            .withParameters(components.toOrderParameters())
            .withSignature(signature);
    }

    function setUpSelfFulfillRestrictedMultiOffer(
        ContextOverride memory context
    )
        internal
        returns (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory resolvers,
            Fulfillment[] memory fulfillments
        )
    {
        erc721s[0].mint(offerer1.addr, 1);

        AdvancedOrder memory advancedOrder;
        AdvancedOrder memory advancedOrder2;

        uint256 considerAmount = 10;
        zone = new ValidationOffererZone(considerAmount + 1);

        uint256 matchAmount = context.exactAmount
            ? considerAmount
            : considerAmount - 1;

        advancedOrder = createOpenConsiderErc20(
            context,
            offerer1,
            considerAmount
        );
        advancedOrder2 = createRestrictedOffersErc20(context, matchAmount);

        fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib.fromDefault(FF_SF),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponentLib
                        .empty()
                        .withOrderIndex(1)
                        .withItemIndex(0),
                    FulfillmentComponentLib
                        .empty()
                        .withOrderIndex(1)
                        .withItemIndex(1)
                ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponentLib.empty()
                )
            })
        );
        orders = SeaportArrays.AdvancedOrders(advancedOrder, advancedOrder2);

        return (orders, resolvers, fulfillments);
    }

    function execMultiOffer(ContextOverride memory context) external stateless {
        (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory resolvers,
            Fulfillment[] memory fulfillments
        ) = setUpSelfFulfillRestrictedMultiOffer(context);
        context.seaport.matchAdvancedOrders(
            orders,
            resolvers,
            fulfillments,
            address(0x1234)
        );
    }

    function createRestrictedOffersErc20(
        ContextOverride memory context,
        uint256 amountLessOne
    ) internal view returns (AdvancedOrder memory advancedOrder) {
        OfferItem[] memory offer = SeaportArrays.OfferItems(
            OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(amountLessOne)
                .withEndAmount(amountLessOne),
            OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(amountLessOne)
                .withEndAmount(amountLessOne)
        );
        ConsiderationItem[] memory consideration = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withRecipient(context.offerer.addr)
                    .withIdentifierOrCriteria(1)
            );
        Account memory _offerer = context.offerer;
        OrderComponents memory components = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(_offerer.addr)
            .withOffer(offer)
            .withConsideration(consideration)
            .withCounter(context.seaport.getCounter(_offerer.addr))
            .withConduitKey(context.conduitKey)
            .withOrderType(OrderType.FULL_RESTRICTED)
            .withZone(address(zone));

        bytes32 orderHash = seaport.getOrderHash(components);
        bytes memory signature = signOrder(
            context.seaport,
            _offerer.key,
            orderHash
        );
        advancedOrder = AdvancedOrderLib
            .fromDefault(FULL)
            .withParameters(components.toOrderParameters())
            .withSignature(signature);
    }

    function execSelfFulfillRestricted(
        ContextOverride memory context
    ) external stateless {
        (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory resolvers,
            Fulfillment[] memory fulfillments
        ) = setUpSelfFulfillRestricted(context);

        context.seaport.matchAdvancedOrders(
            orders,
            resolvers,
            fulfillments,
            address(0x1234)
        );
    }
}
