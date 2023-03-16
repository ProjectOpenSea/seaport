// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AggregatableConsideration,
    ProcessComponentParams,
    AggregatableOfferer,
    MatchFulfillmentStorageLayout
} from "../lib/Structs.sol";
import {
    MatchComponent,
    MatchComponentType
} from "../../lib/types/MatchComponentType.sol";
import {
    FulfillmentComponent,
    Fulfillment,
    Order,
    AdvancedOrder,
    OrderParameters,
    OfferItem,
    ConsiderationItem
} from "../../SeaportSol.sol";
import { MatchFulfillmentLib } from "./MatchFulfillmentLib.sol";
import { MatchFulfillmentLayout } from "./MatchFulfillmentLayout.sol";

library MatchFulfillmentHelper {
    /**
     * @notice Generate matched fulfillments for a list of orders
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return fulfillments
     */
    function getMatchedFulfillments(Order[] memory orders)
        internal
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents,
            MatchComponent[] memory remainingConsiderationComponents
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getMatchedFulfillments(orderParameters);
    }

    /**
     * @notice Generate matched fulfillments for a list of orders
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return fulfillments
     */
    function getMatchedFulfillments(AdvancedOrder[] memory orders)
        internal
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents,
            MatchComponent[] memory remainingConsiderationComponents
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getMatchedFulfillments(orderParameters);
    }

    /**
     * @notice Generate matched fulfillments for a list of orders
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return fulfillments
     */
    function getMatchedFulfillments(OrderParameters[] memory orders)
        internal
        returns (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory remainingOfferComponents,
            MatchComponent[] memory remainingConsiderationComponents
        )
    {
        // increment counter to get clean mappings and enumeration
        MatchFulfillmentLayout.incrementFulfillmentCounter();
        // load the storage layout
        MatchFulfillmentStorageLayout storage layout =
            MatchFulfillmentLayout.getStorageLayout();

        // iterate over each order and process the offer and consideration components
        for (uint256 i; i < orders.length; ++i) {
            OrderParameters memory parameters = orders[i];
            // insert MatchComponents into the offer mapping, grouped by token, tokenId, offerer, and conduitKey
            // also update per-token+tokenId enumerations of AggregatableOfferer

            preProcessOfferItems(
                parameters.offer,
                parameters.offerer,
                parameters.conduitKey,
                i,
                layout
            );
            // insert MatchComponents into the offer mapping, grouped by token, tokenId, and recipient
            // also update AggregatableConsideration enumeration
            preProcessConsiderationItems(parameters.consideration, i, layout);
        }

        // iterate over groups of consideration components and find matching offer components
        uint256 considerationLength = layout.considerationEnumeration.length;
        for (uint256 i; i < considerationLength; ++i) {
            // get the token information
            AggregatableConsideration storage token =
                layout.considerationEnumeration[i];
            // load the consideration components
            MatchComponent[] storage considerationComponents = layout
                .considerationMap[token.recipient][token.contractAddress][token
                .tokenId];
            // load the enumeration of offerer+conduit keys for offer components that match this token
            AggregatableOfferer[] storage offererEnumeration = layout
                .tokenToOffererEnumeration[token.contractAddress][token.tokenId];
            // iterate over each offerer+conduit with offer components that match this token and create matching fulfillments
            // this will update considerationComponents in-place in storage, which we check at the beginning of each loop
            for (uint256 j; j < offererEnumeration.length; ++j) {
                // if all consideration components have been fulfilled, break
                if (considerationComponents.length == 0) {
                    break;
                }
                // load the AggregatableOfferer
                AggregatableOfferer storage aggregatableOfferer =
                    offererEnumeration[j];
                // load the associated offer components for this offerer+conduit
                MatchComponent[] storage offerComponents = layout.offerMap[token
                    .contractAddress][token.tokenId][aggregatableOfferer.offerer][aggregatableOfferer
                    .conduitKey];

                // create a fulfillment matching the offer and consideration components until either or both are exhausted
                Fulfillment memory fulfillment = MatchFulfillmentLib
                    .createFulfillment(offerComponents, considerationComponents);
                // append the fulfillment to the array of fulfillments
                fulfillments =
                    MatchFulfillmentLib.extend(fulfillments, fulfillment);
                // loop back around in case not all considerationComponents have been completely fulfilled
            }
        }

        // get any remaining offer components
        for (uint256 i; i < orders.length; ++i) {
            OrderParameters memory parameters = orders[i];
            // insert MatchComponents into the offer mapping, grouped by token, tokenId, offerer, and conduitKey
            // also update per-token+tokenId enumerations of AggregatableOfferer
            remainingOfferComponents = MatchFulfillmentLib.extend(
                remainingOfferComponents,
                postProcessOfferItems(
                    parameters.offer,
                    parameters.offerer,
                    parameters.conduitKey,
                    layout
                )
            );

            remainingConsiderationComponents = MatchFulfillmentLib.extend(
                remainingConsiderationComponents,
                postProcessConsiderationItems(parameters.consideration, layout)
            );
        }
        remainingOfferComponents =
            MatchFulfillmentLib.dedupe(remainingOfferComponents);
        remainingConsiderationComponents =
            MatchFulfillmentLib.dedupe(remainingConsiderationComponents);
    }

    /**
     * @notice Process offer items and insert them into enumeration and map
     * @param offer offer items
     * @param offerer offerer
     * @param orderIndex order index of processed items
     * @param layout storage layout of helper
     */
    function preProcessOfferItems(
        OfferItem[] memory offer,
        address offerer,
        bytes32 conduitKey,
        uint256 orderIndex,
        MatchFulfillmentStorageLayout storage layout
    ) private {
        // iterate over each offer item
        for (uint256 j; j < offer.length; ++j) {
            // grab offer item
            // TODO: spentItems?
            OfferItem memory item = offer[j];
            MatchComponent component = MatchComponentType.createMatchComponent({
                amount: uint240(item.startAmount),
                orderIndex: uint8(orderIndex),
                itemIndex: uint8(j)
            });
            AggregatableOfferer memory aggregatableOfferer = AggregatableOfferer({
                offerer: offerer,
                conduitKey: conduitKey
            });

            // if it does not exist in the map, add it to our per-token+id enumeration
            if (
                !MatchFulfillmentLib.aggregatableOffererExists(
                    item.token,
                    item.identifierOrCriteria,
                    aggregatableOfferer,
                    layout
                )
            ) {
                // add to enumeration for specific tokenhash (tokenAddress+tokenId)
                layout.tokenToOffererEnumeration[item.token][item
                    .identifierOrCriteria].push(aggregatableOfferer);
            }
            // update aggregatable mapping array with this component
            layout.offerMap[item.token][item.identifierOrCriteria][offerer][conduitKey]
                .push(component);
        }
    }

    function postProcessOfferItems(
        OfferItem[] memory offer,
        address offerer,
        bytes32 conduitKey,
        MatchFulfillmentStorageLayout storage layout
    ) private view returns (MatchComponent[] memory remainingOfferComponents) {
        // iterate over each offer item
        for (uint256 j; j < offer.length; ++j) {
            // grab offer item
            // TODO: spentItems?
            OfferItem memory item = offer[j];

            // update aggregatable mapping array with this component
            remainingOfferComponents = MatchFulfillmentLib.extend(
                remainingOfferComponents,
                layout.offerMap[item.token][item.identifierOrCriteria][offerer][conduitKey]
            );
        }
    }

    /**
     * @notice Process consideration items and insert them into enumeration and map
     * @param consideration consideration items
     * @param orderIndex order index of processed items
     * @param layout storage layout of helper
     */
    function preProcessConsiderationItems(
        ConsiderationItem[] memory consideration,
        uint256 orderIndex,
        MatchFulfillmentStorageLayout storage layout
    ) private {
        // iterate over each consideration item
        for (uint256 j; j < consideration.length; ++j) {
            // grab consideration item
            ConsiderationItem memory item = consideration[j];
            // TODO: use receivedItem here?
            MatchComponent component = MatchComponentType.createMatchComponent({
                amount: uint240(item.startAmount),
                orderIndex: uint8(orderIndex),
                itemIndex: uint8(j)
            });
            // create enumeration struct
            AggregatableConsideration memory token = AggregatableConsideration({
                recipient: item.recipient,
                contractAddress: item.token,
                tokenId: item.identifierOrCriteria
            });
            // if it does not exist in the map, add it to our enumeration
            if (
                !MatchFulfillmentLib.aggregatableConsiderationExists(
                    token, layout
                )
            ) {
                layout.considerationEnumeration.push(token);
            }
            // update mapping with this component
            layout.considerationMap[token.recipient][token.contractAddress][token
                .tokenId].push(component);
        }
    }

    function postProcessConsiderationItems(
        ConsiderationItem[] memory consideration,
        MatchFulfillmentStorageLayout storage layout
    )
        private
        view
        returns (MatchComponent[] memory remainingConsiderationComponents)
    {
        // iterate over each consideration item
        for (uint256 j; j < consideration.length; ++j) {
            // grab consideration item
            ConsiderationItem memory item = consideration[j];

            remainingConsiderationComponents = MatchFulfillmentLib.extend(
                remainingConsiderationComponents,
                layout.considerationMap[item.recipient][item.token][item
                    .identifierOrCriteria]
            );
        }
    }
}
