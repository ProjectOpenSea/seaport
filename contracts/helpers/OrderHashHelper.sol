// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { OrderParameters } from "../lib/ConsiderationStructs.sol";

/**
 * @title OrderHashHelper
 * @author iamameme
 * @notice OrderHashHelper contains an internal pure view function
 *         to derive an order hash from given order parameters.
 */
contract OrderHashHelper {
    // Cached constants from ConsiderationConstants
    uint256 internal constant _ORDERPARAMETERS_OFFER_HEAD_OFFSET = 0x40;
    uint256 internal constant _ONE_WORD = 0x20;
    uint256 internal constant _EIP712_OFFERITEM_SIZE = 0xc0;
    uint256 internal constant _ORDERPARAMETERS_CONSIDERATION_HEAD_OFFSET = 0x60;
    uint256 internal constant _EIP712_CONSIDERATIONITEM_SIZE = 0xe0;
    uint256 internal constant _ORDER_PARAMETERS_COUNTER_OFFSET = 0x140;
    uint256 internal constant _FREE_MEMORY_POINTER_SLOT = 0x40;
    uint256 internal constant _EIP712_ORDER_SIZE = 0x180;
    // Compiled typehash constants
    bytes32 internal constant _OFFER_ITEM_TYPEHASH =
        0xa66999307ad1bb4fde44d13a5d710bd7718e0c87c1eef68a571629fbf5b93d02;
    bytes32 internal constant _CONSIDERATION_ITEM_TYPEHASH =
        0x42d81c6929ffdc4eb27a0808e40e82516ad42296c166065de7f812492304ff6e;
    bytes32 internal constant _ORDER_TYPEHASH =
        0xfa445660b7e21515a59617fcd68910b487aa5808b8abda3d78bc85df364b2c2f;

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
        bytes32 typeHash = _OFFER_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(_FREE_MEMORY_POINTER_SLOT)

            // Get the pointer to the offers array.
            let offerArrPtr := mload(
                add(orderParameters, _ORDERPARAMETERS_OFFER_HEAD_OFFSET)
            )

            // Load the length.
            let offerLength := mload(offerArrPtr)

            // Set the pointer to the first offer's head.
            offerArrPtr := add(offerArrPtr, _ONE_WORD)

            // Iterate over the offer items.
            // prettier-ignore
            for { let i := 0 } lt(i, offerLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the offer data and subtract one word
                // to get typeHash pointer.
                let ptr := sub(mload(offerArrPtr), _ONE_WORD)

                // Read the current value before the offer data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(hashArrPtr, keccak256(ptr, _EIP712_OFFERITEM_SIZE))

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers by one word.
                offerArrPtr := add(offerArrPtr, _ONE_WORD)
                hashArrPtr := add(hashArrPtr, _ONE_WORD)
            }

            // Derive the offer hash using the hashes of each item.
            offerHash := keccak256(
                mload(_FREE_MEMORY_POINTER_SLOT),
                mul(offerLength, _ONE_WORD)
            )
        }

        // Declare a variable for the derived hash of the consideration array.
        bytes32 considerationHash;

        // Read consideration item typehash from runtime code & place on stack.
        typeHash = _CONSIDERATION_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(_FREE_MEMORY_POINTER_SLOT)

            // Get the pointer to the consideration array.
            let considerationArrPtr := add(
                mload(
                    add(
                        orderParameters,
                        _ORDERPARAMETERS_CONSIDERATION_HEAD_OFFSET
                    )
                ),
                _ONE_WORD
            )

            // Iterate over the consideration items (not including tips).
            // prettier-ignore
            for { let i := 0 } lt(i, originalConsiderationLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the consideration data and subtract one
                // word to get typeHash pointer.
                let ptr := sub(mload(considerationArrPtr), _ONE_WORD)

                // Read the current value before the consideration data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(
                    hashArrPtr,
                    keccak256(ptr, _EIP712_CONSIDERATIONITEM_SIZE)
                )

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers by one word.
                considerationArrPtr := add(considerationArrPtr, _ONE_WORD)
                hashArrPtr := add(hashArrPtr, _ONE_WORD)
            }

            // Derive the consideration hash using the hashes of each item.
            considerationHash := keccak256(
                mload(_FREE_MEMORY_POINTER_SLOT),
                mul(originalConsiderationLength, _ONE_WORD)
            )
        }

        // Read order item EIP-712 typehash from runtime code & place on stack.
        typeHash = _ORDER_TYPEHASH;

        // Utilize assembly to access derived hashes & other arguments directly.
        assembly {
            // Retrieve pointer to the region located just behind parameters.
            let typeHashPtr := sub(orderParameters, _ONE_WORD)

            // Store the value at that pointer location to restore later.
            let previousValue := mload(typeHashPtr)

            // Store the order item EIP-712 typehash at the typehash location.
            mstore(typeHashPtr, typeHash)

            // Retrieve the pointer for the offer array head.
            let offerHeadPtr := add(
                orderParameters,
                _ORDERPARAMETERS_OFFER_HEAD_OFFSET
            )

            // Retrieve the data pointer referenced by the offer head.
            let offerDataPtr := mload(offerHeadPtr)

            // Store the offer hash at the retrieved memory location.
            mstore(offerHeadPtr, offerHash)

            // Retrieve the pointer for the consideration array head.
            let considerationHeadPtr := add(
                orderParameters,
                _ORDERPARAMETERS_CONSIDERATION_HEAD_OFFSET
            )

            // Retrieve the data pointer referenced by the consideration head.
            let considerationDataPtr := mload(considerationHeadPtr)

            // Store the consideration hash at the retrieved memory location.
            mstore(considerationHeadPtr, considerationHash)

            // Retrieve the pointer for the counter.
            let counterPtr := add(
                orderParameters,
                _ORDER_PARAMETERS_COUNTER_OFFSET
            )

            // Store the counter at the retrieved memory location.
            mstore(counterPtr, counter)

            // Derive the order hash using the full range of order parameters.
            orderHash := keccak256(typeHashPtr, _EIP712_ORDER_SIZE)

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
