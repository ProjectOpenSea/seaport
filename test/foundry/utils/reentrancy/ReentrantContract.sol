//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import { Consideration } from "../../../../contracts/Consideration.sol";
import { ReentrancyPoint } from "./ReentrantEnums.sol";
import { FulfillBasicOrderParameters, FulfillOrderParameters, FulfillAdvancedOrderParameters, FulfillAvailableOrdersParameters, FulfillAvailableAdvancedOrdersParameters, MatchOrdersParameters, MatchAdvancedOrdersParameters, CancelParameters, ValidateParameters, ReentrantCallParameters } from "./ReentrantStructs.sol";
import { BasicOrderParameters, OfferItem, ConsiderationItem, OrderParameters, OrderComponents, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver, BatchExecution } from "../../../../contracts/lib/ConsiderationStructs.sol";

contract ReentrantContract {
    Consideration consideration;
    ReentrancyPoint reentrancyPoint;
    bool reenter;

    event BytesReason(bytes data);

    ///@dev use setters since etching code at an address won't copy storage
    function setReenter(bool _reenter) public {
        reenter = _reenter;
    }

    function setConsideration(Consideration _consideration) external {
        consideration = _consideration;
    }

    function setReentrancyPoint(ReentrancyPoint _reentrancyPoint) external {
        reentrancyPoint = _reentrancyPoint;
    }

    /**
     * @dev call target function with empty parameters - should be rejected for reentrancy before any issues arise
     */
    function _doReenter() internal {
        if (reentrancyPoint == ReentrancyPoint.FulfillBasicOrder) {
            BasicOrderParameters memory params;
            try consideration.fulfillBasicOrder(params) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        }
        // else if (reentrancyPoint == ReentrancyPoint.FulfillOrder) {
        //     Order memory order;
        //     consideration.fulfillOrder(order, bytes32(0));
        // } else if (reentrancyPoint == ReentrancyPoint.FulfillAdvancedOrder) {
        //     AdvancedOrder memory order;
        //     CriteriaResolver[]
        //         memory criteriaResolvers = new CriteriaResolver[](0);

        //     consideration.fulfillAdvancedOrder(
        //         order,
        //         criteriaResolvers,
        //         bytes32(0)
        //     );
        // } else if (reentrancyPoint == ReentrancyPoint.FulfillAvailableOrders) {
        //     Order[] memory orders;
        //     FulfillmentComponent[][] memory orderFulfillments;
        //     FulfillmentComponent[][] memory considerationFulfillments;

        //     consideration.fulfillAvailableOrders(
        //         orders,
        //         orderFulfillments,
        //         considerationFulfillments,
        //         bytes32(0),
        //         0
        //     );
        // } else if (
        //     reentrancyPoint == ReentrancyPoint.FulfillAvailableAdvancedOrders
        // ) {
        //     AdvancedOrder[] memory advancedOrders;
        //     CriteriaResolver[] memory criteriaResolvers;
        //     FulfillmentComponent[][] memory orderFulfillments;
        //     FulfillmentComponent[][] memory considerationFulfillments;

        //     consideration.fulfillAvailableAdvancedOrders(
        //         advancedOrders,
        //         criteriaResolvers,
        //         orderFulfillments,
        //         considerationFulfillments,
        //         bytes32(0),
        //         0
        //     );
        // } else if (reentrancyPoint == ReentrancyPoint.MatchOrders) {
        //     Order[] memory orders;
        //     Fulfillment[] memory orderFulfillments;
        //     consideration.matchOrders(orders, orderFulfillments);
        // } else if (reentrancyPoint == ReentrancyPoint.MatchAdvancedOrders) {
        //     AdvancedOrder[] memory advancedOrders;
        //     CriteriaResolver[] memory criteriaResolvers;
        //     Fulfillment[] memory orderFulfillments;
        //     consideration.matchAdvancedOrders(
        //         advancedOrders,
        //         criteriaResolvers,
        //         orderFulfillments
        //     );
        // } else if (reentrancyPoint == ReentrancyPoint.Cancel) {
        //     OrderComponents[] memory orders;
        //     consideration.cancel(orders);
        // } else if (reentrancyPoint == ReentrancyPoint.Validate) {
        //     Order[] memory orders;
        //     consideration.validate(orders);
        // } else if (reentrancyPoint == ReentrancyPoint.IncrementNonce) {
        //     consideration.incrementNonce();
        // }
    }

    receive() external payable {
        if (reenter) {
            _doReenter();
        }
    }
}
