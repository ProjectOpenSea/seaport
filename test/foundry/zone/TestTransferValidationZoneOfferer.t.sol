// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import {
    ConsiderationItem,
    OfferItem,
    ItemType,
    OrderType,
    AdvancedOrder,
    Order,
    CriteriaResolver,
    BasicOrderParameters,
    AdditionalRecipient,
    FulfillmentComponent,
    Fulfillment,
    OrderComponents,
    OrderParameters
} from "../../../contracts/lib/ConsiderationStructs.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    FulfillmentLib,
    FulfillmentComponentLib,
    OrderParametersLib,
    OrderComponentsLib,
    OrderLib,
    OfferItemLib,
    ConsiderationItemLib,
    SeaportArrays
} from "../../../contracts/helpers/sol/lib/SeaportStructLib.sol";
import {
    TestTransferValidationZoneOfferer
} from "../../../contracts/test/TestTransferValidationZoneOfferer.sol";

contract TestTransferValidationZoneOffererTest is BaseOrderTest {
    using FulfillmentLib for Fulfillment;
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;
    using OrderLib for Order[];

    TestTransferValidationZoneOfferer zone;

    // constant strings for recalling struct lib "defaults"
    // ideally these live in a base test class
    string constant ONE_ETH = "one eth";
    string constant SINGLE_721 = "single 721";
    string constant VALIDATION_ZONE = "validation zone";
    string constant FIRST_FIRST = "first first";
    string constant SECOND_FIRST = "second first";
    string constant FIRST_SECOND__FIRST = "first&second first";
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

        // create a one-element array comtaining first_first
        SeaportArrays.FulfillmentComponents(firstFirst).saveDefaultMany(
            FIRST_FIRST
        );
        // create a one-element array comtaining second_first
        SeaportArrays.FulfillmentComponents(secondFirst).saveDefaultMany(
            SECOND_FIRST
        );

        // create a two-element array comtaining first_first and second_first
        SeaportArrays
            .FulfillmentComponents(firstFirst, secondFirst)
            .saveDefaultMany(FIRST_SECOND__FIRST);
    }

    struct Context {
        ConsiderationInterface seaport;
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

    function testAggregate() public {
        prepareAggregate();

        test(this.execAggregate, Context({ seaport: consideration }));
        test(this.execAggregate, Context({ seaport: referenceConsideration }));
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
            Context({ seaport: consideration })
        );
        test(
            this.execMatchContractOrdersWithConduit,
            Context({ seaport: referenceConsideration })
        );
    }

    function execMatchContractOrdersWithConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            bytes32 conduitKey,
            uint256 numOrders
        ) = _buildFulfillmentDataMirrorContractOrders(context);

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchOrders{ value: 2 ether }({
            orders: orders,
            fulfillments: fulfillments
        });
    }

    function testMatchOpenAndContractOrdersWithConduit() public {
        test(
            this.execMatchOpenAndContractOrdersWithConduit,
            Context({ seaport: consideration })
        );
        test(
            this.execMatchOpenAndContractOrdersWithConduit,
            Context({ seaport: referenceConsideration })
        );
    }

    function execMatchOpenAndContractOrdersWithConduit(
        Context memory context
    ) external stateless {
        (
            Order[] memory orders,
            Fulfillment[] memory fulfillments,
            bytes32 conduitKey,
            uint256 numOrders
        ) = _buildFulfillmentDataOpenOrderAndMirrorContractOrder(context);

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.seaport.matchOrders{ value: 2 ether }({
            orders: orders,
            fulfillments: fulfillments
        });
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
                orders[i] = toUnsignedOrder(
                    context.seaport,
                    orderComponents[i]
                );
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
        // offer fulfillments cannot be aggregated (cannot batch transfer 721s) so there will be one array per order
        FulfillmentComponent[][] memory offerFulfillments = SeaportArrays
            .FulfillmentComponentArrays(
                // first FulfillmentComponents[] is single FulfillmentComponent for test721_1 id 1
                FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST),
                // second FulfillmentComponents[] is single FulfillmentComponent for test721_2 id 1
                FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
            );
        // consideration fulfillments can be aggregated (can batch transfer eth) so there will be one array for both orders
        FulfillmentComponent[][]
            memory considerationFulfillments = SeaportArrays
                .FulfillmentComponentArrays(
                    // two-element fulfillmentcomponents array, one for each order
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

        transferValidationOfferer1.setExpectedRecipient(
            address(transferValidationOfferer2)
        );
        transferValidationOfferer2.setExpectedRecipient(
            address(transferValidationOfferer1)
        );

        vm.label(address(transferValidationOfferer1), "offerer1");
        vm.label(address(transferValidationOfferer2), "offerer2");

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

    function _buildFulfillmentDataOpenOrderAndMirrorContractOrder(
        Context memory context
    )
        internal
        returns (Order[] memory, Fulfillment[] memory, bytes32, uint256)
    {
        // Create contract offerer
        TestTransferValidationZoneOfferer transferValidationOfferer1 = new TestTransferValidationZoneOfferer(
                address(0)
            );

        transferValidationOfferer1.setExpectedRecipient(offerer1.addr);

        vm.label(address(transferValidationOfferer1), "contractOfferer");

        // Mint 721 to contract offerer 1
        test721_1.mint(address(transferValidationOfferer1), 1);

        allocateTokensAndApprovals(
            address(transferValidationOfferer1),
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
        ConsiderationInterface seaport,
        OrderComponents memory orderComponents
    ) internal view returns (Order memory order) {
        order = OrderLib.empty().withParameters(
            orderComponents.toOrderParameters()
        );
    }
}
