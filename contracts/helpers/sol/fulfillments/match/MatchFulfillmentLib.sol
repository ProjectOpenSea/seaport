// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AggregatableToken, ProcessComponentParams } from "../lib/Structs.sol";
import {
    MatchComponent,
    MatchComponentType
} from "../../lib/types/MatchComponentType.sol";
import { FulfillmentComponent, Fulfillment } from "../../SeaportSol.sol";

library MatchFulfillmentLib {
    /**
     * @notice Check if a token already exists in a mapping by checking the length of the array at that slot
     * @param token token to check
     * @param map map to check
     */
    function tokenConsiderationExists(
        AggregatableToken memory token,
        mapping(
            address /*offererOrRecipient*/
                => mapping(
                    address /*tokenContract*/
                        => mapping(
                            uint256 /*identifier*/ => MatchComponent[] /*components*/
                        )
                )
            ) storage map
    ) internal view returns (bool) {
        return map[token.offererOrRecipient][token.contractAddress][token
            .tokenId].length > 0;
    }

    /**
     * @notice Check if an entry into the offer component mapping already exists by checking its length
     */
    function offererTokenComboExists(
        address token,
        uint256 tokenId,
        address offerer,
        bytes32 conduitKey,
        mapping(
            address /*tokenContract*/
                => mapping(
                    uint256 /*identifier*/
                        => mapping(
                            address /*offerer*/
                                => mapping(
                                    bytes32 /*conduitKey*/ => MatchComponent[] /*components*/
                                )
                        )
                )
            ) storage offerMap
    ) internal view returns (bool) {
        return offerMap[token][tokenId][offerer][conduitKey].length > 0;
    }

    function processConsiderationComponent(
        MatchComponent[] storage offerComponents,
        MatchComponent[] storage considerationComponents,
        ProcessComponentParams memory params
    ) internal {
        // iterate over offer components
        while (params.offerItemIndex < offerComponents.length) {
            MatchComponent considerationComponent =
                considerationComponents[params.considerationItemIndex];

            // if consideration has been completely credited, break to next consideration component
            if (considerationComponent.getAmount() == 0) {
                break;
            }
            processOfferComponent({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents,
                params: params
            });
        }

        scuffExtend(
            params.considerationFulfillmentComponents,
            considerationComponents[params.considerationItemIndex]
                .toFulfillmentComponent()
        );
    }

    function scuffLength(
        FulfillmentComponent[] memory components,
        uint256 newLength
    ) internal pure {
        assembly {
            mstore(components, newLength)
        }
    }

    function scuffExtend(
        FulfillmentComponent[] memory components,
        FulfillmentComponent memory newComponent
    ) internal pure {
        uint256 index = components.length;
        scuffLength(components, index + 1);
        components[index] = newComponent;
    }

    function allocateAndShrink(uint256 maxLength)
        internal
        pure
        returns (FulfillmentComponent[] memory components)
    {
        components = new FulfillmentComponent[](maxLength);
        scuffLength(components, 0);
        return components;
    }

    function added(
        FulfillmentComponent[] memory components,
        MatchComponent component
    ) internal pure returns (bool) {
        if (components.length == 0) {
            return false;
        }
        FulfillmentComponent memory fulfillmentComponent =
            component.toFulfillmentComponent();
        FulfillmentComponent memory lastComponent =
            components[components.length - 1];
        return lastComponent.orderIndex != fulfillmentComponent.orderIndex
            && lastComponent.itemIndex == fulfillmentComponent.itemIndex;
    }

    function processOfferComponent(
        MatchComponent[] storage offerComponents,
        MatchComponent[] storage considerationComponents,
        ProcessComponentParams memory params
    ) internal {
        // re-load components each iteration as they may have been modified
        MatchComponent offerComponent = offerComponents[params.offerItemIndex];
        MatchComponent considerationComponent =
            considerationComponents[params.considerationItemIndex];
        if (offerComponent.getAmount() > considerationComponent.getAmount()) {
            // if offer amount is greater than consideration amount, set consideration to zero and credit from offer amount
            offerComponents[params.offerItemIndex] =
                offerComponent.subtractAmount(considerationComponent);
            considerationComponents[params.considerationItemIndex] =
                considerationComponent.setAmount(0);
        } else {
            // otherwise deplete offer amount and credit consideration amount
            considerationComponents[params.considerationItemIndex] =
                considerationComponent.subtractAmount(offerComponent);
            offerComponents[params.offerItemIndex] = offerComponent.setAmount(0);
            ++params.offerItemIndex;
        }
        // an offer component may have already been added if it was not depleted by an earlier consideration item
        if (!added(params.offerFulfillmentComponents, offerComponent)) {
            scuffExtend(
                params.offerFulfillmentComponents,
                offerComponent.toFulfillmentComponent()
            );
        }
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
        // optimistically allocate arrays of fulfillment components
        FulfillmentComponent[] memory offerFulfillmentComponents =
            allocateAndShrink(offerComponents.length);
        FulfillmentComponent[] memory considerationFulfillmentComponents =
            allocateAndShrink(considerationComponents.length);
        // iterate over consideration components
        ProcessComponentParams memory params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        for (
            uint256 considerationItemIndex;
            considerationItemIndex < considerationComponents.length;
            ++considerationItemIndex
        ) {
            // params will be updated directly by called functions ecxept for considerationItemIndex
            params.considerationItemIndex = considerationItemIndex;
            processConsiderationComponent({
                offerComponents: offerComponents,
                considerationComponents: considerationComponents,
                params: params
            });
        }

        // remove any zero-amount components so they are skipped in future fulfillments
        cleanUpZeroedComponents(offerComponents);
        cleanUpZeroedComponents(considerationComponents);

        // return a discrete fulfillment since either or both of the sets of components have been exhausted
        // if offer or consideration items remain, they will be revisited in subsequent calls
        return Fulfillment({
            offerComponents: offerFulfillmentComponents,
            considerationComponents: considerationFulfillmentComponents
        });
    }

    /**
     * @dev Removes any zero-amount components from the start of the array
     */
    function cleanUpZeroedComponents(MatchComponent[] storage components)
        internal
    {
        // cache components in memory
        MatchComponent[] memory cachedComponents = components;
        // clear storage array
        while (components.length > 0) {
            components.pop();
        }
        // re-add non-zero components
        for (uint256 i = 0; i < cachedComponents.length; ++i) {
            if (cachedComponents[i].getAmount() > 0) {
                components.push(cachedComponents[i]);
            }
        }
    }

    // /**
    //  * @dev Swaps the element at the given index with the last element and pops
    //  * @param components components
    //  * @param index index to swap with last element and pop
    //  */
    // function popIndex(MatchComponent[] storage components, uint256 index)
    //     internal
    // {
    //     uint256 length = components.length;
    //     if (length == 0) {
    //         return;
    //     }
    //     components[index] = components[length - 1];
    //     components.pop();
    // }

    /**
     * @dev Truncates an array to the given length by overwriting its length in memory
     */
    function truncateArray(FulfillmentComponent[] memory array, uint256 length)
        internal
        pure
        returns (FulfillmentComponent[] memory truncatedArray)
    {
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
}
