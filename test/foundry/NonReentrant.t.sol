// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { AdditionalRecipient, Fulfillment, OfferItem, ConsiderationItem, FulfillmentComponent, OrderComponents, AdvancedOrder, BasicOrderParameters, Order } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { EntryPoint, ReentryPoint } from "./utils/reentrancy/ReentrantEnums.sol";
import { OrderParameters, CriteriaResolver } from "./utils/reentrancy/ReentrantStructs.sol";

contract NonReentrantTest is BaseOrderTest {
    BasicOrderParameters basicOrderParameters;
    OrderComponents orderComponents;
    AdditionalRecipient recipient;
    OrderParameters orderParameters;
    Order order;
    Order[] orders;
    ReentryPoint reentryPoint;
    ConsiderationInterface currentConsideration;
    bool reentered;
    bool shouldReenter;

    /**
     * @dev Foundry fuzzes enums as uints, so we need to manually fuzz on uints and use vm.assume
     * to filter out invalid values
     */
    struct FuzzInputs {
        uint8 entryPoint;
        uint8 reentryPoint;
    }

    /**
     * @dev struct to test combinations of entrypoints and reentrancy points
     */
    struct NonReentrantInputs {
        EntryPoint entryPoint;
        ReentryPoint reentryPoint;
    }

    struct Context {
        ConsiderationInterface consideration;
        NonReentrantInputs args;
    }

    event BytesReason(bytes data);

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNonReentrant() public {
        for (uint256 i; i < 7; i++) {
            for (uint256 j; j < 10; j++) {
                NonReentrantInputs memory inputs = NonReentrantInputs(
                    EntryPoint(i),
                    ReentryPoint(j)
                );
                test(
                    this.nonReentrant,
                    Context(referenceConsideration, inputs)
                );
                test(this.nonReentrant, Context(consideration, inputs));
            }
        }
    }

    function nonReentrant(Context memory context) external stateless {
        currentConsideration = context.consideration;
        reentryPoint = context.args.reentryPoint;
        this._entryPoint(context.args.entryPoint, 2, false);

        // make sure reentry calls are valid by calling with a new token id
        this._reentryPoint(11);
    }

    // public so we can use try/catch
    function _entryPoint(
        EntryPoint entryPoint,
        uint256 tokenId,
        bool reentering
    ) public {
        if (entryPoint == EntryPoint.FulfillBasicOrder) {
            BasicOrderParameters
                memory _basicOrderParameters = prepareBasicOrder(tokenId);
            if (!reentering) {
                shouldReenter = true;
                vm.expectEmit(
                    true,
                    false,
                    false,
                    false,
                    address(address(this))
                );
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.fulfillBasicOrder(_basicOrderParameters);
            shouldReenter = false;
        } else if (entryPoint == EntryPoint.FulfillOrder) {
            (
                Order memory params,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareOrder(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.fulfillOrder{ value: value }(
                params,
                fulfillerConduitKey
            );
        } else if (entryPoint == EntryPoint.FulfillAdvancedOrder) {
            (
                AdvancedOrder memory _order,
                CriteriaResolver[] memory criteriaResolvers,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareAdvancedOrder(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.fulfillAdvancedOrder{ value: value }(
                _order,
                criteriaResolvers,
                fulfillerConduitKey,
                address(0)
            );
        } else if (entryPoint == EntryPoint.FulfillAvailableOrders) {
            (
                Order[] memory _orders,
                FulfillmentComponent[][] memory _offerFulfillments,
                FulfillmentComponent[][] memory _considerationFulfillments,
                bytes32 fulfillerConduitKey,
                uint256 maximumFulfilled
            ) = prepareAvailableOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            vm.prank(alice);
            currentConsideration.fulfillAvailableOrders{ value: 1 }(
                _orders,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
        } else if (entryPoint == EntryPoint.FulfillAvailableAdvancedOrders) {
            (
                AdvancedOrder[] memory advancedOrders,
                CriteriaResolver[] memory criteriaResolvers,
                FulfillmentComponent[][] memory _offerFulfillments,
                FulfillmentComponent[][] memory _considerationFulfillments,
                bytes32 fulfillerConduitKey,
                uint256 maximumFulfilled
            ) = prepareFulfillAvailableAdvancedOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            vm.prank(alice);
            currentConsideration.fulfillAvailableAdvancedOrders{ value: 1 }(
                advancedOrders,
                criteriaResolvers,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                address(0),
                maximumFulfilled
            );
        } else if (entryPoint == EntryPoint.MatchOrders) {
            (
                Order[] memory _orders,
                Fulfillment[] memory _fulfillments
            ) = prepareMatchOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.matchOrders{ value: 1 }(
                _orders,
                _fulfillments
            );
        } else if (entryPoint == EntryPoint.MatchAdvancedOrders) {
            (
                AdvancedOrder[] memory _orders,
                CriteriaResolver[] memory criteriaResolvers,
                Fulfillment[] memory _fulfillments
            ) = prepareMatchAdvancedOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, true, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.matchAdvancedOrders{ value: 1 }(
                _orders,
                criteriaResolvers,
                _fulfillments
            );
        }
    }

    function _reentryPoint(uint256 tokenId) public {
        if (reentryPoint == ReentryPoint.Cancel) {
            prepareBasicOrder(tokenId);
            OrderComponents[] memory _orders = new OrderComponents[](1);
            _orders[0] = orderComponents;
            currentConsideration.cancel(_orders);
        } else if (reentryPoint == ReentryPoint.Validate) {
            Order[] memory _orders = new Order[](1);
            (Order memory _order, , ) = prepareOrder(tokenId);
            _orders[0] = _order;
            currentConsideration.validate(_orders);
        } else if (reentryPoint == ReentryPoint.IncrementCounter) {
            currentConsideration.incrementCounter();
        }
    }

    function prepareBasicOrder(uint256 tokenId)
        internal
        returns (BasicOrderParameters memory _basicOrderParameters)
    {
        test1155_1.mint(address(this), tokenId, 2);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155, // ItemType
                address(test1155_1), // token
                tokenId, // identifier
                1, // start amt
                1 // end amt
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.ERC20, // ItemType
                address(token1), // Token
                0, // identifier
                1, // start amount
                1, // end amout
                payable(address(this)) // recipient
            )
        );

        uint256 counter = currentConsideration.getCounter(address(this));

        orderComponents.offerer = address(this);
        orderComponents.zone = address(1);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = globalSalt++;
        orderComponents.conduitKey = conduitKeyOne;
        orderComponents.counter = counter;

        bytes32 orderHash = currentConsideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );
        return
            toBasicOrderParameters(
                orderComponents,
                BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN,
                signature
            );
    }

    function prepareOrder(uint256 tokenId)
        internal
        returns (
            Order memory _order,
            bytes32 fulfillerConduitKey,
            uint256 value
        )
    {
        test1155_1.mint(address(this), tokenId, 10);

        _configureERC1155OfferItem(tokenId, 10);
        _configureEthConsiderationItem(payable(this), 10);
        _configureEthConsiderationItem(payable(0), 10);
        _configureEthConsiderationItem(alice, 10);
        uint256 counter = currentConsideration.getCounter(address(this));

        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            counter
        );

        bytes32 orderHash = currentConsideration.getOrderHash(_orderComponents);

        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );
        value = 30;
        _order = Order(_orderParameters, signature);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareAdvancedOrder(uint256 tokenId)
        internal
        returns (
            AdvancedOrder memory _order,
            CriteriaResolver[] memory criteriaResolvers,
            bytes32 fulfillerConduitKey,
            uint256 value
        )
    {
        test1155_1.mint(address(this), tokenId, 10);

        _configureERC1155OfferItem(tokenId, uint256(10));
        _configureEthConsiderationItem(payable(this), uint256(10));
        _configureEthConsiderationItem(payable(address(0)), uint256(10));
        _configureEthConsiderationItem(payable(address(this)), uint256(10));
        uint256 counter = currentConsideration.getCounter(address(this));
        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.PARTIAL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            counter
        );

        bytes32 orderHash = currentConsideration.getOrderHash(_orderComponents);

        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );

        value = 30;
        _order = AdvancedOrder(_orderParameters, 1, 1, signature, "");
        criteriaResolvers = new CriteriaResolver[](0);
        fulfillerConduitKey = bytes32(0);
    }

    function prepareAvailableOrders(uint256 tokenId)
        internal
        returns (
            Order[] memory _orders,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {
        test721_1.mint(address(this), tokenId);
        _configureERC721OfferItem(tokenId);
        _configureEthConsiderationItem(payable(address(this)), 1);
        uint256 counter = currentConsideration.getCounter(address(this));

        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            counter
        );
        bytes32 orderHash = currentConsideration.getOrderHash(_orderComponents);
        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );

        fulfillmentComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(fulfillmentComponents);
        considerationComponentsArray.push(fulfillmentComponents);
        _offerFulfillments = offerComponentsArray;
        _considerationFulfillments = considerationComponentsArray;
        fulfillerConduitKey = bytes32(0);
        maximumFulfilled = 100;

        _orders = new Order[](1);
        _orders[0] = Order(_orderParameters, signature);
    }

    function prepareFulfillAvailableAdvancedOrders(uint256 tokenId)
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
        ) = prepareAvailableOrders(tokenId);
        advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = AdvancedOrder(
            _orders[0].parameters,
            1,
            1,
            _orders[0].signature,
            ""
        );
    }

    function prepareMatchOrders(uint256 tokenId)
        internal
        returns (Order[] memory, Fulfillment[] memory)
    {
        test721_1.mint(address(this), tokenId);
        _configureERC721OfferItem(tokenId);
        _configureEthConsiderationItem(payable(address(this)), 1);
        uint256 counter = currentConsideration.getCounter(address(this));
        orderComponents.offerer = address(this);
        orderComponents.zone = address(0);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = globalSalt++;
        orderComponents.conduitKey = bytes32(0);
        orderComponents.counter = counter;
        bytes32 orderHash = currentConsideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );

        orderParameters.offerer = address(this);
        orderParameters.zone = address(0);
        orderParameters.offer = offerItems;
        orderParameters.consideration = considerationItems;
        orderParameters.orderType = OrderType.FULL_OPEN;
        orderParameters.startTime = block.timestamp;
        orderParameters.endTime = block.timestamp + 1;
        orderParameters.zoneHash = bytes32(0);
        orderParameters.salt = orderComponents.salt;
        orderParameters.conduitKey = bytes32(0);
        orderParameters.totalOriginalConsiderationItems = 1;

        order.parameters = orderParameters;
        order.signature = signature;

        orders.push(order);

        delete offerItems;
        delete considerationItems;
        _configureEthOfferItem(1);
        _configureErc721ConsiderationItem(payable(this), tokenId);
        counter = currentConsideration.getCounter(address(bob));
        orderComponents.offerer = bob;
        orderComponents.zone = address(0);
        orderComponents.offer = offerItems;
        orderComponents.consideration = considerationItems;
        orderComponents.orderType = OrderType.FULL_OPEN;
        orderComponents.startTime = block.timestamp;
        orderComponents.endTime = block.timestamp + 1;
        orderComponents.zoneHash = bytes32(0);
        orderComponents.salt = globalSalt++;
        orderComponents.conduitKey = bytes32(0);
        orderComponents.counter = counter;

        bytes32 mirrorOrderHash = currentConsideration.getOrderHash(
            orderComponents
        );
        bytes memory mirrorSignature = signOrder(
            currentConsideration,
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
        orderParameters.salt = orderComponents.salt;
        orderParameters.conduitKey = bytes32(0);
        orderParameters.totalOriginalConsiderationItems = 1;

        order.parameters = orderParameters;
        order.signature = mirrorSignature;
        orders.push(order);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        // map order offer to mirror consideration
        firstFulfillment.offerComponents = fulfillmentComponents;
        // map mirror consideration to order offer
        secondFulfillment.considerationComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        // map mirror offer to order consideration
        firstFulfillment.considerationComponents = fulfillmentComponents;
        // map order consideration to mirror offer
        secondFulfillment.offerComponents = fulfillmentComponents;

        fulfillments.push(firstFulfillment);
        fulfillments.push(secondFulfillment);

        return (orders, fulfillments);
    }

    function _convertOrderToAdvanced(Order memory _order)
        internal
        pure
        returns (AdvancedOrder memory)
    {
        return AdvancedOrder(_order.parameters, 1, 1, _order.signature, "");
    }

    function prepareMatchAdvancedOrders(uint256 tokenId)
        internal
        returns (
            AdvancedOrder[] memory _orders,
            CriteriaResolver[] memory criteriaResolvers,
            Fulfillment[] memory _fulfillments
        )
    {
        Order[] memory _regOrders;
        (_regOrders, _fulfillments) = prepareMatchOrders(tokenId);
        _orders = new AdvancedOrder[](2);
        _orders[0] = _convertOrderToAdvanced(_regOrders[0]);
        _orders[1] = _convertOrderToAdvanced(_regOrders[1]);
        criteriaResolvers = new CriteriaResolver[](0);
        return (_orders, criteriaResolvers, _fulfillments);
    }

    ///@dev allow signing for this contract since it needs to be recipient of basic order to reenter on receive
    function isValidSignature(bytes32, bytes memory)
        external
        pure
        returns (bytes4)
    {
        return 0x1626ba7e;
    }

    function _doReenter() internal {
        if (uint256(reentryPoint) < 7) {
            try
                this._entryPoint(EntryPoint(uint256(reentryPoint)), 10, true)
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else {
            try this._reentryPoint(10) {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        }
    }

    receive() external payable override {
        _doReenter();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public override returns (bytes4) {
        if (shouldReenter && !reentered) {
            reentered = true;
            _doReenter();
        }
        return this.onERC1155Received.selector;
    }
}
