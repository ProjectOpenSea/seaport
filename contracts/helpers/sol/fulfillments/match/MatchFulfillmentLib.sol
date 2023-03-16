// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AggregatableConsideration,
    ProcessComponentParams,
    MatchFulfillmentStorageLayout,
    AggregatableOfferer
} from "../lib/Structs.sol";
import {
    MatchComponent,
    MatchComponentType
} from "../../lib/types/MatchComponentType.sol";
import { FulfillmentComponent, Fulfillment } from "../../SeaportSol.sol";
// import { LibString } from "solady/src/utils/LibString.sol";
// import { console } from "hardhat/console.sol";

library MatchFulfillmentLib {
    /**
     * @notice Check if a token already exists in a mapping by checking the length of the array at that slot
     * @param token token to check
     * @param layout storage layout
     */
    function aggregatableConsiderationExists(
        AggregatableConsideration memory token,
        MatchFulfillmentStorageLayout storage layout
    ) internal view returns (bool) {
        return layout.considerationMap[token.recipient][token.contractAddress][token
            .tokenId].length > 0;
    }

    /**
     * @notice Check if an entry into the offer component mapping already exists by checking its length
     */
    function aggregatableOffererExists(
        address token,
        uint256 tokenId,
        AggregatableOfferer memory offerer,
        MatchFulfillmentStorageLayout storage layout
    ) internal view returns (bool) {
        return layout.offerMap[token][tokenId][offerer.offerer][offerer
            .conduitKey].length > 0;
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

    function previouslyAdded(
        FulfillmentComponent[] memory components,
        FulfillmentComponent memory fulfillmentComponent
    ) internal pure returns (bool) {
        if (components.length == 0) {
            return false;
        }

        FulfillmentComponent memory lastComponent =
            components[components.length - 1];
        return lastComponent.orderIndex == fulfillmentComponent.orderIndex
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
            // emit log("used up consideration");
            // if offer amount is greater than consideration amount, set consideration to zero and credit from offer amount
            offerComponent =
                offerComponent.subtractAmount(considerationComponent);
            considerationComponent = considerationComponent.setAmount(0);
            offerComponents[params.offerItemIndex] = offerComponent;
            considerationComponents[params.considerationItemIndex] =
                considerationComponent;
        } else {
            // emit log("used up offer");
            considerationComponent =
                considerationComponent.subtractAmount(offerComponent);
            offerComponent = offerComponent.setAmount(0);

            // otherwise deplete offer amount and credit consideration amount
            considerationComponents[params.considerationItemIndex] =
                considerationComponent;

            offerComponents[params.offerItemIndex] = offerComponent;
            ++params.offerItemIndex;
        }
        // an offer component may have already been added if it was not depleted by an earlier consideration item
        if (
            !previouslyAdded(
                params.offerFulfillmentComponents,
                offerComponent.toFulfillmentComponent()
            )
        ) {
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
