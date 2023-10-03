// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ItemType } from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    NavigatorOfferItem,
    NavigatorConsiderationItem
} from "./SeaportNavigatorTypes.sol";

library HelperItemLib {
    error InvalidIdentifier(uint256 identifier, uint256[] candidateIdentifiers);
    error InvalidItemTypeForCandidateIdentifiers();

    /**
     * @dev Internal error: Could not convert item type.
     */
    error UnknownItemType();

    /**
     * @dev Normalizes the type of a NavigatorOfferItem based on the presence of
     *      criteria. This originated in the context of the fuzz tests in
     *      ./test/foundry/new, where an item might be assigned a pseudorandom
     *      type and a pseudorandom criteria. In this context, it will just
     *      correct an incorrect item type. If the item has criteria, ERC721 and
     *      ERC1155 items will be normalized to ERC721_WITH_CRITERIA and
     *      ERC1155_WITH_CRITERIA, respectively. Reverts with UnknownItemType if
     *      the item type is neither ERC721,  ERC721_WITH_CRITERIA, ERC1155, nor
     *      ERC1155_WITH_CRITERIA.
     *
     * @param item The NavigatorOfferItem to normalize.
     *
     * @return ItemType The normalized item type.
     */
    function normalizeType(
        NavigatorOfferItem memory item
    ) internal pure returns (ItemType) {
        ItemType itemType = item.itemType;
        if (hasCriteria(item)) {
            return _normalizeType(itemType);
        } else {
            return itemType;
        }
    }

    /**
     * @dev Normalizes the type of a NavigatorConsiderationItem based on the
     *      presence of criteria. This originated in the context of the fuzz
     *      tests in ./test/foundry/new, where an item might be assigned a
     *      pseudorandom type and a pseudorandom criteriaOrIdentifier. In this
     *      context, it will just correct an incorrect item type. If the item
     *      has criteria, ERC721 and ERC1155 items will be normalized to
     *      ERC721_WITH_CRITERIA and ERC1155_WITH_CRITERIA, respectively.
     *
     * @param item The NavigatorConsiderationItem to normalize.
     *
     * @return ItemType The normalized item type.
     */
    function normalizeType(
        NavigatorConsiderationItem memory item
    ) internal pure returns (ItemType) {
        ItemType itemType = item.itemType;
        if (hasCriteria(item)) {
            return _normalizeType(itemType);
        } else {
            return itemType;
        }
    }

    function hasCriteria(
        NavigatorOfferItem memory item
    ) internal pure returns (bool) {
        // Candidate identifiers are passed in by the caller as an array of
        // uint256s and converted by Navigator.
        return item.candidateIdentifiers.length > 0;
    }

    function hasCriteria(
        NavigatorConsiderationItem memory item
    ) internal pure returns (bool) {
        // Candidate identifiers are passed in by the caller as an array of
        // uint256s and converted by Navigator.
        return item.candidateIdentifiers.length > 0;
    }

    function validate(NavigatorOfferItem memory item) internal pure {
        _validateItem(
            item.itemType,
            item.candidateIdentifiers.length,
            item.identifier,
            item.candidateIdentifiers,
            hasCriteria(item)
        );
    }

    function validate(NavigatorConsiderationItem memory item) internal pure {
        _validateItem(
            item.itemType,
            item.candidateIdentifiers.length,
            item.identifier,
            item.candidateIdentifiers,
            hasCriteria(item)
        );
    }

    function _normalizeType(ItemType itemType) private pure returns (ItemType) {
        if (
            itemType == ItemType.ERC721 ||
            itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            return ItemType.ERC721_WITH_CRITERIA;
        } else if (
            itemType == ItemType.ERC1155 ||
            itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            return ItemType.ERC1155_WITH_CRITERIA;
        } else {
            revert UnknownItemType();
        }
    }

    // Shared function to validate Navigator items
    function _validateItem(
        ItemType itemType,
        uint256 itemCandidateIdentifiersLength,
        uint256 identifier,
        uint256[] memory candidateIdentifiers,
        bool _hasCriteria
    ) private pure {
        // If the item has criteria, the item type must be ERC721 or ERC1155.
        if (itemType == ItemType.ERC20 || itemType == ItemType.NATIVE) {
            if (_hasCriteria) {
                revert InvalidItemTypeForCandidateIdentifiers();
            } else {
                return;
            }
        }
        // If the item has no candidate identifiers, the item identifier must be
        // non-zero.
        //
        // NOTE: This is only called after `item.hasCriteria()` checks
        // which ensure that `item.candidateIdentifiers.length > 0` but if it
        // were used in other contexts, this would prohibit the use of
        // legitimate 0 identifiers.
        if (itemCandidateIdentifiersLength == 0 && identifier == 0) {
            revert InvalidIdentifier(identifier, candidateIdentifiers);
        }
        // If the item has candidate identifiers, the item identifier must be
        // zero or wildcard for one of the candidates.
        if (itemCandidateIdentifiersLength > 0) {
            bool identifierFound;
            for (uint256 i; i < itemCandidateIdentifiersLength; i++) {
                if (candidateIdentifiers[i] == identifier) {
                    identifierFound = true;
                    break;
                }
            }
            if (!identifierFound && identifier != 0) {
                revert InvalidIdentifier(identifier, candidateIdentifiers);
            }
        }
    }
}
