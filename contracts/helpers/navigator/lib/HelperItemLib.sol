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
        return item.candidateIdentifiers.length > 0;
    }

    function hasCriteria(
        NavigatorConsiderationItem memory item
    ) internal pure returns (bool) {
        return item.candidateIdentifiers.length > 0;
    }

    function validate(NavigatorOfferItem memory item) internal pure {
        _validateItem(
            item.itemType,
            item.candidateIdentifiers.length,
            item.identifier,
            item.candidateIdentifiers
        );
    }

    function validate(NavigatorConsiderationItem memory item) internal pure {
        _validateItem(
            item.itemType,
            item.candidateIdentifiers.length,
            item.identifier,
            item.candidateIdentifiers
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
        uint256[] memory candidateIdentifiers
    ) private pure {
        if (itemType == ItemType.ERC20 || itemType == ItemType.NATIVE) {
            if (itemCandidateIdentifiersLength > 0) {
                revert InvalidItemTypeForCandidateIdentifiers();
            } else {
                return;
            }
        }
        // If the item has candidate identifiers, the item identifier must be
        // zero for wildcard or one of the candidates.
        if (itemCandidateIdentifiersLength == 0 && identifier == 0) {
            revert InvalidIdentifier(identifier, candidateIdentifiers);
        }
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
