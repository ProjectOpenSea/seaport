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
    FuzzInputs empty;

    // constant strings for recalling struct lib defaults
    // ideally these live in a base test class
    string constant ONE_ETH = "one eth";
    string constant THREE_ERC20 = "three erc20";
    string constant SINGLE_721 = "single 721";
    string constant VALIDATION_ZONE = "validation zone";
    string constant CONTRACT_ORDER = "contract order";

    // *_FIRST
    string constant FIRST_FIRST = "first first";
    string constant SECOND_FIRST = "second first";
    string constant THIRD_FIRST = "third first";
    string constant FOURTH_FIRST = "fourth first";
    string constant FIFTH_FIRST = "fifth first";
    // *_SECOND
    string constant FIRST_SECOND = "first second";
    string constant SECOND_SECOND = "second second";
    string constant THIRD_SECOND = "third second";
    string constant FOURTH_SECOND = "fourth second";
    string constant FIFTH_SECOND = "fifth second";
    // *__FIRST
    string constant FIRST_SECOND__FIRST = "first&second first";
    string constant FIRST_SECOND_THIRD__FIRST = "first&second&third first";
    string constant FIRST_SECOND_THIRD_FOURTH__FIRST =
        "first&second&third&fourth first";
    string constant FIRST_SECOND_THIRD_FOURTH_FIFTH__FIRST =
        "first&second&third&fourth&fifth first";
    // *__SECOND
    string constant FIRST_SECOND__SECOND = "first&second second";
    string constant FIRST_SECOND_THIRD__SECOND = "first&second&third second";
    string constant FIRST_SECOND_THIRD_FOURTH__SECOND =
        "first&second&third&fourth second";
    string constant FIRST_SECOND_THIRD_FOURTH_FIFTH__SECOND =
        "first&second&third&fourth&fifth second";

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
            .saveDefault(VALIDATION_ZONE); // not strictly necessary
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

        // Default FulfillmentComponent defaults.

        // *_FIRST
        // create a default fulfillmentComponent for first_first
        // corresponds to first offer or consideration item in the first order
        FulfillmentComponent memory firstFirst = FulfillmentComponentLib
            .empty()
            .withOrderIndex(0)
            .withItemIndex(0)
            .saveDefault(FIRST_FIRST);
        // create a default fulfillmentComponent for second_first
        // corresponds to first offer or consideration item in the second order
        FulfillmentComponent memory secondFirst = FulfillmentComponentLib
            .empty()
            .withOrderIndex(1)
            .withItemIndex(0)
            .saveDefault(SECOND_FIRST);
        // create a default fulfillmentComponent for third_first
        // corresponds to first offer or consideration item in the third order
        FulfillmentComponent memory thirdFirst = FulfillmentComponentLib
            .empty()
            .withOrderIndex(2)
            .withItemIndex(0)
            .saveDefault(THIRD_FIRST);
        // create a default fulfillmentComponent for fourth_first
        // corresponds to first offer or consideration item in the fourth order
        FulfillmentComponent memory fourthFirst = FulfillmentComponentLib
            .empty()
            .withOrderIndex(3)
            .withItemIndex(0)
            .saveDefault(FOURTH_FIRST);
        // create a default fulfillmentComponent for fifth_first
        // corresponds to first offer or consideration item in the fifth order
        FulfillmentComponent memory fifthFirst = FulfillmentComponentLib
            .empty()
            .withOrderIndex(4)
            .withItemIndex(0)
            .saveDefault(FIFTH_FIRST);

        // *_SECOND
        // create a default fulfillmentComponent for first_second
        // corresponds to second offer or consideration item in the first order
        FulfillmentComponent memory firstSecond = FulfillmentComponentLib
            .empty()
            .withOrderIndex(0)
            .withItemIndex(1)
            .saveDefault(FIRST_SECOND);
        // create a default fulfillmentComponent for second_second
        // corresponds to second offer or consideration item in the second order
        FulfillmentComponent memory secondSecond = FulfillmentComponentLib
            .empty()
            .withOrderIndex(1)
            .withItemIndex(1)
            .saveDefault(SECOND_SECOND);
        // create a default fulfillmentComponent for third_second
        // corresponds to second offer or consideration item in the third order
        FulfillmentComponent memory thirdSecond = FulfillmentComponentLib
            .empty()
            .withOrderIndex(2)
            .withItemIndex(1)
            .saveDefault(THIRD_SECOND);
        // create a default fulfillmentComponent for fourth_second
        // corresponds to second offer or consideration item in the fourth order
        FulfillmentComponent memory fourthSecond = FulfillmentComponentLib
            .empty()
            .withOrderIndex(3)
            .withItemIndex(1)
            .saveDefault(FOURTH_SECOND);
        // create a default fulfillmentComponent for fifth_second
        // corresponds to second offer or consideration item in the fifth order
        FulfillmentComponent memory fifthSecond = FulfillmentComponentLib
            .empty()
            .withOrderIndex(4)
            .withItemIndex(1)
            .saveDefault(FIFTH_SECOND);

        // *__FIRST
        // create a two-element array containing first_first and second_first
        SeaportArrays
            .FulfillmentComponents(firstFirst, secondFirst)
            .saveDefaultMany(FIRST_SECOND__FIRST);
        // create a three-element array containing first_first, second_first,
        // and third_first
        SeaportArrays
            .FulfillmentComponents(firstFirst, secondFirst, thirdFirst)
            .saveDefaultMany(FIRST_SECOND_THIRD__FIRST);
        // create a four-element array containing first_first, second_first,
        // third_first, and fourth_first
        SeaportArrays
            .FulfillmentComponents(
                firstFirst,
                secondFirst,
                thirdFirst,
                fourthFirst
            )
            .saveDefaultMany(FIRST_SECOND_THIRD_FOURTH__FIRST);
        // create a five-element array containing first_first, second_first,
        // third_first, fourth_first, and fifth_first
        SeaportArrays
            .FulfillmentComponents(
                firstFirst,
                secondFirst,
                thirdFirst,
                fourthFirst,
                fifthFirst
            )
            .saveDefaultMany(FIRST_SECOND_THIRD_FOURTH_FIFTH__FIRST);

        // *__SECOND
        // create a two-element array containing first_second and second_second
        SeaportArrays
            .FulfillmentComponents(firstSecond, secondSecond)
            .saveDefaultMany(FIRST_SECOND__SECOND);
        // create a three-element array containing first_second, second_second,
        // and third_second
        SeaportArrays
            .FulfillmentComponents(firstSecond, secondSecond, thirdSecond)
            .saveDefaultMany(FIRST_SECOND_THIRD__SECOND);
        // create a four-element array containing first_second, second_second,
        // third_second, and fourth_second
        SeaportArrays
            .FulfillmentComponents(
                firstSecond,
                secondSecond,
                thirdSecond,
                fourthSecond
            )
            .saveDefaultMany(FIRST_SECOND_THIRD_FOURTH__SECOND);
        // create a five-element array containing first_second, second_second,
        // third_second, fourth_second, and fifth_second
        SeaportArrays
            .FulfillmentComponents(
                firstSecond,
                secondSecond,
                thirdSecond,
                fourthSecond,
                fifthSecond
            )
            .saveDefaultMany(FIRST_SECOND_THIRD_FOURTH_FIFTH__SECOND);

        // create a one-element array containing first_first
        SeaportArrays.FulfillmentComponents(firstFirst).saveDefaultMany(
            FIRST_FIRST
        );
        // create a one-element array containing second_first
        SeaportArrays.FulfillmentComponents(secondFirst).saveDefaultMany(
            SECOND_FIRST
        );
    }

    struct Context {
        ConsiderationInterface seaport;
        FuzzInputs args;
    }

    struct FuzzInputs {
        uint256 tokenId;
        uint128 amount;
        uint128 excessNativeTokens;
        uint256 nonAggregatableOfferItemCount;
        uint256 considerationItemCount;
        uint256 maximumFulfilledCount;
        address offerRecipient;
        address considerationRecipient;
        string primeOfferer;
        string mirrorOfferer;
        bytes32 zoneHash;
        uint256 salt;
        bool useConduit;
        bool useTransferValidationZone;
        bool useTransferValidationZoneForPrime;
        bool useTransferValidationZoneForMirror;
        bool useNativeConsideration;
        bool useExcessOfferItems;
        bool specifyRecipient;
        bool includeJunkDataInAdvancedOrder;
    }

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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20,
            Context({ seaport: referenceConsideration, args: empty })
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

    // NOTE: This demonstrates undocumented behavior. If the maxFulfilled is
    //  less than the number of orders, we fire off an ill-formed
    // `validateOrder` call.
    function testExecFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast()
        public
    {
        prepareFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast();
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast,
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipLast,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitAndERC20Collision,
            Context({ seaport: referenceConsideration, args: empty })
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
        // checks, which we want to tinker with.
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this
                .execFulfillAvailableAdvancedOrdersWithConduitAndERC20SkipMultiple,
            Context({ seaport: referenceConsideration, args: empty })
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
        // checks, which we want to tinker with.
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execFulfillAvailableAdvancedOrdersWithConduitNativeAndERC20,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execAggregate,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchContractOrdersWithConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchAdvancedContractOrdersWithConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchOpenAndContractOrdersWithConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchFullRestrictedOrdersNoConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchAdvancedFullRestrictedOrdersNoConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchAdvancedMirrorContractOrdersWithConduitNoConduit,
            Context({ seaport: referenceConsideration, args: empty })
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
            Context({ seaport: consideration, args: empty })
        );
        test(
            this.execMatchAdvancedMirrorOrdersRestrictedAndUnrestricted,
            Context({ seaport: referenceConsideration, args: empty })
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

    function testFulfillAvailableAdvancedNonAggregatedFuzz(
        FuzzInputs memory args
    ) public {
        // Avoid weird overflow issues.
        args.amount = uint128(bound(args.amount, 0xff, 0xffffffffffffffff));
        args.tokenId = bound(args.tokenId, 0xff, 0xffffffffffffffff);
        args.considerationItemCount = bound(args.considerationItemCount, 1, 3);
        args.nonAggregatableOfferItemCount = bound(
            args.nonAggregatableOfferItemCount,
            1,
            16
        );
        // Fulfill between 1 and the number of items on the offer side, since
        // the test sets up one order per non-aggregatable offer item.
        args.maximumFulfilledCount = bound(
            args.maximumFulfilledCount,
            1,
            args.nonAggregatableOfferItemCount
        );
        args.excessNativeTokens = uint128(
            bound(args.excessNativeTokens, 0, 0xfffffffff)
        );
        // Don't set the offer recipient to the null address, because that
        // is the way to indicate that the caller should be the recipient.
        args.offerRecipient = address(
            uint160(bound(uint160(args.offerRecipient), 1, type(uint160).max))
        );
        args.considerationRecipient = address(
            uint160(
                bound(
                    uint160(args.considerationRecipient),
                    1,
                    type(uint160).max
                )
            )
        );
        // To put three items in the consideration, we need to have include
        // native tokens.
        args.useNativeConsideration =
            args.useNativeConsideration ||
            args.considerationItemCount >= 3;
        test(
            this.execFulfillAvailableAdvancedNonAggregatedFuzz,
            Context(consideration, args)
        );
        test(
            this.execFulfillAvailableAdvancedNonAggregatedFuzz,
            Context(referenceConsideration, args)
        );
    }

    function execFulfillAvailableAdvancedNonAggregatedFuzz(
        Context memory context
    ) external stateless {
        // Use a conduit sometimes.
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        // Mint enough ERC721s to cover the number of NFTs for sale.
        for (uint256 i; i < context.args.nonAggregatableOfferItemCount; i++) {
            test721_1.mint(offerer1.addr, context.args.tokenId + i);
        }

        // Mint enough ERC20s to cover price per NFT * NFTs for sale.
        token1.mint(
            address(this),
            context.args.amount * context.args.nonAggregatableOfferItemCount
        );

        if (context.args.considerationItemCount >= 2) {
            // If the fuzz args call for 2 consideration items per order, mint
            // additional ERC20s.
            token2.mint(
                address(this),
                context.args.amount * context.args.nonAggregatableOfferItemCount
            );
        }

        // Create the orders.
        AdvancedOrder[] memory advancedOrders = _buildOrdersFromFuzzArgs(
            context,
            false,
            offerer1.key
        );

        // Create the fulfillments.
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getNaiveFulfillmentComponents(advancedOrders);

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // If we're using the transfer validation zone, make sure that it
        // is actually enforcing what we expect it to.
        if (context.args.useTransferValidationZone) {
            vm.expectRevert(
                abi.encodeWithSignature(
                    "InvalidOwner(address,address,address,uint256)",
                    context.args.offerRecipient,
                    address(this),
                    address(test721_1),
                    context.args.tokenId // Should revert on the first.
                )
            );
            context.seaport.fulfillAvailableAdvancedOrders{
                value: context.args.useNativeConsideration
                    ? context.args.excessNativeTokens +
                        (context.args.amount *
                            context.args.maximumFulfilledCount)
                    : context.args.excessNativeTokens
            }({
                advancedOrders: advancedOrders,
                criteriaResolvers: criteriaResolvers,
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                fulfillerConduitKey: bytes32(conduitKey),
                recipient: address(this),
                maximumFulfilled: context.args.maximumFulfilledCount
            });
        }

        if (!context.args.useNativeConsideration) {
            // This checks that the ERC20 transfers were not all aggregated into
            // a single transfer.
            vm.expectEmit(true, true, true, true, address(token1));
            emit Transfer(
                address(this), // from
                address(context.args.considerationRecipient), // to
                context.args.amount // value
            );

            if (context.args.considerationItemCount >= 2) {
                // This checks that the second consideration item is being
                // properly handled.
                vm.expectEmit(true, true, true, true, address(token2));
                emit Transfer(
                    address(this), // from
                    address(context.args.considerationRecipient), // to
                    context.args.amount // value
                );
            }
        }

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders{
            value: context.args.useNativeConsideration
                ? context.args.excessNativeTokens +
                    (context.args.amount * context.args.maximumFulfilledCount)
                : context.args.excessNativeTokens
        }({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKey),
            recipient: context.args.offerRecipient,
            maximumFulfilled: context.args.maximumFulfilledCount
        });

        // Check that the zone was called the expected number of times.
        if (context.args.useTransferValidationZone) {
            assertTrue(zone.callCount() == context.args.maximumFulfilledCount);
        }

        // Check that the NFTs were transferred to the expected recipient.
        for (uint256 i = 0; i < context.args.maximumFulfilledCount; i++) {
            assertEq(
                test721_1.ownerOf(context.args.tokenId + i),
                context.args.offerRecipient
            );
        }
    }

    function testFulfillAvailableAdvancedAggregatedFuzz(
        FuzzInputs memory args
    ) public {
        // Avoid weird overflow issues.
        args.amount = uint128(bound(args.amount, 0xff, 0xffffffffffffffff));
        args.tokenId = bound(args.tokenId, 0xff, 0xffffffffffffffff);
        args.nonAggregatableOfferItemCount = bound(
            args.nonAggregatableOfferItemCount,
            2,
            16
        );
        // Fulfill between 1 and the number of items on the offer side, since
        // the test sets up one order per non-aggregatable offer item.
        args.maximumFulfilledCount = bound(
            args.maximumFulfilledCount,
            1,
            args.nonAggregatableOfferItemCount
        );
        args.excessNativeTokens = uint128(
            bound(args.excessNativeTokens, 0, 0xfffffffff)
        );
        // Don't set the offer recipient to the null address, because that
        // is the way to indicate that the caller should be the recipient.
        args.offerRecipient = address(
            uint160(bound(uint160(args.offerRecipient), 1, type(uint160).max))
        );
        test(
            this.execFulfillAvailableAdvancedAggregatedFuzz,
            Context(consideration, args)
        );
        test(
            this.execFulfillAvailableAdvancedAggregatedFuzz,
            Context(referenceConsideration, args)
        );
    }

    function execFulfillAvailableAdvancedAggregatedFuzz(
        Context memory context
    ) external stateless {
        // Use a conduit sometimes.
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        // Mint enough ERC721s to cover the number of NFTs for sale.
        for (uint256 i; i < context.args.nonAggregatableOfferItemCount; i++) {
            test721_1.mint(offerer1.addr, context.args.tokenId + i);
        }

        // Mint enough ERC20s to cover price per NFT * NFTs for sale.
        token1.mint(
            address(this),
            context.args.amount * context.args.nonAggregatableOfferItemCount
        );

        if (context.args.considerationItemCount >= 2) {
            // If the fuzz args call for 2 consideration items per order, mint
            // additional ERC20s.
            token2.mint(
                address(this),
                context.args.amount * context.args.nonAggregatableOfferItemCount
            );
        }

        // Create the orders.
        AdvancedOrder[] memory advancedOrders = _buildOrdersFromFuzzArgs(
            context,
            true,
            offerer1.key
        );

        // Get the aggregated fulfillment components.
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = FulfillmentHelper.getAggregatedFulfillmentComponents(
                advancedOrders
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        // If we're using the transfer validation zone, make sure that it
        // is actually enforcing what we expect it to.
        if (context.args.useTransferValidationZone) {
            vm.expectRevert(
                abi.encodeWithSignature(
                    "InvalidOwner(address,address,address,uint256)",
                    context.args.offerRecipient,
                    address(this),
                    address(test721_1),
                    context.args.tokenId // Should revert on the first.
                )
            );
            context.seaport.fulfillAvailableAdvancedOrders{
                value: context.args.useNativeConsideration
                    ? context.args.excessNativeTokens +
                        (context.args.amount *
                            context.args.maximumFulfilledCount)
                    : context.args.excessNativeTokens
            }({
                advancedOrders: advancedOrders,
                criteriaResolvers: criteriaResolvers,
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                fulfillerConduitKey: bytes32(conduitKey),
                recipient: address(this),
                maximumFulfilled: context.args.maximumFulfilledCount
            });
        }

        // This checks that the ERC20 transfers were all aggregated into a
        // single transfer.
        vm.expectEmit(true, true, true, true, address(token1));
        emit Transfer(
            address(this), // from
            address(context.args.considerationRecipient), // to
            context.args.amount * context.args.maximumFulfilledCount // amount
        );

        // Make the call to Seaport.
        context.seaport.fulfillAvailableAdvancedOrders{
            value: context.args.useNativeConsideration
                ? context.args.excessNativeTokens +
                    (context.args.amount * context.args.maximumFulfilledCount)
                : context.args.excessNativeTokens
        }({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKey),
            recipient: context.args.offerRecipient,
            maximumFulfilled: context.args.maximumFulfilledCount
        });

        // Check that the zone was called the expected number of times.
        if (context.args.useTransferValidationZone) {
            assertTrue(zone.callCount() == context.args.maximumFulfilledCount);
        }

        // Check that the NFTs were transferred to the expected recipient.
        for (uint256 i = 0; i < context.args.maximumFulfilledCount; i++) {
            assertEq(
                test721_1.ownerOf(context.args.tokenId + i),
                context.args.offerRecipient
            );
        }
    }

    // TODO: Clean up the bounds here and maybe rename the FuzzInputs fields or
    //       make a new struct for fuzz args for Match.
    function testMatchAdvancedOrdersBasicFuzz(FuzzInputs memory args) public {
        // Avoid weird overflow issues.
        args.amount = uint128(bound(args.amount, 0xff, 0xffffffffffffffff));
        args.tokenId = bound(args.tokenId, 0xff, 0xffffffffffffffff);
        // // TODO: Come back and think about this.
        // args.considerationItemCount = bound(
        //     args.considerationItemCount,
        //     1,
        //     1
        // );
        args.nonAggregatableOfferItemCount = bound(
            args.nonAggregatableOfferItemCount,
            1,
            8 // More than this causes a revert.  Maybe gas related?
        );
        args.excessNativeTokens = uint128(
            bound(args.excessNativeTokens, 0, 0xfffffffff)
        );
        // Don't set the offer recipient to the null address, because that
        // is the way to indicate that the caller should be the recipient.
        args.offerRecipient = address(
            uint160(bound(uint160(args.offerRecipient), 1, type(uint160).max))
        );

        // Only want this to be true if we're NOT using the transfer validation
        // zone.
        args.useExcessOfferItems =
            args.useExcessOfferItems &&
            !(args.useTransferValidationZoneForPrime ||
                args.useTransferValidationZoneForMirror);

        test(
            this.execMatchAdvancedOrdersBasicFuzz,
            Context(consideration, args)
        );
        test(
            this.execMatchAdvancedOrdersBasicFuzz,
            Context(referenceConsideration, args)
        );
    }

    function execMatchAdvancedOrdersBasicFuzz(
        Context memory context
    ) external stateless {
        fuzzPrimeOfferer = makeAndAllocateAccount(context.args.primeOfferer);
        fuzzMirrorOfferer = makeAndAllocateAccount(context.args.mirrorOfferer);

        // Set fuzzMirrorOfferer as the expected offer recipient.
        zone.setExpectedOfferRecipient(fuzzMirrorOfferer.addr);

        // Create the orders and fulfuillments.
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments
        ) = _buildOrdersAndFulfillmentsMirrorOrdersFromFuzzArgs(context);

        // Set up the advanced orders array.
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](
            orders.length
        );

        // Convert the orders to advanced orders.
        for (uint256 i = 0; i < orders.length; i++) {
            advancedOrders[i] = orders[i].toAdvancedOrder(
                1,
                1,
                context.args.includeJunkDataInAdvancedOrder
                    ? bytes(abi.encodePacked(context.args.salt))
                    : bytes("")
            );
        }

        // TODO: Come back and think about this.
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        // Make the call to Seaport.
        context.seaport.matchAdvancedOrders{
            value: (context.args.amount *
                context.args.nonAggregatableOfferItemCount) +
                context.args.excessNativeTokens
        }(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            // Send the excess offer items to the recipient specified by the
            // fuzz args.
            context.args.specifyRecipient // This is really excess item recipient in this case.
                ? address(context.args.offerRecipient)
                : address(0)
        );

        // Expected call count is the number of prime orders using the transfer
        // validation zone, plus the number of mirror orders using the transfer
        // validation zone.
        uint256 expectedCallCount = 0;
        if (context.args.useTransferValidationZoneForPrime) {
            expectedCallCount += context.args.nonAggregatableOfferItemCount;
        }
        if (context.args.useTransferValidationZoneForMirror) {
            expectedCallCount += context.args.nonAggregatableOfferItemCount;
        }
        assertTrue(zone.callCount() == expectedCallCount);

        // Check that the NFTs were transferred to the expected recipient.
        for (
            uint256 i = 0;
            i < context.args.nonAggregatableOfferItemCount;
            i++
        ) {
            assertEq(
                test721_1.ownerOf(context.args.tokenId + i),
                fuzzMirrorOfferer.addr
            );
        }

        if (context.args.useExcessOfferItems) {
            // Check that the excess offer NFTs were transferred to the expected
            // recipient.
            for (
                uint256 i = 0;
                i < context.args.nonAggregatableOfferItemCount;
                i++
            ) {
                assertEq(
                    test721_1.ownerOf((context.args.tokenId + i) * 2),
                    context.args.specifyRecipient // This is really excess recipient in this case.
                        ? context.args.offerRecipient
                        : address(this)
                );
            }
        }
    }

    function _buildOrdersFromFuzzArgs(
        Context memory context,
        bool aggregated,
        uint256 key
    ) internal returns (AdvancedOrder[] memory advancedOrders) {
        // Create the OrderComponents array from the fuzz args.
        OrderComponents[] memory orderComponents;
        if (aggregated) {
            orderComponents = _buildOrderComponentsArrayFromFuzzArgsAggregated(
                context
            );
        } else {
            orderComponents = _buildOrderComponentsArrayFromFuzzArgsNonAggregated(
                context
            );
        }

        // Set up the AdvancedOrder array.
        AdvancedOrder[] memory _advancedOrders = new AdvancedOrder[](
            context.args.nonAggregatableOfferItemCount
        );

        // Iterate over the OrderComponents array and build an AdvancedOrder
        // for each OrderComponents.
        Order memory order;
        for (uint256 i = 0; i < orderComponents.length; i++) {
            if (orderComponents[i].orderType == OrderType.CONTRACT) {
                revert("Not implemented.");
            } else {
                // Create the order.
                order = toOrder(context.seaport, orderComponents[i], key);
                // Convert it to an AdvancedOrder and add it to the array.
                _advancedOrders[i] = order.toAdvancedOrder(
                    1,
                    1,
                    context.args.includeJunkDataInAdvancedOrder
                        ? bytes(abi.encodePacked(context.args.salt))
                        : bytes("")
                );
            }
        }

        return _advancedOrders;
    }

    struct OrderComponentInfra {
        OrderComponents orderComponents;
        OrderComponents[] orderComponentsArray;
        OfferItem[][] offerItemsArray;
        ConsiderationItem[][] considerationItemsArray;
        ConsiderationItem nativeConsiderationItem;
        ConsiderationItem erc20ConsiderationItemOne;
        ConsiderationItem erc20ConsiderationItemTwo;
    }

    function _buildOrderComponentsArrayFromFuzzArgsAggregated(
        Context memory context
    ) internal returns (OrderComponents[] memory _orderComponentsArray) {
        OrderComponentInfra memory orderComponentInfra = OrderComponentInfra(
            OrderComponentsLib.empty(),
            new OrderComponents[](context.args.nonAggregatableOfferItemCount),
            new OfferItem[][](context.args.nonAggregatableOfferItemCount),
            new ConsiderationItem[][](
                context.args.nonAggregatableOfferItemCount
            ),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty()
        );

        // Create a reusable native consideration item.
        orderComponentInfra.nativeConsiderationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withIdentifierOrCriteria(0)
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        // Create a reusable ERC20 consideration item.
        orderComponentInfra.erc20ConsiderationItemOne = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(token1))
            .withIdentifierOrCriteria(0)
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        // Create a second reusable ERC20 consideration item.
        orderComponentInfra.erc20ConsiderationItemTwo = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withIdentifierOrCriteria(0)
            .withToken(address(token2))
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        for (uint256 i; i < context.args.nonAggregatableOfferItemCount; i++) {
            // Add a one-element OfferItems[] to the OfferItems[][].
            orderComponentInfra.offerItemsArray[i] = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.args.tokenId + i)
            );

            // Iterate over each offer item and add two
            // consideration items.

            if (context.args.useNativeConsideration) {
                orderComponentInfra.considerationItemsArray[i] = SeaportArrays
                    .ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem,
                        orderComponentInfra.erc20ConsiderationItemOne
                    );
            } else {
                orderComponentInfra.considerationItemsArray[i] = SeaportArrays
                    .ConsiderationItems(
                        orderComponentInfra.erc20ConsiderationItemOne,
                        orderComponentInfra.erc20ConsiderationItemTwo
                    );
            }
        }

        // Use either the transfer validation zone or the test zone for all
        // orders.
        address fuzzyZone;
        TestZone testZone;

        if (context.args.useTransferValidationZone) {
            zone = new TestTransferValidationZoneOfferer(
                context.args.offerRecipient
            );
            fuzzyZone = address(zone);
        } else {
            testZone = new TestZone();
            fuzzyZone = address(testZone);
        }

        bytes32 conduitKey;

        for (
            uint256 i = 0;
            i < context.args.nonAggregatableOfferItemCount;
            i++
        ) {
            // if context.args.useConduit is false: don't use conduits at all.
            // if context.args.useConduit is true:
            //      if context.args.tokenId % 2 == 0:
            //          use conduits for some and not for others
            //      if context.args.tokenId % 2 != 0:
            //          use conduits for all
            // This is plainly deranged, but it allows for conduit use
            // for all, for some, and for none without weighing down the stack.
            conduitKey = !context.args.useNativeConsideration &&
                context.args.useConduit &&
                (context.args.tokenId % 2 == 0 ? i % 2 == 0 : true)
                ? conduitKeyOne
                : bytes32(0);

            // Build the order components.
            orderComponentInfra.orderComponents = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(orderComponentInfra.offerItemsArray[i])
                .withConsideration(
                    orderComponentInfra.considerationItemsArray[i]
                )
                .withZone(fuzzyZone)
                .withZoneHash(context.args.zoneHash)
                .withConduitKey(conduitKey)
                .withSalt(context.args.salt % (i + 1)); // Is this dumb?

            // Add the OrderComponents to the OrderComponents[].
            orderComponentInfra.orderComponentsArray[i] = orderComponentInfra
                .orderComponents;
        }

        return orderComponentInfra.orderComponentsArray;
    }

    function _buildOrderComponentsArrayFromFuzzArgsNonAggregated(
        Context memory context
    ) internal returns (OrderComponents[] memory _orderComponentsArray) {
        OrderComponentInfra memory orderComponentInfra = OrderComponentInfra(
            OrderComponentsLib.empty(),
            new OrderComponents[](context.args.nonAggregatableOfferItemCount),
            new OfferItem[][](context.args.nonAggregatableOfferItemCount),
            new ConsiderationItem[][](
                context.args.nonAggregatableOfferItemCount
            ),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty(),
            ConsiderationItemLib.empty()
        );

        // Create a reusable native consideration item.
        orderComponentInfra.nativeConsiderationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withIdentifierOrCriteria(0)
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        // Create a reusable ERC20 consideration item.
        orderComponentInfra.erc20ConsiderationItemOne = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(token1))
            .withIdentifierOrCriteria(0)
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        // Create a second reusable ERC20 consideration item.
        orderComponentInfra.erc20ConsiderationItemTwo = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withIdentifierOrCriteria(0)
            .withToken(address(token2))
            .withStartAmount(context.args.amount)
            .withEndAmount(context.args.amount)
            .withRecipient(context.args.considerationRecipient);

        for (uint256 i; i < context.args.nonAggregatableOfferItemCount; i++) {
            // Add a one-element OfferItems[] to the OfferItems[][].
            orderComponentInfra.offerItemsArray[i] = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.args.tokenId + i)
            );

            if (context.args.considerationItemCount == 1) {
                // If the fuzz args call for native consideration...
                if (context.args.useNativeConsideration) {
                    // ...add a native consideration item...
                    orderComponentInfra.considerationItemsArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem
                    );
                } else {
                    // ...otherwise, add an ERC20 consideration item.
                    orderComponentInfra.considerationItemsArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.erc20ConsiderationItemOne
                    );
                }
            } else if (context.args.considerationItemCount == 2) {
                // If the fuzz args call for native consideration...
                if (context.args.useNativeConsideration) {
                    // ...add a native consideration item and an ERC20
                    // consideration item...
                    orderComponentInfra.considerationItemsArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.nativeConsiderationItem,
                        orderComponentInfra.erc20ConsiderationItemOne
                    );
                } else {
                    // ...otherwise, add two ERC20 consideration items.
                    orderComponentInfra.considerationItemsArray[
                        i
                    ] = SeaportArrays.ConsiderationItems(
                        orderComponentInfra.erc20ConsiderationItemOne,
                        orderComponentInfra.erc20ConsiderationItemTwo
                    );
                }
            } else {
                orderComponentInfra.considerationItemsArray[i] = SeaportArrays
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

        if (context.args.useTransferValidationZone) {
            zone = new TestTransferValidationZoneOfferer(
                context.args.offerRecipient
            );
            fuzzyZone = address(zone);
        } else {
            testZone = new TestZone();
            fuzzyZone = address(testZone);
        }

        bytes32 conduitKey;

        for (
            uint256 i = 0;
            i < context.args.nonAggregatableOfferItemCount;
            i++
        ) {
            // if context.args.useConduit is false: don't use conduits at all.
            // if context.args.useConduit is true:
            //      if context.args.tokenId % 2 == 0:
            //          use conduits for some and not for others
            //      if context.args.tokenId % 2 != 0:
            //          use conduits for all
            // This is plainly deranged, but it allows for conduit use
            // for all, for some, and for none without weighing down the stack.
            conduitKey = !context.args.useNativeConsideration &&
                context.args.useConduit &&
                (context.args.tokenId % 2 == 0 ? i % 2 == 0 : true)
                ? conduitKeyOne
                : bytes32(0);

            // Build the order components.
            orderComponentInfra.orderComponents = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(orderComponentInfra.offerItemsArray[i])
                .withConsideration(
                    orderComponentInfra.considerationItemsArray[i]
                )
                .withZone(fuzzyZone)
                .withZoneHash(context.args.zoneHash)
                .withConduitKey(conduitKey)
                .withSalt(context.args.salt % (i + 1)); // Is this dumb?

            // Add the OrderComponents to the OrderComponents[].
            orderComponentInfra.orderComponentsArray[i] = orderComponentInfra
                .orderComponents;
        }

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
                orders[i] = toUnsignedOrder(orderComponents[i]);
            else orders[i] = toOrder(context.seaport, orderComponents[i], key);
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
        // technically we do not need to copy() since first order components is
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
        // technically we do not need to copy() since first order components is
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

        Fulfillment[] memory fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                ),
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
        );

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

        Fulfillment[] memory fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                ),
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
        );

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

        Fulfillment[] memory fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                ),
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
        );

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

        orders[0] = toOrder(context.seaport, orderComponents, offerer1.key);
        orders[1] = toOrder(context.seaport, orderComponents2, offerer2.key);

        Fulfillment[] memory fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                ),
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
        );

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

        orders[0] = toOrder(context.seaport, orderComponents, offerer1.key);
        orders[1] = toOrder(context.seaport, orderComponents2, offerer2.key);

        Fulfillment[] memory fulfillments = SeaportArrays.Fulfillments(
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                ),
            FulfillmentLib
                .empty()
                .withOfferComponents(
                    FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
                )
                .withConsiderationComponents(
                    FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                )
        );

        return (orders, fulfillments, bytes32(0), 2);
    }

    struct OrderAndFulfillmentInfra {
        OfferItem[] offerArray;
        ConsiderationItem[] considerationArray;
        OrderComponents orderComponents;
        Order[] orders;
        Fulfillment[] fulfillments;
    }

    function _buildOrdersAndFulfillmentsMirrorOrdersFromFuzzArgs(
        Context memory context
    ) internal returns (Order[] memory, Fulfillment[] memory) {
        uint256 i;

        OrderAndFulfillmentInfra memory infra = OrderAndFulfillmentInfra(
            new OfferItem[](context.args.nonAggregatableOfferItemCount),
            new ConsiderationItem[](context.args.nonAggregatableOfferItemCount),
            OrderComponentsLib.empty(),
            new Order[](context.args.nonAggregatableOfferItemCount * 2),
            new Fulfillment[](context.args.nonAggregatableOfferItemCount * 2)
        );

        // Iterate once for each nonAggregatableOfferItemCount, which is
        // used as the number of order pairs to make here.
        for (i = 0; i < context.args.nonAggregatableOfferItemCount; i++) {
            // Mint an ERC721 to sell.
            test721_1.mint(fuzzPrimeOfferer.addr, context.args.tokenId + i);

            // If the fuzz args call for an excess offer item...
            if (context.args.useExcessOfferItems) {
                // ... mint another ERC721 to sell.
                test721_1.mint(
                    fuzzPrimeOfferer.addr,
                    (context.args.tokenId + i) * 2
                );
                // Create the OfferItem[] for the offered item and the
                // excess item.
                infra.offerArray = SeaportArrays.OfferItems(
                    OfferItemLib
                        .fromDefault(SINGLE_721)
                        .withToken(address(test721_1))
                        .withIdentifierOrCriteria(context.args.tokenId + i),
                    OfferItemLib
                        .fromDefault(SINGLE_721)
                        .withToken(address(test721_1))
                        .withIdentifierOrCriteria(
                            (context.args.tokenId + i) * 2
                        )
                );
            } else {
                // Otherwise, create the OfferItem[] for the one offered
                // item.
                infra.offerArray = SeaportArrays.OfferItems(
                    OfferItemLib
                        .fromDefault(SINGLE_721)
                        .withToken(address(test721_1))
                        .withIdentifierOrCriteria(context.args.tokenId + i)
                );
            }

            // Create the ConsiderationItem[] the offerer expects.  It's
            // the same whether or not excess items are used.
            infra.considerationArray = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(ONE_ETH)
                    .withRecipient(fuzzPrimeOfferer.addr)
                    .withStartAmount(context.args.amount)
                    .withEndAmount(context.args.amount)
            );

            // Build the OrderComponents for the prime offerer's order.
            infra.orderComponents = OrderComponentsLib
                .fromDefault(VALIDATION_ZONE)
                .withOffer(infra.offerArray)
                .withConsideration(infra.considerationArray)
                .withZone(address(0))
                .withOrderType(OrderType.FULL_OPEN)
                .withConduitKey(
                    context.args.tokenId % 2 == 0 ? conduitKeyOne : bytes32(0)
                )
                .withOfferer(fuzzPrimeOfferer.addr)
                .withCounter(context.seaport.getCounter(fuzzPrimeOfferer.addr));

            // If the fuzz args call for a transfer validation zone...
            if (context.args.useTransferValidationZoneForPrime) {
                // ... set the zone to the transfer validation zone and
                // set the order type to FULL_RESTRICTED.
                infra.orderComponents = infra
                    .orderComponents
                    .copy()
                    .withZone(address(zone))
                    .withOrderType(OrderType.FULL_RESTRICTED);
            }

            // Add the order to the orders array.
            infra.orders[i] = toOrder(
                context.seaport,
                infra.orderComponents,
                fuzzPrimeOfferer.key
            );

            // Create mirror offer and consideration.
            infra.offerArray = SeaportArrays.OfferItems(
                OfferItemLib
                    .fromDefault(ONE_ETH)
                    .withStartAmount(context.args.amount)
                    .withEndAmount(context.args.amount)
            );

            // Note that the consideration on the mirror is always just
            // one NFT, even if the prime order has an excess item.
            infra.considerationArray = SeaportArrays.ConsiderationItems(
                ConsiderationItemLib
                    .fromDefault(SINGLE_721)
                    .withToken(address(test721_1))
                    .withIdentifierOrCriteria(context.args.tokenId + i)
                    .withRecipient(fuzzMirrorOfferer.addr)
            );

            // Build the OrderComponents for the mirror offerer's order.
            infra.orderComponents = infra
                .orderComponents
                .copy()
                .withOrderType(OrderType.FULL_OPEN)
                .withOfferer(fuzzMirrorOfferer.addr)
                .withOffer(infra.offerArray)
                .withConsideration(infra.considerationArray)
                .withZone(address(0))
                .withOfferer(fuzzMirrorOfferer.addr)
                .withCounter(
                    context.seaport.getCounter(fuzzMirrorOfferer.addr)
                );

            // Not sure why but this approach cures a stack depth error.
            {
                infra.orderComponents = infra
                    .orderComponents
                    .copy()
                    .withConduitKey(
                        context.args.useConduit ? conduitKeyOne : bytes32(0)
                    );
            }

            if (context.args.useTransferValidationZoneForMirror) {
                infra.orderComponents = infra
                    .orderComponents
                    .copy()
                    .withZone(address(zone))
                    .withOrderType(OrderType.FULL_RESTRICTED);
            }

            infra.orders[
                i + context.args.nonAggregatableOfferItemCount
            ] = toOrder(
                context.seaport,
                infra.orderComponents,
                fuzzMirrorOfferer.key
            );
        }

        Fulfillment memory fulfillment;

        // infra.orders.length should always be divisible by 2 because we create
        // two orders for each sale.

        for (i = 0; i < (infra.orders.length / 2); i++) {
            // Create the fulfillments for the "prime" order.
            fulfillment = FulfillmentLib
                .empty()
                .withOfferComponents(
                    SeaportArrays.FulfillmentComponents(
                        FulfillmentComponentLib
                            .empty()
                            .withOrderIndex(i)
                            .withItemIndex(0)
                    )
                )
                .withConsiderationComponents(
                    SeaportArrays.FulfillmentComponents(
                        FulfillmentComponentLib
                            .empty()
                            .withOrderIndex(i + (infra.orders.length / 2))
                            .withItemIndex(0)
                    )
                );

            infra.fulfillments[i] = fulfillment;

            // Create the fulfillments for the "mirror" order.
            fulfillment = FulfillmentLib
                .empty()
                .withOfferComponents(
                    SeaportArrays.FulfillmentComponents(
                        FulfillmentComponentLib
                            .empty()
                            .withOrderIndex(i + (infra.orders.length / 2))
                            .withItemIndex(0)
                    )
                )
                .withConsiderationComponents(
                    SeaportArrays.FulfillmentComponents(
                        FulfillmentComponentLib
                            .empty()
                            .withOrderIndex(i)
                            .withItemIndex(0)
                    )
                );

            infra.fulfillments[i + (infra.orders.length / 2)] = fulfillment;
        }

        return (infra.orders, infra.fulfillments);
    }

    function toOrder(
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

    function toUnsignedOrder(
        OrderComponents memory orderComponents
    ) internal pure returns (Order memory order) {
        order = OrderLib.empty().withParameters(
            orderComponents.toOrderParameters()
        );
    }
}
