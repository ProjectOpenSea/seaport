//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import { Consideration } from "../../../../contracts/Consideration.sol";
import { ERC1155TokenReceiver } from "@rari-capital/solmate/src/tokens/ERC1155.sol";
import { ReentrancyPoint } from "./ReentrantEnums.sol";
import { FulfillBasicOrderParameters, FulfillOrderParameters, FulfillAdvancedOrderParameters, FulfillAvailableOrdersParameters, FulfillAvailableAdvancedOrdersParameters, MatchOrdersParameters, MatchAdvancedOrdersParameters, CancelParameters, ValidateParameters, ReentrantCallParameters } from "./ReentrantStructs.sol";
import { BasicOrderParameters, OfferItem, ConsiderationItem, OrderParameters, OrderComponents, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver, BatchExecution } from "../../../../contracts/lib/ConsiderationStructs.sol";

contract ReentrantContract {
    Consideration consideration;
    ReentrancyPoint reentrancyPoint;
    bool reenter;

    constructor(Consideration _consideration, ReentrancyPoint _reentrancyPoint)
    {
        consideration = _consideration;
        reentrancyPoint = _reentrancyPoint;
    }

    function setReenter(bool _reenter) public {
        reenter = _reenter;
    }

    /**
     * @dev call target function with empty parameters - should be rejected for reentrancy before any issues arise
     */
    function _doReenter() internal {
        if (reentrancyPoint == ReentrancyPoint.FulfillBasicOrder) {
            BasicOrderParameters memory params;
            consideration.fulfillBasicOrder(params);
        } else if (reentrancyPoint == ReentrancyPoint.FulfillOrder) {
            Order memory order;
            consideration.fulfillOrder(order, bytes32(0));
        } else if (reentrancyPoint == ReentrancyPoint.FulfillAdvancedOrder) {
            AdvancedOrder memory order;
            CriteriaResolver[]
                memory criteriaResolvers = new CriteriaResolver[](0);

            consideration.fulfillAdvancedOrder(
                order,
                criteriaResolvers,
                bytes32(0)
            );
        } else if (reentrancyPoint == ReentrancyPoint.FulfillAvailableOrders) {
            Order[] memory orders;
            FulfillmentComponent[][] memory orderFulfillments;
            FulfillmentComponent[][] memory considerationFulfillments;

            consideration.fulfillAvailableOrders(
                orders,
                orderFulfillments,
                considerationFulfillments,
                bytes32(0),
                0
            );
        } else if (
            reentrancyPoint == ReentrancyPoint.FulfillAvailableAdvancedOrders
        ) {
            AdvancedOrder[] memory advancedOrders;
            CriteriaResolver[] memory criteriaResolvers;
            FulfillmentComponent[][] memory orderFulfillments;
            FulfillmentComponent[][] memory considerationFulfillments;

            consideration.fulfillAvailableAdvancedOrders(
                advancedOrders,
                criteriaResolvers,
                orderFulfillments,
                considerationFulfillments,
                bytes32(0),
                0
            );
        } else if (reentrancyPoint == ReentrancyPoint.MatchOrders) {
            Order[] memory orders;
            Fulfillment[] memory orderFulfillments;
            consideration.matchOrders(orders, orderFulfillments);
        } else if (reentrancyPoint == ReentrancyPoint.MatchAdvancedOrders) {
            AdvancedOrder[] memory advancedOrders;
            CriteriaResolver[] memory criteriaResolvers;
            Fulfillment[] memory orderFulfillments;
            consideration.matchAdvancedOrders(
                advancedOrders,
                criteriaResolvers,
                orderFulfillments
            );
        } else if (reentrancyPoint == ReentrancyPoint.Cancel) {
            OrderComponents[] memory orders;
            consideration.cancel(orders);
        } else if (reentrancyPoint == ReentrancyPoint.Validate) {
            Order[] memory orders;
            consideration.validate(orders);
        } else if (reentrancyPoint == ReentrancyPoint.IncrementNonce) {
            consideration.incrementNonce();
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public returns (bytes4) {
        if (reenter) {
            _doReenter();
        }
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4) {
        if (reenter) {
            _doReenter();
        }
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
