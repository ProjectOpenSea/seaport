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

    struct Context {
        Consideration consideration;
        NonReentrantInputs args;
    }

    event BytesReason(bytes data);

    function setUp() public virtual override {
        super.setUp();
    }

    function getOrderParameters(address payable offerer, OrderType orderType)
        internal
        view
        returns (OrderParameters memory)
    {
        return
            OrderParameters(
                offerer,
                address(0),
                offerItems,
                considerationItems,
                orderType,
                block.timestamp,
                block.timestamp + 1,
                bytes32(0),
                0,
                bytes32(0),
                considerationItems.length
            );
    }

    function testNonReentrant(FuzzInputs memory _inputs) public {
        vm.assume(_inputs.entryPoint < 7 && _inputs.reentrancyPoint < 10);

        NonReentrantInputs memory inputs = NonReentrantInputs(
            EntryPoint(_inputs.entryPoint),
            ReentrancyPoint(_inputs.reentrancyPoint)
        );
        // _testNonReentrant(NonReentrant(consideration, inputs));
        _testNonReentrant(Context(referenceConsideration, inputs));
    }

    function prepareBasicOrder(Context memory context)
        internal
        returns (BasicOrderParameters memory _basicOrderParameters)
    {
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

        uint256 nonce = context.consideration.getNonce(address(alice));

        orderComponents.offerer = payable(alice);
        orderComponents.zone = address(1);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = 0;
        orderComponents.conduitKey = bytes32(0);
        orderComponents.nonce = nonce;

        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );
        return
            toBasicOrderParameters(
                orderComponents,
                BasicOrderType.ETH_TO_ERC721_FULL_OPEN,
                signature
            );
    }

    function prepareOrder(Context memory context)
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
        uint256 nonce = context.consideration.getNonce(alice);

        OrderParameters memory _orderParameters = getOrderParameters(
            alice,
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
        );

        bytes32 orderHash = context.consideration.getOrderHash(
            _orderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );
        value = 30;
        _order = Order(_orderParameters, signature);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareAdvancedOrder(Context memory context)
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
        uint256 nonce = context.consideration.getNonce(alice);
        OrderParameters memory _orderParameters = getOrderParameters(
            alice,
            OrderType.PARTIAL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
        );

        bytes32 orderHash = context.consideration.getOrderHash(
            _orderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        value = 30;
        _order = AdvancedOrder(_orderParameters, 1, 1, signature, "");
        criteriaResolvers = new CriteriaResolver[](0);
        fulfillerConduitKey = bytes32(0);
    }

    function toOrderComponents(OrderParameters memory _params, uint256 nonce)
        internal
        pure
        returns (OrderComponents memory)
    {
        return
            OrderComponents(
                _params.offerer,
                _params.zone,
                _params.offer,
                _params.consideration,
                _params.orderType,
                _params.startTime,
                _params.endTime,
                _params.zoneHash,
                _params.salt,
                _params.conduitKey,
                nonce
            );
    }

    function toBasicOrderParameters(
        Order memory _order,
        BasicOrderType basicOrderType
    ) internal pure returns (BasicOrderParameters memory) {
        return
            BasicOrderParameters(
                _order.parameters.consideration[0].token,
                _order.parameters.consideration[0].identifierOrCriteria,
                _order.parameters.consideration[0].endAmount,
                payable(_order.parameters.offerer),
                _order.parameters.zone,
                _order.parameters.offer[0].token,
                _order.parameters.offer[0].identifierOrCriteria,
                _order.parameters.offer[0].endAmount,
                basicOrderType,
                _order.parameters.startTime,
                _order.parameters.endTime,
                _order.parameters.zoneHash,
                _order.parameters.salt,
                _order.parameters.conduitKey,
                bytes32(0),
                0,
                new AdditionalRecipient[](0),
                _order.signature
            );
    }

    function toBasicOrderParameters(
        OrderComponents memory _order,
        BasicOrderType basicOrderType,
        bytes memory signature
    ) internal pure returns (BasicOrderParameters memory) {
        return
            BasicOrderParameters(
                _order.consideration[0].token,
                _order.consideration[0].identifierOrCriteria,
                _order.consideration[0].endAmount,
                payable(_order.offerer),
                _order.zone,
                _order.offer[0].token,
                _order.offer[0].identifierOrCriteria,
                _order.offer[0].endAmount,
                basicOrderType,
                _order.startTime,
                _order.endTime,
                _order.zoneHash,
                _order.salt,
                _order.conduitKey,
                bytes32(0),
                0,
                new AdditionalRecipient[](0),
                signature
            );
    }

    function prepareFulfillAvailableOrders(Context memory context)
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
        uint256 nonce = context.consideration.getNonce(alice);

        OrderParameters memory _orderParameters = getOrderParameters(
            alice,
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
        );
        bytes32 orderHash = context.consideration.getOrderHash(
            _orderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );
        firstOfferFulfillment.push(FulfillmentComponent(0, 0));
        offerFulfillments.push(firstOfferFulfillment);
        considerationFulfillments.push(firstOfferFulfillment);
        _offerFulfillments = offerFulfillments;
        _considerationFulfillments = considerationFulfillments;
        fulfillerConduitKey = bytes32(0);
        maximumFulfilled = 100;

        _orders = new Order[](1);
        _orders[0] = Order(_orderParameters, signature);
    }

    function prepareFullfillAvailableAdvancedOrders(Context memory context)
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
        ) = prepareFulfillAvailableOrders(context);
        advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = AdvancedOrder(
            _orders[0].parameters,
            1,
            1,
            _orders[0].signature,
            ""
        );
    }

    function prepareMatchOrders(Context memory context)
        internal
        returns (Order[] memory, Fulfillment[] memory)
    {
        test721_1.mint(alice, 1);
        _configureERC721OfferItem(1);
        _configureEthConsiderationItem(payable(reenterer), 1);
        uint256 nonce = context.consideration.getNonce(alice);
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
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
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
        nonce = context.consideration.getNonce(address(bob));
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

        bytes32 mirrorOrderHash = context.consideration.getOrderHash(
            orderComponents
        );
        bytes memory mirrorSignature = signOrder(
            context.consideration,
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

    function _convertOrderToAdvanced(Order memory _order)
        internal
        pure
        returns (AdvancedOrder memory)
    {
        return AdvancedOrder(_order.parameters, 1, 1, _order.signature, "");
    }

    function prepareMatchAdvancedOrders(Context memory context)
        internal
        returns (
            AdvancedOrder[] memory _orders,
            CriteriaResolver[] memory criteriaResolvers,
            Fulfillment[] memory _fulfillments
        )
    {
        Order[] memory _regOrders;
        (_regOrders, _fulfillments) = prepareMatchOrders(context);
        _orders = new AdvancedOrder[](2);
        _orders[0] = _convertOrderToAdvanced(_regOrders[0]);
        _orders[1] = _convertOrderToAdvanced(_regOrders[1]);
        criteriaResolvers = new CriteriaResolver[](0);
        return (_orders, criteriaResolvers, _fulfillments);
    }

    function _etchReentrantCodeToUserAddress(Context memory context) internal {
        reenterer = new ReentrantContract();
        vm.etch(alice, address(reenterer).code);
        reenterer = ReentrantContract(payable(alice));
        reenterer.setConsideration(context.consideration);
        reenterer.setReentrancyPoint(context.args.reentrancyPoint);
        reenterer.setReenter(true);
    }

    function _testNonReentrant(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        reenterer = new ReentrantContract();
        reenterer.setConsideration(context.consideration);
        reenterer.setReentrancyPoint(context.args.reentrancyPoint);
        reenterer.setReenter(true);
        if (context.args.entryPoint == EntryPoint.FulfillBasicOrder) {
            _etchReentrantCodeToUserAddress(context);
            BasicOrderParameters
                memory _basicOrderParameters = prepareBasicOrder(context);
            vm.expectEmit(true, false, false, false, address(alice));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.fulfillBasicOrder{ value: 1 }(
                _basicOrderParameters
            );
        } else if (context.args.entryPoint == EntryPoint.FulfillOrder) {
            (
                Order memory params,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareOrder(context);
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
            ) = prepareAdvancedOrder(context);
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
            ) = prepareFulfillAvailableOrders(context);
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
            ) = prepareFullfillAvailableAdvancedOrders(context);
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
            ) = prepareMatchOrders(context);
            vm.expectEmit(true, false, false, false, address(reenterer));
            emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            context.consideration.matchOrders{ value: 1 }(
                _orders,
                _fulfillments
            );
        } else if (context.args.entryPoint == EntryPoint.MatchAdvancedOrders) {
            (
                AdvancedOrder[] memory _orders,
                CriteriaResolver[] memory criteriaResolvers,
                Fulfillment[] memory _fulfillments
            ) = prepareMatchAdvancedOrders(context);
            context.consideration.matchAdvancedOrders{ value: 1 }(
                _orders,
                criteriaResolvers,
                _fulfillments
            );
        }
    }
}
