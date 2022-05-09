// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { AdditionalRecipient, Fulfillment, OfferItem, ConsiderationItem, FulfillmentComponent, OrderComponents, AdvancedOrder, BasicOrderParameters, Order } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { ReentrantContract } from "./utils/reentrancy/ReentrantContract.sol";
import { EntryPoint, ReentrancyPoint } from "./utils/reentrancy/ReentrantEnums.sol";
import { FulfillBasicOrderParameters, FulfillOrderParameters, FulfillAdvancedOrderParameters, FulfillAvailableOrdersParameters, FulfillAvailableAdvancedOrdersParameters, MatchOrdersParameters, MatchAdvancedOrdersParameters, CancelParameters, ValidateParameters, ReentrantCallParameters, CriteriaResolver } from "./utils/reentrancy/ReentrantStructs.sol";

contract NonReentrantTest is BaseOrderTest {
    ReentrantContract reenterer;

    BasicOrderParameters defaultBasicOrderParameters;
    OrderComponents defaultOrderComponents;
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

    function setUp() public virtual override {
        super.setUp();
        // todo: don't do this all in setup. see if can use memory structs
        defaultBasicOrderParameters.considerationToken = address(0);
        defaultBasicOrderParameters.considerationIdentifier = 0;
        defaultBasicOrderParameters.considerationAmount = 1;
        defaultBasicOrderParameters.offerer = payable(alice);
        defaultBasicOrderParameters.zone = address(1);
        defaultBasicOrderParameters.offerToken = address(test721_1);
        defaultBasicOrderParameters.offerIdentifier = 1;
        defaultBasicOrderParameters.offerAmount = 1;
        defaultBasicOrderParameters.basicOrderType = BasicOrderType
            .ETH_TO_ERC721_FULL_OPEN;
        defaultBasicOrderParameters.startTime = block.timestamp;
        defaultBasicOrderParameters.endTime = block.timestamp + 1;
        defaultBasicOrderParameters.zoneHash = bytes32(0);
        defaultBasicOrderParameters.salt = 0;
        defaultBasicOrderParameters.offererConduitKey = bytes32(0);
        defaultBasicOrderParameters.fulfillerConduitKey = bytes32(0);
        defaultBasicOrderParameters.totalOriginalAdditionalRecipients = 0;
        // don't set additional recipients
        // don't set signature

        defaultOrderComponents.offerer = defaultBasicOrderParameters.offerer;
        defaultOrderComponents.zone = defaultBasicOrderParameters.zone;
        // don't set offer items
        // don't set consideration items
        defaultOrderComponents.orderType = OrderType.FULL_OPEN;
        defaultOrderComponents.startTime = defaultBasicOrderParameters
            .startTime;
        defaultOrderComponents.endTime = defaultBasicOrderParameters.endTime;
        defaultOrderComponents.zoneHash = defaultBasicOrderParameters.zoneHash;
        defaultOrderComponents.salt = defaultBasicOrderParameters.salt;
        defaultOrderComponents.conduitKey = defaultBasicOrderParameters
            .offererConduitKey;
        // don't set nonce
    }

    function testNonReentrant(FuzzInputs memory _inputs) public {
        vm.assume(_inputs.entryPoint < 7 && _inputs.reentrancyPoint < 10);
        vm.assume(
            ReentrancyPoint(_inputs.reentrancyPoint) ==
                ReentrancyPoint.FulfillBasicOrder
        );
        NonReentrantInputs memory inputs = NonReentrantInputs(
            EntryPoint(_inputs.entryPoint),
            ReentrancyPoint(_inputs.reentrancyPoint)
        );
        // _testNonReentrant(NonReentrant(consideration, inputs));
        _testNonReentrant(NonReentrant(referenceConsideration, inputs));
    }

    function prepareBasicOrder(NonReentrant memory context)
        internal
        returns (BasicOrderParameters memory order)
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

        uint256 nonce = context.consideration.getNonce(address(alice)); //beepboopbeepboop

        OrderComponents memory orderComponents = OrderComponents(
            defaultOrderComponents.offerer,
            defaultOrderComponents.zone,
            offerItems,
            considerationItems,
            defaultOrderComponents.orderType,
            defaultOrderComponents.startTime,
            defaultOrderComponents.endTime,
            defaultOrderComponents.zoneHash,
            defaultOrderComponents.salt,
            defaultOrderComponents.conduitKey,
            nonce
        );
        bytes32 orderHash = context.consideration.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );
        // recipient = AdditionalRecipient(1, payable(address(reenterer)));
        // additionalRecipients.push(recipient);
        order = BasicOrderParameters(
            defaultBasicOrderParameters.considerationToken,
            defaultBasicOrderParameters.considerationIdentifier,
            defaultBasicOrderParameters.considerationAmount,
            defaultBasicOrderParameters.offerer,
            defaultBasicOrderParameters.zone,
            defaultBasicOrderParameters.offerToken,
            defaultBasicOrderParameters.offerIdentifier,
            defaultBasicOrderParameters.offerAmount,
            defaultBasicOrderParameters.basicOrderType,
            defaultBasicOrderParameters.startTime,
            defaultBasicOrderParameters.endTime,
            defaultBasicOrderParameters.zoneHash,
            defaultBasicOrderParameters.salt,
            defaultBasicOrderParameters.offererConduitKey,
            defaultBasicOrderParameters.fulfillerConduitKey,
            defaultBasicOrderParameters.totalOriginalAdditionalRecipients,
            additionalRecipients,
            signature
        );
    }

    function prepareOrder(NonReentrant memory context)
        internal
        returns (Order memory, bytes32)
    {}

    function prepareAdvancedOrder(NonReentrant memory context)
        internal
        returns (
            AdvancedOrder memory order,
            CriteriaResolver[] memory criteriaResolvers,
            bytes32 fulfillerConduitKey
        )
    {}

    function prepareFulfillAvailableOrders(NonReentrant memory context)
        internal
        returns (
            Order[] memory orders,
            FulfillmentComponent[][] memory _offerFulfillments,
            FulfillmentComponent[][] memory _considerationFulfillments,
            bytes32 fulfillerConduitKey,
            uint256 maximumFulfilled
        )
    {}

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

    function _testNonReentrant(NonReentrant memory context)
        internal
        resetTokenBalancesBetweenRuns
    {
        reenterer = new ReentrantContract();
        vm.etch(alice, address(reenterer).code);
        reenterer = ReentrantContract(payable(alice));
        reenterer.setConsideration(context.consideration);
        reenterer.setReentrancyPoint(context.args.reentrancyPoint);
        reenterer.setReenter(true);
        if (context.args.entryPoint == EntryPoint.FulfillBasicOrder) {
            BasicOrderParameters memory params = prepareBasicOrder(context);
            // vm.expectRevert(
            //     // abi.encodeWithSignature(
            //     //     "EtherTransferGenericFailure(address,uint256)",
            //     //     alice,
            //     //     1
            //     // )
            //     abi.encodeWithSignature("NoReentrantCalls()")
            // );
            vm.expectRevert(
                abi.encodeWithSignature(
                    "EtherTransferGenericFailure(address,uint256)",
                    alice,
                    1
                )
                // abi.encodeWithSignature("NoReentrantCalls()")
            );
            context.consideration.fulfillBasicOrder{ value: 1 }(params);
        }
        /**  else if (context.args.entryPoint == EntryPoint.FulfillOrder) {
            (Order memory params, bytes32 fulfillerConduitKey) = prepareOrder(
                context
            );
            context.consideration.fulfillOrder(params, fulfillerConduitKey);
        } else if (context.args.entryPoint == EntryPoint.FulfillAdvancedOrder) {
            (
                AdvancedOrder memory order,
                CriteriaResolver[] memory criteriaResolvers,
                bytes32 fulfillerConduitKey
            ) = prepareAdvancedOrder(context);
            context.consideration.fulfillAdvancedOrder(
                order,
                criteriaResolvers,
                fulfillerConduitKey
            );
        } else if (
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
