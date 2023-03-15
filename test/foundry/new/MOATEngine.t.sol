// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";

import { MOATEngine, Structure, Type, Family } from "./helpers/MOATEngine.sol";

contract MOATEngineTest is BaseOrderTest {
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

    using MOATEngine for AdvancedOrder;
    using MOATEngine for AdvancedOrder[];

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

        assertEq(order.getStructure(), Structure.STANDARD);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

        assertEq(order.getStructure(), Structure.STANDARD);
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

        assertEq(order.getStructure(), Structure.ADVANCED);
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

    function assertEq(Family a, Family b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(Structure a, Structure b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(Type a, Type b) internal {
        assertEq(uint8(a), uint8(b));
    }
}
