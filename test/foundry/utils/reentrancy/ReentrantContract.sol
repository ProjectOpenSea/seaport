//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import { Consideration } from "../../../../contracts/Consideration.sol";
import { ReentryPoint } from "./ReentrantEnums.sol";
import { FulfillBasicOrderParameters, FulfillOrderParameters, FulfillAdvancedOrderParameters, FulfillAvailableOrdersParameters, FulfillAvailableAdvancedOrdersParameters, MatchOrdersParameters, MatchAdvancedOrdersParameters, CancelParameters, ValidateParameters, ReentrantCallParameters } from "./ReentrantStructs.sol";
import { BasicOrderParameters, OfferItem, ConsiderationItem, OrderParameters, OrderComponents, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver } from "../../../../contracts/lib/ConsiderationStructs.sol";

contract ReentrantContract {
    Consideration consideration;
    ReentryPoint reentryPoint;
    bool reenter;

    event BytesReason(bytes data);

    ///@dev use setters since etching code at an address won't copy storage
    function setReenter(bool _reenter) public {
        reenter = _reenter;
    }

    function setConsideration(Consideration _consideration) external {
        consideration = _consideration;
    }

    function setReentryPoint(ReentryPoint _reentryPoint) external {
        reentryPoint = _reentryPoint;
    }

    /**
     * @dev call target function with empty parameters - should be rejected for reentrancy before any issues arise
     */
    function _doReenter() internal {
        if (reentryPoint == ReentryPoint.FulfillBasicOrder) {
            BasicOrderParameters memory params;
            try consideration.fulfillBasicOrder(params) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.FulfillOrder) {
            Order memory order;
            try consideration.fulfillOrder(order, bytes32(0)) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.FulfillAdvancedOrder) {
            AdvancedOrder memory order;
            CriteriaResolver[]
                memory criteriaResolvers = new CriteriaResolver[](0);

            try
                consideration.fulfillAdvancedOrder(
                    order,
                    criteriaResolvers,
                    bytes32(0)
                )
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.FulfillAvailableOrders) {
            Order[] memory orders;
            FulfillmentComponent[][] memory orderFulfillments;
            FulfillmentComponent[][] memory considerationFulfillments;

            try
                consideration.fulfillAvailableOrders(
                    orders,
                    orderFulfillments,
                    considerationFulfillments,
                    bytes32(0),
                    0
                )
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (
            reentryPoint == ReentryPoint.FulfillAvailableAdvancedOrders
        ) {
            AdvancedOrder[] memory advancedOrders;
            CriteriaResolver[] memory criteriaResolvers;
            FulfillmentComponent[][] memory orderFulfillments;
            FulfillmentComponent[][] memory considerationFulfillments;

            try
                consideration.fulfillAvailableAdvancedOrders(
                    advancedOrders,
                    criteriaResolvers,
                    orderFulfillments,
                    considerationFulfillments,
                    bytes32(0),
                    0
                )
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.MatchOrders) {
            Order[] memory orders;
            Fulfillment[] memory orderFulfillments;
            try consideration.matchOrders(orders, orderFulfillments) {} catch (
                bytes memory reason
            ) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.MatchAdvancedOrders) {
            AdvancedOrder[] memory advancedOrders;
            CriteriaResolver[] memory criteriaResolvers;
            Fulfillment[] memory orderFulfillments;
            try
                consideration.matchAdvancedOrders(
                    advancedOrders,
                    criteriaResolvers,
                    orderFulfillments
                )
            {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.Cancel) {
            OrderComponents[] memory orders;
            try consideration.cancel(orders) {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.Validate) {
            Order[] memory orders;
            try consideration.validate(orders) {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        } else if (reentryPoint == ReentryPoint.IncrementNonce) {
            try consideration.incrementNonce() {} catch (bytes memory reason) {
                emit BytesReason(reason);
            }
        }
    }

    receive() external payable {
        if (reenter) {
            _doReenter();
        }
    }
}
