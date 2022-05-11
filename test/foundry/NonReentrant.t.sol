// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { AdditionalRecipient, Fulfillment, OfferItem, ConsiderationItem, FulfillmentComponent, OrderComponents, AdvancedOrder, BasicOrderParameters, Order } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { ReentrantContract } from "./utils/reentrancy/ReentrantContract.sol";
import { EntryPoint, ReentrancyPoint } from "./utils/reentrancy/ReentrantEnums.sol";
import { FulfillBasicOrderParameters, FulfillOrderParameters, OrderParameters, FulfillAdvancedOrderParameters, FulfillAvailableOrdersParameters, FulfillAvailableAdvancedOrdersParameters, MatchOrdersParameters, MatchAdvancedOrdersParameters, CancelParameters, ValidateParameters, ReentrantCallParameters, CriteriaResolver } from "./utils/reentrancy/ReentrantStructs.sol";

contract NonReentrantTest is BaseOrderTest {
    ReentrantContract reenterer;
    BasicOrderParameters basicOrderParameters;
    OrderComponents orderComponents;
    AdditionalRecipient recipient;
    AdditionalRecipient[] additionalRecipients;

    /**
     * @dev Foundry fuzzes enums as uints, so we need to manually fuzz on uints and use vm.assume
     * to filter out invalid values
     */
    struct FuzzInputs {
        uint8 entryPoint;
        uint8 reentrancyPoint;
    }

    /**
     * @dev struct to test combinations of entrypoints and reentrancy points
     */
    struct NonReentrantInputs {
        EntryPoint entryPoint;
        ReentrancyPoint reentrancyPoint;
    }

    struct NonReentrant {
        Consideration consideration;
        NonReentrantInputs args;
    }

    event BytesReason(bytes data);

    function _setUpBasicOrderParameters() internal {
        basicOrderParameters.considerationToken = address(0);
        basicOrderParameters.considerationIdentifier = 0;
        basicOrderParameters.considerationAmount = 1;
        basicOrderParameters.offerer = payable(alice);
        basicOrderParameters.zone = address(1);
        basicOrderParameters.offerToken = address(test721_1);
        basicOrderParameters.offerIdentifier = 1;
        basicOrderParameters.offerAmount = 1;
        basicOrderParameters.basicOrderType = BasicOrderType
            .ETH_TO_ERC721_FULL_OPEN;
        basicOrderParameters.startTime = block.timestamp;
        basicOrderParameters.endTime = block.timestamp + 1;
        basicOrderParameters.zoneHash = bytes32(0);
        basicOrderParameters.salt = 0;
        basicOrderParameters.offererConduitKey = bytes32(0);
        basicOrderParameters.fulfillerConduitKey = bytes32(0);
        basicOrderParameters.totalOriginalAdditionalRecipients = 0;
        // don't set additional recipients
        // don't set signature
    }

    function _setUpOrderComponents() internal {
        orderComponents.offerer = basicOrderParameters.offerer;
        orderComponents.zone = basicOrderParameters.zone;
        // don't set offer items
        // don't set consideration items
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = basicOrderParameters.startTime;
        orderComponents.endTime = basicOrderParameters.endTime;
        orderComponents.zoneHash = basicOrderParameters.zoneHash;
        orderComponents.salt = basicOrderParameters.salt;
        orderComponents.conduitKey = basicOrderParameters.offererConduitKey;
        // don't set nonce
    }

    function setUp() public virtual override {
        super.setUp();
        _setUpBasicOrderParameters();
        _setUpOrderComponents();
    }

    function testNonReentrant(FuzzInputs memory _inputs) public {
        vm.assume(_inputs.entryPoint < 7 && _inputs.reentrancyPoint < 10);
        vm.assume(
            ReentrancyPoint(_inputs.reentrancyPoint) ==
                ReentrancyPoint.FulfillBasicOrder ||
                ReentrancyPoint(_inputs.reentrancyPoint) ==
                ReentrancyPoint.FulfillAdvancedOrder ||
                ReentrancyPoint(_inputs.reentrancyPoint) ==
                ReentrancyPoint.FulfillOrder
        );
        NonReentrantInputs memory inputs = NonReentrantInputs(
            EntryPoint(_inputs.entryPoint),
            ReentrancyPoint(_inputs.reentrancyPoint)
        );
        // _testNonReentrant(NonReentrant(consideration, inputs));
        _testNonReentrant(NonReentrant(referenceConsideration, inputs));
    }

    function prepareBasicOrderParameters(NonReentrant memory context) internal {
        test721_1.mint(address(alice), 1);

        offerItems.push(
            OfferItem(
                ItemType.ERC721, // ItemType
                address(test721_1), // token
                1, // identifier
                1, // start amt
                1 // end amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE, // ItemType
                address(0), // Token
                0, // identifier
                1, // start amount
                1, // end amout
                payable(alice) // recipient
            )
        );

        uint256 nonce = context.consideration.getNonce(address(alice)); //beepboopbeepboop

        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.nonce = nonce;

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );
        basicOrderParameters.signature = signature;
    }

    function prepareOrder()
        internal
        returns (
            Order memory order,
            bytes32 fulfillerConduitKey,
            uint256 value
        )
    {
        test1155_1.mint(alice, 1, 10);

        _configureERC1155OfferItem(1, uint256(10));
        _configureEthConsiderationItem(alice, uint256(10));
        _configureEthConsiderationItem(payable(address(0)), uint256(10));
        _configureEthConsiderationItem(payable(reenterer), uint256(10));
        uint256 nonce = referenceConsideration.getNonce(alice);
        orderComponents.offerer = alice;
        orderComponents.zone = address(0);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = 0;
        orderComponents.conduitKey = bytes32(0);
        orderComponents.nonce = nonce;

        bytes32 orderHash = referenceConsideration.getOrderHash(
            orderComponents
        );

        bytes memory signature = signOrder(
            referenceConsideration,
            alicePk,
            orderHash
        );

        OrderParameters memory orderParameters = OrderParameters(
            alice,
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            3
        );
        value = 30;
        order = Order(orderParameters, signature);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareAdvancedOrder()
        internal
        returns (
            AdvancedOrder memory order,
            CriteriaResolver[] memory criteriaResolvers,
            bytes32 fulfillerConduitKey,
            uint256 value
        )
    {
        test1155_1.mint(alice, 1, 10);

        _configureERC1155OfferItem(1, uint256(10));
        _configureEthConsiderationItem(alice, uint256(10));
        _configureEthConsiderationItem(payable(address(0)), uint256(10));
        _configureEthConsiderationItem(payable(reenterer), uint256(10));
        uint256 nonce = referenceConsideration.getNonce(alice);
        orderComponents.offerer = alice;
        orderComponents.zone = address(0);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.PARTIAL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = 0;
        orderComponents.conduitKey = bytes32(0);
        orderComponents.nonce = nonce;

        bytes32 orderHash = referenceConsideration.getOrderHash(
            orderComponents
        );

        bytes memory signature = signOrder(
            referenceConsideration,
            alicePk,
            orderHash
        );

        OrderParameters memory orderParameters = OrderParameters(
            alice,
            address(0),
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            3
        );
        value = 30;
        order = AdvancedOrder(orderParameters, 1, 1, signature, "");
        criteriaResolvers = new CriteriaResolver[](0);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareFulfillAvailableOrders(NonReentrant memory context)
        internal
        returns (
            Order[] memory orders,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureErc20ConsiderationItem(payable(reenterer), 1);
    }

    function prepareFullfillAvailableAdvancedOrders(NonReentrant memory context)
        internal
        returns (
            AdvancedOrder[] memory advancedOrders,
            CriteriaResolver[] memory criteriaResolvers,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {}

    function prepareMatchOrders(NonReentrant memory context)
        internal
        returns (Order[] memory orders, Fulfillment[] memory fulfillments)
    {}

    function prepareMatchAdvancedOrders(NonReentrant memory context)
        internal
        returns (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory criteriaResolvers,
            Fulfillment[] memory fulfillments
        )
    {}

    function _setUpReenterer(NonReentrant memory context) internal {
        reenterer = new ReentrantContract();
        vm.etch(alice, address(reenterer).code);
        reenterer = ReentrantContract(payable(alice));
        reenterer.setConsideration(context.consideration);
        reenterer.setReentrancyPoint(context.args.reentrancyPoint);
        reenterer.setReenter(true);
    }

    function _testNonReentrant(NonReentrant memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        if (context.args.entryPoint == EntryPoint.FulfillBasicOrder) {
            _setUpReenterer(context);
            prepareBasicOrderParameters(context);
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillBasicOrder{ value: 1 }(
                basicOrderParameters
            );
        } else if (context.args.entryPoint == EntryPoint.FulfillOrder) {
            reenterer = new ReentrantContract();
            reenterer.setConsideration(context.consideration);
            reenterer.setReentrancyPoint(context.args.reentrancyPoint);
            reenterer.setReenter(true);
            (
                Order memory params,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareOrder();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillOrder{ value: value }(
                params,
                fulfillerConduitKey
            );
        } else if (context.args.entryPoint == EntryPoint.FulfillAdvancedOrder) {
            reenterer = new ReentrantContract();
            reenterer.setConsideration(context.consideration);
            reenterer.setReentrancyPoint(context.args.reentrancyPoint);
            reenterer.setReenter(true);
            (
                AdvancedOrder memory order,
                CriteriaResolver[] memory criteriaResolvers,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareAdvancedOrder();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillAdvancedOrder{ value: value }(
                order,
                criteriaResolvers,
                fulfillerConduitKey
            );
        } /**  else if (
            context.args.entryPoint == EntryPoint.FulfillAvailableOrders
        ) {
            (
                Order[] memory orders,
                FulfillmentComponent[][] memory _offerFulfillments,
                FulfillmentComponent[][] memory _considerationFulfillments,
                bytes32 fulfillerConduitKey,
                uint256 maximumFulfilled
            ) = prepareFulfillAvailableOrders(context);
            context.consideration.fulfillAvailableOrders(
                orders,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
        } else if (
            context.args.entryPoint == EntryPoint.FulfillAvailableAdvancedOrders
        ) {
            (
                AdvancedOrder[] memory advancedOrders,
                CriteriaResolver[] memory criteriaResolvers,
                FulfillmentComponent[][] memory _offerFulfillments,
                FulfillmentComponent[][] memory _considerationFulfillments,
                bytes32 fulfillerConduitKey,
                uint256 maximumFulfilled
            ) = prepareFullfillAvailableAdvancedOrders(context);
            context.consideration.fulfillAvailableAdvancedOrders(
                advancedOrders,
                criteriaResolvers,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
        } else if (context.args.entryPoint == EntryPoint.MatchOrders) {
            (
                Order[] memory orders,
                Fulfillment[] memory fulfillments
            ) = prepareMatchOrders(context);
            context.consideration.matchOrders(orders, fulfillments);
        } else if (context.args.entryPoint == EntryPoint.MatchAdvancedOrders) {
            (
                AdvancedOrder[] memory orders,
                CriteriaResolver[] memory criteriaResolvers,
                Fulfillment[] memory fulfillments
            ) = prepareMatchAdvancedOrders(context);
            context.consideration.matchAdvancedOrders(
                orders,
                criteriaResolvers,
                fulfillments
            );
        }
        */
    }
}
