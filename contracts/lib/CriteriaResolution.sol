// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ItemType, Side } from "./ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    OrderParameters,
    AdvancedOrder,
    CriteriaResolver
} from "./ConsiderationStructs.sol";

import "./ConsiderationConstants.sol";

// prettier-ignore
import {
    CriteriaResolutionErrors
} from "../interfaces/CriteriaResolutionErrors.sol";

/**
 * @title CriteriaResolution
 * @author 0age
 * @notice CriteriaResolution contains a collection of pure functions related to
 *         resolving criteria-based items.
 */
contract CriteriaResolution is CriteriaResolutionErrors {
    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param advancedOrders     The orders to apply criteria resolvers to.
     * @param criteriaResolvers  An array where each element contains a
     *                           reference to a specific order as well as that
     *                           order's offer or consideration, a token
     *                           identifier, and a proof that the supplied token
     *                           identifier is contained in the order's merkle
     *                           root. Note that a root of zero indicates that
     *                           any transferrable token identifier is valid and
     *                           that no proof needs to be supplied.
     */
    function _applyCriteriaResolvers(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Retrieve length of criteria resolvers array and place on stack.
            uint256 totalCriteriaResolvers = criteriaResolvers.length;

            // Retrieve length of orders array and place on stack.
            uint256 totalAdvancedOrders = advancedOrders.length;

            // Iterate over each criteria resolver.
            for (uint256 i = 0; i < totalCriteriaResolvers; ++i) {
                // Retrieve the criteria resolver.
                CriteriaResolver memory criteriaResolver = (
                    criteriaResolvers[i]
                );

                // Read the order index from memory and place it on the stack.
                uint256 orderIndex = criteriaResolver.orderIndex;

                // Ensure that the order index is in range.
                if (orderIndex >= totalAdvancedOrders) {
                    revert OrderCriteriaResolverOutOfRange();
                }

                // Skip criteria resolution for order if not fulfilled.
                if (advancedOrders[orderIndex].numerator == 0) {
                    continue;
                }

                // Retrieve the parameters for the order.
                OrderParameters memory orderParameters = (
                    advancedOrders[orderIndex].parameters
                );

                // Read component index from memory and place it on the stack.
                uint256 componentIndex = criteriaResolver.index;

                // Declare values for item's type and criteria.
                ItemType itemType;
                uint256 identifierOrCriteria;

                // If the criteria resolver refers to an offer item...
                if (criteriaResolver.side == Side.OFFER) {
                    // Retrieve the offer.
                    OfferItem[] memory offer = orderParameters.offer;

                    // Ensure that the component index is in range.
                    if (componentIndex >= offer.length) {
                        revert OfferCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using the component index.
                    OfferItem memory offerItem = offer[componentIndex];

                    // Read item type and criteria from memory & place on stack.
                    itemType = offerItem.itemType;
                    identifierOrCriteria = offerItem.identifierOrCriteria;

                    // Optimistically update item type to remove criteria usage.
                    ItemType newItemType;
                    assembly {
                        newItemType := sub(3, eq(itemType, 4))
                    }
                    offerItem.itemType = newItemType;

                    // Optimistically update identifier w/ supplied identifier.
                    offerItem.identifierOrCriteria = criteriaResolver
                        .identifier;
                } else {
                    // Otherwise, the resolver refers to a consideration item.
                    ConsiderationItem[] memory consideration = (
                        orderParameters.consideration
                    );

                    // Ensure that the component index is in range.
                    if (componentIndex >= consideration.length) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    // Retrieve relevant item using order and component index.
                    ConsiderationItem memory considerationItem = (
                        consideration[componentIndex]
                    );

                    // Read item type and criteria from memory & place on stack.
                    itemType = considerationItem.itemType;
                    identifierOrCriteria = (
                        considerationItem.identifierOrCriteria
                    );

                    // Optimistically update item type to remove criteria usage.
                    ItemType newItemType;
                    assembly {
                        newItemType := sub(3, eq(itemType, 4))
                    }
                    considerationItem.itemType = newItemType;

                    // Optimistically update identifier w/ supplied identifier.
                    considerationItem.identifierOrCriteria = (
                        criteriaResolver.identifier
                    );
                }

                // Ensure the specified item type indicates criteria usage.
                if (!_isItemWithCriteria(itemType)) {
                    revert CriteriaNotEnabledForItem();
                }

                // If criteria is not 0 (i.e. a collection-wide offer)...
                if (identifierOrCriteria != uint256(0)) {
                    // Verify identifier inclusion in criteria root using proof.
                    _verifyProof(
                        criteriaResolver.identifier,
                        identifierOrCriteria,
                        criteriaResolver.criteriaProof
                    );
                }
            }

            // Iterate over each advanced order.
            for (uint256 i = 0; i < totalAdvancedOrders; ++i) {
                // Retrieve the advanced order.
                AdvancedOrder memory advancedOrder = advancedOrders[i];

                // Skip criteria resolution for order if not fulfilled.
                if (advancedOrder.numerator == 0) {
                    continue;
                }

                // Retrieve the parameters for the order.
                OrderParameters memory orderParameters = (
                    advancedOrders[i].parameters
                );

                // Read consideration length from memory and place on stack.
                uint256 totalItems = orderParameters.consideration.length;

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < totalItems; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(
                            orderParameters.consideration[j].itemType
                        )
                    ) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                // Read offer length from memory and place on stack.
                totalItems = orderParameters.offer.length;

                // Iterate over each offer item on the order.
                for (uint256 j = 0; j < totalItems; ++j) {
                    // Ensure item type no longer indicates criteria usage.
                    if (
                        _isItemWithCriteria(orderParameters.offer[j].itemType)
                    ) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }
        }
    }

    /**
     * @dev Internal pure function to check whether a given item type represents
     *      a criteria-based ERC721 or ERC1155 item (e.g. an item that can be
     *      resolved to one of a number of different identifiers at the time of
     *      order fulfillment).
     *
     * @param itemType The item type in question.
     *
     * @return withCriteria A boolean indicating that the item type in question
     *                      represents a criteria-based item.
     */
    function _isItemWithCriteria(ItemType itemType)
        internal
        pure
        returns (bool withCriteria)
    {
        // ERC721WithCriteria is item type 4. ERC1155WithCriteria is item type
        // 5.
        assembly {
            withCriteria := gt(itemType, 3)
        }
    }

    /**
     * @dev Internal pure function to ensure that a given element is contained
     *      in a merkle root via a supplied proof.
     *
     * @param leaf  The element for which to prove inclusion.
     * @param root  The merkle root that inclusion will be proved against.
     * @param proof The merkle proof.
     */
    function _verifyProof(
        uint256 leaf,
        uint256 root,
        bytes32[] memory proof
    ) internal pure {
        bool isValid;

        assembly {
            let computedHash := leaf // Start the hash off as just the starting leaf.

            // Get the memory start location of the first element in the proof array.
            let data := add(proof, 0x20)

            // Iterate over proof elements to compute root hash.
            for {
                let end := add(data, mul(mload(proof), 0x20))
            } lt(data, end) {
                data := add(data, 0x20)
            } {
                let loadedData := mload(data)

                switch gt(computedHash, loadedData)
                case 0 {
                    mstore(0, computedHash)
                    mstore(0x20, loadedData)
                }
                default {
                    mstore(0, loadedData)
                    mstore(0x20, computedHash)
                }

                computedHash := keccak256(0, 0x40)
            }

            isValid := eq(computedHash, root)
        }

        if (!isValid) revert InvalidProof();
    }
}
