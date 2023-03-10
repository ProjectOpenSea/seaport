// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./SeaportSol.sol";

library FulfillmentHelper {
    bytes32 private constant fulfillmentOfferMapKey =
        keccak256("FulfillmentHelper.fulfillmentOfferMap");
    bytes32 private constant fulfillmentConsiderationMapKey =
        keccak256("FulfillmentHelper.fulfillmentConsiderationMap");
    bytes32 private constant fulfillmentOfferEnumerationKey =
        keccak256("FulfillmentHelper.fulfillmentOfferEnumeration");
    bytes32 private constant fulfillmentConsiderationEnumerationKey =
        keccak256("FulfillmentHelper.fulfillmentconsiderationEnumeration");

    // used to effectively "wipe" the mappings and enumerations each time getAggregated is called
    bytes32 private constant fulfillmentCounterKey =
        keccak256("FulfillmentHelper.fulfillmentCounter");

    struct AggregatableToken {
        address offererOrRecipient;
        address contractAddress;
        uint256 tokenId;
    }

    /**
     * @notice get naive 2d fulfillment component arrays for
     * fulfillAvailableOrders, one 1d array for each offer and consideration
     * item
     * @param orders orders
     * @return offer
     * @return consideration
     */
    function getNaiveFulfillmentComponents(Order[] memory orders)
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getNaiveFulfillmentComponents(orderParameters);
    }

    /**
     * @notice get naive 2d fulfillment component arrays for
     * fulfillAvailableOrders, one 1d array for each offer and consideration
     * item
     * @param orders orders
     * @return offer
     * @return consideration
     */
    function getNaiveFulfillmentComponents(AdvancedOrder[] memory orders)
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getNaiveFulfillmentComponents(orderParameters);
    }

    /**
     * @notice get naive 2d fulfillment component arrays for
     * fulfillAvailableOrders, one 1d array for each offer and consideration
     * item
     * @param orderParameters orderParameters
     * @return offer
     * @return consideration
     */
    function getNaiveFulfillmentComponents(
        OrderParameters[] memory orderParameters
    )
        internal
        pure
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        // get total number of offer items and consideration items
        uint256 numOffers;
        uint256 numConsiderations;
        for (uint256 i = 0; i < orderParameters.length; i++) {
            OrderParameters memory parameters = orderParameters[i];

            numOffers += parameters.offer.length;
            numConsiderations += parameters.consideration.length;
        }

        // create arrays
        offer = new FulfillmentComponent[][](numOffers);
        consideration = new FulfillmentComponent[][](numConsiderations);
        uint256 offerIndex;
        uint256 considerationIndex;
        // iterate over orders again, creating one one-element array per offer and consideration item
        for (uint256 i = 0; i < orderParameters.length; i++) {
            OrderParameters memory parameters = orderParameters[i];
            for (uint256 j; j < parameters.offer.length; j++) {
                offer[offerIndex] = SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: i, itemIndex: j })
                );
                ++offerIndex;
            }
            // do the same for consideration
            for (uint256 j; j < parameters.consideration.length; j++) {
                consideration[considerationIndex] = SeaportArrays
                    .FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: i, itemIndex: j })
                );
                ++considerationIndex;
            }
        }
        return (offer, consideration);
    }

    /**
     * @notice Get aggregated fulfillment components for aggregatable types from the same offerer or to the same recipient
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return offer
     * @return consideration
     */
    function getAggregatedFulfillmentComponents(Order[] memory orders)
        internal
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getAggregatedFulfillmentComponents(orderParameters);
    }

    /**
     * @notice Get aggregated fulfillment components for aggregatable types from the same offerer or to the same recipient
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return offer
     * @return consideration
     */
    function getAggregatedFulfillmentComponents(AdvancedOrder[] memory orders)
        internal
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        OrderParameters[] memory orderParameters =
            new OrderParameters[](orders.length);
        for (uint256 i = 0; i < orders.length; i++) {
            orderParameters[i] = orders[i].parameters;
        }
        return getAggregatedFulfillmentComponents(orderParameters);
    }

    /**
     * @notice Get aggregated fulfillment components for aggregatable types from the same offerer or to the same recipient
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return offer
     * @return consideration
     */
    function getAggregatedFulfillmentComponents(OrderParameters[] memory orders)
        internal
        returns (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        )
    {
        // increment counter to get clean mappings and enumeration
        incrementFulfillmentCounter();

        // get mappings and enumerations
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                        )
                )
            ) storage offerMap = getMap(fulfillmentOfferMapKey);
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                        )
                )
            ) storage considerationMap =
                getMap(fulfillmentConsiderationMapKey);
        AggregatableToken[] storage offerEnumeration =
            getEnumeration(fulfillmentOfferEnumerationKey);
        AggregatableToken[] storage considerationEnumeration =
            getEnumeration(fulfillmentConsiderationEnumerationKey);

        // iterate over each order
        for (uint256 i; i < orders.length; ++i) {
            OrderParameters memory parameters = orders[i];
            processOffer(
                parameters.offer,
                parameters.offerer,
                i,
                offerMap,
                offerEnumeration
            );
            processConsideration(
                parameters.consideration,
                i,
                considerationMap,
                considerationEnumeration
            );
        }

        // allocate offer arrays
        offer = new FulfillmentComponent[][](offerEnumeration.length);
        // iterate over enumerated groupings and add to array
        for (uint256 i; i < offerEnumeration.length; ++i) {
            AggregatableToken memory token = offerEnumeration[i];
            offer[i] = offerMap[token.offererOrRecipient][token.contractAddress][token
                .tokenId];
        }
        // do the same for considerations
        consideration = new FulfillmentComponent[][](
            considerationEnumeration.length
        );
        for (uint256 i; i < considerationEnumeration.length; ++i) {
            AggregatableToken memory token = considerationEnumeration[i];
            consideration[i] = considerationMap[token.offererOrRecipient][token
                .contractAddress][token.tokenId];
        }
        return (offer, consideration);
    }

    /**
     * @notice Process offer items and insert them into enumeration and map
     * @param offer offer items
     * @param offerer offerer
     * @param orderIndex order index of processed items
     * @param offerMap map to save components to
     * @param offerEnumeration enumeration to save aggregatabletokens to
     */
    function processOffer(
        OfferItem[] memory offer,
        address offerer,
        uint256 orderIndex,
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                        )
                )
            ) storage offerMap,
        AggregatableToken[] storage offerEnumeration
    ) private {
        // iterate over each offer item
        for (uint256 j; j < offer.length; ++j) {
            // create the fulfillment component for this offer item
            FulfillmentComponent memory component =
                FulfillmentComponent({ orderIndex: orderIndex, itemIndex: j });
            // grab order parameters to get offerer
            // grab offer item
            OfferItem memory item = offer[j];
            // create enumeration struct
            AggregatableToken memory token = AggregatableToken({
                offererOrRecipient: offerer,
                contractAddress: item.token,
                tokenId: item.identifierOrCriteria
            });
            // if it does not exist in the map, add it to our enumeration
            if (!exists(token, offerMap)) {
                offerEnumeration.push(token);
            }
            // update mapping with this component
            offerMap[token.offererOrRecipient][token.contractAddress][token
                .tokenId].push(component);
        }
    }

    /**
     * @notice Process consideration items and insert them into enumeration and map
     * @param consideration consideration items
     * @param orderIndex order index of processed items
     * @param considerationMap map to save components to
     * @param considerationEnumeration enumeration to save aggregatabletokens to
     */
    function processConsideration(
        ConsiderationItem[] memory consideration,
        uint256 orderIndex,
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                        )
                )
            ) storage considerationMap,
        AggregatableToken[] storage considerationEnumeration
    ) private {
        // iterate over each offer item
        for (uint256 j; j < consideration.length; ++j) {
            // create the fulfillment component for this offer item
            FulfillmentComponent memory component =
                FulfillmentComponent({ orderIndex: orderIndex, itemIndex: j });
            // grab consideration item
            ConsiderationItem memory item = consideration[j];
            // create enumeration struct
            AggregatableToken memory token = AggregatableToken({
                offererOrRecipient: item.recipient,
                contractAddress: item.token,
                tokenId: item.identifierOrCriteria
            });
            // if it does not exist in the map, add it to our enumeration
            if (!exists(token, considerationMap)) {
                considerationEnumeration.push(token);
            }
            // update mapping with this component
            considerationMap[token.offererOrRecipient][token.contractAddress][token
                .tokenId].push(component);
        }
    }

    /**
     * @notice Check if a token already exists in a mapping by checking the length of the array at that slot
     * @param token token to check
     * @param map map to check
     */
    function exists(
        AggregatableToken memory token,
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                        )
                )
            ) storage map
    ) private view returns (bool) {
        return map[token.offererOrRecipient][token.contractAddress][token
            .tokenId].length > 0;
    }

    /**
     * @notice increment the fulfillmentCounter to effectively clear the mappings and enumerations between calls
     */
    function incrementFulfillmentCounter() private {
        bytes32 counterKey = fulfillmentCounterKey;
        assembly {
            sstore(counterKey, add(sload(counterKey), 1))
        }
    }

    /**
     * @notice Get the mapping of tokens for a given key (offer or consideration), derived from the hash of the key and the current fulfillmentCounter value
     * @param key Original key used to derive the slot of the enumeration
     */
    function getMap(bytes32 key)
        private
        view
        returns (
            mapping(
                address /*offererOrRecipient*/
                    => mapping(
                        address /*tokenContract*/
                            => mapping(
                                uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                            )
                    )
                ) storage map
        )
    {
        bytes32 counterKey = fulfillmentCounterKey;
        assembly {
            mstore(0, key)
            mstore(0x20, sload(counterKey))
            map.slot := keccak256(0, 0x40)
        }
    }

    /**
     * @notice Get the enumeration of AggregatableTokens for a given key (offer or consideration), derived from the hash of the key and the current fulfillmentCounter value
     * @param key Original key used to derive the slot of the enumeration
     */
    function getEnumeration(bytes32 key)
        private
        view
        returns (AggregatableToken[] storage tokens)
    {
        bytes32 counterKey = fulfillmentCounterKey;
        assembly {
            mstore(0, key)
            mstore(0x20, sload(counterKey))
            tokens.slot := keccak256(0, 0x40)
        }
    }
}
