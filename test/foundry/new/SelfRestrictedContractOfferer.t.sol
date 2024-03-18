// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    ConsiderationItem,
    Fulfillment,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    CriteriaResolver,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib,
    SeaportArrays
} from "seaport-sol/src/SeaportSol.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

import { ValidationOffererZone } from "./zones/ValidationOffererZone.sol";

import {
    ERC20Interface,
    ERC721Interface
} from "seaport-types/src/interfaces/AbridgedTokenInterfaces.sol";

contract SelfRestrictedContractOffererTest is BaseOrderTest {
    using AdvancedOrderLib for AdvancedOrder;
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    ValidationOffererZone offerer;

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

    function testSelfFulfillRestrictedNoConduitExactAmount69() public {
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
        AdvancedOrder memory advancedOrder;
        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration;
        OrderComponents memory components;
        bytes32 orderHash;
        bytes memory signature;
        AdvancedOrder memory advancedOrder2;

        uint256 considerAmount = 10;
        offerer = new ValidationOffererZone(considerAmount + 1);

        erc721s[0].mint(address(offerer), 1);

        allocateTokensAndApprovals(address(offerer), type(uint128).max);

        uint256 matchAmount = context.exactAmount
            ? considerAmount
            : considerAmount + 1;

        // create the first order
        // offer: 1 ERC721
        // consider: 10 ERC20
        {
            consideration = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withIdentifierOrCriteria(1)
                    .withRecipient(address(offerer))
            );
            offer = SeaportArrays.OfferItems(
                OfferItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[0]))
                    .withStartAmount(matchAmount)
                    .withEndAmount(matchAmount)
            );

            components = OrderComponentsLib
                .fromDefault(STANDARD)
                .withOfferer(address(offerer))
                .withOffer(offer)
                .withConsideration(consideration)
                .withOrderType(OrderType.CONTRACT);

            // orderHash = seaport.getOrderHash(components);
            // signature = signOrder(context.seaport, offerer1.key, orderHash);
            advancedOrder = AdvancedOrderLib.fromDefault(FULL).withParameters(
                components.toOrderParameters()
            );
        }

        // create the second order
        // offer: 100 ERC20
        // consider: 1 ERC721
        {
            consideration = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[0]))
                    .withStartAmount(considerAmount)
                    .withEndAmount(considerAmount)
                    .withRecipient(address(offerer))
            );
            offer = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_ERC721)
                    .withToken(address(erc721s[0]))
                    .withIdentifierOrCriteria(1)
            );
            components = components
                .copy()
                .withOffer(offer)
                .withConsideration(consideration)
                .withOrderType(OrderType.FULL_OPEN)
                .withCounter(context.seaport.getCounter(address(offerer))); //.withZone(address(zone))
            // .withConduitKey(bytes32(0));

            orderHash = seaport.getOrderHash(components);
            Order memory order = Order({
                parameters: components.toOrderParameters(),
                signature: ""
            });
            vm.prank(address(offerer));
            context.seaport.incrementCounter();
            vm.prank(address(offerer));
            context.seaport.validate(SeaportArrays.Orders(order));

            advancedOrder2 = AdvancedOrderLib
                .fromDefault(FULL)
                .withParameters(components.toOrderParameters())
                .withSignature(signature);
        }

        fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib.fromDefault(FF_SF),
            FulfillmentLib.fromDefault(SF_FF)
        );
        orders = SeaportArrays.AdvancedOrders(advancedOrder2, advancedOrder);

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
            address(this)
        );
    }
}
