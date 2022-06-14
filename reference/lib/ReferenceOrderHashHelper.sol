// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ConsiderationItem, OfferItem, OrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";

/**
 * @title  OrderHashHelper
 * @author iamameme
 * @notice OrderHashHelper contains an internal pure view function
 *         to derive an order hash from given order parameters.
 */
contract ReferenceOrderHashHelper {
    // Compiled typehash constants
    bytes32 constant OFFER_ITEM_TYPEHASH =
        0xa66999307ad1bb4fde44d13a5d710bd7718e0c87c1eef68a571629fbf5b93d02;
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH =
        0x42d81c6929ffdc4eb27a0808e40e82516ad42296c166065de7f812492304ff6e;
    bytes32 constant ORDER_TYPEHASH =
        0xfa445660b7e21515a59617fcd68910b487aa5808b8abda3d78bc85df364b2c2f;

    /**
     * @dev Internal pure function to derive the EIP-712 hash for an offer item.
     *
     * @param offerItem The offered item to hash.
     *
     * @return The hash.
     */
    function _hashOfferItem(OfferItem memory offerItem)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    OFFER_ITEM_TYPEHASH,
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    offerItem.startAmount,
                    offerItem.endAmount
                )
            );
    }

    /**
     * @dev Internal pure function to derive the EIP-712 hash for a
     *      consideration item.
     *
     * @param considerationItem The consideration item to hash.
     *
     * @return The hash.
     */
    function _hashConsiderationItem(ConsiderationItem memory considerationItem)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    CONSIDERATION_ITEM_TYPEHASH,
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    considerationItem.startAmount,
                    considerationItem.endAmount,
                    considerationItem.recipient
                )
            );
    }

    /**
     * @dev Internal pure function to derive the order hash for a given order.
     *      Note that only the original consideration items are included in the
     *      order hash, as additional consideration items may be supplied by the
     *      caller.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param counter           The counter of the order to hash.
     *
     * @return orderHash The hash.
     */
    function _deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) internal pure returns (bytes32 orderHash) {
        // Designate new memory regions for offer and consideration item hashes.
        bytes32[] memory offerHashes = new bytes32[](
            orderParameters.offer.length
        );
        bytes32[] memory considerationHashes = new bytes32[](
            orderParameters.totalOriginalConsiderationItems
        );

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
            // Hash the offer and place the result into memory.
            offerHashes[i] = _hashOfferItem(orderParameters.offer[i]);
        }

        // Iterate over each consideration on the order.
        for (
            uint256 i = 0;
            i < orderParameters.totalOriginalConsiderationItems;
            ++i
        ) {
            // Hash the consideration and place the result into memory.
            considerationHashes[i] = _hashConsiderationItem(
                orderParameters.consideration[i]
            );
        }

        // Derive and return the order hash as specified by EIP-712.
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    orderParameters.offerer,
                    orderParameters.zone,
                    keccak256(abi.encodePacked(offerHashes)),
                    keccak256(abi.encodePacked(considerationHashes)),
                    orderParameters.orderType,
                    orderParameters.startTime,
                    orderParameters.endTime,
                    orderParameters.zoneHash,
                    orderParameters.salt,
                    orderParameters.conduitKey,
                    counter
                )
            );
    }
}
