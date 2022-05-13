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
    BasicOrderParameters basicOrderParameters;
    OrderComponents orderComponents;
    AdditionalRecipient recipient;
    AdditionalRecipient[] additionalRecipients;
    OrderParameters orderParameters;
    Order order;
    Order[] orders;
    ReentrancyPoint reentrancyPoint;
    Consideration currentConsideration;

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

    function prepareBasicOrder(uint256 tokenId)
        internal
        returns (BasicOrderParameters memory _basicOrderParameters)
    {
        test721_1.mint(address(this), tokenId);

        offerItems.push(
            OfferItem(
                ItemType.ERC721, // ItemType
                address(test721_1), // token
                tokenId, // identifier
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
                payable(address(this)) // recipient
            )
        );

        uint256 nonce = currentConsideration.getNonce(address(this));

        orderComponents.offerer = address(this);
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

        bytes32 orderHash = currentConsideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            currentConsideration,
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

    function prepareOrder(uint256 tokenId)
        internal
        returns (
            Order memory _order,
            bytes32 fulfillerConduitKey,
            uint256 value
        )
    {
        test1155_1.mint(address(this), tokenId, 10);

        _configureERC1155OfferItem(tokenId, uint256(10));
        _configureEthConsiderationItem(payable(this), uint256(10));
        _configureEthConsiderationItem(payable(0), uint256(10));
        _configureEthConsiderationItem(alice, uint256(10));
        uint256 nonce = currentConsideration.getNonce(address(this));

        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
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
        uint256 nonce = currentConsideration.getNonce(address(this));
        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.PARTIAL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
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
        uint256 nonce = currentConsideration.getNonce(address(this));

        OrderParameters memory _orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory _orderComponents = toOrderComponents(
            _orderParameters,
            nonce
        );
        bytes32 orderHash = currentConsideration.getOrderHash(_orderComponents);
        bytes memory signature = signOrder(
            currentConsideration,
            alicePk,
            orderHash
        );
        delete fulfillmentComponents;
        delete offerComponentsArray;
        delete considerationComponentsArray;

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

    function prepareFullfillAvailableAdvancedOrders(uint256 tokenId)
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
        uint256 nonce = currentConsideration.getNonce(address(this));
        orderComponents.offerer = address(this);
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
        orderParameters.salt = 0;
        orderParameters.conduitKey = bytes32(0);
        orderParameters.totalOriginalConsiderationItems = 1;

        order.parameters = orderParameters;
        order.signature = signature;

        orders.push(order);

        delete offerItems;
        delete considerationItems;
        _configureEthOfferItem(1);
        _configureErc721ConsiderationItem(payable(this), tokenId);
        nonce = currentConsideration.getNonce(address(bob));
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

    function _testNonReentrant(Context memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        currentConsideration = context.consideration;
        reentrancyPoint = context.args.reentrancyPoint;
        _entryPoint(context.args.entryPoint, 2, false);
    }

    // public so we can use try/catch
    function _entryPoint(
        EntryPoint entryPoint,
        uint256 tokenId,
        bool reentering
    ) public {
        if (entryPoint == EntryPoint.FulfillBasicOrder) {
            // _etchReentrantCodeToUserAddress(context);
            BasicOrderParameters
                memory _basicOrderParameters = prepareBasicOrder(tokenId);
            if (!reentering) {
                vm.expectEmit(
                    true,
                    false,
                    false,
                    false,
                    address(address(this))
                );
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }

            currentConsideration.fulfillBasicOrder{ value: 1 }(
                _basicOrderParameters
            );
        } else if (entryPoint == EntryPoint.FulfillOrder) {
            (
                Order memory params,
                bytes32 fulfillerConduitKey,
                uint256 value
            ) = prepareOrder(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, false, address(this));
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
                vm.expectEmit(true, false, false, false, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.fulfillAdvancedOrder{ value: value }(
                _order,
                criteriaResolvers,
                fulfillerConduitKey
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
                vm.expectEmit(true, false, false, false, address(this));
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
            ) = prepareFullfillAvailableAdvancedOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, false, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            vm.prank(alice);
            currentConsideration.fulfillAvailableAdvancedOrders{ value: 1 }(
                advancedOrders,
                criteriaResolvers,
                _offerFulfillments,
                _considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
        } else if (entryPoint == EntryPoint.MatchOrders) {
            (
                Order[] memory _orders,
                Fulfillment[] memory _fulfillments
            ) = prepareMatchOrders(tokenId);
            if (!reentering) {
                vm.expectEmit(true, false, false, false, address(this));
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
                vm.expectEmit(true, false, false, false, address(this));
                emit BytesReason(abi.encodeWithSignature("NoReentrantCalls()"));
            }
            currentConsideration.matchAdvancedOrders{ value: 1 }(
                _orders,
                criteriaResolvers,
                _fulfillments
            );
        }
    }

    function reentryPoint(ReentrancyPoint reentryPoint) internal {}

    ///@dev allow signing for this contract since it needs to be recipient of basic order to reenter on receive
    function isValidSignature(bytes32, bytes memory)
        external
        pure
        returns (bytes4)
    {
        return 0x1626ba7e;
    }

    /**
     * @dev call target function with empty parameters - should be rejected for reentrancy before any issues arise
     */
    function _doReenter() internal {
        if (uint256(reentrancyPoint) < 7) {
            try
                this._entryPoint(EntryPoint(uint256(reentrancyPoint)), 10, true)
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        }
        // if (reentrancyPoint == ReentrancyPoint.FulfillBasicOrder) {
        //     BasicOrderParameters memory params;
        //     try currentConsideration.fulfillBasicOrder(params) {} catch (
        //         bytes memory reason
        //     ) {
        //         emit BytesReason(reason);
        //     }
        // } else if (reentrancyPoint == ReentrancyPoint.FulfillOrder) {
        //     Order memory _order;
        //     try currentConsideration.fulfillOrder(_order, bytes32(0)) {} catch (
        //         bytes memory reason
        //     ) {
        //         emit BytesReason(reason);
        //     }
        // } else if (reentrancyPoint == ReentrancyPoint.FulfillAdvancedOrder) {
        //     AdvancedOrder memory _order;
        //     CriteriaResolver[]
        //         memory criteriaResolvers = new CriteriaResolver[](0);
        //     try
        //         currentConsideration.fulfillAdvancedOrder(
        //             _order,
        //             criteriaResolvers,
        //             bytes32(0)
        //         )
        //     {} catch (bytes memory reason) {
        //         emit BytesReason(reason);
        //     }
        // } else if (reentrancyPoint == ReentrancyPoint.FulfillAvailableOrders) {
        //     Order[] memory _orders;
        //     FulfillmentComponent[][] memory orderFulfillments;
        //     FulfillmentComponent[][] memory considerationFulfillments;
        //     try
        //         currentConsideration.fulfillAvailableOrders(
        //             _orders,
        //             orderFulfillments,
        //             considerationFulfillments,
        //             bytes32(0),
        //             0
        //         )
        //     {} catch (bytes memory reason) {
        //         emit BytesReason(reason);
        //     }
        // } else if (
        //     reentrancyPoint == ReentrancyPoint.FulfillAvailableAdvancedOrders
        // ) {
        //     AdvancedOrder[] memory advancedOrders;
        //     CriteriaResolver[] memory criteriaResolvers;
        //     FulfillmentComponent[][] memory orderFulfillments;
        //     FulfillmentComponent[][] memory considerationFulfillments;
        //     try
        //         currentConsideration.fulfillAvailableAdvancedOrders(
        //             advancedOrders,
        //             criteriaResolvers,
        //             orderFulfillments,
        //             considerationFulfillments,
        //             bytes32(0),
        //             0
        //         )
        //     {} catch (bytes memory reason) {
        //         emit BytesReason(reason);
        //     }
        // } else if (reentrancyPoint == ReentrancyPoint.MatchOrders) {
        //     Order[] memory _orders;
        //     Fulfillment[] memory orderFulfillments;
        //     try
        //         currentConsideration.matchOrders(_orders, orderFulfillments)
        //     {} catch (bytes memory reason) {
        //         emit BytesReason(reason);
        //     }
        // } else if (reentrancyPoint == ReentrancyPoint.MatchAdvancedOrders) {
        //     AdvancedOrder[] memory advancedOrders;
        //     CriteriaResolver[] memory criteriaResolvers;
        //     Fulfillment[] memory orderFulfillments;
        //     try
        //         currentConsideration.matchAdvancedOrders(
        //             advancedOrders,
        //             criteriaResolvers,
        //             orderFulfillments
        //         )
        //     {} catch (bytes memory reason) {
        //         emit BytesReason(reason);
        //     }
        // } else
        else if (reentrancyPoint == ReentrancyPoint.Cancel) {
            OrderComponents[] memory _orders;
            try currentConsideration.cancel(_orders) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        } else if (reentrancyPoint == ReentrancyPoint.Validate) {
            Order[] memory _orders;
            try currentConsideration.validate(_orders) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        } else if (reentrancyPoint == ReentrancyPoint.IncrementNonce) {
            try currentConsideration.incrementNonce() {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        }
    }

    receive() external payable override {
        _doReenter();
    }
}
