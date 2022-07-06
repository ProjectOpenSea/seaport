// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ItemType, Side } from "contracts/lib/ConsiderationEnums.sol";

import {
    OfferItem,
    ConsiderationItem,
    OrderParameters,
    AdvancedOrder,
    CriteriaResolver,
    SpentItem,
    ReceivedItem
} from "contracts/lib/ConsiderationStructs.sol";

import { OrderToExecute } from "./ReferenceConsiderationStructs.sol";

import "contracts/lib/ConsiderationConstants.sol";

import {
    CriteriaResolutionErrors
} from "contracts/interfaces/CriteriaResolutionErrors.sol";

/**
 * @title CriteriaResolution
 * @author 0age
 * @notice CriteriaResolution contains a collection of pure functions related to
 *         resolving criteria-based items.
 */
contract ReferenceCriteriaResolution is CriteriaResolutionErrors {
    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param ordersToExecute    The orders to apply criteria resolvers to.
     * @param criteriaResolvers  An array where each element contains a
     *                           reference to a specific order as well as that
     *                           order's offer or consideration, a token
     *                           identifier, and a proof that the supplied token
     *                           identifier is contained in the order's merkle
     *                           root. Note that a root of zero indicates that
     *                           any transferable token identifier is valid and
     *                           that no proof needs to be supplied.
     */
    function _applyCriteriaResolvers(
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Retrieve length of criteria resolvers array and place on stack.
        uint256 arraySize = criteriaResolvers.length;

        // Iterate over each criteria resolver.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the criteria resolver.
            CriteriaResolver memory criteriaResolver = (criteriaResolvers[i]);

            // Read the order index from memory and place it on the stack.
            uint256 orderIndex = criteriaResolver.orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= ordersToExecute.length) {
                revert OrderCriteriaResolverOutOfRange();
            }

            // Skip criteria resolution for order if not fulfilled.
            if (ordersToExecute[orderIndex].numerator == 0) {
                continue;
            }

            // Read component index from memory and place it on the stack.
            uint256 componentIndex = criteriaResolver.index;

            // Declare values for item's type and criteria.
            ItemType itemType;
            uint256 identifierOrCriteria;

            // If the criteria resolver refers to an offer item...
            if (criteriaResolver.side == Side.OFFER) {
                SpentItem[] memory spentItems = ordersToExecute[orderIndex]
                    .spentItems;
                // Ensure that the component index is in range.
                if (componentIndex >= spentItems.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using component index.
                SpentItem memory offer = (spentItems[componentIndex]);

                // Read item type and criteria from memory & place on stack.
                itemType = offer.itemType;
                identifierOrCriteria = offer.identifier;

                // Optimistically update item type to remove criteria usage.
                if (itemType == ItemType.ERC721_WITH_CRITERIA) {
                    offer.itemType = ItemType.ERC721;
                } else {
                    offer.itemType = ItemType.ERC1155;
                }

                // Optimistically update identifier w/ supplied identifier.
                offer.identifier = criteriaResolver.identifier;
            } else {
                // Otherwise, the resolver refers to a consideration item.

                // Retrieve relevant item using order index.
                ReceivedItem[] memory receivedItems = ordersToExecute[
                    orderIndex
                ].receivedItems;

                // Ensure that the component index is in range.
                if (componentIndex >= receivedItems.length) {
                    revert ConsiderationCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using component index.
                ReceivedItem memory consideration = (
                    receivedItems[componentIndex]
                );

                // Read item type and criteria from memory & place on stack.
                itemType = consideration.itemType;
                identifierOrCriteria = consideration.identifier;

                // Optimistically update item type to remove criteria usage.
                if (itemType == ItemType.ERC721_WITH_CRITERIA) {
                    consideration.itemType = ItemType.ERC721;
                } else {
                    consideration.itemType = ItemType.ERC1155;
                }

                // Optimistically update identifier w/ supplied identifier.
                consideration.identifier = (criteriaResolver.identifier);
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

        // Retrieve length of orders array and place on stack.
        arraySize = ordersToExecute.length;

        // Iterate over each order to execute.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the order to execute.
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Read offer length from memory and place on stack.
            uint256 totalItems = orderToExecute.spentItems.length;

            // Skip criteria resolution for order if not fulfilled.
            if (orderToExecute.numerator == 0) {
                continue;
            }

            // Iterate over each offer item on the order.
            for (uint256 j = 0; j < totalItems; ++j) {
                // Ensure item type no longer indicates criteria usage.
                if (
                    _isItemWithCriteria(orderToExecute.spentItems[j].itemType)
                ) {
                    revert UnresolvedOfferCriteria();
                }
            }

            // Read consideration length from memory and place on stack.
            totalItems = (orderToExecute.receivedItems.length);

            // Iterate over each consideration item on the order.
            for (uint256 j = 0; j < totalItems; ++j) {
                // Ensure item type no longer indicates criteria usage.
                if (
                    _isItemWithCriteria(
                        orderToExecute.receivedItems[j].itemType
                    )
                ) {
                    revert UnresolvedConsiderationCriteria();
                }
            }
        }
    }

    /**
     * @dev Internal pure function to apply criteria resolvers containing
     *      specific token identifiers and associated proofs to order items.
     *
     * @param advancedOrder      The order to apply criteria resolvers to.
     * @param criteriaResolvers  An array where each element contains a
     *                           reference to a specific order as well as that
     *                           order's offer or consideration, a token
     *                           identifier, and a proof that the supplied token
     *                           identifier is contained in the order's merkle
     *                           root. Note that a root of zero indicates that
     *                           any transferable token identifier is valid and
     *                           that no proof needs to be supplied.
     */
    function _applyCriteriaResolversAdvanced(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        // Retrieve length of criteria resolvers array and place on stack.
        uint256 arraySize = criteriaResolvers.length;

        // Retrieve the parameters for the order.
        OrderParameters memory orderParameters = (advancedOrder.parameters);

        // Iterate over each criteria resolver.
        for (uint256 i = 0; i < arraySize; ++i) {
            // Retrieve the criteria resolver.
            CriteriaResolver memory criteriaResolver = (criteriaResolvers[i]);

            // Read the order index from memory and place it on the stack.
            uint256 orderIndex = criteriaResolver.orderIndex;

            if (orderIndex != 0) {
                revert OrderCriteriaResolverOutOfRange();
            }

            // Read component index from memory and place it on the stack.
            uint256 componentIndex = criteriaResolver.index;

            // Declare values for item's type and criteria.
            ItemType itemType;
            uint256 identifierOrCriteria;

            // If the criteria resolver refers to an offer item...
            if (criteriaResolver.side == Side.OFFER) {
                // Ensure that the component index is in range.
                if (componentIndex >= orderParameters.offer.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using order and component index.
                OfferItem memory offer = (
                    orderParameters.offer[componentIndex]
                );

                // Read item type and criteria from memory & place on stack.
                itemType = offer.itemType;
                identifierOrCriteria = offer.identifierOrCriteria;

                // Optimistically update item type to remove criteria usage.
                if (itemType == ItemType.ERC721_WITH_CRITERIA) {
                    offer.itemType = ItemType.ERC721;
                } else {
                    offer.itemType = ItemType.ERC1155;
                }

                // Optimistically update identifier w/ supplied identifier.
                offer.identifierOrCriteria = criteriaResolver.identifier;
            } else {
                // Otherwise, the resolver refers to a consideration item.
                // Ensure that the component index is in range.
                if (componentIndex >= orderParameters.consideration.length) {
                    revert ConsiderationCriteriaResolverOutOfRange();
                }

                // Retrieve relevant item using order and component index.
                ConsiderationItem memory consideration = (
                    orderParameters.consideration[componentIndex]
                );

                // Read item type and criteria from memory & place on stack.
                itemType = consideration.itemType;
                identifierOrCriteria = consideration.identifierOrCriteria;

                // Optimistically update item type to remove criteria usage.
                if (itemType == ItemType.ERC721_WITH_CRITERIA) {
                    consideration.itemType = ItemType.ERC721;
                } else {
                    consideration.itemType = ItemType.ERC1155;
                }

                // Optimistically update identifier w/ supplied identifier.
                consideration.identifierOrCriteria = (
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

        // Validate Criteria on order has been resolved

        // Read consideration length from memory and place on stack.
        uint256 totalItems = (advancedOrder.parameters.consideration.length);

        // Iterate over each consideration item on the order.
        for (uint256 i = 0; i < totalItems; ++i) {
            // Ensure item type no longer indicates criteria usage.
            if (
                _isItemWithCriteria(
                    advancedOrder.parameters.consideration[i].itemType
                )
            ) {
                revert UnresolvedConsiderationCriteria();
            }
        }

        // Read offer length from memory and place on stack.
        totalItems = advancedOrder.parameters.offer.length;

        // Iterate over each offer item on the order.
        for (uint256 i = 0; i < totalItems; ++i) {
            // Ensure item type no longer indicates criteria usage.
            if (
                _isItemWithCriteria(advancedOrder.parameters.offer[i].itemType)
            ) {
                revert UnresolvedOfferCriteria();
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
        withCriteria = uint256(itemType) > 3;
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
        // Hash the supplied leaf to use as the initial proof element.
        bytes32 computedHash = keccak256(abi.encodePacked(leaf));

        // Iterate over each proof element.
        for (uint256 i = 0; i < proof.length; ++i) {
            // Retrieve the proof element.
            bytes32 proofElement = proof[i];

            // Sort and hash proof elements and update the computed hash.
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of proof)
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                // Hash(current element of proof + current computed hash)
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        // Ensure that the final derived hash matches the expected root.
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
        }
    }
}
