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
    OfferItem,
    ConsiderationItem,
    Order,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    CriteriaResolver
} from "../../../lib/ConsiderationStructs.sol";

import { ItemType, Side } from "../../../lib/ConsiderationEnums.sol";
import {
    AmountDeriverHelper
} from "../lib/fulfillment/AmountDeriverHelper.sol";
import {
    FulfillmentComponentSet,
    FulfillmentComponentSetLib
} from "./FulfillmentComponentSet.sol";
import { FulfillmentComponentSortLib } from "./FulfillmentComponentSortLib.sol";

contract ExecutionHelper is AmountDeriverHelper {
    using FulfillmentComponentSetLib for FulfillmentComponentSet;
    using FulfillmentComponentSortLib for FulfillmentComponent[];
    error InsufficientNativeTokensSupplied();

    FulfillmentComponentSet temp;

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
            orderDetails.offer.length +
                orderDetails.consideration.length +
                (excessNativeTokens > 0 ? 1 : 0)
        );
        uint256 executionIndex = 0;
        for (uint256 i = 0; i < orderDetails.offer.length; i++) {
            implicitExecutions[executionIndex] = Execution({
                offerer: orderDetails.offerer,
                conduitKey: orderDetails.conduitKey,
                item: ReceivedItem({
                    itemType: orderDetails.consideration[i].itemType,
                    token: orderDetails.offer[i].token,
                    identifier: orderDetails.offer[i].identifier,
                    amount: orderDetails.offer[i].amount,
                    recipient: payable(recipient)
                })
            });
            executionIndex++;
        }

        for (uint256 i = 0; i < orderDetails.consideration.length; i++) {
            implicitExecutions[executionIndex] = Execution({
                offerer: fulfiller,
                conduitKey: fulfillerConduitKey,
                item: orderDetails.consideration[i]
            });
            executionIndex++;
        }

        if (excessNativeTokens > 0) {
            implicitExecutions[executionIndex] = Execution({
                offerer: fulfiller, // should be seaport
                conduitKey: bytes32(0),
                item: ReceivedItem({
                    itemType: ItemType.NATIVE,
                    token: address(0),
                    identifier: 0,
                    amount: excessNativeTokens,
                    recipient: payable(fulfiller)
                })
            });
        }
    }

    function providesExcessNativeTokens(
        OrderDetails[] memory orderDetails,
        uint256 nativeTokensSupplied
    ) internal pure returns (uint256 excessNativeTokens) {
        for (uint256 i = 0; i < orderDetails.length; i++) {
            excessNativeTokens += providesExcessNativeTokens(
                orderDetails[i],
                nativeTokensSupplied
            );
        }
    }

    function providesExcessNativeTokens(
        OrderDetails memory orderDetails,
        uint256 nativeTokensSupplied
    ) internal pure returns (uint256 excessNativeTokens) {
        for (uint256 i = 0; i < orderDetails.consideration.length; i++) {
            if (orderDetails.consideration[i].token == address(0)) {
                if (
                    nativeTokensSupplied < orderDetails.consideration[i].amount
                ) {
                    revert InsufficientNativeTokensSupplied();
                }
                nativeTokensSupplied -= orderDetails.consideration[i].amount;
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
        if (orderDetails.offer.length != 1) {
            revert("not a basic order");
        }
        if (orderDetails.offer[0].itemType == ItemType.ERC20) {
            require(nativeTokensSupplied == 0, "native tokens not allowed");
            require(orderDetails.consideration.length > 0, "no items received");

            implicitExecutions = new Execution[](
                1 + orderDetails.consideration.length
            );
            implicitExecutions[0] = Execution({
                offerer: fulfiller,
                conduitKey: fulfillerConduitKey,
                item: orderDetails.consideration[0]
            });

            uint256 additionalAmounts = 0;

            for (uint256 i = 1; i < orderDetails.consideration.length; i++) {
                implicitExecutions[i] = Execution({
                    offerer: orderDetails.offerer,
                    conduitKey: orderDetails.conduitKey,
                    item: orderDetails.consideration[i]
                });
                additionalAmounts += orderDetails.consideration[i].amount;
            }
            implicitExecutions[orderDetails.consideration.length] = Execution({
                offerer: orderDetails.offerer,
                conduitKey: orderDetails.conduitKey,
                item: ReceivedItem({
                    itemType: orderDetails.offer[0].itemType,
                    token: orderDetails.offer[0].token,
                    identifier: orderDetails.offer[0].identifier,
                    amount: orderDetails.offer[0].amount - additionalAmounts,
                    recipient: payable(fulfiller)
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
                1 + orderDetails.consideration.length
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
        Order[] memory orders,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        address recipient,
        uint256 nativeTokensSupplied
    )
        internal
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        temp.clear();
        OrderDetails[] memory orderDetails = toOrderDetails(orders);
        explicitExecutions = processExplicitExecutions(
            orderDetails,
            offerFulfillments,
            considerationFulfillments,
            payable(recipient)
        );
        implicitExecutions = processImplicitExecutions(
            orderDetails,
            offerFulfillments,
            payable(recipient)
        );
        uint256 excessNativeTokens = providesExcessNativeTokens(
            orderDetails,
            nativeTokensSupplied
        );
        if (excessNativeTokens > 0) {
            Execution memory excessNativeExecution = Execution({
                offerer: payable(recipient),
                conduitKey: bytes32(0),
                item: ReceivedItem({
                    itemType: ItemType.NATIVE,
                    token: address(0),
                    identifier: 0,
                    amount: excessNativeTokens,
                    recipient: payable(recipient)
                })
            });
            Execution[] memory tempExecutions = new Execution[](
                implicitExecutions.length + 1
            );
            for (uint256 i = 0; i < implicitExecutions.length; i++) {
                tempExecutions[i] = implicitExecutions[i];
            }
            tempExecutions[implicitExecutions.length] = excessNativeExecution;
        }
    }

    function getItemAndRecipient(
        OrderDetails[] memory order,
        FulfillmentComponent memory component,
        address payable recipient,
        Side side
    )
        internal
        pure
        returns (SpentItem memory item, address payable trueRecipient)
    {
        OrderDetails memory details = order[component.orderIndex];
        if (side == Side.OFFER) {
            item = details.offer[component.itemIndex];
            trueRecipient = recipient;
        } else {
            ReceivedItem memory _item = details.consideration[
                component.itemIndex
            ];
            assembly {
                item := _item
            }
            trueRecipient = _item.recipient;
        }
    }

    function processAggregatedFulfillmentComponents(
        OrderDetails[] memory orderDetails,
        FulfillmentComponent[] memory aggregatedComponents,
        address payable recipient,
        Side side
    ) internal pure returns (Execution memory) {
        // aggregate the amounts of each item
        uint256 aggregatedAmount;
        for (uint256 j = 0; j < aggregatedComponents.length; j++) {
            (SpentItem memory item, ) = getItemAndRecipient(
                orderDetails,
                aggregatedComponents[j],
                recipient,
                side
            );
            aggregatedAmount += item.amount;
        }
        // use the first fulfillment component to get the order details
        FulfillmentComponent memory first = aggregatedComponents[0];
        OrderDetails memory details = orderDetails[first.orderIndex];
        (
            SpentItem memory firstItem,
            address payable trueRecipient
        ) = getItemAndRecipient(orderDetails, first, recipient, side);
        return
            Execution({
                offerer: details.offerer,
                conduitKey: details.conduitKey,
                item: ReceivedItem({
                    itemType: firstItem.itemType,
                    token: firstItem.token,
                    identifier: firstItem.identifier,
                    amount: aggregatedAmount,
                    recipient: trueRecipient
                })
            });
    }

    function processExplicitExecutions(
        OrderDetails[] memory orderDetails,
        FulfillmentComponent[][] memory offerComponents,
        FulfillmentComponent[][] memory considerationComponents,
        address payable recipient
    ) internal pure returns (Execution[] memory explicitExecutions) {
        // convert offerFulfillments to explicitExecutions
        explicitExecutions = new Execution[](
            offerComponents.length + considerationComponents.length
        );
        // iterate over each array of fulfillment components
        for (uint256 i = 0; i < offerComponents.length; i++) {
            FulfillmentComponent[]
                memory aggregatedComponents = offerComponents[i];
            explicitExecutions[i] = processAggregatedFulfillmentComponents(
                orderDetails,
                aggregatedComponents,
                recipient,
                Side.OFFER
            );
        }
        // iterate over each array of fulfillment components
        for (
            uint256 i = offerComponents.length;
            i < considerationComponents.length + offerComponents.length;
            i++
        ) {
            FulfillmentComponent[]
                memory aggregatedComponents = considerationComponents[i];
            explicitExecutions[
                i + offerComponents.length
            ] = processAggregatedFulfillmentComponents(
                orderDetails,
                aggregatedComponents,
                recipient,
                Side.CONSIDERATION
            );
        }
    }

    function processImplicitExecutions(
        OrderDetails[] memory orderDetails,
        FulfillmentComponent[][] memory offerFulfillments,
        address payable recipient
    ) internal returns (Execution[] memory implicitExecutions) {
        // add all offer fulfillment components to temp
        for (uint256 i = 0; i < orderDetails.length; i++) {
            OrderDetails memory details = orderDetails[i];
            for (uint256 j; j < details.offer.length; j++) {
                temp.add(FulfillmentComponent({ orderIndex: i, itemIndex: j }));
            }
        }
        // remove all explicitly enumerated offer fulfillment components
        for (uint256 i = 0; i < offerFulfillments.length; i++) {
            for (uint256 j = 0; j < offerFulfillments[i].length; j++) {
                temp.remove(offerFulfillments[i][j]);
            }
        }

        // enumerate all remaining offer fulfillment components
        // and assemble them into the implicitExecutions array, if any
        implicitExecutions = new Execution[](temp.length());
        FulfillmentComponent[] memory implicit = temp.enumeration;
        // sort so they are ordered by orderIndex and then itemIndex,
        // which is how Seaport will execute them
        implicit.sort();

        for (uint256 i = 0; i < implicit.length; i++) {
            FulfillmentComponent memory component = implicit[i];
            OrderDetails memory details = orderDetails[component.orderIndex];
            SpentItem memory item = details.offer[component.itemIndex];
            implicitExecutions[i] = Execution({
                offerer: details.offerer,
                conduitKey: details.conduitKey,
                item: ReceivedItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifier: item.identifier,
                    amount: item.amount,
                    recipient: recipient
                })
            });
        }
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
}
