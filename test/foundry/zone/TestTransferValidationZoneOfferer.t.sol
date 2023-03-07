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

    // constant strings for recalling struct lib "defaults"
    // ideally these live in a base test class
    string constant ONE_ETH = "one eth";
    string constant THREE_ERC20 = "three erc20";
    string constant SINGLE_721 = "single 721";
    string constant VALIDATION_ZONE = "validation zone";
    string constant FIRST_FIRST = "first first";
    string constant SECOND_FIRST = "second first";
    string constant THIRD_FIRST = "third second";
    string constant FOURTH_FIRST = "fourth first";
    string constant FIFTH_FIRST = "fifth first";
    string constant FIRST_SECOND = "first second";
    string constant SECOND_SECOND = "second second";
    string constant FIRST_SECOND__FIRST = "first&second first";
    string constant FIRST_SECOND__SECOND = "first&second second";
    string constant FIRST_SECOND_THIRD__FIRST = "first&second&third first";
    string constant FIRST_SECOND_THIRD_FOURTH__FIRST =
        "first&second&third&fourth first";
    string constant FIRST_SECOND_THIRD_FOURTH_FIFTH__FIRST =
        "first&second&third&fourth&fifth first";
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

        // create a one-element array containing first_first
        SeaportArrays.FulfillmentComponents(firstFirst).saveDefaultMany(
            FIRST_FIRST
        );
        // create a one-element array containing second_first
        SeaportArrays.FulfillmentComponents(secondFirst).saveDefaultMany(
            SECOND_FIRST
        );

        // create a two-element array containing first_first and second_first
        SeaportArrays
            .FulfillmentComponents(firstFirst, secondFirst)
            .saveDefaultMany(FIRST_SECOND__FIRST);

        // create a two-element array containing first_second and second_second
        SeaportArrays
            .FulfillmentComponents(firstSecond, secondSecond)
            .saveDefaultMany(FIRST_SECOND__SECOND);

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
    }

    struct Context {
        ConsiderationInterface seaport;
        FuzzInputs args;
    }

    struct FuzzInputs {
        uint256 tokenId;
        uint128 amount;
        uint256 nonAggregatableOfferOrderCount;
        address offerRecipient;
        address considerationRecipient;
        bytes32 zoneHash;
        uint256 salt;
        bool useConduit;
        bool useTransferValidationZone;
    }

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
        ) = _buildFulfillmentsComponentsForMultipleOrders(2, 1);

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
        ) = _buildFulfillmentsComponentsForMultipleOrders(2, 2);

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
        ) = _buildFulfillmentsComponentsForMultipleOrders(2, 2);

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
        ) = _buildFulfillmentsComponentsForMultipleOrders(3, 1);

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
        ) = _buildFulfillmentsComponentsForMultipleOrders(2, 2);

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

    function testFulfillAdvancedBasicFuzz(FuzzInputs memory args) public {
        args.amount = uint128(bound(args.amount, 0xff, 0xffffffffffffffff));
        args.tokenId = bound(args.tokenId, 0xff, 0xffffffffffffffff);
        args.nonAggregatableOfferOrderCount = bound(
            args.nonAggregatableOfferOrderCount,
            1,
            5
        );
        args.offerRecipient = address(
            uint160(bound(uint160(args.offerRecipient), 1, type(uint160).max))
        );
        test(
            this.execFulfillAdvancedBasicFuzz,
            Context(referenceConsideration, args)
        );
        test(this.execFulfillAdvancedBasicFuzz, Context(consideration, args));
    }

    function execFulfillAdvancedBasicFuzz(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        for (uint256 i; i < context.args.nonAggregatableOfferOrderCount; i++) {
            test721_1.mint(offerer1.addr, context.args.tokenId + i);
        }

        token1.mint(
            address(this),
            context.args.amount * context.args.nonAggregatableOfferOrderCount
        );

        AdvancedOrder[] memory advancedOrders = _buildOrdersFromFuzzArgs(
            context,
            offerer1.key
        );

        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = _buildFulfillmentsComponentsForMultipleOrders(
                context.args.nonAggregatableOfferOrderCount,
                1
            );

        // Create the empty criteria resolvers.
        CriteriaResolver[] memory criteriaResolvers;

        Context memory _context = context;

        if (_context.args.useTransferValidationZone) {
            vm.expectRevert(
                abi.encodeWithSignature(
                    "InvalidOwner(address,address,address,uint256)",
                    _context.args.offerRecipient,
                    address(this),
                    address(test721_1),
                    _context.args.tokenId
                )
            );
            _context.seaport.fulfillAvailableAdvancedOrders({
                advancedOrders: advancedOrders,
                criteriaResolvers: criteriaResolvers,
                offerFulfillments: offerFulfillments,
                considerationFulfillments: considerationFulfillments,
                fulfillerConduitKey: bytes32(conduitKey),
                recipient: address(this),
                maximumFulfilled: context.args.nonAggregatableOfferOrderCount
            });
        }

        // Make the call to Seaport.
        _context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(conduitKey),
            recipient: _context.args.offerRecipient,
            maximumFulfilled: context.args.nonAggregatableOfferOrderCount
        });

        if (_context.args.useTransferValidationZone) {
            assertTrue(zone.called());
            assertTrue(
                zone.callCount() == context.args.nonAggregatableOfferOrderCount
            );
        }

        for (
            uint256 i = 0;
            i < context.args.nonAggregatableOfferOrderCount;
            i++
        ) {
            assertEq(
                test721_1.ownerOf(_context.args.tokenId + i),
                _context.args.offerRecipient
            );
        }
    }

    function _buildOrderComponentsArrayFromFuzzArgs(
        Context memory context
    ) internal returns (OrderComponents[] memory _orderComponentsArray) {
        OrderComponents[] memory orderComponentsArray = new OrderComponents[](
            context.args.nonAggregatableOfferOrderCount
        );
        OfferItem[][] memory offerItemsArray = new OfferItem[][](
            context.args.nonAggregatableOfferOrderCount
        );
        ConsiderationItem[][]
            memory considerationItemsArray = new ConsiderationItem[][](
                context.args.nonAggregatableOfferOrderCount
            );

        {
            for (
                uint256 i;
                i < context.args.nonAggregatableOfferOrderCount;
                i++
            ) {
                offerItemsArray[i] = SeaportArrays.OfferItems(
                    OfferItemLib
                        .fromDefault(SINGLE_721)
                        .withToken(address(test721_1))
                        .withIdentifierOrCriteria(context.args.tokenId + i)
                );
                considerationItemsArray[i] = SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC20)
                        .withIdentifierOrCriteria(0)
                        .withToken(address(token1))
                        .withStartAmount(context.args.amount)
                        .withEndAmount(context.args.amount)
                        .withRecipient(context.args.considerationRecipient)
                );
            }
        }

        {
            address fuzzyZone;

            {
                // TestZone testZone;

                // if (context.args.useTransferValidationZone) {
                zone = new TestTransferValidationZoneOfferer(
                    context.args.offerRecipient
                );
                fuzzyZone = address(zone);
                // }
                // else {
                //     testZone = new TestZone();
                //     fuzzyZone = address(testZone);
                // }
            }
            {
                bytes32 conduitKey = context.args.useConduit
                    ? conduitKeyOne
                    : bytes32(0);
                OrderComponents memory orderComponents;
                for (
                    uint256 i = 0;
                    i < context.args.nonAggregatableOfferOrderCount;
                    i++
                ) {
                    OfferItem[][] memory _offerItemsArray = offerItemsArray;
                    ConsiderationItem[][]
                        memory _considerationItemsArray = considerationItemsArray;

                    orderComponents = OrderComponentsLib
                        .fromDefault(VALIDATION_ZONE)
                        .withOffer(_offerItemsArray[i])
                        .withConsideration(_considerationItemsArray[i])
                        .withZone(fuzzyZone)
                        .withZoneHash(context.args.zoneHash)
                        .withConduitKey(conduitKey)
                        .withSalt(context.args.salt); //  % (i + 1)

                    orderComponentsArray[i] = orderComponents;
                }
            }
        }

        return orderComponentsArray;
    }

    function _buildOrdersFromFuzzArgs(
        Context memory context,
        uint256 key
    ) internal returns (AdvancedOrder[] memory advancedOrders) {
        OrderComponents[]
            memory orderComponents = _buildOrderComponentsArrayFromFuzzArgs(
                context
            );

        AdvancedOrder[] memory _advancedOrders = new AdvancedOrder[](
            context.args.nonAggregatableOfferOrderCount
        );

        {
            Order memory order;
            for (uint256 i = 0; i < orderComponents.length; i++) {
                if (orderComponents[i].orderType == OrderType.CONTRACT) {
                    order = toUnsignedOrder(orderComponents[i]);
                    // TODO: REMOVE: Does this make sense?  Maybe revert here?
                    _advancedOrders[i] = order.toAdvancedOrder(1, 1, "");
                } else {
                    order = toOrder(context.seaport, orderComponents[i], key);
                    _advancedOrders[i] = order.toAdvancedOrder(1, 1, "");
                }
            }
        }

        return _advancedOrders;
    }

    function _buildFulfillmentsComponentsForMultipleOrders(
        uint256 numberOfOfferSideOrders,
        uint256 numberOfConsiderationSideOrders
    )
        internal
        view
        returns (
            FulfillmentComponent[][] memory _offerFulfillmentComponents,
            FulfillmentComponent[][] memory _considerationFulfillmentComponents
        )
    {
        FulfillmentComponent[][]
            memory offerFulfillmentComponents = new FulfillmentComponent[][](
                numberOfOfferSideOrders
            );
        FulfillmentComponent[][]
            memory considerationFulfillmentComponents = new FulfillmentComponent[][](
                numberOfConsiderationSideOrders
            );

        if (numberOfConsiderationSideOrders == 1) {
            if (numberOfOfferSideOrders == 1) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
                    );
            } else if (numberOfOfferSideOrders == 2) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__FIRST
                        )
                    );
            } else if (numberOfOfferSideOrders == 3) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD__FIRST
                        )
                    );
            } else if (numberOfOfferSideOrders == 4) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FOURTH_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD_FOURTH__FIRST
                        )
                    );
            } else if (numberOfOfferSideOrders == 5) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FOURTH_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIFTH_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD_FOURTH_FIFTH__FIRST
                        )
                    );
            }
        } else if (numberOfConsiderationSideOrders == 2) {
            if (numberOfOfferSideOrders == 1) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST),
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__SECOND
                        )
                    );
            } else if (numberOfOfferSideOrders == 2) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__FIRST
                        ),
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__SECOND
                        )
                    );
            } else if (numberOfOfferSideOrders == 3) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD__FIRST
                        ),
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__SECOND
                        )
                    );
            } else if (numberOfOfferSideOrders == 4) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FOURTH_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD_FOURTH__FIRST
                        ),
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__SECOND
                        )
                    );
            } else if (numberOfOfferSideOrders == 5) {
                offerFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIRST_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(SECOND_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(THIRD_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FOURTH_FIRST)
                        ),
                        SeaportArrays.FulfillmentComponents(
                            FulfillmentComponentLib.fromDefault(FIFTH_FIRST)
                        )
                    );
                considerationFulfillmentComponents = SeaportArrays
                    .FulfillmentComponentArrays(
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND_THIRD_FOURTH_FIFTH__FIRST
                        ),
                        FulfillmentComponentLib.fromDefaultMany(
                            FIRST_SECOND__SECOND
                        )
                    );
            }
        }

        return (offerFulfillmentComponents, considerationFulfillmentComponents);
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
        view
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

        // create fulfillments
        // offer fulfillments cannot be aggregated (cannot batch transfer 721s)
        // so there will be one array per order
        FulfillmentComponent[][] memory offerFulfillments = SeaportArrays
            .FulfillmentComponentArrays(
                // first FulfillmentComponents[] is single FulfillmentComponent
                // for test721_1 id 1
                FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST),
                // second FulfillmentComponents[] is single FulfillmentComponent
                // for test721_2 id 1
                FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
            );
        // consideration fulfillments can be aggregated (can batch transfer eth)
        // so there will be one array for both orders
        FulfillmentComponent[][]
            memory considerationFulfillments = SeaportArrays
                .FulfillmentComponentArrays(
                    // two-element fulfillmentcomponents array, one for each
                    // order
                    FulfillmentComponentLib.fromDefaultMany(FIRST_SECOND__FIRST)
                );

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
