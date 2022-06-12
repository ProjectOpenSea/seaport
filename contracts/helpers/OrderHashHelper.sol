// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { OrderParameters } from "../lib/ConsiderationStructs.sol";

import { ConsiderationBase } from "../lib/ConsiderationBase.sol";

/**
 * @title OrderHashHelper
 * @author iamameme
 * @notice OrderHashHelper contains an internal pure view function
 *         to derive an order hash from given order parameters.
 */
contract OrderHashHelper {
    // Cached constants from ConsiderationConstants
    uint256 constant OrderParameters_offer_head_offset = 0x40;
    uint256 constant OneWord = 0x20;
    uint256 constant EIP712_OfferItem_size = 0xc0;
    uint256 constant OrderParameters_consideration_head_offset = 0x60;
    uint256 constant EIP712_ConsiderationItem_size = 0xe0;
    uint256 constant OrderParameters_counter_offset = 0x140;
    uint256 constant FreeMemoryPointerSlot = 0x40;
    uint256 constant EIP712_Order_size = 0x180;
    // Compiled typehash constants
    bytes32 constant OFFER_ITEM_TYPEHASH = 0xa66999307ad1bb4fde44d13a5d710bd7718e0c87c1eef68a571629fbf5b93d02;
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH = 0x42d81c6929ffdc4eb27a0808e40e82516ad42296c166065de7f812492304ff6e;
    bytes32 constant ORDER_TYPEHASH = 0xfa445660b7e21515a59617fcd68910b487aa5808b8abda3d78bc85df364b2c2f;

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
    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) internal pure returns (bytes32 orderHash) {
        // Get length of original consideration array and place it on the stack.
        uint256 originalConsiderationLength = (
            orderParameters.totalOriginalConsiderationItems
        );

        /*
         * Memory layout for an array of structs (dynamic or not) is similar
         * to ABI encoding of dynamic types, with a head segment followed by
         * a data segment. The main difference is that the head of an element
         * is a memory pointer rather than an offset.
         */

        // Declare a variable for the derived hash of the offer array.
        bytes32 offerHash;

        // Read offer item EIP-712 typehash from runtime code & place on stack.
        bytes32 typeHash = OFFER_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the offers array.
            let offerArrPtr := mload(
                add(orderParameters, OrderParameters_offer_head_offset)
            )

            // Load the length.
            let offerLength := mload(offerArrPtr)

            // Set the pointer to the first offer's head.
            offerArrPtr := add(offerArrPtr, OneWord)

            // Iterate over the offer items.
            // prettier-ignore
            for { let i := 0 } lt(i, offerLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the offer data and subtract one word
                // to get typeHash pointer.
                let ptr := sub(mload(offerArrPtr), OneWord)

                // Read the current value before the offer data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(hashArrPtr, keccak256(ptr, EIP712_OfferItem_size))

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers by one word.
                offerArrPtr := add(offerArrPtr, OneWord)
                hashArrPtr := add(hashArrPtr, OneWord)
            }

            // Derive the offer hash using the hashes of each item.
            offerHash := keccak256(
                mload(FreeMemoryPointerSlot),
                mul(offerLength, OneWord)
            )
        }

        // Declare a variable for the derived hash of the consideration array.
        bytes32 considerationHash;

        // Read consideration item typehash from runtime code & place on stack.
        typeHash = CONSIDERATION_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the consideration array.
            let considerationArrPtr := add(
                mload(
                    add(
                        orderParameters,
                        OrderParameters_consideration_head_offset
                    )
                ),
                OneWord
            )

            // Iterate over the consideration items (not including tips).
            // prettier-ignore
            for { let i := 0 } lt(i, originalConsiderationLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the consideration data and subtract one
                // word to get typeHash pointer.
                let ptr := sub(mload(considerationArrPtr), OneWord)

                // Read the current value before the consideration data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(
                    hashArrPtr,
                    keccak256(ptr, EIP712_ConsiderationItem_size)
                )

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers by one word.
                considerationArrPtr := add(considerationArrPtr, OneWord)
                hashArrPtr := add(hashArrPtr, OneWord)
            }

            // Derive the consideration hash using the hashes of each item.
            considerationHash := keccak256(
                mload(FreeMemoryPointerSlot),
                mul(originalConsiderationLength, OneWord)
            )
        }

        // Read order item EIP-712 typehash from runtime code & place on stack.
        typeHash = ORDER_TYPEHASH;

        // Utilize assembly to access derived hashes & other arguments directly.
        assembly {
            // Retrieve pointer to the region located just behind parameters.
            let typeHashPtr := sub(orderParameters, OneWord)

            // Store the value at that pointer location to restore later.
            let previousValue := mload(typeHashPtr)

            // Store the order item EIP-712 typehash at the typehash location.
            mstore(typeHashPtr, typeHash)

            // Retrieve the pointer for the offer array head.
            let offerHeadPtr := add(
                orderParameters,
                OrderParameters_offer_head_offset
            )

            // Retrieve the data pointer referenced by the offer head.
            let offerDataPtr := mload(offerHeadPtr)

            // Store the offer hash at the retrieved memory location.
            mstore(offerHeadPtr, offerHash)

            // Retrieve the pointer for the consideration array head.
            let considerationHeadPtr := add(
                orderParameters,
                OrderParameters_consideration_head_offset
            )

            // Retrieve the data pointer referenced by the consideration head.
            let considerationDataPtr := mload(considerationHeadPtr)

            // Store the consideration hash at the retrieved memory location.
            mstore(considerationHeadPtr, considerationHash)

            // Retrieve the pointer for the counter.
            let counterPtr := add(
                orderParameters,
                OrderParameters_counter_offset
            )

            // Store the counter at the retrieved memory location.
            mstore(counterPtr, counter)

            // Derive the order hash using the full range of order parameters.
            orderHash := keccak256(typeHashPtr, EIP712_Order_size)

            // Restore the value previously held at typehash pointer location.
            mstore(typeHashPtr, previousValue)

            // Restore offer data pointer at the offer head pointer location.
            mstore(offerHeadPtr, offerDataPtr)

            // Restore consideration data pointer at the consideration head ptr.
            mstore(considerationHeadPtr, considerationDataPtr)

            // Restore consideration item length at the counter pointer.
            mstore(counterPtr, originalConsiderationLength)
        }
    }
}
