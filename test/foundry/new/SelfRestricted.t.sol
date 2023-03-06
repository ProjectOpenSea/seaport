// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
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

    ValidationOffererZone zone;

    struct ContextOverride {
        SeaportInterface seaport;
        bytes32 conduitKey;
        bool exactAmount;
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
                exactAmount: true
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: true
            })
        );
    }

    function testSelfFulfillRestrictedWithConduitExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: conduitKey,
                exactAmount: true
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: conduitKey,
                exactAmount: true
            })
        );
    }

    function testSelfFulfillRestrictedNoConduitNotExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                exactAmount: false
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: false
            })
        );
    }

    function testSelfFulfillRestrictedWithConduitNotExactAmount() public {
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: seaport,
                conduitKey: conduitKey,
                exactAmount: false
            })
        );
        test(
            this.execSelfFulfillRestricted,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                exactAmount: false
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
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;
        OrderComponents memory components;
        bytes32 orderHash;
        bytes memory signature;
        AdvancedOrder memory advancedOrder2;

        uint256 considerAmount = 10;
        zone = new ValidationOffererZone(considerAmount + 1);

        uint256 matchAmount = context.exactAmount
            ? considerAmount
            : considerAmount + 1;

        // create the first order
        // offer: 1 ERC721
        // consider: 10 ERC20
        {
            offer = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withIdentifierOrCriteria(1)
            );
            consideration = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[0]))
                    .withRecipient(offerer1.addr)
                    .withStartAmount(considerAmount)
                    .withEndAmount(considerAmount)
            );

            components = OrderComponentsLib
                .fromDefault(STANDARD)
                .withOfferer(offerer1.addr)
                .withOffer(offer)
                .withConsideration(consideration)
                .withCounter(context.seaport.getCounter(offerer1.addr))
                .withConduitKey(context.conduitKey);

            orderHash = seaport.getOrderHash(components);
            signature = signOrder(context.seaport, offerer1.key, orderHash);
            advancedOrder = AdvancedOrderLib
                .fromDefault(FULL)
                .withParameters(components.toOrderParameters())
                .withSignature(signature);
        }

        // create the second order
        // offer: 100 ERC20
        // consider: 1 ERC721
        {
            offer = SeaportArrays.OfferItems(
                OfferItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[0]))
                    .withStartAmount(matchAmount)
                    .withEndAmount(matchAmount)
            );
            consideration = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withRecipient(offerer1.addr)
                    .withIdentifierOrCriteria(1)
            );
            components = components
                .copy()
                .withOffer(offer)
                .withConsideration(consideration)
                .withOrderType(OrderType.FULL_RESTRICTED)
                .withZone(address(zone));
            // .withConduitKey(bytes32(0));

            orderHash = seaport.getOrderHash(components);
            signature = signOrder(context.seaport, offerer1.key, orderHash);
            advancedOrder2 = AdvancedOrderLib
                .fromDefault(FULL)
                .withParameters(components.toOrderParameters())
                .withSignature(signature);
        }

        fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib.fromDefault(FF_SF),
            FulfillmentLib.fromDefault(SF_FF)
        );
        orders = SeaportArrays.AdvancedOrders(advancedOrder, advancedOrder2);

        return (orders, resolvers, fulfillments);
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
            address(1234)
        );
    }
}
