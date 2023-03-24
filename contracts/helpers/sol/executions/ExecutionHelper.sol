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
import { MatchComponentStruct } from "../lib/types/MatchComponentType.sol";

/**
 * @notice Helper contract for deriving explicit and executions from orders
 *         and fulfillment details
 * @dev TODO: move to the tests folder? not really useful for normal scripting
 */
contract ExecutionHelper is AmountDeriverHelper {
    using FulfillmentComponentSetLib for FulfillmentComponentSet;
    using FulfillmentComponentSortLib for FulfillmentComponent[];
    error InsufficientNativeTokensSupplied();

    /**
     * @notice Represents the details of a single fulfill/match call to Seaport
     *         TODO: move this and OrderDetails struct into a diff helper?
     * @param orders processed details of individual orders
     * @param recipient the explicit recipient of all offer items in the
     *        fulfillAvailable case; implicit recipient of excess offer items
     *        in the match case
     */
    struct FulfillmentDetails {
        OrderDetails[] orders;
        address payable recipient;
    }

    /// @dev Temp set of fulfillment components to track implicit offer executions;
    /// cleared each time getFulfillAvailableExecutions is called
    FulfillmentComponentSet temp;

    /**
     * @notice convert an array of Orders and an explicit recipient to a
     *         FulfillmentDetails struct
     */
    function toFulfillmentDetails(
        Order[] memory orders,
        address recipient
    ) public view returns (FulfillmentDetails memory fulfillmentDetails) {
        OrderDetails[] memory details = toOrderDetails(orders);
        return
            FulfillmentDetails({
                orders: details,
                recipient: payable(recipient)
            });
    }

    /**
     * @notice convert an array of AdvancedOrders and an explicit recipient to a
     *         FulfillmentDetails struct
     */
    function toFulfillmentDetails(
        AdvancedOrder[] memory orders,
        address recipient
    ) public view returns (FulfillmentDetails memory fulfillmentDetails) {
        OrderDetails[] memory details = toOrderDetails(orders);
        return
            FulfillmentDetails({
                orders: details,
                recipient: payable(recipient)
            });
    }

    /**
     * @notice convert an array of AdvancedOrders, an explicit recipient, and
     *         CriteriaResolvers to a FulfillmentDetails struct
     */
    function toFulfillmentDetails(
        AdvancedOrder[] memory orders,
        address recipient,
        CriteriaResolver[] memory resolvers
    ) public view returns (FulfillmentDetails memory fulfillmentDetails) {
        OrderDetails[] memory details = toOrderDetails(orders, resolvers);
        return
            FulfillmentDetails({
                orders: details,
                recipient: payable(recipient)
            });
    }

    /**
     * @notice get explicit and implicit executions for a fulfillAvailable call
     * @param fulfillmentDetails the fulfillment details
     * @param offerFulfillments 2d array of offer fulfillment components
     * @param considerationFulfillments 2d array of consideration fulfillment
     * @param nativeTokensSupplied the amount of native tokens supplied to the
     *        fulfillAvailable call
     * @return explicitExecutions the explicit executions
     * @return implicitExecutions the implicit executions (unspecified offer items)
     */
    function getFulfillAvailableExecutions(
        FulfillmentDetails memory fulfillmentDetails,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        uint256 nativeTokensSupplied
    )
        public
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        temp.clear();
        OrderDetails[] memory orderDetails = fulfillmentDetails.orders;
        address payable recipient = fulfillmentDetails.recipient;
        explicitExecutions = processExplicitExecutionsFromAggregatedComponents(
            fulfillmentDetails,
            offerFulfillments,
            considerationFulfillments
        );
        implicitExecutions = processImplicitOfferExecutionsFromExplicitAggregatedComponents(
            fulfillmentDetails,
            offerFulfillments
        );
        uint256 excessNativeTokens = processExcessNativeTokens(
            orderDetails,
            nativeTokensSupplied
        );
        if (excessNativeTokens > 0) {
            // technically ether comes back from seaport, but possibly useful for balance changes?
            Execution memory excessNativeExecution = Execution({
                offerer: recipient,
                conduitKey: bytes32(0),
                item: ReceivedItem({
                    itemType: ItemType.NATIVE,
                    token: address(0),
                    identifier: 0,
                    amount: excessNativeTokens,
                    recipient: recipient
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

    /**
     * @notice Process an array of fulfillments into an array of explicit and
     *         implicit executions.
     * @param fulfillmentDetails The fulfillment details.
     * @param fulfillments An array of fulfillments.
     * @param remainingOfferComponents A *sorted*  array of offer fulfillment
     *        components that were not used in any fulfillment.
     */
    function getMatchExecutions(
        FulfillmentDetails memory fulfillmentDetails,
        Fulfillment[] memory fulfillments,
        FulfillmentComponent[] memory remainingOfferComponents
    )
        internal
        pure
        returns (
            Execution[] memory explicitExecutions,
            Execution[] memory implicitExecutions
        )
    {
        explicitExecutions = new Execution[](fulfillments.length);
        for (uint256 i = 0; i < fulfillments.length; i++) {
            explicitExecutions[i] = processExecutionFromFulfillment(
                fulfillmentDetails,
                fulfillments[i]
            );
        }
        implicitExecutions = processExecutionsFromIndividualOfferFulfillmentComponents(
            fulfillmentDetails.orders,
            fulfillmentDetails.recipient,
            remainingOfferComponents
        );
    }

    // return executions for fulfilOrder and fulfillAdvancedOrder
    function getStandardExecutions(
        OrderDetails memory orderDetails,
        address fulfiller,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 nativeTokensSupplied
    ) public pure returns (Execution[] memory implicitExecutions) {
        uint256 excessNativeTokens = processExcessNativeTokens(
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

    // return executions for fulfillBasicOrder and fulfillBasicOrderEfficient
    function getBasicExecutions(
        OrderDetails memory orderDetails,
        address fulfiller,
        bytes32 fulfillerConduitKey,
        uint256 nativeTokensSupplied
    ) public pure returns (Execution[] memory implicitExecutions) {
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

    /**
     * @notice Given orders, return any excess native tokens
     */
    function processExcessNativeTokens(
        OrderDetails[] memory orderDetails,
        uint256 nativeTokensSupplied
    ) internal pure returns (uint256 excessNativeTokens) {
        excessNativeTokens = nativeTokensSupplied;
        for (uint256 i = 0; i < orderDetails.length; i++) {
            // subtract native tokens consumed by each order
            excessNativeTokens -= processExcessNativeTokens(
                orderDetails[i],
                nativeTokensSupplied
            );
        }
        // any remaining native tokens are returned
        return excessNativeTokens;
    }

    /**
     * @notice Given an order, return any excess native tokens
     */
    function processExcessNativeTokens(
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

    /**
     * @notice Get the item and recipient for a given fulfillment component
     * @param orders The order details
     * @param offerRecipient The offer recipient
     * @param component The fulfillment component
     * @param side The side of the order
     */
    function getItemAndRecipient(
        OrderDetails[] memory orders,
        address payable offerRecipient,
        FulfillmentComponent memory component,
        Side side
    )
        internal
        pure
        returns (SpentItem memory item, address payable trueRecipient)
    {
        OrderDetails memory details = orders[component.orderIndex];
        if (side == Side.OFFER) {
            item = details.offer[component.itemIndex];
            trueRecipient = offerRecipient;
        } else {
            ReceivedItem memory _item = details.consideration[
                component.itemIndex
            ];
            // cast to SpentItem
            assembly {
                item := _item
            }
            trueRecipient = _item.recipient;
        }
    }

    /**
     * @notice Process the aggregated fulfillment components for a given side of an order
     * @param orders The fulfillment details
     * @param offerRecipient The recipient for any offer items
     *        Note: may not be FulfillmentDetails' recipient, eg, when
     *        processing matchOrders fulfillments
     * @param aggregatedComponents The aggregated fulfillment components
     
     * @param side The side of the order
     * @return The execution
     */
    function processExecutionFromAggregatedFulfillmentComponents(
        OrderDetails[] memory orders,
        address payable offerRecipient,
        FulfillmentComponent[] memory aggregatedComponents,
        Side side
    ) internal pure returns (Execution memory) {
        // aggregate the amounts of each item
        uint256 aggregatedAmount;
        for (uint256 j = 0; j < aggregatedComponents.length; j++) {
            (SpentItem memory item, ) = getItemAndRecipient(
                orders,
                offerRecipient,
                aggregatedComponents[j],
                side
            );
            aggregatedAmount += item.amount;
        }
        // use the first fulfillment component to get the order details
        FulfillmentComponent memory first = aggregatedComponents[0];
        (
            SpentItem memory firstItem,
            address payable trueRecipient
        ) = getItemAndRecipient(orders, offerRecipient, first, side);
        OrderDetails memory details = orders[first.orderIndex];
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

    /**
     * @notice Process explicit executions from 2d aggregated fulfillAvailable
     *         fulfillment components arrays
     * @param fulfillmentDetails The fulfillment details
     * @param offerComponents The offer components
     * @param considerationComponents The consideration components
     * @return explicitExecutions The explicit executions
     */
    function processExplicitExecutionsFromAggregatedComponents(
        FulfillmentDetails memory fulfillmentDetails,
        FulfillmentComponent[][] memory offerComponents,
        FulfillmentComponent[][] memory considerationComponents
    ) internal pure returns (Execution[] memory explicitExecutions) {
        // convert offerFulfillments to explicitExecutions
        explicitExecutions = new Execution[](
            offerComponents.length + considerationComponents.length
        );
        OrderDetails[] memory orders = fulfillmentDetails.orders;
        address payable recipient = fulfillmentDetails.recipient;
        // process offers
        // iterate over each array of fulfillment components
        for (uint256 i = 0; i < offerComponents.length; i++) {
            FulfillmentComponent[]
                memory aggregatedComponents = offerComponents[i];
            explicitExecutions[
                i
            ] = processExecutionFromAggregatedFulfillmentComponents(
                orders,
                recipient,
                aggregatedComponents,
                Side.OFFER
            );
        }
        // process considerations
        // iterate over each array of fulfillment components
        for (uint256 i; i < considerationComponents.length; i++) {
            FulfillmentComponent[]
                memory aggregatedComponents = considerationComponents[i];
            explicitExecutions[
                i + offerComponents.length
            ] = processExecutionFromAggregatedFulfillmentComponents(
                orders,
                recipient,
                aggregatedComponents,
                Side.CONSIDERATION
            );
        }
    }

    /**
     * @notice Process an array of *sorted* fulfillment components into an array of executions.
     * Note that components must be sorted.
     * @param orderDetails The order details
     * @param components The fulfillment components
     * @param recipient The recipient of implicit executions
     */
    function processExecutionsFromIndividualOfferFulfillmentComponents(
        OrderDetails[] memory orderDetails,
        address payable recipient,
        FulfillmentComponent[] memory components
    ) internal pure returns (Execution[] memory executions) {
        executions = new Execution[](components.length);

        for (uint256 i = 0; i < components.length; i++) {
            FulfillmentComponent memory component = components[i];
            OrderDetails memory details = orderDetails[component.orderIndex];
            SpentItem memory item = details.offer[component.itemIndex];
            executions[i] = Execution({
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

    /**
     * @notice Generate implicit Executions for a set of orders by getting all
     *         offer items that are not explicitly enumerated in the aggregated
     *         offer fulfillment components.
     * @param fulfillmentDetails fulfillment details
     * @param offerFulfillments explicitly enumerated aggregated offer
     *        fulfillment components
     */
    function processImplicitOfferExecutionsFromExplicitAggregatedComponents(
        FulfillmentDetails memory fulfillmentDetails,
        FulfillmentComponent[][] memory offerFulfillments
    ) internal returns (Execution[] memory implicitExecutions) {
        // add all offer fulfillment components to temp
        OrderDetails[] memory orderDetails = fulfillmentDetails.orders;
        address payable recipient = fulfillmentDetails.recipient;
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
        FulfillmentComponent[] memory implicit = temp.enumeration;
        // sort them by orderIndex and itemIndex, since that is how Seaport
        // will execute them
        implicit.sort();
        implicitExecutions = processExecutionsFromIndividualOfferFulfillmentComponents(
            orderDetails,
            recipient,
            temp.enumeration
        );
    }

    /**
     * @notice Process a Fulfillment into an Execution
     * @param fulfillmentDetails fulfillment details
     * @param fulfillment A Fulfillment.
     * @return An Execution.
     */
    function processExecutionFromFulfillment(
        FulfillmentDetails memory fulfillmentDetails,
        Fulfillment memory fulfillment
    ) internal pure returns (Execution memory) {
        // grab first consideration component
        FulfillmentComponent memory firstConsiderationComponent = fulfillment
            .considerationComponents[0];
        // get recipient of the execution
        address payable recipient = fulfillmentDetails
            .orders[firstConsiderationComponent.orderIndex]
            .consideration[firstConsiderationComponent.itemIndex]
            .recipient;
        return
            processExecutionFromAggregatedFulfillmentComponents(
                fulfillmentDetails.orders,
                recipient,
                fulfillment.offerComponents,
                Side.OFFER
            );
    }
}
