// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    MatchFulfillmentHelper
} from "../fulfillments/match/MatchFulfillmentHelper.sol";
import {
    FulfillAvailableHelper
} from "../fulfillments/available/FulfillAvailableHelper.sol";
import {
    AmountDeriverHelper
} from "../lib/fulfillment/AmountDeriverHelper.sol";
import {
    Execution,
    Fulfillment,
    FulfillmentComponent,
    AdvancedOrder,
    Order,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    CriteriaResolver
} from "../../../lib/ConsiderationStructs.sol";

library ExecutionHelper {
    using AmountDeriverHelper for OrderParameters;
    using AmountDeriverHelper for OrderParameters[];

    error InsufficientNativeTokensSupplied();

    struct OrderDetails {
        address offerer;
        bytes32 conduitKey;
        SpentItem[] spentItems;
        ReceivedItem[] receivedItems;
    }

    // return executions for fulfilOrder and fulfillAdvancedOrder
    function getStandardExecutions(
        OrderDetails memory orderDetails,
        address fulfiller,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 nativeTokensSupplied
    ) internal pure returns (Execution[] memory implicitExecutions) {
        uint256 excessNativeTokens = providesExcessNativeTokens(
            orderDetails,
            nativeTokensSupplied
        );
        implicitExecutions = new Execution[](
            orderDetails.spentItems.length +
                orderDetails.receivedItems.length +
                (excessNativeTokens > 0 ? 1 : 0)
        );
        uint256 executionIndex = 0;
        for (uint256 i = 0; i < orderDetails.spentItems.length; i++) {
            implicitExecutions[executionIndex] = Execution({
                offerer: orderDetails.offerer,
                conduitKey: orderDetails.conduitKey,
                receivedItem: ReceivedItem({
                    itemType: orderDetails.spentItems[i].itemType,
                    token: orderDetails.spentItems[i].token,
                    identifier: orderDetails.spentItems[i].identifier,
                    amount: orderDetails.spentItems[i].amount,
                    recipient: recipient
                })
            });
            executionIndex++;
        }

        for (uint256 i = 0; i < orderDetails.receivedItems.length; i++) {
            implicitExecutions[executionIndex] = Execution({
                offerer: fulfiller,
                conduitKey: fulfillerConduitKey,
                receivedItem: orderDetails.receivedItems[i]
            });
            executionIndex++;
        }

        if (excessNativeTokens > 0) {
            implicitExecutions[executionIndex] = Execution({
                offerer: fulfiller, // should be seaport
                conduitKey: bytes32(0),
                receivedItem: ReceivedItem({
                    itemType: 0,
                    token: address(0),
                    identifier: 0,
                    amount: excessNativeTokens,
                    recipient: fulfiller
                })
            });
        }
    }

    function providesExcessNativeTokens(
        OrderDetails memory orderDetails,
        uint256 nativeTokensSupplied
    ) internal pure returns (uint256 excessNativeTokens) {
        for (uint256 i = 0; i < orderDetails.receivedItems.length; i++) {
            if (orderDetails.receivedItems[i].token == address(0)) {
                if (
                    nativeTokensSupplied < orderDetails.receivedItems[i].amount
                ) {
                    revert InsufficientNativeTokensSupplied();
                }
                nativeTokensSupplied -= orderDetails.receivedItems[i].amount;
            }
        }
        excessNativeTokens = nativeTokensSupplied;
    }

    // return executions for fulfillBasicOrder and fulfillBasicOrderEfficient
    function getBasicExecutions(
        OrderDetails memory orderDetails,
        address fulfiller,
        bytes32 fulfillerConduitKey,
        uint256 nativeTokensSupplied
    ) internal pure returns (Execution[] memory implicitExecutions) {
        if (orderDetails.spentItems.length != 1) {
            revert("not a basic order");
        }
        if (orderDetails.spentItems[0].itemType == ItemType.ERC20) {
            require(nativeTokensSupplied == 0, "native tokens not allowed");
            require(orderDetails.receivedItems.length > 0, "no items received");

            implicitExecutions = new Execution[](
                1 + orderDetails.receivedItems.length
            );
            implicitExecutions[0] = Execution({
                offerer: fulfiller,
                conduitKey: fulfillerConduitKey,
                receivedItem: orderDetails.receivedItems[0]
            });

            uint256 additionalAmounts = 0;

            for (uint256 i = 1; i < orderDetails.receivedItems.length; i++) {
                implicitExecutions[i] = Execution({
                    offerer: orderDetails.offerer,
                    conduitKey: orderDetails.conduitKey,
                    receivedItem: orderDetails.receivedItems[i]
                });
                additionalAmounts += orderDetails.receivedItems[i].amount;
            }
            implicitExecutions[orderDetails.receivedItems.length] = Execution({
                offerer: orderDetails.offerer,
                conduitKey: orderDetails.conduitKey,
                receivedItem: ReceivedItem({
                    itemType: orderDetails.spentItems[0].itemType,
                    token: orderDetails.spentItems[0].token,
                    identifier: orderDetails.spentItems[0].identifier,
                    amount: orderDetails.spentItems[0].amount -
                        additionalAmounts,
                    recipient: fulfiller
                })
            });
        } else {
            // use existing function but order of executions has to be shifted
            // so second execution is returned last in cases where no returned native tokens
            // or second to last in cases where returned native tokens
            Execution[] memory standardExecutions = getStandardExecutions(
                orderDetails,
                fulfiller,
                fulfillerConduitKey,
                fulfiller,
                nativeTokensSupplied
            );
            require(standardExecutions.length > 1, "too short for basic order");
            implicitExecutions = new Execution[](standardExecutions.length);
            implicitExecutions[0] = standardExecutions[0];

            if (
                standardExecutions.length >
                1 + orderDetails.receivedItems.length
            ) {
                for (uint256 i = 2; i < implicitExecutions.length - 1; i++) {
                    implicitExecutions[i - 1] = standardExecutions[i];
                }
                implicitExecutions[
                    implicitExecutions.length - 2
                ] = standardExecutions[1];
                implicitExecutions[
                    implicitExecutions.length - 1
                ] = standardExecutions[implicitExecutions.length - 1];
            } else {
                for (uint256 i = 2; i < implicitExecutions.length; i++) {
                    implicitExecutions[i - 1] = standardExecutions[i];
                }
                implicitExecutions[
                    implicitExecutions.length - 1
                ] = standardExecutions[1];
            }
        }
    }

    function getAvailableExecutions(
        OrderDetails[] memory orderDetailsArray,
        bool[] memory availableOrders,
        FulfillmentComponent[] memory offerFulfillments,
        FulfillmentComponent[] memory considerationFulfillments,
        address fulfiller,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 nativeTokensSupplied
    )
        internal
        pure
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        // stub for now
    }

    //
    function getMatchExecutions(
        OrderDetails[] memory orderItemsArray,
        Fulfillment[] memory fulfillments,
        address caller,
        address recipient,
        uint256 nativeTokensSupplied
    )
        internal
        pure
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        // stub for now
    }

    function getOrderDetails(
        AdvancedOrder memory order,
        uint256 timestamp,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (OrderDetails memory orderDetails) {
        orderDetails = OrderDetails({
            offerer: order.offerer,
            conduitKey: order.conduitKey,
            spentItems: getSpentItems(
                order.parameters.offer,
                order.numerator,
                order.denominator,
                timestamp,
                criteriaResolvers
            ),
            receivedItems: getReceivedItems(
                order.parameters.consideration,
                order.numerator,
                order.denominator,
                timestamp,
                criteriaResolvers
            )
        });
    }

    function getOrderDetails(
        AdvancedOrder[] memory orders,
        uint256 timestamp,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (OrderDetails[] memory orderDetailsArray) {
        orderDetailsArray = new OrderDetails[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            orderDetailsArray[i] = getOrderDetails(
                orders[i],
                timestamp,
                criteriaResolvers
            );
        }
    }

    function getSpentItems(
        OfferItem[] memory offer,
        uint256 numerator,
        uint256 denominator,
        uint256 /*timestamp*/,
        CriteriaResolver[] memory /*criteriaResolvers*/
    ) internal pure returns (SpentItem[] memory spentItems) {
        require(
            numerator == denominator,
            "get spent items only supports 1:1 ratio"
        );
        spentItems = new SpentItem[](offer.length);
        for (uint256 i = 0; i < offer.length; i++) {
            require(
                offer[i].itemType != ItemType.ERC721_WITH_CRITERIA &&
                    offer[i].itemType != ItemType.ERC1155_WITH_CRITERIA,
                "get spent items criteria not suppported"
            );
            require(
                offer[i].startAmount == offer[i].endAmount,
                "get spent items only supports fixed amounts"
            );

            spentItems[i] = SpentItem({
                itemType: offer[i].itemType,
                token: offer[i].token,
                identifier: offer[i].identifierOrCriteria,
                amount: offer[i].startAmount
            });
        }
    }

    function getReceivedItems(
        ConsiderationItem[] memory consideration,
        uint256 numerator,
        uint256 denominator,
        uint256 /*timestamp*/,
        CriteriaResolver[] memory /*criteriaResolvers*/
    ) internal pure returns (ReceivedItem[] memory receivedItems) {
        require(
            numerator == denominator,
            "get received items only supports 1:1 ratio"
        );
        receivedItems = new ReceivedItem[](consideration.length);
        for (uint256 i = 0; i < consideration.length; i++) {
            require(
                consideration[i].itemType != ItemType.ERC721_WITH_CRITERIA &&
                    consideration[i].itemType != ItemType.ERC1155_WITH_CRITERIA,
                "get received items criteria not suppported"
            );
            require(
                consideration[i].startAmount == consideration[i].endAmount,
                "get received items only supports fixed amounts"
            );

            receivedItems[i] = ReceivedItem({
                itemType: consideration[i].itemType,
                token: consideration[i].token,
                identifier: consideration[i].identifierOrCriteria,
                amount: consideration[i].startAmount,
                recipient: consideration[i].recipient
            });
        }
    }

    // function getOrderDetails(
    //     OrderParameters memory order
    // ) internal pure returns (OrderDetails memory orderDetails) {}

    // function getOrderDetails(
    //     OrderParameters[] memory orders
    // ) internal pure returns (OrderDetails[] memory orderDetailsArray) {}

    function getOrderDetails(
        uint256 timestamp,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (OrderDetails memory orderDetails) {}

    // TODO: add previewOrders to getOrderDetails when order is contract order

    // three step proces
    // 1. convert orders into order details
    // derive conduit
    // apply partial fractions
    // derive amount
    // resolve criteria
    // run previewOrders for contract orders

    // 2. take order details and high level stuff to work out explicit/implicit executions

    // 3. take explicit/implicit executions and validate executions, transfer events, balance changes
    // happening outside execution helper library

    // start by implementing getOrderDetails
    // set conduitKey to 0
    // if start amount == end amount, use start amount
    // no partial fractions yet

    // implicit execution will be for excess offer items

    // problem with match fulfillment helpers is that it takes orders and only generate specific fulfillment array
    // want to be able to mutate fulfillment array
    // helper for advanced orders <> specific fullfilments
}
