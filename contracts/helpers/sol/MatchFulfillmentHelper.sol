// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./SeaportSol.sol";
import {
    MatchComponent,
    MatchComponentType
} from "./lib/types/MatchComponentType.sol";
import { LibSort } from "solady/src/utils/LibSort.sol";

// used to effectively "wipe" the mappings and enumerations each time getAggregated is called
bytes32 constant fulfillmentCounterKey = keccak256(
    "MatchFulfillmentHelper.fulfillmentCounter"
);

bytes32 constant fulfillmentHelperStorageBaseKey = keccak256(
    "MatchFulfillmentHelper.storageBase"
);

struct FulfillmentHelperCounterLayout {
    uint256 fulfillmentCounter;
}

// TODO: won't work for partial fulfills of criteria resolved
// TODO: won't work for hybrid tokens that implement multiple token interfaces
struct FulfillmentHelperStorageLayout {
    mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => mapping(address /*offerer*/ => mapping(bytes32 /*conduitKey*/ => MatchComponent[] /*components*/)))) offerMap;
    mapping(address /*recipient*/ => mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => MatchComponent[] /*components*/))) considerationMap;
    // a given aggregatable consideration component will have its own set of aggregatable offer components
    mapping(address /*token*/ => mapping(uint256 /*tokenId*/ => OffererAndConduit[] /*offererEnumeration*/)) tokenToOffererEnumeration;
    // aggregatable consideration components can be enumerated normally
    AggregatableToken[] considerationEnumeration;
}

/**
 * @notice Offers can only be aggregated if they share an offerer *and* conduitKey
 */
struct OffererAndConduit {
    address offerer;
    bytes32 conduitKey;
}

/**
 *
 * @notice Considerations can only be aggregated if they share a token address, id, and recipient (and itemType, but in the vast majority of cases, a token is only one type)
 */
struct AggregatableToken {
    address offererOrRecipient;
    address contractAddress;
    uint256 tokenId;
}

library MatchFulfillmentPriv {
    /**
     * @notice Check if a token already exists in a mapping by checking the length of the array at that slot
     * @param token token to check
     * @param map map to check
     */
    function tokenConsiderationExists(
        AggregatableToken memory token,
        mapping(address /*offererOrRecipient*/ => mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => MatchComponent[] /*components*/)))
            storage map
    ) internal view returns (bool) {
        return
            map[token.offererOrRecipient][token.contractAddress][token.tokenId]
                .length > 0;
    }

    /**
     * @notice Check if an entry into the offer component mapping already exists by checking its length
     */
    function offererTokenComboExists(
        address token,
        uint256 tokenId,
        address offerer,
        bytes32 conduitKey,
        mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => mapping(address /*offerer*/ => mapping(bytes32 /*conduitKey*/ => MatchComponent[] /*components*/))))
            storage offerMap
    ) internal view returns (bool) {
        return offerMap[token][tokenId][offerer][conduitKey].length > 0;
    }

    // TODO: REMOVE: Undo all this when James comes through with a proper fix.

    struct CreateFulfillmentInfra {
        uint256 offerLength;
        uint256 considerationLength;
        uint256 offerFulfillmentIndex;
        uint256 considerationFulfillmentIndex;
        FulfillmentComponent[] offerFulfillmentComponents;
        FulfillmentComponent[] considerationFulfillmentComponents;
        uint256 offerIndex;
        uint256 considerationIndex;
        bool credited;
        bool midCredit;
        MatchComponent offerComponent;
        MatchComponent considerationComponent;
        uint256 offerAmount;
        uint256 considerationAmount;
    }

    /**
     * Credit offer components to consideration components until either or both are exhausted
     * Updates arrays in storage to remove 0-item components after credits
     * @param offerComponents Aggregatable offer components
     * @param considerationComponents Aggregatable consideration components
     */
    function createFulfillment(
        MatchComponent[] storage offerComponents,
        MatchComponent[] storage considerationComponents
    ) internal returns (Fulfillment memory) {

        CreateFulfillmentInfra memory infra;

        infra.offerLength = offerComponents.length;
        infra.considerationLength = considerationComponents.length;
        // track indexes of fulfillments since not all may be used up
        infra.offerFulfillmentIndex;
        infra.considerationFulfillmentIndex;
        // optimistically allocate array of offer fulfillment components
        infra.offerFulfillmentComponents = new FulfillmentComponent[](
                infra.offerLength
            );
        infra.considerationFulfillmentComponents = new FulfillmentComponent[](
                infra.considerationLength
            );
        // iterate over consideration components
        infra.offerIndex;
        for (
            infra.considerationIndex;
            infra.considerationIndex < infra.considerationLength;
            ++infra.considerationIndex
        ) {
            // only include this considerationItem in the fulfillment if there is an offerItem that has credited to it
            infra.credited;
            // it's possible that not all of an offer component will be used up; this helps to track that
            infra.midCredit;

            {
                // iterate over offer components
                while (infra.offerIndex < infra.offerLength) {
                    // re-load components each iteration as they may have been modified
                    infra.offerComponent = offerComponents[infra.offerIndex];
                    infra.considerationComponent = considerationComponents[
                        infra.considerationIndex
                    ];
                    // cache amounts
                    infra.offerAmount = infra.offerComponent.getAmount();
                    infra.considerationAmount = infra.considerationComponent.getAmount();
                    // if consideration has been completely credited, break to next consideration component
                    if (infra.considerationAmount == 0) {
                        break;
                    }
                    // note that this consideration component has been credited
                    infra.credited = true;
                    if (infra.offerAmount > infra.considerationAmount) {
                        // if offer amount is greater than consideration amount, set consideration to zero and credit from offer amount
                        offerComponents[infra.offerIndex] = infra.offerComponent
                            .subtractAmount(infra.considerationComponent);
                        considerationComponents[
                            infra.considerationIndex
                        ] = infra.considerationComponent.setAmount(0);
                        // don't add duplicates of this fulfillment if it is credited towards multiple consideration items; note that it is mid-credit and add after the loop if it was not added in another iteration
                        infra.midCredit = true;
                    } else {
                        // if we were midCredit, we are no longer, so set to false, since it will be added as part of this branch
                        infra.midCredit = false;
                        // otherwise deplete offer amount and credit consideration amount
                        considerationComponents[
                            infra.considerationIndex
                        ] = infra.considerationComponent.subtractAmount(
                            infra.offerComponent
                        );
                        offerComponents[infra.offerIndex] = infra.offerComponent.setAmount(
                            0
                        );
                        ++infra.offerIndex;
                        // add offer component to fulfillment components and increment index
                        infra.offerFulfillmentComponents[
                            infra.offerFulfillmentIndex
                        ] = infra.offerComponent.toFulfillmentComponent();
                        infra.offerFulfillmentIndex++;
                    }
                }
                // if we were midCredit, add to fulfillment components
                if (infra.midCredit) {
                    // add offer component to fulfillment components and increment index
                    infra.offerFulfillmentComponents[
                        infra.offerFulfillmentIndex
                    ] = offerComponents[infra.offerIndex].toFulfillmentComponent();
                    infra.offerFulfillmentIndex++;
                }

                // check that an offer item was actually credited to this consideration item
                // if we ran out of offer items,
                if (infra.credited) {
                    // add consideration component to fulfillment components and increment index
                    infra.considerationFulfillmentComponents[
                        infra.considerationFulfillmentIndex
                    ] = considerationComponents[infra.considerationIndex]
                        .toFulfillmentComponent();
                    infra.considerationFulfillmentIndex++;
                }
            }
        }
        // remove any zero-amount components so they are skipped in future fulfillments
        cleanUpZeroedComponents(offerComponents);
        cleanUpZeroedComponents(considerationComponents);
        // truncate arrays to remove unused elements and set correct length
        infra.offerFulfillmentComponents = truncateArray(
            infra.offerFulfillmentComponents,
            infra.offerFulfillmentIndex
        );
        infra.considerationFulfillmentComponents = truncateArray(
            infra.considerationFulfillmentComponents,
            infra.considerationFulfillmentIndex
        );
        // return a discrete fulfillment since either or both of the sets of components have been exhausted
        // if offer or consideration items remain, they will be revisited in subsequent calls
        return
            Fulfillment({
                offerComponents: infra.offerFulfillmentComponents,
                considerationComponents: infra.considerationFulfillmentComponents
            });
    }

    /**
     * @dev Removes any zero-amount components from the start of the array
     */
    function cleanUpZeroedComponents(
        MatchComponent[] storage components
    ) internal {
        uint256 length = components.length;
        uint256 lastAmount = components[length - 1].getAmount();
        // if last amount is zero, then all amounts were fully credited. pop everything.
        if (lastAmount == 0) {
            for (uint256 i = 0; i < length; ++i) {
                components.pop();
            }
        } else {
            // otherwise pop until the first non-zero amount is found
            for (uint256 i; i < length; ++i) {
                if (components[i].getAmount() == 0) {
                    popIndex(components, i);
                } else {
                    break;
                }
            }
        }
    }

    /**
     * @dev Swaps the element at the given index with the last element and pops
     * @param components components
     * @param index index to swap with last element and pop
     */
    function popIndex(
        MatchComponent[] storage components,
        uint256 index
    ) internal {
        uint256 length = components.length;
        if (length == 0) {
            return;
        }
        components[index] = components[length - 1];
        components.pop();
    }

    /**
     * @dev return keccak256(abi.encode(contractAddress, tokenId))
     */
    function getTokenHash(
        address contractAddress,
        uint256 tokenId
    ) internal pure returns (bytes32 tokenHash) {
        assembly {
            mstore(0, contractAddress)
            mstore(0x20, tokenId)
            tokenHash := keccak256(0, 0x40)
        }
    }

    /**
     * @dev Truncates an array to the given length by overwriting memory
     */
    function truncateArray(
        FulfillmentComponent[] memory array,
        uint256 length
    ) internal pure returns (FulfillmentComponent[] memory truncatedArray) {
        assembly {
            mstore(array, length)
            truncatedArray := array
        }
    }

    /**
     * @notice Extend fulfillments array with new fulfillment
     */
    function extend(
        Fulfillment[] memory fulfillments,
        Fulfillment memory newFulfillment
    ) internal pure returns (Fulfillment[] memory newFulfillments) {
        newFulfillments = new Fulfillment[](fulfillments.length + 1);
        for (uint256 i = 0; i < fulfillments.length; i++) {
            newFulfillments[i] = fulfillments[i];
        }
        newFulfillments[fulfillments.length] = newFulfillment;
    }

    /**
     * @notice load storage layout for the current fulfillmentCounter
     */
    function getStorageLayout()
        internal
        view
        returns (FulfillmentHelperStorageLayout storage layout)
    {
        FulfillmentHelperCounterLayout
            storage counterLayout = getCounterLayout();
        uint256 counter = counterLayout.fulfillmentCounter;
        bytes32 storageLayoutKey = fulfillmentHelperStorageBaseKey;
        assembly {
            mstore(0, counter)
            mstore(0x20, storageLayoutKey)
            layout.slot := keccak256(0, 0x40)
        }
    }

    /**
     * @notice load storage layout for the counter itself
     */
    function getCounterLayout()
        internal
        pure
        returns (FulfillmentHelperCounterLayout storage layout)
    {
        bytes32 counterLayoutKey = fulfillmentCounterKey;
        assembly {
            layout.slot := counterLayoutKey
        }
    }

    /**
     * @notice increment the fulfillmentCounter to effectively clear the mappings and enumerations between calls
     */
    function incrementFulfillmentCounter() internal {
        FulfillmentHelperCounterLayout
            storage counterLayout = getCounterLayout();
        counterLayout.fulfillmentCounter += 1;
    }

    /**
     * @notice Get the mapping of tokens for a given key (offer or consideration), derived from the hash of the key and the current fulfillmentCounter value
     * @param key Original key used to derive the slot of the enumeration
     */
    function getMap(
        bytes32 key
    )
        internal
        view
        returns (
            mapping(address /*offererOrRecipient*/ => mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => MatchComponent[] /*components*/)))
                storage map
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
    function getEnumeration(
        bytes32 key
    ) internal view returns (AggregatableToken[] storage tokens) {
        bytes32 counterKey = fulfillmentCounterKey;
        assembly {
            mstore(0, key)
            mstore(0x20, sload(counterKey))
            tokens.slot := keccak256(0, 0x40)
        }
    }
}

library MatchFulfillmentHelper {
    /**
     * @notice Generate matched fulfillments for a list of orders
     * NOTE: this will break for multiple criteria items that resolve
     * to different identifiers
     * @param orders orders
     * @return fulfillments
     */
    function getMatchedFulfillments(
        Order[] memory orders
    ) internal returns (Fulfillment[] memory fulfillments) {
        OrderParameters[] memory orderParameters = new OrderParameters[](
            orders.length
        );
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
    function getMatchedFulfillments(
        AdvancedOrder[] memory orders
    ) internal returns (Fulfillment[] memory fulfillments) {
        OrderParameters[] memory orderParameters = new OrderParameters[](
            orders.length
        );
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
    function getMatchedFulfillments(
        OrderParameters[] memory orders
    ) internal returns (Fulfillment[] memory fulfillments) {
        // increment counter to get clean mappings and enumeration
        MatchFulfillmentPriv.incrementFulfillmentCounter();
        // load the storage layout
        FulfillmentHelperStorageLayout storage layout = MatchFulfillmentPriv
            .getStorageLayout();

        // iterate over each order and process the offer and consideration components
        for (uint256 i; i < orders.length; ++i) {
            OrderParameters memory parameters = orders[i];
            // insert MatchComponents into the offer mapping, grouped by token, tokenId, offerer, and conduitKey
            // also update per-token+tokenId enumerations of OffererAndConduit
            processOffer(
                parameters.offer,
                parameters.offerer,
                parameters.conduitKey,
                i,
                layout.offerMap,
                layout.tokenToOffererEnumeration
            );
            // insert MatchComponents into the offer mapping, grouped by token, tokenId, and recipient
            // also update AggregatableToken enumeration
            processConsideration(
                parameters.consideration,
                i,
                layout.considerationMap,
                layout.considerationEnumeration
            );
        }

        // iterate over groups of consideration components and find matching offer components
        uint256 considerationLength = layout.considerationEnumeration.length;
        for (uint256 i; i < considerationLength; ++i) {
            // get the token information
            AggregatableToken storage token = layout.considerationEnumeration[
                i
            ];
            // load the consideration components
            MatchComponent[] storage considerationComponents = layout
                .considerationMap[token.offererOrRecipient][
                    token.contractAddress
                ][token.tokenId];
            // load the enumeration of offerer+conduit keys for offer components that match this token
            OffererAndConduit[] storage offererEnumeration = layout
                .tokenToOffererEnumeration[token.contractAddress][
                    token.tokenId
                ];
            // iterate over each offerer+conduit with offer components that match this token and create matching fulfillments
            // this will update considerationComponents in-place in storage, which we check at the beginning of each loop
            for (uint256 j; j < offererEnumeration.length; ++j) {
                // if all consideration components have been fulfilled, break
                if (considerationComponents.length == 0) {
                    break;
                }
                // load the OffererAndConduit
                OffererAndConduit
                    storage offererAndConduit = offererEnumeration[j];
                // load the associated offer components for this offerer+conduit
                MatchComponent[] storage offerComponents = layout.offerMap[
                    token.contractAddress
                ][token.tokenId][offererAndConduit.offerer][
                        offererAndConduit.conduitKey
                    ];

                // create a fulfillment matching the offer and consideration components until either or both are exhausted
                Fulfillment memory fulfillment = MatchFulfillmentPriv
                    .createFulfillment(
                        offerComponents,
                        considerationComponents
                    );
                // append the fulfillment to the array of fulfillments
                fulfillments = MatchFulfillmentPriv.extend(fulfillments, fulfillment);

                // loop back around in case not all considerationComponents have been completely fulfilled
            }
        }
    }

    /**
     * @notice Process offer items and insert them into enumeration and map
     * @param offer offer items
     * @param offerer offerer
     * @param orderIndex order index of processed items
     * @param offerMap map to save components to
     * @param offererEnumeration enumeration to save aggregatabletokens to
     */
    function processOffer(
        OfferItem[] memory offer,
        address offerer,
        bytes32 conduitKey,
        uint256 orderIndex,
        mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => mapping(address /*offerer*/ => mapping(bytes32 /*conduitKey*/ => MatchComponent[] /*components*/))))
            storage offerMap,
        mapping(address /*token*/ => mapping(uint256 /*tokenId*/ => OffererAndConduit[]))
            storage offererEnumeration
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

            // if it does not exist in the map, add it to our per-token+id enumeration
            if (
                !MatchFulfillmentPriv.offererTokenComboExists(
                    item.token,
                    item.identifierOrCriteria,
                    offerer,
                    conduitKey,
                    offerMap
                )
            ) {
                // add to enumeration for specific tokenhash (tokenAddress+tokenId)

                offererEnumeration[item.token][item.identifierOrCriteria].push(
                    OffererAndConduit({
                        offerer: offerer,
                        conduitKey: conduitKey
                    })
                );
            }
            // update aggregatable mapping array with this component
            offerMap[item.token][item.identifierOrCriteria][offerer][conduitKey]
                .push(component);
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
        mapping(address /*offererOrRecipient*/ => mapping(address /*tokenContract*/ => mapping(uint256 /*identifier*/ => MatchComponent[] /*components*/)))
            storage considerationMap,
        AggregatableToken[] storage considerationEnumeration
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
            AggregatableToken memory token = AggregatableToken({
                offererOrRecipient: item.recipient,
                contractAddress: item.token,
                tokenId: item.identifierOrCriteria
            });
            // if it does not exist in the map, add it to our enumeration
            if (
                !MatchFulfillmentPriv.tokenConsiderationExists(
                    token,
                    considerationMap
                )
            ) {
                considerationEnumeration.push(token);
            }
            // update mapping with this component
            considerationMap[token.offererOrRecipient][token.contractAddress][
                token.tokenId
            ].push(component);
        }
    }
}
