// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
    ItemType,
    OfferItem,
    Order,
    OrderComponents,
    OrderType
} from "../../../contracts/lib/ConsiderationStructs.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import {
    ConsiderationItemLib,
    FulfillmentComponentLib,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    SeaportArrays
} from "../../../contracts/helpers/sol/lib/SeaportStructLib.sol";

import {
    TestTransferValidationZoneOfferer
} from "../../../contracts/test/TestTransferValidationZoneOfferer.sol";

import { FulfillmentHelper } from "seaport-sol/FulfillmentHelper.sol";

import { MatchFulfillmentHelper } from "seaport-sol/MatchFulfillmentHelper.sol";

import { TestZone } from "./impl/TestZone.sol";

contract TestTransferValidationZoneOffererTest is BaseOrderTest {
    using FulfillmentLib for Fulfillment;
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderLib for Order[];

    TestTransferValidationZoneOfferer zone;

    // constant strings for recalling struct lib defaults
    // ideally these live in a base test class
    string constant ONE_ETH = "one eth";
    string constant THREE_ERC20 = "three erc20";
    string constant SINGLE_721 = "single 721";
    string constant VALIDATION_ZONE = "validation zone";
    string constant CONTRACT_ORDER = "contract order";

    function setUp() public virtual override {
        super.setUp();
        zone = new TestTransferValidationZoneOfferer(address(0));

        // create a default considerationItem for one ether;
        // note that it does not have recipient set
        ConsiderationItemLib
        .empty()
        .withItemType(ItemType.NATIVE)
        .withToken(address(0)) // not strictly necessary
            .withStartAmount(1 ether)
            .withEndAmount(1 ether)
            .withIdentifierOrCriteria(0)
            .saveDefault(ONE_ETH); // not strictly necessary

        // create a default offerItem for one ether;
        // note that it does not have recipient set
        OfferItemLib
        .empty()
        .withItemType(ItemType.NATIVE)
        .withToken(address(0)) // not strictly necessary
            .withStartAmount(1 ether)
            .withEndAmount(1 ether)
            .withIdentifierOrCriteria(0)
            .saveDefault(ONE_ETH); // not strictly necessary

        // create a default consideration for a single 721;
        // note that it does not have recipient, token or
        // identifier set
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .saveDefault(SINGLE_721);

        // create a default considerationItem for three erc20;
        // note that it does not have recipient set
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withStartAmount(3 ether)
            .withEndAmount(3 ether)
            .withIdentifierOrCriteria(0)
            .saveDefault(THREE_ERC20); // not strictly necessary

        // create a default offerItem for a single 721;
        // note that it does not have token or identifier set
        OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .saveDefault(SINGLE_721);

        OrderComponentsLib
        .empty()
        .withOfferer(offerer1.addr)
        .withZone(address(zone))
        // fill in offer later
        // fill in consideration later
        .withOrderType(OrderType.FULL_RESTRICTED)
        .withStartTime(block.timestamp)
        .withEndTime(block.timestamp + 1)
        .withZoneHash(bytes32(0)) // not strictly necessary
            .withSalt(0)
            .withConduitKey(conduitKeyOne)
            .saveDefault(VALIDATION_ZONE);
        // fill in counter later

        // create a default orderComponents for a contract order
        OrderComponentsLib
        .empty()
        .withOrderType(OrderType.CONTRACT)
        .withStartTime(block.timestamp)
        .withEndTime(block.timestamp + 1)
        .withZoneHash(bytes32(0)) // not strictly necessary
            .withSalt(0)
            .withConduitKey(conduitKeyOne)
            .saveDefault(CONTRACT_ORDER);
    }

    struct Context {
        ConsiderationInterface seaport;
        FulfillFuzzInputs fulfillArgs;
        MatchFuzzInputs matchArgs;
    }

    struct FulfillFuzzInputs {
        uint256 tokenId;
        uint128 amount;
        uint128 excessNativeTokens;
        uint256 orderCount;
        uint256 considerationItemsPerOrderCount;
        uint256 maximumFulfilledCount;
        address offerRecipient;
        address considerationRecipient;
        bytes32 zoneHash;
        uint256 salt;
        bool shouldAggregateFulfillmentComponents;
        bool shouldUseConduit;
        bool shouldUseTransferValidationZone;
        bool shouldIncludeNativeConsideration;
        bool shouldIncludeExcessOfferItems;
        bool shouldSpecifyRecipient;
        bool shouldIncludeJunkDataInAdvancedOrder;
    }

    struct MatchFuzzInputs {
        uint256 tokenId;
        uint128 amount;
        uint128 excessNativeTokens;
        uint256 orderPairCount;
        uint256 considerationItemsPerPrimeOrderCount;
        // This is currently used only as the unspent prime offer item recipient
        // but would also set the recipient for unspent mirror offer items if
        // any were added in the test in the future.
        address unspentPrimeOfferItemRecipient;
        string primeOfferer;
        string mirrorOfferer;
        bytes32 zoneHash;
        uint256 salt;
        bool shouldUseConduit;
        bool shouldUseTransferValidationZoneForPrime;
        bool shouldUseTransferValidationZoneForMirror;
        bool shouldIncludeNativeConsideration;
        bool shouldIncludeExcessOfferItems;
        bool shouldSpecifyUnspentOfferItemRecipient;
        bool shouldIncludeJunkDataInAdvancedOrder;
    }

    FulfillFuzzInputs emptyFulfill;
    MatchFuzzInputs emptyMatch;

    Account fuzzPrimeOfferer;
    Account fuzzMirrorOfferer;

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {
            fail("Expected revert");
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testExecFulfillAvailableAdvancedOrdersWithConduitAndERC20()
        public
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20();
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20()
        internal
    {
        test721_1.mint(offerer1.addr, 42);
        test721_1.mint(offerer1.addr, 43);
    }

    function execFulfillAvailableAdvancedOrdersWithConduitAndERC20(
        Context memory context
    ) external stateless {
        // Set up an NFT recipient.
        address considerationRecipientAddress = makeAddr(
            "considerationRecipientAddress"
        );

        // This instance of the zone expects bob to be the recipient of all
        // spent items (the ERC721s).
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(bob)
            );

        // Set up variables we'll use below the following block.
        OrderComponents memory orderComponentsOne;
        OrderComponents memory orderComponentsTwo;
        AdvancedOrder[] memory advancedOrders;

        // Create a block to deal with stack depth issues.
        {
            // Create the offer items for the first order.
            OfferItem[] memory offerItemsOne = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(42)
            );

            // Create the consideration items for the first order.
            ConsiderationItem[] memory considerationItemsOne = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withRecipient(considerationRecipientAddress)
                );

            // Create the order components for the first order.
            orderComponentsOne = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsOne)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the offer items for the second order.
            OfferItem[] memory offerItemsTwo = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(43)
            );

            // Create the order components for the second order using the same
            // consideration items as the first order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsTwo)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the orders.
            Order[] memory orders = _buildOrders(
                context,
                SeaportArrays.OrderComponentsArray(
                    orderComponentsOne,
                    orderComponentsTwo
                ),
                offerer1.key
            );

            // Convert the orders to advanced orders.
            advancedOrders = SeaportArrays.AdvancedOrders(
                orders[0].toAdvancedOrder(1, 1, ""),
                orders[1].toAdvancedOrder(1, 1, "")
            );
        }

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // Expect this to revert because the zone is set up to expect bob to be
        // the recipient of all spent items.
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidOwner(address,address,address,uint256)",
                address(bob),
                address(this),
                address(test721_1),
                42
            )
        );
        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: address(this),
            maximumFulfilled: 2
        });

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: address(bob),
            maximumFulfilled: 2
        });

        assertTrue(transferValidationZone.called());
        assertTrue(transferValidationZone.callCount() == 2);
    }

    function testExecFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast()
        public
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast();
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast()
        internal
    {
        test721_1.mint(offerer1.addr, 42);
        test721_1.mint(offerer1.addr, 43);
    }

    function execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast(
        Context memory context
    ) external stateless {
        // Set up an NFT recipient.
        address considerationRecipientAddress = makeAddr(
            "considerationRecipientAddress"
        );

        // This instance of the zone expects bob to be the recipient of all
        // spent items (the ERC721s).
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(0)
            );

        // Set up variables we'll use below the following block.
        OrderComponents memory orderComponentsOne;
        OrderComponents memory orderComponentsTwo;
        AdvancedOrder[] memory advancedOrders;

        // Create a block to deal with stack depth issues.
        {
            // Create the offer items for the first order.
            OfferItem[] memory offerItemsOne = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(42)
            );

            // Create the consideration items for the first order.
            ConsiderationItem[] memory considerationItemsOne = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withRecipient(considerationRecipientAddress),
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withStartAmount(5 ether)
                        .withEndAmount(5 ether)
                        .withRecipient(considerationRecipientAddress)
                );

            // Create the order components for the first order.
            orderComponentsOne = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsOne)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the offer items for the second order.
            OfferItem[] memory offerItemsTwo = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(43)
            );

            // Create the consideration items for the second order.
            ConsiderationItem[] memory considerationItemsTwo = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withStartAmount(7 ether)
                        .withEndAmount(7 ether)
                        .withRecipient(considerationRecipientAddress),
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withStartAmount(9 ether)
                        .withEndAmount(9 ether)
                        .withRecipient(considerationRecipientAddress)
                );

            // Create the order components for the second order using the same
            // consideration items as the first order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsTwo)
                .withConsideration(considerationItemsTwo)
                .withZone(address(transferValidationZone));

            // Create the orders.
            Order[] memory orders = _buildOrders(
                context,
                SeaportArrays.OrderComponentsArray(
                    orderComponentsOne,
                    orderComponentsTwo
                ),
                offerer1.key
            );

            // Convert the orders to advanced orders.
            advancedOrders = SeaportArrays.AdvancedOrders(
                orders[0].toAdvancedOrder(1, 1, ""),
                orders[1].toAdvancedOrder(1, 1, "")
            );
        }

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: address(0),
            maximumFulfilled: advancedOrders.length - 1
        });
    }

    function testExecFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision()
        public
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision();
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision()
        internal
    {
        test721_1.mint(offerer1.addr, 42);
        test721_1.mint(offerer1.addr, 43);
    }

    function execFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision(
        Context memory context
    ) external stateless {
        string memory stranger = "stranger";
        address strangerAddress = makeAddr(stranger);
        uint256 strangerAddressUint = uint256(
            uint160(address(strangerAddress))
        );

        // Make sure the fulfiller has enough to cover the consideration.
        token1.mint(address(this), strangerAddressUint);

        // Make the stranger rich enough that the balance check passes.
        token1.mint(strangerAddress, strangerAddressUint);

        // This instance of the zone expects offerer1 to be the recipient of all
        // spent items (the ERC721s). This permits bypassing the ERC721 transfer
        // checks, which would otherwise block the consideration transfer
        // checks, which is the target to tinker with.
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(offerer1.addr)
            );

        // Set up variables we'll use below the following block.
        OrderComponents memory orderComponentsOne;
        OrderComponents memory orderComponentsTwo;
        AdvancedOrder[] memory advancedOrders;

        // Create a block to deal with stack depth issues.
        {
            // Create the offer items for the first order.
            OfferItem[] memory offerItemsOne = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(42)
            );

            // Create the consideration items for the first order.
            ConsiderationItem[] memory considerationItemsOne = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withStartAmount(strangerAddressUint)
                        .withEndAmount(strangerAddressUint)
                        .withRecipient(payable(offerer1.addr))
                );

            // Create the order components for the first order.
            orderComponentsOne = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsOne)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the offer items for the second order.
            OfferItem[] memory offerItemsTwo = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(43)
            );

            // Create the order components for the second order using the same
            // consideration items as the first order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsTwo)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the orders.
            Order[] memory orders = _buildOrders(
                context,
                SeaportArrays.OrderComponentsArray(
                    orderComponentsOne,
                    orderComponentsTwo
                ),
                offerer1.key
            );

            // Convert the orders to advanced orders.
            advancedOrders = SeaportArrays.AdvancedOrders(
                orders[0].toAdvancedOrder(1, 1, ""),
                orders[1].toAdvancedOrder(1, 1, "")
            );
        }

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: address(offerer1.addr),
            maximumFulfilled: advancedOrders.length - 1
        });

        assertTrue(transferValidationZone.callCount() == 1);
    }

    function testExecFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple()
        public
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple();
        test(
            this
                .execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this
                .execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple()
        internal
    {
        test721_1.mint(offerer1.addr, 42);
        test721_1.mint(offerer1.addr, 43);
        test721_1.mint(offerer1.addr, 44);
    }

    function execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple(
        Context memory context
    ) external stateless {
        // The idea here is to fulfill one, skinny through a second using the
        // collision trick, and then see what happens on the third.

        string memory stranger = "stranger";
        address strangerAddress = makeAddr(stranger);
        uint256 strangerAddressUint = uint256(
            uint160(address(strangerAddress))
        );

        // Make sure the fulfiller has enough to cover the consideration.
        token1.mint(address(this), strangerAddressUint * 3);

        // Make the stranger rich enough that the balance check passes.
        token1.mint(strangerAddress, strangerAddressUint);

        // This instance of the zone expects offerer1 to be the recipient of all
        // spent items (the ERC721s). This permits bypassing the ERC721 transfer
        // checks, which would otherwise block the consideration transfer
        // checks, which the the target to tinker with.
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(offerer1.addr)
            );

        // Set up variables we'll use below the following block.
        OrderComponents memory orderComponentsOne;
        OrderComponents memory orderComponentsTwo;
        OrderComponents memory orderComponentsThree;
        AdvancedOrder[] memory advancedOrders;
        OfferItem[] memory offerItems;
        ConsiderationItem[] memory considerationItems;

        // Create a block to deal with stack depth issues.
        {
            // Create the offer items for the first order.
            offerItems = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(42)
            );

            // Create the consideration items for the first order.
            considerationItems = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(THREE_ERC20)
                    .withToken(address(token1))
                    .withStartAmount(1 ether)
                    .withEndAmount(1 ether)
                    .withRecipient(payable(offerer1.addr))
            );

            // Create the order components for the first order.
            orderComponentsOne = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItems)
                .withConsideration(considerationItems)
                .withZone(address(transferValidationZone));

            // Create the offer items for the second order.
            offerItems = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(43)
            );

            // Create the consideration items for the first order.
            considerationItems = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(THREE_ERC20)
                    .withToken(address(token1))
                    .withStartAmount(strangerAddressUint)
                    .withEndAmount(strangerAddressUint)
                    .withRecipient(payable(offerer1.addr))
            );

            // Create the order components for the second order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItems)
                .withConsideration(considerationItems)
                .withZone(address(transferValidationZone));

            // Create the offer items for the third order.
            offerItems = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(44)
            );

            // Create the consideration items for the third order.
            considerationItems = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(THREE_ERC20)
                    .withToken(address(token1))
                    .withStartAmount(3 ether)
                    .withEndAmount(3 ether)
                    .withRecipient(payable(offerer1.addr)) // Not necessary, but explicit
            );

            // Create the order components for the third order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItems)
                .withConsideration(considerationItems)
                .withZone(address(transferValidationZone));

            // Create the orders.
            Order[] memory orders = _buildOrders(
                context,
                SeaportArrays.OrderComponentsArray(
                    orderComponentsOne,
                    orderComponentsTwo,
                    orderComponentsThree
                ),
                offerer1.key
            );

            // Convert the orders to advanced orders.
            advancedOrders = SeaportArrays.AdvancedOrders(
                orders[0].toAdvancedOrder(1, 1, ""),
                orders[1].toAdvancedOrder(1, 1, ""),
                orders[2].toAdvancedOrder(1, 1, "")
            );
        }

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // Should not revert.
        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: offerer1.addr,
            maximumFulfilled: advancedOrders.length - 2
        });
    }

    function testFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20()
        internal
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20();

        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function prepareFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20()
        internal
    {
        test721_1.mint(offerer1.addr, 42);
        test721_1.mint(offerer1.addr, 43);
    }

    function execFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20(
        Context memory context
    ) external stateless {
        // Set up an NFT recipient.
        address considerationRecipientAddress = makeAddr(
            "considerationRecipientAddress"
        );

        // This instance of the zone expects the fulfiller to be the recipient
        // recipient of all spent items.
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(0)
            );

        // Set up variables we'll use below the following block.
        OrderComponents memory orderComponentsOne;
        OrderComponents memory orderComponentsTwo;
        AdvancedOrder[] memory advancedOrders;

        // Create a block to deal with stack depth issues.
        {
            // Create the offer items for the first order.
            OfferItem[] memory offerItemsOne = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(42)
            );

            // Create the consideration items for the first order.
            ConsiderationItem[] memory considerationItemsOne = SeaportArrays
                .ConsiderationItems(
                    ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                        considerationRecipientAddress
                    ),
                    ConsiderationItemLib
                        .fromDefault(THREE_ERC20)
                        .withToken(address(token1))
                        .withRecipient(considerationRecipientAddress)
                );

            // Create the order components for the first order.
            orderComponentsOne = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsOne)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the offer items for the second order.
            OfferItem[] memory offerItemsTwo = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(43)
            );

            // Create the order components for the second order.
            orderComponentsTwo = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(offerItemsTwo)
                .withConsideration(considerationItemsOne)
                .withZone(address(transferValidationZone));

            // Create the orders.
            Order[] memory orders = _buildOrders(
                context,
                SeaportArrays.OrderComponentsArray(
                    orderComponentsOne,
                    orderComponentsTwo
                ),
                offerer1.key
            );

            // Convert the orders to advanced orders.
            advancedOrders = SeaportArrays.AdvancedOrders(
                orders[0].toAdvancedOrder(1, 1, ""),
                orders[1].toAdvancedOrder(1, 1, "")
            );
        }

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders{ value: 3 ether }({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKeyOne),
            recipient: address(0),
            maximumFulfilled: 2
        });
    }

    function testAggregate() public {
        prepareAggregate();

        test(
            this.execAggregate,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execAggregate,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    ///@dev prepare aggregate test by minting tokens to offerer1
    function prepareAggregate() internal {
        test721_1.mint(offerer1.addr, 1);
        test721_2.mint(offerer1.addr, 1);
    }

    function execAggregate(Context memory context) external stateless {
        (
            Order[] memory orders,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            bytes32 conduitKey,
            uint256 numOrders
        ) = _buildFulfillmentData(context);

        context.seaport.fulfillAvailableOrders{ value: 2 ether }({
            orders: orders,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: conduitKey,
            maximumFulfilled: numOrders
        });
    }

    function testMatchContractOrdersWithConduit() public {
        test(
            this.execMatchContractOrdersWithConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchContractOrdersWithConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchContractOrdersWithConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorContractOrders(context);

        context.seaport.matchOrders{ value: 1 ether }({
            orders: orders,
            fulfillments: fulfillments
        });
    }

    function testExecMatchAdvancedContractOrdersWithConduit() public {
        test(
            this.execMatchAdvancedContractOrdersWithConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchAdvancedContractOrdersWithConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchAdvancedContractOrdersWithConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorContractOrders(context);

        AdvancedOrder[] memory advancedOrders;

        // Convert the orders to advanced orders.
        advancedOrders = SeaportArrays.AdvancedOrders(
            orders[0].toAdvancedOrder(1, 1, ""),
            orders[1].toAdvancedOrder(1, 1, "")
        );

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchAdvancedOrders{ value: 1 ether }(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    function testMatchOpenAndContractOrdersWithConduit() public {
        test(
            this.execMatchOpenAndContractOrdersWithConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchOpenAndContractOrdersWithConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchOpenAndContractOrdersWithConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataOpenOrderAndMirrorContractOrder(context);

        context.seaport.matchOrders{ value: 1 ether }({
            orders: orders,
            fulfillments: fulfillments
        });
    }

    function testMatchFullRestrictedOrdersNoConduit() public {
        test(
            this.execMatchFullRestrictedOrdersNoConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchFullRestrictedOrdersNoConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchFullRestrictedOrdersNoConduit(
        Context memory context
    ) external stateless {
        // set offerer2 as the expected offer recipient
        zone.setExpectedOfferRecipient(offerer2.addr);

        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorOrdersNoConduit(context);

        context.seaport.matchOrders{ value: 2 ether }({
            orders: orders,
            fulfillments: fulfillments
        });
    }

    function testMatchAdvancedFullRestrictedOrdersNoConduit() public {
        test(
            this.execMatchAdvancedFullRestrictedOrdersNoConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchAdvancedFullRestrictedOrdersNoConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchAdvancedFullRestrictedOrdersNoConduit(
        Context memory context
    ) external stateless {
        // set offerer2 as the expected offer recipient
        zone.setExpectedOfferRecipient(offerer2.addr);

        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorOrdersNoConduit(context);

        AdvancedOrder[] memory advancedOrders;

        // Convert the orders to advanced orders.
        advancedOrders = SeaportArrays.AdvancedOrders(
            orders[0].toAdvancedOrder(1, 1, ""),
            orders[1].toAdvancedOrder(1, 1, "")
        );

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchAdvancedOrders{ value: 1 ether }(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    function testExecMatchAdvancedMirrorContractOrdersWithConduitNoConduit()
        public
    {
        test(
            this.execMatchAdvancedMirrorContractOrdersWithConduitNoConduit,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchAdvancedMirrorContractOrdersWithConduitNoConduit,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchAdvancedMirrorContractOrdersWithConduitNoConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorContractOrdersWithConduitNoConduit(
                context
            );

        AdvancedOrder[] memory advancedOrders;

        // Convert the orders to advanced orders.
        advancedOrders = SeaportArrays.AdvancedOrders(
            orders[0].toAdvancedOrder(1, 1, ""),
            orders[1].toAdvancedOrder(1, 1, "")
        );

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchAdvancedOrders{ value: 1 ether }(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    function testExecMatchAdvancedMirrorOrdersRestrictedAndUnrestricted()
        public
    {
        test(
            this.execMatchAdvancedMirrorOrdersRestrictedAndUnrestricted,
            Context({
                seaport: consideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
        test(
            this.execMatchAdvancedMirrorOrdersRestrictedAndUnrestricted,
            Context({
                seaport: referenceConsideration,
                fulfillArgs: emptyFulfill,
                matchArgs: emptyMatch
            })
        );
    }

    function execMatchAdvancedMirrorOrdersRestrictedAndUnrestricted(
        Context memory context
    ) external stateless {
        // set offerer2 as the expected offer recipient
        zone.setExpectedOfferRecipient(offerer2.addr);

        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            ,

        ) = _buildFulfillmentDataMirrorOrdersRestrictedAndUnrestricted(context);

        AdvancedOrder[] memory advancedOrders;

        // Convert the orders to advanced orders.
        advancedOrders = SeaportArrays.AdvancedOrders(
            orders[0].toAdvancedOrder(1, 1, ""),
            orders[1].toAdvancedOrder(1, 1, "")
        );

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchAdvancedOrders{ value: 1 ether }(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    function testMatchAdvancedOrdersFuzz(
        MatchFuzzInputs memory matchArgs
    ) public {
        // Avoid weird overflow issues.
        matchArgs.amount = uint128(
            bound(matchArgs.amount, 1, 0xffffffffffffffff)
        );
        // Avoid trying to mint the same token.
        matchArgs.tokenId = bound(matchArgs.tokenId, 0xff, 0xffffffffffffffff);
        // Make 1-8 order pairs per call.  Each order pair will have 1-2 offer
        // items on the prime side (depending on whether
        // shouldIncludeExcessOfferItems is true or false).
        matchArgs.orderPairCount = bound(matchArgs.orderPairCount, 1, 8);
        // Use 1-3 (prime) consideration items per order.
        matchArgs.considerationItemsPerPrimeOrderCount = bound(
            matchArgs.considerationItemsPerPrimeOrderCount,
            1,
            3
        );
        // To put three items in the consideration, native tokens must be
        // included.
        matchArgs.shouldIncludeNativeConsideration =
            matchArgs.shouldIncludeNativeConsideration ||
            matchArgs.considerationItemsPerPrimeOrderCount >= 3;
        // Only include an excess offer item when NOT using the transfer
        // validation zone or the zone will revert.
        matchArgs.shouldIncludeExcessOfferItems =
            matchArgs.shouldIncludeExcessOfferItems &&
            !(matchArgs.shouldUseTransferValidationZoneForPrime ||
                matchArgs.shouldUseTransferValidationZoneForMirror);
        // Include some excess native tokens to check that they're ending up
        // with the caller afterward.
        matchArgs.excessNativeTokens = uint128(
            bound(
                matchArgs.excessNativeTokens,
                0,
                0xfffffffffffffffffffffffffffff
            )
        );
        // Don't set the offer recipient to the null address, because that's the
        // way to indicate that the caller should be the recipient.
        matchArgs.unspentPrimeOfferItemRecipient = address(
            uint160(
                bound(
                    uint160(matchArgs.unspentPrimeOfferItemRecipient),
                    1,
                    type(uint160).max
                )
            )
        );

        // TODO: REMOVE: I probably need to create an array of addresses with
        // dirty balances and an array of addresses that are contracts that
        // cause problems with native token transfers.

        test(
            this.execMatchAdvancedOrdersFuzz,
            Context(consideration, emptyFulfill, matchArgs)
        );
        test(
            this.execMatchAdvancedOrdersFuzz,
            Context(referenceConsideration, emptyFulfill, matchArgs)
        );
    }

    // Used for stack management.
    struct MatchAdvancedOrderInfra {
        Order[] orders;
        Fulfillment[] fulfillments;
        AdvancedOrder[] advancedOrders;
        CriteriaResolver[] criteriaResolvers;
        uint256 callerBalanceBefore;
        uint256 callerBalanceAfter;
        uint256 primeOffererBalanceBefore;
        uint256 primeOffererBalanceAfter;
    }

    function execMatchAdvancedOrdersFuzz(
        Context memory context
    ) external stateless {
        // Set up the infrastructure for this function in a struct to avoid
        // stack depth issues.
        MatchAdvancedOrderInfra memory infra = MatchAdvancedOrderInfra({
            orders: new Order[](context.matchArgs.orderPairCount),
            fulfillments: new Fulfillment[](context.matchArgs.orderPairCount),
            advancedOrders: new AdvancedOrder[](
                context.matchArgs.orderPairCount
            ),
            criteriaResolvers: new CriteriaResolver[](0),
            callerBalanceBefore: 0,
            callerBalanceAfter: 0,
            primeOffererBalanceBefore: 0,
            primeOffererBalanceAfter: 0
        });

        // TODO: (Someday) See if the stack can tolerate fuzzing criteria
        // resolvers.

        // The prime offerer is offering NFTs and considering ERC20/Native.
        fuzzPrimeOfferer = makeAndAllocateAccount(
            context.matchArgs.primeOfferer
        );
        // The mirror offerer is offering ERC20/Native and considering NFTs.
        fuzzMirrorOfferer = makeAndAllocateAccount(
            context.matchArgs.mirrorOfferer
        );

        // Set fuzzMirrorOfferer as the zone's expected offer recipient.
        zone.setExpectedOfferRecipient(fuzzMirrorOfferer.addr);

        // Create the orders and fulfuillments.
        (
            infra.orders,
            infra.fulfillments
        ) = _buildOrdersAndFulfillmentsMirrorOrdersFromFuzzArgs(context);

        // Set up the advanced orders array.
        infra.advancedOrders = new AdvancedOrder[](infra.orders.length);

        // Convert the orders to advanced orders.
        for (uint256 i = 0; i < infra.orders.length; i++) {
            infra.advancedOrders[i] = infra.orders[i].toAdvancedOrder(
                1,
                1,
                context.matchArgs.shouldIncludeJunkDataInAdvancedOrder
                    ? bytes(abi.encodePacked(context.matchArgs.salt))
                    : bytes("")
            );
        }

        // Set up event expectations.
        if (
            // If the fuzzPrimeOfferer and fuzzMirrorOfferer are the same
            // address, then the ERC20 transfers will be filtered.
            fuzzPrimeOfferer.addr != fuzzMirrorOfferer.addr
        ) {
            if (
                // When shouldIncludeNativeConsideration is false, there will be
                // exactly one token1 consideration item per orderPairCount. And
                // they'll all get aggregated into a single transfer.
                !context.matchArgs.shouldIncludeNativeConsideration
            ) {
                // This checks that the ERC20 transfers were all aggregated into
                // a single transfer.
                vm.expectEmit(true, true, true, true, address(token1));
                emit Transfer(
                    address(fuzzMirrorOfferer.addr), // from
                    address(fuzzPrimeOfferer.addr), // to
                    context.matchArgs.amount * context.matchArgs.orderPairCount
                );
            }

            if (
                // When considerationItemsPerPrimeOrderCount is 3, there will be
                // exactly one token2 consideration item per orderPairCount.
                // And they'll all get aggregated into a single transfer.
                context.matchArgs.considerationItemsPerPrimeOrderCount >= 3
            ) {
                vm.expectEmit(true, true, true, true, address(token2));
                emit Transfer(
                    address(fuzzMirrorOfferer.addr), // from
                    address(fuzzPrimeOfferer.addr), // to
                    context.matchArgs.amount * context.matchArgs.orderPairCount
                );
            }
        }

        // Store the native token balances before the call for later reference.
        infra.callerBalanceBefore = address(this).balance;
        infra.primeOffererBalanceBefore = address(fuzzPrimeOfferer.addr)
            .balance;

        // Make the call to Seaport.
        context.seaport.matchAdvancedOrders{
            value: (context.matchArgs.amount *
                context.matchArgs.orderPairCount) +
                context.matchArgs.excessNativeTokens
        }(
            infra.advancedOrders,
            infra.criteriaResolvers,
            infra.fulfillments,
            // If shouldSpecifyUnspentOfferItemRecipient is true, send the
            // unspent offer items to the recipient specified by the fuzz args.
            // Otherwise, pass in the zero address, which will result in the
            // unspent offer items being sent to the caller.
            context.matchArgs.shouldSpecifyUnspentOfferItemRecipient
                ? address(context.matchArgs.unspentPrimeOfferItemRecipient)
                : address(0)
        );

        // Note the native token balances after the call for later checks.
        infra.callerBalanceAfter = address(this).balance;
        infra.primeOffererBalanceAfter = address(fuzzPrimeOfferer.addr).balance;

        // The expected call count is the number of prime orders using the
        // transfer validation zone, plus the number of mirror orders using the
        // transfer validation zone.  So, expected call count can be 0,
        // context.matchArgs.orderPairCount, or context.matchArgs.orderPairCount
        // * 2.
        uint256 expectedCallCount = 0;
        if (context.matchArgs.shouldUseTransferValidationZoneForPrime) {
            expectedCallCount += context.matchArgs.orderPairCount;
        }
        if (context.matchArgs.shouldUseTransferValidationZoneForMirror) {
            expectedCallCount += context.matchArgs.orderPairCount;
        }
        assertTrue(zone.callCount() == expectedCallCount);

        // Check that the NFTs were transferred to the expected recipient.
        for (uint256 i = 0; i < context.matchArgs.orderPairCount; i++) {
            assertEq(
                test721_1.ownerOf(context.matchArgs.tokenId + i),
                fuzzMirrorOfferer.addr
            );
        }

        if (context.matchArgs.shouldIncludeExcessOfferItems) {
            // Check that the excess offer NFTs were transferred to the expected
            // recipient.
            for (uint256 i = 0; i < context.matchArgs.orderPairCount; i++) {
                assertEq(
                    test721_1.ownerOf((context.matchArgs.tokenId + i) * 2),
                    context.matchArgs.shouldSpecifyUnspentOfferItemRecipient
                        ? context.matchArgs.unspentPrimeOfferItemRecipient
                        : address(this)
                );
            }
        }

        if (context.matchArgs.shouldIncludeNativeConsideration) {
            // Check that ETH is moving from the caller to the prime offerer.
            // This also checks that excess native tokens are being swept back
            // to the caller.
            assertEq(
                infra.callerBalanceBefore -
                    context.matchArgs.amount *
                    context.matchArgs.orderPairCount,
                infra.callerBalanceAfter
            );
            assertEq(
                infra.primeOffererBalanceBefore +
                    context.matchArgs.amount *
                    context.matchArgs.orderPairCount,
                infra.primeOffererBalanceAfter
            );
        } else {
            assertEq(infra.callerBalanceBefore, infra.callerBalanceAfter);
        }
    }

    function testFulfillAvailableAdvancedFuzz(
        FulfillFuzzInputs memory fulfillArgs
    ) public {
        // Limit this value to avoid overflow issues.
        fulfillArgs.amount = uint128(
            bound(fulfillArgs.amount, 1, 0xffffffffffffffff)
        );
        // Limit this value to avoid overflow issues.
        fulfillArgs.tokenId = bound(fulfillArgs.tokenId, 1, 0xffffffffffffffff);
        // Create between 1 and 16 orders.
        fulfillArgs.orderCount = bound(fulfillArgs.orderCount, 1, 16);
        // Use between 1 and 3 consideration items per order.
        fulfillArgs.considerationItemsPerOrderCount = bound(
            fulfillArgs.considerationItemsPerOrderCount,
            1,
            3
        );
        // To put three items in the consideration, native tokens must be
        // included.
        fulfillArgs.shouldIncludeNativeConsideration =
            fulfillArgs.shouldIncludeNativeConsideration ||
            fulfillArgs.considerationItemsPerOrderCount >= 3;
        // TODO: (Someday) Think about excess offer items.
        // Fulfill between 1 and the orderCount.
        fulfillArgs.maximumFulfilledCount = bound(
            fulfillArgs.maximumFulfilledCount,
            1,
            fulfillArgs.orderCount
        );
        // Limit this value to avoid overflow issues.
        fulfillArgs.excessNativeTokens = uint128(
            bound(
                fulfillArgs.excessNativeTokens,
                0,
                0xfffffffffffffffffffffffffffff
            )
        );
        // Don't set the offer recipient to the null address, because that's the
        // way to indicate that the caller should be the recipient and because
        // some tokens refuse to transfer to the null address.
        fulfillArgs.offerRecipient = address(
            uint160(
                bound(uint160(fulfillArgs.offerRecipient), 1, type(uint160).max)
            )
        );
        // Don't set the consideration recipient to the null address, because
        // some tokens refuse to transfer to the null address.
        fulfillArgs.considerationRecipient = address(
            uint160(
                bound(
                    uint160(fulfillArgs.considerationRecipient),
                    1,
                    type(uint160).max
                )
            )
        );

        test(
            this.execFulfillAvailableAdvancedFuzz,
            Context(consideration, fulfillArgs, emptyMatch)
        );
        test(
            this.execFulfillAvailableAdvancedFuzz,
            Context(referenceConsideration, fulfillArgs, emptyMatch)
        );
    }

    function execFulfillAvailableAdvancedFuzz(
        Context memory context
    ) external stateless {
        // TODO: (Someday) See if the stack can tolerate fuzzing criteria
        // resolvers.

        // Use a conduit sometimes.
        bytes32 conduitKey = context.fulfillArgs.shouldUseConduit
            ? conduitKeyOne
            : bytes32(0);

        // Mint enough ERC721s to cover the number of NFTs for sale.
        for (uint256 i; i < context.fulfillArgs.orderCount; i++) {
            test721_1.mint(offerer1.addr, context.fulfillArgs.tokenId + i);
        }

        // Mint enough ERC20s to cover price per NFT * NFTs for sale.
        token1.mint(
            address(this),
            context.fulfillArgs.amount * context.fulfillArgs.orderCount
        );
        token2.mint(
            address(this),
            context.fulfillArgs.amount * context.fulfillArgs.orderCount
        );

        // Create the orders.
        AdvancedOrder[] memory advancedOrders = _buildOrdersFromFuzzArgs(
            context,
            offerer1.key
        );

        // Set up the fulfillment arrays.
        FulfillmentComponent[][] memory offerFulfillments;
        FulfillmentComponent[][] memory considerationFulfillments;

        // Create the fulfillments.
        if (context.fulfillArgs.shouldAggregateFulfillmentComponents) {
            (offerFulfillments, considerationFulfillments) = FulfillmentHelper
                .getAggregatedFulfillmentComponents(advancedOrders);
        } else {
            (offerFulfillments, considerationFulfillments) = FulfillmentHelper
                .getNaiveFulfillmentComponents(advancedOrders);
        }

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // If the fuzz args call for using the transfer validation zone, make
        // sure that it is actually enforcing the expected requirements.
        if (context.fulfillArgs.shouldUseTransferValidationZone) {
            address strangerAddress = address(0xdeafbeef);

            vm.expectRevert(
                abi.encodeWithSignature(
                    "InvalidOwner(address,address,address,uint256)",
                    // The expected recipient is either the offer recipient or
                    // the caller, depending on the fuzz args.
                    context.fulfillArgs.shouldSpecifyRecipient
                        ? context.fulfillArgs.offerRecipient
                        : address(this),
                    // The stranger address gets passed into the recipient field
                    // below, so it will be the actual recipient.
                    strangerAddress,
                    address(test721_1),
                    // Should revert on the first call.
                    context.fulfillArgs.tokenId
                )
            );
            // Make the call to Seaport.
            context.seaport.fulfillAvailableAdvancedOrders{
                value: context.fulfillArgs.excessNativeTokens +
                    (
                        context.fulfillArgs.shouldIncludeNativeConsideration
                            ? (context.fulfillArgs.amount *
                                context.fulfillArgs.maximumFulfilledCount)
                            : 0
                    )
            }({
                advancedOrders: advancedOrders,
                criteriaResolvers: criteriaResolvers,
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                fulfillerConduitKey: bytes32(conduitKey),
                recipient: strangerAddress,
                maximumFulfilled: context.fulfillArgs.maximumFulfilledCount
            });
        }

        if (!context.fulfillArgs.shouldIncludeNativeConsideration) {
            // This checks that the ERC20 transfers were not all aggregated
            // into a single transfer.
            vm.expectEmit(true, true, true, true, address(token1));
            emit Transfer(
                address(this), // from
                address(context.fulfillArgs.considerationRecipient), // to
                // The value should in the transfer event should either be
                // the amount * the number of NFTs for sale (if aggregating) or
                // the amount (if not aggregating).
                context.fulfillArgs.amount *
                    (
                        context.fulfillArgs.shouldAggregateFulfillmentComponents
                            ? context.fulfillArgs.maximumFulfilledCount
                            : 1
                    )
            );

            if (context.fulfillArgs.considerationItemsPerOrderCount >= 2) {
                // This checks that the second consideration item is being
                // properly handled.
                vm.expectEmit(true, true, true, true, address(token2));
                emit Transfer(
                    address(this), // from
                    address(context.fulfillArgs.considerationRecipient), // to
                    context.fulfillArgs.amount *
                        (
                            context
                                .fulfillArgs
                                .shouldAggregateFulfillmentComponents
                                ? context.fulfillArgs.maximumFulfilledCount
                                : 1
                        ) // value
                );
            }
        }

        // Store caller balance before the call for later comparison.
        uint256 callerBalanceBefore = address(this).balance;

        // Make the call to Seaport. When the fuzz args call for using native
        // consideration, send enough native tokens to cover the amount per sale
        // * the number of sales.  Otherwise, send just the excess native
        // tokens.
        context.seaport.fulfillAvailableAdvancedOrders{
            value: context.fulfillArgs.excessNativeTokens +
                (
                    context.fulfillArgs.shouldIncludeNativeConsideration
                        ? context.fulfillArgs.amount *
                            context.fulfillArgs.maximumFulfilledCount
                        : 0
                )
        }({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKey),
            // If the fuzz args call for specifying a recipient, pass in the
            // offer recipient.  Otherwise, pass in the null address, which
            // sets the caller as the recipient.
            recipient: context.fulfillArgs.shouldSpecifyRecipient
                ? context.fulfillArgs.offerRecipient
                : address(0),
            maximumFulfilled: context.fulfillArgs.maximumFulfilledCount
        });

        // Store caller balance after the call for later comparison.
        uint256 callerBalanceAfter = address(this).balance;

        // Check that the zone was called the expected number of times.
        if (context.fulfillArgs.shouldUseTransferValidationZone) {
            assertTrue(
                zone.callCount() == context.fulfillArgs.maximumFulfilledCount
            );
        }

        // Check that the NFTs were transferred to the expected recipient.
        for (
            uint256 i = 0;
            i < context.fulfillArgs.maximumFulfilledCount;
            i++
        ) {
            assertEq(
                test721_1.ownerOf(context.fulfillArgs.tokenId + i),
                context.fulfillArgs.shouldSpecifyRecipient
                    ? context.fulfillArgs.offerRecipient
                    : address(this)
            );
        }

        // TODO: REMOVE: Maybe just change these to balance checks to avoid the
        // headache of setting up a list of addresses with dirty balances.

        // Check that the ERC20s or native tokens were transferred to the
        // expected recipient according to the fuzz args.
        if (!context.fulfillArgs.shouldIncludeNativeConsideration) {
            assertEq(
                token1.balanceOf(context.fulfillArgs.considerationRecipient),
                context.fulfillArgs.amount *
                    context.fulfillArgs.maximumFulfilledCount
            );

            if (context.fulfillArgs.considerationItemsPerOrderCount >= 2) {
                assertEq(
                    token2.balanceOf(
                        context.fulfillArgs.considerationRecipient
                    ),
                    context.fulfillArgs.amount *
                        context.fulfillArgs.maximumFulfilledCount
                );
            }
        } else {
            assertEq(
                context.fulfillArgs.considerationRecipient.balance,
                context.fulfillArgs.amount *
                    context.fulfillArgs.maximumFulfilledCount
            );
            // Check that excess native tokens are being handled properly.  The
            // consideration (amount * maximumFulfilledCount) should be spent,
            // and the excessNativeTokens should be returned.
            assertEq(
                callerBalanceAfter +
                    context.fulfillArgs.amount *
                    context.fulfillArgs.maximumFulfilledCount,
                callerBalanceBefore
            );
        }
    }

    function _buildOrdersFromFuzzArgs(
        Context memory context,
        uint256 key
    ) internal returns (AdvancedOrder[] memory advancedOrders) {
        // Create the OrderComponents array from the fuzz args.
        OrderComponents[] memory orderComponents;
        orderComponents = _buildOrderComponentsArrayFromFuzzArgs(context);

        // Set up the AdvancedOrder array.
        AdvancedOrder[] memory _advancedOrders = new AdvancedOrder[](
            context.fulfillArgs.orderCount
        );

        // Iterate over the OrderComponents array and build an AdvancedOrder
        // for each OrderComponents.
        Order memory order;
        for (uint256 i = 0; i < orderComponents.length; i++) {
            if (orderComponents[i].orderType == OrderType.CONTRACT) {
                revert("Not implemented.");
            } else {
                // Create the order.
                order = _toOrder(context.seaport, orderComponents[i], key);
                // Convert it to an AdvancedOrder and add it to the array.
                _advancedOrders[i] = order.toAdvancedOrder(
                    1,
                    1,
                    // Reusing salt here for junk data.
                    context.fulfillArgs.shouldIncludeJunkDataInAdvancedOrder
                        ? bytes(abi.encodePacked(context.fulfillArgs.salt))
                        : bytes("")
                );
            }
        }

        return _advancedOrders;
    }

    // Used for stack management.
    struct OrderComponentInfra {
        OrderComponents orderComponents;
        OrderComponents[] orderComponentsArray;
        OfferItem[][] offerItemArray;
        ConsiderationItem[][] considerationItemArray;
        ConsiderationItem nativeConsiderationItem;
        ConsiderationItem erc20ConsiderationItemOne;
        ConsiderationItem erc20ConsiderationItemTwo;
    }

    function _buildOrderComponentsArrayFromFuzzArgs(
        Context memory context
    ) internal returns (OrderComponents[] memory _orderComponentsArray) {
        // Set up the OrderComponentInfra struct.
        OrderComponentInfra memory orderComponentInfra = OrderComponentInfra(
            OrderComponentsLib.empty(),
            new OrderComponents[](context.fulfillArgs.orderCount),
            new OfferItem[][](context.fulfillArgs.orderCount),
            new ConsiderationItem[][](context.fulfillArgs.orderCount),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty()
        );

        // Create three different consideration items.
        (
            orderComponentInfra.nativeConsiderationItem,
            orderComponentInfra.erc20ConsiderationItemOne,
            orderComponentInfra.erc20ConsiderationItemTwo
        ) = _createReusableConsiderationItems(
            context.fulfillArgs.amount,
            context.fulfillArgs.considerationRecipient
        );

        // Iterate once for each order and create the OfferItems[] and
        // ConsiderationItems[] for each order.
        for (uint256 i; i < context.fulfillArgs.orderCount; i++) {
            // Add a one-element OfferItems[] to the OfferItems[][].
            orderComponentInfra.offerItemArray[i] = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.fulfillArgs.tokenId + i)
            );

            if (context.fulfillArgs.considerationItemsPerOrderCount == 1) {
                // If the fuzz args call for native consideration...
                if (context.fulfillArgs.shouldIncludeNativeConsideration) {
                    // ...add a native consideration item...
                    orderComponentInfra.considerationItemArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem
                    );
                } else {
                    // ...otherwise, add an ERC20 consideration item.
                    orderComponentInfra.considerationItemArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.erc20ConsiderationItemOne
                    );
                }
            } else if (
                context.fulfillArgs.considerationItemsPerOrderCount == 2
            ) {
                // If the fuzz args call for native consideration...
                if (context.fulfillArgs.shouldIncludeNativeConsideration) {
                    // ...add a native consideration item and an ERC20
                    // consideration item...
                    orderComponentInfra.considerationItemArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem,
                        orderComponentInfra.erc20ConsiderationItemOne
                    );
                } else {
                    // ...otherwise, add two ERC20 consideration items.
                    orderComponentInfra.considerationItemArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.erc20ConsiderationItemOne,
                        orderComponentInfra.erc20ConsiderationItemTwo
                    );
                }
            } else {
                orderComponentInfra.considerationItemArray[i] = SeaportArrays
                    .ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem,
                        orderComponentInfra.erc20ConsiderationItemOne,
                        orderComponentInfra.erc20ConsiderationItemTwo
                    );
            }
        }

        // Use either the transfer validation zone or the test zone for all
        // orders.
        address fuzzyZone;
        TestZone testZone;

        if (context.fulfillArgs.shouldUseTransferValidationZone) {
            zone = new TestTransferValidationZoneOfferer(
                context.fulfillArgs.shouldSpecifyRecipient
                    ? context.fulfillArgs.offerRecipient
                    : address(this)
            );
            fuzzyZone = address(zone);
        } else {
            testZone = new TestZone();
            fuzzyZone = address(testZone);
        }

        bytes32 conduitKey;

        // Iterate once for each order and create the OrderComponents.
        for (uint256 i = 0; i < context.fulfillArgs.orderCount; i++) {
            // if context.fulfillArgs.shouldUseConduit is false: don't use conduits at all.
            // if context.fulfillArgs.shouldUseConduit is true:
            //      if context.fulfillArgs.tokenId % 2 == 0:
            //          use conduits for some and not for others
            //      if context.fulfillArgs.tokenId % 2 != 0:
            //          use conduits for all
            // This is plainly deranged, but it allows for conduit use
            // for all, for some, and none without weighing down the stack.
            conduitKey = !context
                .fulfillArgs
                .shouldIncludeNativeConsideration &&
                context.fulfillArgs.shouldUseConduit &&
                (context.fulfillArgs.tokenId % 2 == 0 ? i % 2 == 0 : true)
                ? conduitKeyOne
                : bytes32(0);

            // Build the order components.
            orderComponentInfra.orderComponents = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(orderComponentInfra.offerItemArray[i])
                .withConsideration(
                    orderComponentInfra.considerationItemArray[i]
                )
                .withZone(fuzzyZone)
                .withZoneHash(context.fulfillArgs.zoneHash)
                .withConduitKey(conduitKey)
                .withSalt(context.fulfillArgs.salt % (i + 1)); // Is this dumb?

            // Add the OrderComponents to the OrderComponents[].
            orderComponentInfra.orderComponentsArray[i] = orderComponentInfra
                .orderComponents;
        }

        // Return the OrderComponents[].
        return orderComponentInfra.orderComponentsArray;
    }

    ///@dev build multiple orders from the same offerer
    function _buildOrders(
        Context memory context,
        OrderComponents[] memory orderComponents,
        uint256 key
    ) internal view returns (Order[] memory) {
        Order[] memory orders = new Order[](orderComponents.length);
        for (uint256 i = 0; i < orderComponents.length; i++) {
            if (orderComponents[i].orderType == OrderType.CONTRACT)
                orders[i] = _toUnsignedOrder(orderComponents[i]);
            else orders[i] = _toOrder(context.seaport, orderComponents[i], key);
        }
        return orders;
    }

    function _buildFulfillmentData(
        Context memory context
    )
        internal
        returns (
            Order[] memory,
            FulfillmentComponent[][] memory,
            FulfillmentComponent[][] memory,
            bytes32,
            uint256
        )
    {
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    offerer1.addr
                )
            );
        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        // build first order components
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(context.seaport.getCounter(offerer1.addr));

        // second order components only differs by what is offered
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_2))
                .withIdentifierOrCriteria(1)
        );
        // technically there's no need to copy() since first order components is
        // not used again, but to encourage good practices, make a copy and
        // edit that
        OrderComponents memory orderComponents2 = orderComponents
            .copy()
            .withOffer(offerArray);

        Order[] memory orders = _buildOrders(
            context,
            SeaportArrays.OrderComponentsArray(
                orderComponents,
                orderComponents2
            ),
            offerer1.key
        );

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(orders);

        return (
            orders,
            offerFulfillments,
            considerationFulfillments,
            conduitKeyOne,
            2
        );
    }

    //@dev builds fulfillment data for a contract order from the
    //     TestTransferValidationZoneOfferer and its mirror order
    //     (one offerItem and one considerationItem)
    function _buildFulfillmentDataMirrorContractOrders(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // Create contract offerers
        TestTransferValidationZoneOfferer transferValidationOfferer1 = new TestTransferValidationZoneOfferer(
                address(0)
            );
        TestTransferValidationZoneOfferer transferValidationOfferer2 = new TestTransferValidationZoneOfferer(
                address(0)
            );

        transferValidationOfferer1.setExpectedOfferRecipient(
            address(transferValidationOfferer2)
        );
        transferValidationOfferer2.setExpectedOfferRecipient(
            address(transferValidationOfferer1)
        );

        vm.label(address(transferValidationOfferer1), "contractOfferer1");
        vm.label(address(transferValidationOfferer2), "contractOfferer2");

        // Mint 721 to contract offerer 1
        test721_1.mint(address(transferValidationOfferer1), 1);

        allocateTokensAndApprovals(
            address(transferValidationOfferer1),
            uint128(MAX_INT)
        );
        allocateTokensAndApprovals(
            address(transferValidationOfferer2),
            uint128(MAX_INT)
        );

        // Create one eth consideration for contract order 1
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    address(transferValidationOfferer1)
                )
            );
        // Create single 721 offer for contract order 1
        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        // Build first order components
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(CONTRACT_ORDER)
            .withOfferer(address(transferValidationOfferer1))
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(
                context.seaport.getCounter(address(transferValidationOfferer1))
            );

        // Second order components mirror first order components
        // Create one eth offer for contract order 2
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib.fromDefault(ONE_ETH)
        );

        // Create one 721 consideration for contract order 2
        considerationArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
                .withRecipient(address(transferValidationOfferer2))
        );
        // technically there's no need to copy() since first order components is
        // not used again, but to encourage good practices, make a copy and
        // edit that
        OrderComponents memory orderComponents2 = orderComponents
            .copy()
            .withOfferer(address(transferValidationOfferer2))
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(
                context.seaport.getCounter(address(transferValidationOfferer2))
            );

        Order[] memory orders = _buildOrders(
            context,
            SeaportArrays.OrderComponentsArray(
                orderComponents,
                orderComponents2
            ),
            offerer1.key
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orders);

        return (orders, fulfillments, conduitKeyOne, 2);
    }

    function _buildFulfillmentDataMirrorContractOrdersWithConduitNoConduit(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // Create contract offerers
        TestTransferValidationZoneOfferer transferValidationOfferer1 = new TestTransferValidationZoneOfferer(
                address(0)
            );
        TestTransferValidationZoneOfferer transferValidationOfferer2 = new TestTransferValidationZoneOfferer(
                address(0)
            );

        transferValidationOfferer1.setExpectedOfferRecipient(
            address(transferValidationOfferer2)
        );
        transferValidationOfferer2.setExpectedOfferRecipient(
            address(transferValidationOfferer1)
        );

        vm.label(address(transferValidationOfferer1), "contractOfferer1");
        vm.label(address(transferValidationOfferer2), "contractOfferer2");

        // Mint 721 to contract offerer 1
        test721_1.mint(address(transferValidationOfferer1), 1);

        allocateTokensAndApprovals(
            address(transferValidationOfferer1),
            uint128(MAX_INT)
        );
        allocateTokensAndApprovals(
            address(transferValidationOfferer2),
            uint128(MAX_INT)
        );

        // Create one eth consideration for contract order 1
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    address(transferValidationOfferer1)
                )
            );
        // Create single 721 offer for contract order 1
        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        // Build first order components
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(CONTRACT_ORDER)
            .withOfferer(address(transferValidationOfferer1))
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(
                context.seaport.getCounter(address(transferValidationOfferer1))
            );

        // Second order components mirror first order components
        // Create one eth offer for contract order 2
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib.fromDefault(ONE_ETH)
        );

        // Create one 721 consideration for contract order 2
        considerationArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
                .withRecipient(address(transferValidationOfferer2))
        );

        // copy first order components and set conduit key to 0
        OrderComponents memory orderComponents2 = orderComponents
            .copy()
            .withOfferer(address(transferValidationOfferer2))
            .withConduitKey(bytes32(0))
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(
                context.seaport.getCounter(address(transferValidationOfferer2))
            );

        Order[] memory orders = _buildOrders(
            context,
            SeaportArrays.OrderComponentsArray(
                orderComponents,
                orderComponents2
            ),
            offerer1.key
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orders);

        return (orders, fulfillments, conduitKeyOne, 2);
    }

    function _buildFulfillmentDataOpenOrderAndMirrorContractOrder(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // Create contract offerer
        TestTransferValidationZoneOfferer transferValidationOfferer1 = new TestTransferValidationZoneOfferer(
                offerer1.addr
            );

        vm.label(address(transferValidationOfferer1), "contractOfferer");

        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer(
                address(transferValidationOfferer1)
            );

        // Mint 721 to contract offerer 1
        test721_1.mint(address(transferValidationOfferer1), 1);

        allocateTokensAndApprovals(
            address(transferValidationOfferer1),
            uint128(MAX_INT)
        );

        // Create single 721 offer for contract order 1
        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        // Create one eth consideration for contract order 1
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    address(transferValidationOfferer1)
                )
            );

        // Build first order components
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(CONTRACT_ORDER)
            .withOfferer(address(transferValidationOfferer1))
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withCounter(
                context.seaport.getCounter(address(transferValidationOfferer1))
            );

        // Second order components mirror first order components
        // Create one eth offer for open order
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib.fromDefault(ONE_ETH)
        );

        // Create one 721 consideration for open order
        considerationArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
                .withRecipient(offerer1.addr)
        );

        OrderComponents memory orderComponents2 = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withZone(address(transferValidationZone))
            .withCounter(context.seaport.getCounter(offerer1.addr));

        Order[] memory orders = _buildOrders(
            context,
            SeaportArrays.OrderComponentsArray(
                orderComponents,
                orderComponents2
            ),
            offerer1.key
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orders);

        return (orders, fulfillments, conduitKeyOne, 2);
    }

    function _buildFulfillmentDataMirrorOrdersRestrictedAndUnrestricted(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // mint 721 to offerer 1
        test721_1.mint(offerer1.addr, 1);

        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    offerer1.addr
                )
            );

        // build first restricted order components, remove conduit key
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withConduitKey(bytes32(0))
            .withCounter(context.seaport.getCounter(offerer1.addr));

        // create mirror offer and consideration
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib.fromDefault(ONE_ETH)
        );

        considerationArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
                .withRecipient(offerer2.addr)
        );

        // build second unrestricted order components, remove zone
        OrderComponents memory orderComponents2 = orderComponents
            .copy()
            .withOrderType(OrderType.FULL_OPEN)
            .withOfferer(offerer2.addr)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withZone(address(0))
            .withCounter(context.seaport.getCounter(offerer2.addr));

        Order[] memory orders = new Order[](2);

        orders[0] = _toOrder(context.seaport, orderComponents, offerer1.key);
        orders[1] = _toOrder(context.seaport, orderComponents2, offerer2.key);

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orders);

        return (orders, fulfillments, bytes32(0), 2);
    }

    function _buildFulfillmentDataMirrorOrdersNoConduit(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // mint 721 to offerer 1
        test721_1.mint(offerer1.addr, 1);

        OfferItem[] memory offerArray = SeaportArrays.OfferItems(
            OfferItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
        );
        ConsiderationItem[] memory considerationArray = SeaportArrays
            .ConsiderationItems(
                ConsiderationItemLib.fromDefault(ONE_ETH).withRecipient(
                    offerer1.addr
                )
            );

        // build first order components, remove conduit key
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withConduitKey(bytes32(0))
            .withCounter(context.seaport.getCounter(offerer1.addr));

        // create mirror offer and consideration
        offerArray = SeaportArrays.OfferItems(
            OfferItemLib.fromDefault(ONE_ETH)
        );

        considerationArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(1)
                .withRecipient(offerer2.addr)
        );

        OrderComponents memory orderComponents2 = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOfferer(offerer2.addr)
            .withOffer(offerArray)
            .withConsideration(considerationArray)
            .withConduitKey(bytes32(0))
            .withCounter(context.seaport.getCounter(offerer2.addr));

        Order[] memory orders = new Order[](2);

        orders[0] = _toOrder(context.seaport, orderComponents, offerer1.key);
        orders[1] = _toOrder(context.seaport, orderComponents2, offerer2.key);

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orders);

        return (orders, fulfillments, bytes32(0), 2);
    }

    function _createReusableConsiderationItems(
        uint256 amount,
        address recipient
    )
        internal
        view
        returns (
            ConsiderationItem memory nativeConsiderationItem,
            ConsiderationItem memory erc20ConsiderationItemOne,
            ConsiderationItem memory erc20ConsiderationItemTwo
        )
    {
        // Create a reusable native consideration item.
        nativeConsiderationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withIdentifierOrCriteria(0)
            .withStartAmount(amount)
            .withEndAmount(amount)
            .withRecipient(recipient);

        // Create a reusable ERC20 consideration item.
        erc20ConsiderationItemOne = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(token1))
            .withIdentifierOrCriteria(0)
            .withStartAmount(amount)
            .withEndAmount(amount)
            .withRecipient(recipient);

        // Create a second reusable ERC20 consideration item.
        erc20ConsiderationItemTwo = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withIdentifierOrCriteria(0)
            .withToken(address(token2))
            .withStartAmount(amount)
            .withEndAmount(amount)
            .withRecipient(recipient);
    }

    function _buildPrimeOfferItemArray(
        Context memory context,
        uint256 i
    ) internal view returns (OfferItem[] memory _offerItemArray) {
        // Set up the OfferItem array.
        OfferItem[] memory offerItemArray = new OfferItem[](
            context.matchArgs.shouldIncludeExcessOfferItems ? 2 : 1
        );

        // If the fuzz args call for an excess offer item...
        if (context.matchArgs.shouldIncludeExcessOfferItems) {
            // Create the OfferItem array containing the offered item and the
            // excess item.
            offerItemArray = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.matchArgs.tokenId + i),
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(
                        (context.matchArgs.tokenId + i) * 2
                    )
            );
        } else {
            // Otherwise, create the OfferItem array containing the one offered
            // item.
            offerItemArray = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.matchArgs.tokenId + i)
            );
        }

        return offerItemArray;
    }

    function _buildPrimeConsiderationItemArray(
        Context memory context
    )
        internal
        view
        returns (ConsiderationItem[] memory _considerationItemArray)
    {
        // Set up the ConsiderationItem array.
        ConsiderationItem[]
            memory considerationItemArray = new ConsiderationItem[](
                context.matchArgs.considerationItemsPerPrimeOrderCount
            );

        // Create the consideration items.
        (
            ConsiderationItem memory nativeConsiderationItem,
            ConsiderationItem memory erc20ConsiderationItemOne,
            ConsiderationItem memory erc20ConsiderationItemTwo
        ) = _createReusableConsiderationItems(
                context.matchArgs.amount,
                fuzzPrimeOfferer.addr
            );

        if (context.matchArgs.considerationItemsPerPrimeOrderCount == 1) {
            // If the fuzz args call for native consideration...
            if (context.matchArgs.shouldIncludeNativeConsideration) {
                // ...add a native consideration item...
                considerationItemArray = SeaportArrays.ConsiderationItems(
                    nativeConsiderationItem
                );
            } else {
                // ...otherwise, add an ERC20 consideration item.
                considerationItemArray = SeaportArrays.ConsiderationItems(
                    erc20ConsiderationItemOne
                );
            }
        } else if (
            context.matchArgs.considerationItemsPerPrimeOrderCount == 2
        ) {
            // If the fuzz args call for native consideration...
            if (context.matchArgs.shouldIncludeNativeConsideration) {
                // ...add a native consideration item and an ERC20
                // consideration item...
                considerationItemArray = SeaportArrays.ConsiderationItems(
                    nativeConsiderationItem,
                    erc20ConsiderationItemOne
                );
            } else {
                // ...otherwise, add two ERC20 consideration items.
                considerationItemArray = SeaportArrays.ConsiderationItems(
                    erc20ConsiderationItemOne,
                    erc20ConsiderationItemTwo
                );
            }
        } else {
            // If the fuzz args call for three consideration items per prime
            // order, add all three consideration items.
            considerationItemArray = SeaportArrays.ConsiderationItems(
                nativeConsiderationItem,
                erc20ConsiderationItemOne,
                erc20ConsiderationItemTwo
            );
        }

        return considerationItemArray;
    }

    function _buildMirrorOfferItemArray(
        Context memory context
    ) internal view returns (OfferItem[] memory _offerItemArray) {
        // Set up the OfferItem array.
        OfferItem[] memory offerItemArray = new OfferItem[](1);

        // Create some consideration items.
        (
            ConsiderationItem memory nativeConsiderationItem,
            ConsiderationItem memory erc20ConsiderationItemOne,
            ConsiderationItem memory erc20ConsiderationItemTwo
        ) = _createReusableConsiderationItems(
                context.matchArgs.amount,
                fuzzPrimeOfferer.addr
            );

        // Convert them to OfferItems.
        OfferItem memory nativeOfferItem = _toOfferItem(
            nativeConsiderationItem
        );
        OfferItem memory erc20OfferItemOne = _toOfferItem(
            erc20ConsiderationItemOne
        );
        OfferItem memory erc20OfferItemTwo = _toOfferItem(
            erc20ConsiderationItemTwo
        );

        if (context.matchArgs.considerationItemsPerPrimeOrderCount == 1) {
            // If the fuzz args call for native consideration...
            if (context.matchArgs.shouldIncludeNativeConsideration) {
                // ...add a native consideration item...
                offerItemArray = SeaportArrays.OfferItems(nativeOfferItem);
            } else {
                // ...otherwise, add an ERC20 consideration item.
                offerItemArray = SeaportArrays.OfferItems(erc20OfferItemOne);
            }
        } else if (
            context.matchArgs.considerationItemsPerPrimeOrderCount == 2
        ) {
            // If the fuzz args call for native consideration...
            if (context.matchArgs.shouldIncludeNativeConsideration) {
                // ...add a native consideration item and an ERC20
                // consideration item...
                offerItemArray = SeaportArrays.OfferItems(
                    nativeOfferItem,
                    erc20OfferItemOne
                );
            } else {
                // ...otherwise, add two ERC20 consideration items.
                offerItemArray = SeaportArrays.OfferItems(
                    erc20OfferItemOne,
                    erc20OfferItemTwo
                );
            }
        } else {
            offerItemArray = SeaportArrays.OfferItems(
                nativeOfferItem,
                erc20OfferItemOne,
                erc20OfferItemTwo
            );
        }

        return offerItemArray;
    }

    function buildMirrorConsiderationItemArray(
        Context memory context,
        uint256 i
    )
        internal
        view
        returns (ConsiderationItem[] memory _considerationItemArray)
    {
        // Set up the ConsiderationItem array.
        ConsiderationItem[]
            memory considerationItemArray = new ConsiderationItem[](
                context.matchArgs.considerationItemsPerPrimeOrderCount
            );

        // Note that the consideration array here will always be just one NFT
        // so because the second NFT on the offer side is meant to be excess.
        considerationItemArray = SeaportArrays.ConsiderationItems(
            ConsiderationItemLib
                .fromDefault(SINGLE_721)
                .withToken(address(test721_1))
                .withIdentifierOrCriteria(context.matchArgs.tokenId + i)
                .withRecipient(fuzzMirrorOfferer.addr)
        );

        return considerationItemArray;
    }

    function _buildOrderComponents(
        Context memory context,
        OfferItem[] memory offerItemArray,
        ConsiderationItem[] memory considerationItemArray,
        address offerer,
        bool shouldUseTransferValidationZone
    ) internal view returns (OrderComponents memory _orderComponents) {
        OrderComponents memory orderComponents = OrderComponentsLib.empty();

        // Create the offer and consideration item arrays.
        OfferItem[] memory _offerItemArray = offerItemArray;
        ConsiderationItem[]
            memory _considerationItemArray = considerationItemArray;

        // Build the OrderComponents for the prime offerer's order.
        orderComponents = OrderComponentsLib
            .fromDefault(VALIDATION_ZONE)
            .withOffer(_offerItemArray)
            .withConsideration(_considerationItemArray)
            .withZone(address(0))
            .withOrderType(OrderType.FULL_OPEN)
            .withConduitKey(
                context.matchArgs.tokenId % 2 == 0 ? conduitKeyOne : bytes32(0)
            )
            .withOfferer(offerer)
            .withCounter(context.seaport.getCounter(offerer));

        // If the fuzz args call for a transfer validation zone...
        if (shouldUseTransferValidationZone) {
            // ... set the zone to the transfer validation zone and
            // set the order type to FULL_RESTRICTED.
            orderComponents = orderComponents
                .copy()
                .withZone(address(zone))
                .withOrderType(OrderType.FULL_RESTRICTED);
        }

        return orderComponents;
    }

    // Used for stack depth management.
    struct OrderAndFulfillmentInfra {
        OfferItem[] offerItemArray;
        ConsiderationItem[] considerationItemArray;
        OrderComponents orderComponents;
        Order[] orders;
        Fulfillment fulfillment;
        Fulfillment[] fulfillments;
    }

    function _buildOrdersAndFulfillmentsMirrorOrdersFromFuzzArgs(
        Context memory context
    ) internal returns (Order[] memory, Fulfillment[] memory) {
        uint256 i;

        // Set up the OrderAndFulfillmentInfra struct.
        OrderAndFulfillmentInfra memory infra = OrderAndFulfillmentInfra(
            new OfferItem[](context.matchArgs.orderPairCount),
            new ConsiderationItem[](context.matchArgs.orderPairCount),
            OrderComponentsLib.empty(),
            new Order[](context.matchArgs.orderPairCount * 2),
            FulfillmentLib.empty(),
            new Fulfillment[](context.matchArgs.orderPairCount * 2)
        );

        // Iterate once for each orderPairCount, which is
        // used as the number of order pairs to make here.
        for (i = 0; i < context.matchArgs.orderPairCount; i++) {
            // Mint the NFTs for the prime offerer to sell.
            test721_1.mint(
                fuzzPrimeOfferer.addr,
                context.matchArgs.tokenId + i
            );
            test721_1.mint(
                fuzzPrimeOfferer.addr,
                (context.matchArgs.tokenId + i) * 2
            );

            // Build the OfferItem array for the prime offerer's order.
            infra.offerItemArray = _buildPrimeOfferItemArray(context, i);
            // Build the ConsiderationItem array for the prime offerer's order.
            infra.considerationItemArray = _buildPrimeConsiderationItemArray(
                context
            );

            // Build the OrderComponents for the prime offerer's order.
            infra.orderComponents = _buildOrderComponents(
                context,
                infra.offerItemArray,
                infra.considerationItemArray,
                fuzzPrimeOfferer.addr,
                context.matchArgs.shouldUseTransferValidationZoneForPrime
            );

            // Add the order to the orders array.
            infra.orders[i] = _toOrder(
                context.seaport,
                infra.orderComponents,
                fuzzPrimeOfferer.key
            );

            // Build the offerItemArray for the mirror offerer's order.
            infra.offerItemArray = _buildMirrorOfferItemArray(context);

            // Build the considerationItemArray for the mirror offerer's order.
            // Note that the consideration on the mirror is always just one NFT,
            // even if the prime order has an excess item.
            infra.considerationItemArray = buildMirrorConsiderationItemArray(
                context,
                i
            );

            // Build the OrderComponents for the mirror offerer's order.
            infra.orderComponents = _buildOrderComponents(
                context,
                infra.offerItemArray,
                infra.considerationItemArray,
                fuzzMirrorOfferer.addr,
                context.matchArgs.shouldUseTransferValidationZoneForMirror
            );

            // Create the order and add the order to the orders array.
            infra.orders[i + context.matchArgs.orderPairCount] = _toOrder(
                context.seaport,
                infra.orderComponents,
                fuzzMirrorOfferer.key
            );
        }

        // Build fulfillments.
        infra.fulfillments = MatchFulfillmentHelper.getMatchedFulfillments(
            infra.orders
        );

        return (infra.orders, infra.fulfillments);
    }

    function _toOrder(
        ConsiderationInterface seaport,
        OrderComponents memory orderComponents,
        uint256 pkey
    ) internal view returns (Order memory order) {
        bytes32 orderHash = seaport.getOrderHash(orderComponents);
        bytes memory signature = signOrder(seaport, pkey, orderHash);
        order = OrderLib
            .empty()
            .withParameters(orderComponents.toOrderParameters())
            .withSignature(signature);
    }

    function _toUnsignedOrder(
        OrderComponents memory orderComponents
    ) internal pure returns (Order memory order) {
        order = OrderLib.empty().withParameters(
            orderComponents.toOrderParameters()
        );
    }

    function _toConsiderationItem(
        OfferItem memory item,
        address recipient
    ) internal pure returns (ConsiderationItem memory) {
        return
            ConsiderationItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                recipient: payable(recipient)
            });
    }

    function _toOfferItem(
        ConsiderationItem memory item
    ) internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: item.itemType,
                token: item.token,
                identifierOrCriteria: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount
            });
    }
}
