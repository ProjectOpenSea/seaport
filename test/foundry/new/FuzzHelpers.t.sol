// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";

import "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    Family,
    FuzzHelpers,
    State,
    Structure,
    Type
} from "./helpers/FuzzHelpers.sol";

contract FuzzHelpersTest is BaseOrderTest {
    using AdvancedOrderLib for AdvancedOrder;
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using FulfillmentLib for Fulfillment;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    function setUp() public virtual override {
        super.setUp();

        OrderParameters memory standardOrderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters();

        OrderLib.empty().withParameters(standardOrderParameters).saveDefault(
            STANDARD
        );
    }

    /// @dev An order with no advanced order parameters is STANDARD
    function test_getStructure_Standard() public {
        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.STANDARD);
    }

    /// @dev An order with no advanced order parameters that meets various
    ///      criteria is BASIC.
    function test_getStructure_Basic() public {
        erc721s[0].mint(offerer1.addr, 1);

        OfferItem[] memory offerItems = new OfferItem[](1);
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);

        offerItems[0] = offerItem;

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(1);

        considerationItems[0] = considerationItem;

        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems);

        Order memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(
                orderComponents.toOrderParameters().withOrderType(
                    OrderType.FULL_OPEN
                )
            )
            .withSignature("");

        AdvancedOrder memory advancedOrder = order.toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        assertEq(advancedOrder.getStructure(address(seaport)), Structure.BASIC);
    }

    /// @dev An order with numerator, denominator, or extraData is ADVANCED
    function test_getStructure_Advanced(
        uint120 numerator,
        uint120 denominator,
        bytes memory extraData
    ) public {
        vm.assume(numerator != 0);
        vm.assume(denominator != 0);
        vm.assume(extraData.length != 0);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: numerator,
                denominator: denominator,
                extraData: extraData
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev A non-contract order with offer item criteria is ADVANCED
    function test_getStructure_Advanced_OfferERC721Criteria() public {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib.empty().withItemType(
            ItemType.ERC721_WITH_CRITERIA
        );

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev A non-contract order with offer item criteria is ADVANCED
    function test_getStructure_Advanced_OfferERC1155Criteria() public {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib.empty().withItemType(
            ItemType.ERC1155_WITH_CRITERIA
        );

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev A non-contract order with consideration item criteria is ADVANCED
    function test_getStructure_Advanced_ConsiderationERC721Criteria() public {
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItemLib.empty().withItemType(
            ItemType.ERC721_WITH_CRITERIA
        );

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withConsideration(consideration);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev A non-contract order with consideration item criteria is ADVANCED
    function test_getStructure_Advanced_ConsiderationERC1155Criteria() public {
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItemLib.empty().withItemType(
            ItemType.ERC1155_WITH_CRITERIA
        );

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withConsideration(consideration);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev A contract order with consideration item criteria is STANDARD if
    ///      identifierOrCriteria == 0 for all items
    function test_getStructure_Standard_ConsiderationCriteria_ContractOrder()
        public
    {
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItemLib.empty().withItemType(
            ItemType.ERC721_WITH_CRITERIA
        );

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withConsideration(consideration)
            .withOrderType(OrderType.CONTRACT);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.STANDARD);
    }

    /// @dev A contract order with consideration item criteria is ADVANCED if
    ///      identifierOrCriteria != 0 for any item
    function test_getStructure_Advanced_ConsiderationCriteria_ContractOrder()
        public
    {
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721_WITH_CRITERIA)
            .withIdentifierOrCriteria(1);

        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withConsideration(consideration)
            .withOrderType(OrderType.CONTRACT);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getStructure(address(seaport)), Structure.ADVANCED);
    }

    /// @dev An order with type FULL_OPEN is OPEN
    function test_getType_FullOpen() public {
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOrderType(OrderType.FULL_OPEN);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getType(), Type.OPEN);
    }

    /// @dev An order with type PARTIAL_OPEN is OPEN
    function test_getType_PartialOpen() public {
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOrderType(OrderType.PARTIAL_OPEN);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getType(), Type.OPEN);
    }

    /// @dev An order with type FULL_RESTRICTED is RESTRICTED
    function test_getType_FullRestricted() public {
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOrderType(OrderType.FULL_RESTRICTED);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getType(), Type.RESTRICTED);
    }

    /// @dev An order with type PARTIAL_RESTRICTED is RESTRICTED
    function test_getType_PartialRestricted() public {
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOrderType(OrderType.PARTIAL_RESTRICTED);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getType(), Type.RESTRICTED);
    }

    /// @dev An order with type CONTRACT is CONTRACT
    function test_getType_Contract() public {
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOrderType(OrderType.CONTRACT);

        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getType(), Type.CONTRACT);
    }

    /// @dev A validated order is in state VALIDATED
    function test_getState_ValidatedOrder() public {
        uint256 counter = seaport.getCounter(offerer1.addr);
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withCounter(counter)
            .withOrderType(OrderType.FULL_OPEN)
            .toOrderParameters();
        bytes32 orderHash = seaport.getOrderHash(
            orderParameters.toOrderComponents(counter)
        );

        Order[] memory orders = new Order[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .withSignature(signOrder(seaport, offerer1.key, orderHash));

        assertEq(seaport.validate(orders), true);

        AdvancedOrder memory order = orders[0].toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        assertEq(order.getState(seaport), State.VALIDATED);
    }

    /// @dev A cancelled order is in state CANCELLED
    function test_getState_CancelledOrder() public {
        uint256 counter = seaport.getCounter(offerer1.addr);
        OrderParameters memory orderParameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withCounter(counter)
            .withOrderType(OrderType.FULL_OPEN)
            .toOrderParameters();
        bytes32 orderHash = seaport.getOrderHash(
            orderParameters.toOrderComponents(counter)
        );

        Order[] memory orders = new Order[](1);
        orders[0] = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderParameters)
            .withSignature(signOrder(seaport, offerer1.key, orderHash));

        OrderComponents[] memory orderComponents = new OrderComponents[](1);
        orderComponents[0] = orderParameters.toOrderComponents(counter);

        assertEq(seaport.validate(orders), true);

        vm.prank(offerer1.addr);
        assertEq(seaport.cancel(orderComponents), true);

        AdvancedOrder memory order = orders[0].toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        assertEq(order.getState(seaport), State.CANCELLED);
    }

    /// @dev A new order is in state UNUSED
    function test_getState_NewOrder() public {
        AdvancedOrder memory order = OrderLib
            .fromDefault(STANDARD)
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });

        assertEq(order.getState(seaport), State.UNUSED);
    }

    /// @dev An order[] quantity is its length
    function test_getQuantity(uint8 n) public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](n);

        for (uint256 i; i < n; ++i) {
            orders[i] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });
        }

        assertEq(orders.getQuantity(), n);
    }

    /// @dev An order[] of quantity 1 uses a SINGLE family method
    function test_getFamily_Single() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);

        orders[0] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
            numerator: 0,
            denominator: 0,
            extraData: bytes("")
        });

        assertEq(orders.getFamily(), Family.SINGLE);
    }

    /// @dev An order[] of quantity > 1 uses a COMBINED family method
    function test_getFamily_Combined(uint8 n) public {
        vm.assume(n > 1);
        AdvancedOrder[] memory orders = new AdvancedOrder[](n);

        for (uint256 i; i < n; ++i) {
            orders[i] = OrderLib.fromDefault(STANDARD).toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });
        }

        assertEq(orders.getFamily(), Family.COMBINED);
    }

    function _createOrder(
        ItemType offerItemType,
        ItemType considerationItemType,
        OrderType orderType
    ) internal view returns (AdvancedOrder memory order) {
        bool nftOffered = offerItemType == ItemType.ERC721 ||
            offerItemType == ItemType.ERC1155;

        OfferItem[] memory offerItems = new OfferItem[](1);
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(offerItemType)
            .withToken(nftOffered ? address(erc721s[0]) : address(0))
            .withIdentifierOrCriteria(nftOffered ? 1 : 0)
            .withAmount(1);

        offerItems[0] = offerItem;

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(considerationItemType)
            .withIdentifierOrCriteria(nftOffered ? 0 : 1)
            .withAmount(1);

        considerationItems[0] = considerationItem;

        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems)
            .withOrderType(orderType);

        order = OrderLib
            .fromDefault(STANDARD)
            .withParameters(orderComponents.toOrderParameters())
            .toAdvancedOrder({
                numerator: 0,
                denominator: 0,
                extraData: bytes("")
            });
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC721
     *      item. No partial fills, anyone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC721_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.NATIVE,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC721
     *      item. Partial fills supported, anyone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC721_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.NATIVE,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC721_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC721
     *      item. No partial fills, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC721_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.NATIVE,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC721_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC721
     *      item. Partial fills supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC721_PARTIAL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.NATIVE,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC721_PARTIAL_RESTRICTED
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC1155
     *      item. No partial fills, anyone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC1155_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.NATIVE,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC1155
     *      item. Partial fills supported, anyone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC1155_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.NATIVE,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC1155
     *      item. No partial fills, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC1155_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.NATIVE,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC1155_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide Ether (or other native token) to receive offered ERC1155
     *      item. Partial fills supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ETH_TO_ERC1155_PARTIAL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.NATIVE,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC721 item. No partial fills,
     *      anyone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC721_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.ERC20,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC721 item. Partial fills
     *      supported, anyone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC721_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.ERC20,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC721 item. No partial fills,
     *      only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC721_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.ERC20,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC721_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC721 item. Partial fills
     *      supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC721_PARTIAL_RESTRICTED()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC721,
            ItemType.ERC20,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC1155 item. no partial
     *      fills, anyone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC1155_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.ERC20,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC1155 item. Partial fills
     *      supported, anyone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC1155_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.ERC20,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC1155 item. no partial
     *      fills, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC1155_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.ERC20,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC1155_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC20 item to receive offered ERC1155 item. Partial fills
     *      supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC20_TO_ERC1155_PARTIAL_RESTRICTED()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC1155,
            ItemType.ERC20,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC721 item to receive offered ERC20 item. No partial fills,
     *      anyone can execute.
     */
    function test_getBasicOrderType_ERC721_TO_ERC20_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC721,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC721_TO_ERC20_FULL_OPEN
        );
    }

    /**
     * @dev Provide ERC721 item to receive offered ERC20 item. Partial fills
     *      supported, anyone can execute.
     */
    function test_getBasicOrderType_ERC721_TO_ERC20_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC721,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide ERC721 item to receive offered ERC20 item. No partial fills,
     *      only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC721_TO_ERC20_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC721,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC721 item to receive offered ERC20 item. Partial fills
     *      supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC721_TO_ERC20_PARTIAL_RESTRICTED()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC721,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC1155 item to receive offered ERC20 item. no partial
     *      fills, anyone can execute.
     */
    function test_getBasicOrderType_ERC1155_TO_ERC20_FULL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.FULL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC1155_TO_ERC20_FULL_OPEN
        );
    }

    /**
     * @dev Provide ERC1155 item to receive offered ERC20 item. Partial fills
     *      supported, anyone can execute.
     */
    function test_getBasicOrderType_ERC1155_TO_ERC20_PARTIAL_OPEN() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_OPEN
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_OPEN
        );
    }

    /**
     * @dev Provide ERC1155 item to receive offered ERC20 item. no partial
     *      fills, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC1155_TO_ERC20_FULL_RESTRICTED() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.FULL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC1155_TO_ERC20_FULL_RESTRICTED
        );
    }

    /**
     * @dev Provide ERC1155 item to receive offered ERC20 item. Partial fills
     *      supported, only offerer or zone can execute.
     */
    function test_getBasicOrderType_ERC1155_TO_ERC20_PARTIAL_RESTRICTED()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        order.getBasicOrderTypeEligibility(address(seaport));
        assertEq(
            order.getBasicOrderType(),
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_RESTRICTED
        );
    }

    function test_getBasicOrderTypeEligibility_failure_criteria() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        order.parameters.consideration[0].itemType = ItemType
            .ERC1155_WITH_CRITERIA;

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));
    }

    function test_getBasicOrderTypeEligibility_failure_extraData() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        order.extraData = bytes("extraData");

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));
    }

    function test_getBasicOrderTypeEligibility_failure_offerItemLength()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        OfferItem[] memory offer = new OfferItem[](2);

        offer[0] = order.parameters.offer[0];
        offer[1] = order.parameters.offer[0];

        order.parameters.offer = offer;

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));

        order.parameters.offer = new OfferItem[](0);

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));
    }

    function test_getBasicOrderTypeEligibility_failure_considerationItemLength()
        public
    {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        order.parameters.consideration = new ConsiderationItem[](0);

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));
    }

    function test_getBasicOrderTypeEligibility_failure_nftCount() public {
        AdvancedOrder memory order = _createOrder(
            ItemType.ERC20,
            ItemType.ERC1155,
            OrderType.PARTIAL_RESTRICTED
        );

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0].itemType = ItemType.ERC721;

        order.parameters.offer = offer;

        assertFalse(order.getBasicOrderTypeEligibility(address(seaport)));
    }

    function assertEq(State a, State b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(Family a, Family b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(Structure a, Structure b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(Type a, Type b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(BasicOrderType a, BasicOrderType b) internal {
        assertEq(uint8(a), uint8(b));
    }
}
