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
    // Fulfillment fulfillment;
    // Fulfillment[] fulfillments;
    OrderParameters orderParameters;
    Order order;
    Order[] orders;
    Fulfillment fulfillment;
    FulfillmentComponent fulfillmentComponent;
    FulfillmentComponent[] fulfillmentComponents;

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
            Order memory _order,
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

        OrderParameters memory _orderParameters = OrderParameters(
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
        _order = Order(_orderParameters, signature);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareAdvancedOrder()
        internal
        returns (
            AdvancedOrder memory _order,
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

        OrderParameters memory _orderParameters = OrderParameters(
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
        _order = AdvancedOrder(_orderParameters, 1, 1, signature, "");
        criteriaResolvers = new CriteriaResolver[](0);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareFulfillAvailableOrders()
        internal
        returns (
            Order[] memory _orders,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureEthConsiderationItem(payable(reenterer), 1);
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
        firstOfferFulfillment.push(FulfillmentComponent(0, 0));
        offerFulfillments.push(firstOfferFulfillment);
        considerationFulfillments.push(firstOfferFulfillment);
        OrderParameters memory _orderParameters = OrderParameters(
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
            1
        );
        _offerFulfillments = offerFulfillments;
        _considerationFulfillments = considerationFulfillments;
        fulfillerConduitKey = bytes32(0);
        maximumFulfilled = 100;

        _orders = new Order[](1);
        _orders[0] = Order(_orderParameters, signature);
    }

    function prepareFullfillAvailableAdvancedOrders()
        internal
        returns (
            AdvancedOrder[] memory advancedOrders,
            CriteriaResolver[] memory criteriaResolvers,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {
        criteriaResolvers = new CriteriaResolver[](0);
        Order[] memory _orders;
        (
            _orders,
            _offerFulfillments,
            _considerationFulfillments,
            fulfillerConduitKey,
            maximumFulfilled
        ) = prepareFulfillAvailableOrders();
        advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = AdvancedOrder(
            _orders[0].parameters,
            1,
            1,
            _orders[0].signature,
            ""
        );
    }

    function prepareMatchOrders()
        internal
        returns (Order[] memory, Fulfillment[] memory)
    {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureEthConsiderationItem(payable(reenterer), 1);
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

        orderParameters.offerer = alice;
        orderParameters.zone = address(0);
        orderParameters.offer = offerItems;
        orderParameters.consideration = considerationItems;
        orderParameters.orderType = OrderType.FULL_OPEN;
        orderParameters.startTime = block.timestamp;
        orderParameters.endTime = block.timestamp + 1;
        orderParameters.zoneHash = bytes32(0);
        orderParameters.salt = 0;
        orderParameters.conduitKey = bytes32(0);
        orderParameters.totalOriginalConsiderationItems = 1;

        order.parameters = orderParameters;
        order.signature = signature;

        orders.push(order);

        delete offerItems;
        delete considerationItems;
        _configureEthOfferItem(1);
        _configureErc721ConsiderationItem(alice, 1);
        nonce = referenceConsideration.getNonce(address(bob));
        orderComponents.offerer = bob;
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

        bytes32 mirrorOrderHash = referenceConsideration.getOrderHash(
            orderComponents
        );
        bytes memory mirrorSignature = signOrder(
            referenceConsideration,
            bobPk,
            mirrorOrderHash
        );
        orderParameters.offerer = bob;
        orderParameters.zone = address(0);
        orderParameters.offer = offerItems;
        orderParameters.consideration = considerationItems;
        orderParameters.orderType = OrderType.FULL_OPEN;
        orderParameters.startTime = block.timestamp;
        orderParameters.endTime = block.timestamp + 1;
        orderParameters.zoneHash = bytes32(0);
        orderParameters.salt = 0;
        orderParameters.conduitKey = bytes32(0);
        orderParameters.totalOriginalConsiderationItems = 1;

        order.parameters = orderParameters;
        order.signature = mirrorSignature;
        orders.push(order);

        // map order offer to mirror consideration
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        // push fulfillment
        fulfillments.push(fulfillment);

        // clear working fulfillment
        delete fulfillment;

        // map mirror offer to order consideration
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.offerComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        fulfillment.considerationComponents = fulfillmentComponents;
        fulfillments.push(fulfillment);

        return (orders, fulfillments);
    }

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
        reenterer = new ReentrantContract();
        reenterer.setConsideration(context.consideration);
        reenterer.setReentrancyPoint(context.args.reentrancyPoint);
        reenterer.setReenter(true);
        if (context.args.entryPoint == EntryPoint.FulfillBasicOrder) {
            _setUpReenterer(context);
            prepareBasicOrderParameters(context);
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillBasicOrder{ value: 1 }(
                basicOrderParameters
            );
        } else if (context.args.entryPoint == EntryPoint.FulfillOrder) {
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
            (
                AdvancedOrder memory _order,
                CriteriaResolver[] memory criteriaResolvers,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareAdvancedOrder();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillAdvancedOrder{ value: value }(
                _order,
                criteriaResolvers,
                fulfillerConduitKey
            );
        } else if (
            context.args.entryPoint == EntryPoint.FulfillAvailableOrders
        ) {
            (
                Order[] memory _orders,
                FulfillmentComponent[][] memory _offerFulfillments,
                FulfillmentComponent[][] memory _considerationFulfillments,
                bytes32 fulfillerConduitKey,
                uint256 maximumFulfilled
            ) = prepareFulfillAvailableOrders();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillAvailableOrders{ value: 1 }(
                _orders,
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
            ) = prepareFullfillAvailableAdvancedOrders();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillAvailableAdvancedOrders{ value: 1 }(
                advancedOrders,
                criteriaResolvers,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
        } else if (context.args.entryPoint == EntryPoint.MatchOrders) {
            (
                Order[] memory _orders,
                Fulfillment[] memory _fulfillments
            ) = prepareMatchOrders();
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.matchOrders{ value: 1 }(
                _orders,
                _fulfillments
            );
        } /**else if (context.args.entryPoint == EntryPoint.MatchAdvancedOrders) {
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
