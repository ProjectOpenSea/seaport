// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    BasicOrderParameters,
    Order,
    CriteriaResolver,
    AdvancedOrder,
    FulfillmentComponent,
    Execution,
    Fulfillment,
    OrderComponents,
    OrderParameters,
    SpentItem,
    OfferItem,
    ConsiderationItem,
    ReceivedItem
} from "./ConsiderationStructs.sol";
import "./ConsiderationConstants.sol";
import "./PointerLibraries.sol";

contract ConsiderationDecoder {
    uint256 constant BasicOrderParameters_head_size = 0x0240;
    uint256 constant BasicOrderParameters_fixed_segment_0 = 0x0200;
    uint256 constant BasicOrderParameters_additionalRecipients_offset = 0x0200;
    uint256 constant BasicOrderParameters_signature_offset = 0x0220;

    uint256 constant OrderParameters_head_size = 0x0160;
    uint256 constant OrderParameters_totalOriginalConsiderationItems_offset = (
        0x0140
    );
    uint256 constant AdvancedOrderPlusOrderParameters_head_size = 0x0200;

    uint256 constant Order_signature_offset = 0x20;
    uint256 constant Order_head_size = 0x40;

    uint256 constant AdvancedOrder_fixed_segment_0 = 0x40;

    uint256 constant CriteriaResolver_head_size = 0xa0;
    uint256 constant CriteriaResolver_fixed_segment_0 = 0x80;
    uint256 constant CriteriaResolver_criteriaProof_offset = 0x80;

    uint256 constant FulfillmentComponent_mem_tail_size = 0x40;
    uint256 constant Fulfillment_head_size = 0x40;
    uint256 constant Fulfillment_considerationComponents_offset = 0x20;

    uint256 constant OrderComponents_OrderParameters_common_head_size = 0x0140;

    /**
     * @dev Takes a bytes array from calldata and copies it into memory.
     *
     * @param cdPtrLength A calldata pointer to the start of the bytes array in
     *                    calldata which contains the length of the array.
     *
     * @return mPtrLength A memory pointer to the start of the bytes array in
     *                    memory which contains the length of the array.
     */
    function _decodeBytes(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            // Get the current free memory pointer.
            mPtrLength := mload(FreeMemoryPointerSlot)

            // Derive the size of the bytes array, rounding up to nearest word.
            let size := and(
                add(
                    and(calldataload(cdPtrLength), OffsetOrLengthMask),
                    AlmostTwoWords
                ),
                OnlyFullWordMask
            )

            // Copy bytes from calldata into memory based on pointers and size.
            calldatacopy(mPtrLength, cdPtrLength, size)

            // Update free memory pointer based on the size of the bytes array.
            mstore(FreeMemoryPointerSlot, add(mPtrLength, size))
        }
    }

    /**
     * @dev Takes an offer array from calldata and copies it into memory.
     *
     * @param cdPtrLength A calldata pointer to the start of the offer array
     *                    in calldata which contains the length of the array.
     *
     * @return mPtrLength A memory pointer to the start of the offer array in
     *                    memory which contains the length of the array.
     */
    function _decodeOffer(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            // Retrieve length of array, masking to prevent potential overflow.
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)

            // Get the current free memory pointer.
            mPtrLength := mload(FreeMemoryPointerSlot)

            // Write the array length to memory.
            mstore(mPtrLength, arrLength)

            // Derive the head by adding one word to the length pointer.
            let mPtrHead := add(mPtrLength, OneWord)

            // Derive the tail by adding one word per element (note that structs
            // are written to memory with an offset per struct element).
            let mPtrTail := add(mPtrHead, mul(arrLength, OneWord))

            // Track the next tail, beginning with the initial tail value.
            let mPtrTailNext := mPtrTail

            // Copy all offer array data into memory at the tail pointer.
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, OneWord),
                mul(arrLength, OfferItem_size)
            )

            // Track the next head pointer, starting with initial head value.
            let mPtrHeadNext := mPtrHead

            // Iterate over each head pointer until it reaches the tail.
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                // Write the next tail pointer to next head pointer in memory.
                mstore(mPtrHeadNext, mPtrTailNext)

                // Increment the next head pointer by one word.
                mPtrHeadNext := add(mPtrHeadNext, OneWord)

                // Increment the next tail pointer by the size of an offer item.
                mPtrTailNext := add(mPtrTailNext, OfferItem_size)
            }

            // Update free memory pointer to allocate memory up to end of tail.
            mstore(FreeMemoryPointerSlot, mPtrTailNext)
        }
    }

    /**
     * @dev Takes a consideration array from calldata and copies it into memory.
     *
     * @param cdPtrLength A calldata pointer to the start of the consideration
     *                    array in calldata which contains the length of the
     *                    array.
     *
     * @return mPtrLength A memory pointer to the start of the consideration
     *                    array in memory which contains the length of the
     *                    array.
     */
    function _decodeConsideration(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            // Retrieve length of array, masking to prevent potential overflow.
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)

            // Get the current free memory pointer.
            mPtrLength := mload(FreeMemoryPointerSlot)

            // Write the array length to memory.
            mstore(mPtrLength, arrLength)

            // Derive the head by adding one word to the length pointer.
            let mPtrHead := add(mPtrLength, OneWord)

            // Derive the tail by adding one word per element (note that structs
            // are written to memory with an offset per struct element).
            let mPtrTail := add(mPtrHead, mul(arrLength, OneWord))

            // Track the next tail, beginning with the initial tail value.
            let mPtrTailNext := mPtrTail

            // Copy all consideration array data into memory at tail pointer.
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, OneWord),
                mul(arrLength, ConsiderationItem_size)
            )

            // Track the next head pointer, starting with initial head value.
            let mPtrHeadNext := mPtrHead

            // Iterate over each head pointer until it reaches the tail.
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                // Write the next tail pointer to next head pointer in memory.
                mstore(mPtrHeadNext, mPtrTailNext)

                // Increment the next head pointer by one word.
                mPtrHeadNext := add(mPtrHeadNext, OneWord)

                // Increment next tail pointer by size of a consideration item.
                mPtrTailNext := add(mPtrTailNext, ConsiderationItem_size)
            }

            // Update free memory pointer to allocate memory up to end of tail.
            mstore(FreeMemoryPointerSlot, mPtrTailNext)
        }
    }

    /**
     * @dev Takes a calldata pointer and memory pointer and copies a referenced
     *      OrderParameters struct and associated offer and consideration data
     *      to memory.
     *
     * @param cdPtr A calldata pointer for the OrderParameters struct.
     * @param mPtr A memory pointer to the OrderParameters struct head.
     */
    function _decodeOrderParametersTo(
        CalldataPointer cdPtr,
        MemoryPointer mPtr
    ) internal pure {
        // Copy the full OrderParameters head from calldata to memory.
        cdPtr.copy(mPtr, OrderParameters_head_size);

        // Resolve the offer calldata offset, use that to decode and copy offer
        // from calldata, and write resultant memory offset to head in memory.
        mPtr.offset(OrderParameters_offer_head_offset).write(
            _decodeOffer(cdPtr.pptr(OrderParameters_offer_head_offset))
        );

        // Resolve consideration calldata offset, use that to copy consideration
        // from calldata, and write resultant memory offset to head in memory.
        mPtr.offset(OrderParameters_consideration_head_offset).write(
            _decodeConsideration(
                cdPtr.pptr(OrderParameters_consideration_head_offset)
            )
        );
    }

    /**
     * @dev Takes a calldata pointer to an OrderParameters struct and copies the
     *      decoded struct to memory.
     *
     * @param cdPtr A calldata pointer for the OrderParameters struct.
     *
     * @return mPtr A memory pointer to the OrderParameters struct head.
     */
    function _decodeOrderParameters(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate required memory for the OrderParameters head (offer and
        // consideration are allocated independently).
        mPtr = malloc(OrderParameters_head_size);

        // Decode and copy the order parameters to the newly allocated memory.
        _decodeOrderParametersTo(cdPtr, mPtr);
    }

    /**
     * @dev Takes a calldata pointer to an Order struct and copies the decoded
     *      struct to memory.
     *
     * @param cdPtr A calldata pointer for the Order struct.
     *
     * @return mPtr A memory pointer to the Order struct head.
     */
    function _decodeOrder(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate required memory for the Order head (OrderParameters and
        // signature are allocated independently).
        mPtr = malloc(Order_head_size);

        // Resolve OrderParameters calldata offset, use it to decode and copy
        // from calldata, and write resultant memory offset to head in memory.
        mPtr.write(_decodeOrderParameters(cdPtr.pptr()));

        // Resolve signature calldata offset, use that to decode and copy from
        // calldata, and write resultant memory offset to head in memory.
        mPtr.offset(Order_signature_offset).write(
            _decodeBytes(cdPtr.pptr(Order_signature_offset))
        );
    }

    /**
     * @dev Takes a calldata pointer to an AdvancedOrder struct and copies the
     *      decoded struct to memory.
     *
     * @param cdPtr A calldata pointer for the AdvancedOrder struct.
     *
     * @return mPtr A memory pointer to the AdvancedOrder struct head.
     */
    function _decodeAdvancedOrder(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate memory for AdvancedOrder head and OrderParameters head.
        mPtr = malloc(AdvancedOrderPlusOrderParameters_head_size);

        // Use numerator + denominator calldata offset to decode and copy
        // from calldata and write resultant memory offset to head in memory.
        cdPtr.offset(AdvancedOrder_numerator_offset).copy(
            mPtr.offset(AdvancedOrder_numerator_offset),
            AdvancedOrder_fixed_segment_0
        );

        // Get pointer to memory immediately after advanced order.
        MemoryPointer mPtrParameters = mPtr.offset(AdvancedOrder_head_size);

        // Write pptr for advanced order parameters to memory.
        mPtr.write(mPtrParameters);

        // Resolve OrderParameters calldata pointer & write to allocated region.
        _decodeOrderParametersTo(cdPtr.pptr(), mPtrParameters);

        // Resolve signature calldata offset, use that to decode and copy from
        // calldata, and write resultant memory offset to head in memory.
        mPtr.offset(AdvancedOrder_signature_offset).write(
            _decodeBytes(cdPtr.pptr(AdvancedOrder_signature_offset))
        );

        // Resolve extraData calldata offset, use that to decode and copy from
        // calldata, and write resultant memory offset to head in memory.
        mPtr.offset(AdvancedOrder_extraData_offset).write(
            _decodeBytes(cdPtr.pptr(AdvancedOrder_extraData_offset))
        );
    }

    /**
     * @dev Allocates a single word of empty bytes in memory and returns the
     *      pointer to that memory region.
     *
     * @return mPtr The memory pointer to the new empty word in memory.
     */
    function _getEmptyBytesOrArray()
        internal
        pure
        returns (MemoryPointer mPtr)
    {
        mPtr = malloc(OneWord);
        mPtr.write(0);
    }

    /**
     * @dev Takes a calldata pointer to an Order struct and copies the decoded
     *      struct to memory as an AdvancedOrder.
     *
     * @param cdPtr A calldata pointer for the Order struct.
     *
     * @return mPtr A memory pointer to the AdvancedOrder struct head.
     */
    function _decodeOrderAsAdvancedOrder(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate memory for AdvancedOrder head and OrderParameters head.
        mPtr = malloc(AdvancedOrderPlusOrderParameters_head_size);

        // Get pointer to memory immediately after advanced order.
        MemoryPointer mPtrParameters = mPtr.offset(AdvancedOrder_head_size);

        // Write pptr for advanced order parameters.
        mPtr.write(mPtrParameters);

        // Resolve OrderParameters calldata pointer & write to allocated region.
        _decodeOrderParametersTo(cdPtr.pptr(), mPtrParameters);

        // Write default Order numerator and denominator values (e.g. 1/1).
        mPtr.offset(AdvancedOrder_numerator_offset).write(1);
        mPtr.offset(AdvancedOrder_denominator_offset).write(1);

        // Resolve signature calldata offset, use that to decode and copy from
        // calldata, and write resultant memory offset to head in memory.
        mPtr.offset(AdvancedOrder_signature_offset).write(
            _decodeBytes(cdPtr.pptr(Order_signature_offset))
        );

        // Resolve extraData calldata offset, use that to decode and copy from
        // calldata, and write resultant memory offset to head in memory.
        mPtr.offset(AdvancedOrder_extraData_offset).write(
            _getEmptyBytesOrArray()
        );
    }

    /**
     * @dev Takes a calldata pointer to an array of Order structs and copies the
     *      decoded array to memory as an array of AdvancedOrder structs.
     *
     * @param cdPtrLength A calldata pointer to the start of the orders array in
     *                    calldata which contains the length of the array.
     *
     * @return mPtrLength A memory pointer to the start of the array of advanced
     *                    orders in memory which contains length of the array.
     */
    function _decodeOrdersAsAdvancedOrders(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        // Retrieve length of array, masking to prevent potential overflow.
        uint256 arrLength = cdPtrLength.readMaskedUint256();

        unchecked {
            // Derive offset to the tail based on one word per array element.
            uint256 tailOffset = arrLength * OneWord;

            // Add one additional word for the length and allocate memory.
            mPtrLength = malloc(tailOffset + OneWord);

            // Write the length of the array to memory.
            mPtrLength.write(arrLength);

            // Advance to first memory & calldata pointers (e.g. after length).
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();

            // Iterate over each pointer, word by word, until tail is reached.
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                // Resolve Order calldata offset, use it to decode and copy from
                // calldata, and write resultant AdvancedOrder offset to memory.
                mPtrHead.offset(offset).write(
                    _decodeOrderAsAdvancedOrder(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_dyn_array_bytes32(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 arrSize = (arrLength + 1) * OneWord;
            mPtrLength = malloc(arrSize);
            cdPtrLength.copy(mPtrLength, arrSize);
        }
    }

    function abi_decode_CriteriaResolver(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(CriteriaResolver_head_size);
        cdPtr.copy(mPtr, CriteriaResolver_fixed_segment_0);
        mPtr.offset(CriteriaResolver_criteriaProof_offset).write(
            abi_decode_dyn_array_bytes32(
                cdPtr.pptr(CriteriaResolver_criteriaProof_offset)
            )
        );
    }

    function abi_decode_dyn_array_CriteriaResolver(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * OneWord;
            mPtrLength = malloc(tailOffset + OneWord);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                mPtrHead.offset(offset).write(
                    abi_decode_CriteriaResolver(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_dyn_array_Order(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * OneWord;
            mPtrLength = malloc(tailOffset + OneWord);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                mPtrHead.offset(offset).write(
                    _decodeOrder(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_dyn_array_FulfillmentComponent(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)

            // Get the current free memory pointer.
            mPtrLength := mload(FreeMemoryPointerSlot)

            mstore(mPtrLength, arrLength)
            let mPtrHead := add(mPtrLength, OneWord)
            let mPtrTail := add(mPtrHead, mul(arrLength, OneWord))
            let mPtrTailNext := mPtrTail
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, OneWord),
                mul(arrLength, FulfillmentComponent_mem_tail_size)
            )
            let mPtrHeadNext := mPtrHead
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                mstore(mPtrHeadNext, mPtrTailNext)
                mPtrHeadNext := add(mPtrHeadNext, OneWord)
                mPtrTailNext := add(
                    mPtrTailNext,
                    FulfillmentComponent_mem_tail_size
                )
            }

            // Update the free memory pointer.
            mstore(FreeMemoryPointerSlot, mPtrTailNext)
        }
    }

    function abi_decode_dyn_array_dyn_array_FulfillmentComponent(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * OneWord;
            mPtrLength = malloc(tailOffset + OneWord);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                mPtrHead.offset(offset).write(
                    abi_decode_dyn_array_FulfillmentComponent(
                        cdPtrHead.pptr(offset)
                    )
                );
            }
        }
    }

    function abi_decode_dyn_array_AdvancedOrder(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * OneWord;
            mPtrLength = malloc(tailOffset + OneWord);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                mPtrHead.offset(offset).write(
                    _decodeAdvancedOrder(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_Fulfillment(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(Fulfillment_head_size);
        mPtr.write(abi_decode_dyn_array_FulfillmentComponent(cdPtr.pptr()));
        mPtr.offset(Fulfillment_considerationComponents_offset).write(
            abi_decode_dyn_array_FulfillmentComponent(
                cdPtr.pptr(Fulfillment_considerationComponents_offset)
            )
        );
    }

    function abi_decode_dyn_array_Fulfillment(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * OneWord;
            mPtrLength = malloc(tailOffset + OneWord);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset = 0; offset < tailOffset; offset += OneWord) {
                mPtrHead.offset(offset).write(
                    abi_decode_Fulfillment(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_OrderComponents_as_OrderParameters(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(OrderParameters_head_size);
        cdPtr.copy(mPtr, OrderComponents_OrderParameters_common_head_size);
        mPtr.offset(OrderParameters_offer_head_offset).write(
            _decodeOffer(cdPtr.pptr(OrderParameters_offer_head_offset))
        );
        MemoryPointer consideration = _decodeConsideration(
            cdPtr.pptr(OrderParameters_consideration_head_offset)
        );
        mPtr.offset(OrderParameters_consideration_head_offset).write(
            consideration
        );
        // Write totalOriginalConsiderationItems
        mPtr
            .offset(OrderParameters_totalOriginalConsiderationItems_offset)
            .write(consideration.readUint256());
    }

    /**
     * @dev Decodes the returndata from a call to generateOrder, or returns
     *      empty arrays and a boolean signifying that the returndata does not
     *      adhere to a valid encoding scheme if it cannot be decoded.
     *
     * @return invalidEncoding A boolean signifying whether the returndata has
     *                         an invalid encoding.
     * @return offer           The decoded offer array.
     * @return consideration   The decoded consideration array.
     */
    function _decodeGenerateOrderReturndata()
        internal
        pure
        returns (
            uint256 invalidEncoding,
            MemoryPointer offer,
            MemoryPointer consideration
        )
    {
        assembly {
            // check that returndatasize is at least 80 bytes:
            // offerOffset,considerationOffset,offerLength,considerationLength
            invalidEncoding := lt(returndatasize(), FourWords)

            let offsetOffer
            let offsetConsideration
            let offerLength
            let considerationLength

            if iszero(invalidEncoding) {
                // Copy first two words of calldata (the offsets to offer and
                // consideration array lengths) to scratch space. Multiply by
                // validLength to avoid panics if returndatasize is too small.
                returndatacopy(0, 0, TwoWords)
                offsetOffer := mload(0)
                offsetConsideration := mload(OneWord)

                // If valid length, check that offsets are within returndata.
                let invalidOfferOffset := gt(offsetOffer, returndatasize())
                let invalidConsiderationOffset := gt(
                    offsetConsideration,
                    returndatasize()
                )

                // Only proceed if length (and thus encoding) is valid so far.
                invalidEncoding := or(
                    invalidOfferOffset,
                    invalidConsiderationOffset
                )
                if iszero(invalidEncoding) {
                    // Copy length of offer array to scratch space.
                    returndatacopy(0, offsetOffer, OneWord)
                    offerLength := mload(0)

                    // Copy length of consideration array to scratch space.
                    returndatacopy(OneWord, offsetConsideration, OneWord)
                    considerationLength := mload(OneWord)

                    {
                        // Calculate total size of offer & consideration arrays.
                        let totalOfferSize := mul(SpentItem_size, offerLength)
                        let totalConsiderationSize := mul(
                            ReceivedItem_size,
                            considerationLength
                        )

                        // Add 4 words to total size to cover the offset and
                        // length fields of the two arrays.
                        let totalSize := add(
                            FourWords,
                            add(totalOfferSize, totalConsiderationSize)
                        )
                        // Don't continue if returndatasize exceeds 65535 bytes
                        // or is not equal to the calculated size.
                        invalidEncoding := or(
                            gt(or(offerLength, considerationLength), 0xffff),
                            xor(totalSize, returndatasize())
                        )
                        // Set first word of scratch space to 0 so length of
                        // offer/consideration are set to 0 on invalid encoding.
                        mstore(0, 0)
                    }
                }
            }

            if iszero(invalidEncoding) {
                offer := copySpentItemsAsOfferItems(
                    add(offsetOffer, OneWord),
                    offerLength
                )

                consideration := copyReceivedItemsAsConsiderationItems(
                    add(offsetConsideration, OneWord),
                    considerationLength
                )
            }

            function copySpentItemsAsOfferItems(rdPtrHead, length)
                -> mPtrLength
            {
                mPtrLength := mload(FreeMemoryPointerSlot)
                // allocate memory for array
                mstore(
                    FreeMemoryPointerSlot,
                    add(
                        mPtrLength,
                        add(OneWord, mul(length, add(OfferItem_size, OneWord)))
                    )
                )
                // Write length
                mstore(mPtrLength, length)

                // Use offset from length to minimize stack depth
                let headOffsetFromLength := OneWord

                let headSizeWithLength := mul(add(1, length), OneWord)
                let mPtrTailNext := add(mPtrLength, headSizeWithLength)
                for {

                } lt(headOffsetFromLength, headSizeWithLength) {

                } {
                    mstore(add(mPtrLength, headOffsetFromLength), mPtrTailNext)
                    returndatacopy(mPtrTailNext, rdPtrHead, SpentItem_size)
                    // Copy amount to endAmount
                    mstore(
                        add(mPtrTailNext, Common_endAmount_offset),
                        mload(add(mPtrTailNext, Common_amount_offset))
                    )
                    rdPtrHead := add(rdPtrHead, SpentItem_size)
                    mPtrTailNext := add(mPtrTailNext, OfferItem_size)
                    headOffsetFromLength := add(headOffsetFromLength, OneWord)
                }
            }

            function copyReceivedItemsAsConsiderationItems(rdPtrHead, length)
                -> mPtrLength
            {
                mPtrLength := mload(FreeMemoryPointerSlot)
                // allocate memory for array
                mstore(
                    FreeMemoryPointerSlot,
                    add(
                        mPtrLength,
                        add(
                            OneWord,
                            mul(length, add(ConsiderationItem_size, OneWord))
                        )
                    )
                )
                // Write length
                mstore(mPtrLength, length)

                // Use offset from length to minimize stack depth
                let headOffsetFromLength := OneWord

                let headSizeWithLength := mul(add(1, length), OneWord)
                let mPtrTailNext := add(mPtrLength, headSizeWithLength)
                for {

                } lt(headOffsetFromLength, headSizeWithLength) {

                } {
                    mstore(add(mPtrLength, headOffsetFromLength), mPtrTailNext)
                    // Copy itemType, token, identifier and amount
                    returndatacopy(mPtrTailNext, rdPtrHead, SpentItem_size)
                    // Copy amount and recipient
                    returndatacopy(
                        add(mPtrTailNext, Common_endAmount_offset),
                        add(rdPtrHead, Common_amount_offset),
                        TwoWords
                    )
                    rdPtrHead := add(rdPtrHead, ReceivedItem_size)
                    mPtrTailNext := add(mPtrTailNext, ConsiderationItem_size)
                    headOffsetFromLength := add(headOffsetFromLength, OneWord)
                }
            }
        }
    }

    /**
     * @dev Converts a function returning _decodeGenerateOrderReturndata types
     *      into a function returning offer and consideration types.
     *
     * @param inFn The input function, taking no arguments and returning an
     *             error buffer, spent item array, and received item array.
     *
     * @return outFn The output function, taking no arguments and returning an
     *               error buffer, offer array, and consideration array.
     */
    function _convertGetGeneratedOrderResult(
        function()
            internal
            pure
            returns (uint256, MemoryPointer, MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function()
                internal
                pure
                returns (
                    uint256,
                    OfferItem[] memory,
                    ConsiderationItem[] memory
                ) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking ReceivedItem, address, bytes32, and bytes
     *      types (e.g. the _transfer function) into a function taking
     *      OfferItem, address, bytes32, and bytes types.
     *
     * @param inFn The input function, taking ReceivedItem, address, bytes32,
     *             and bytes types (e.g. the _transfer function).
     *
     * @return outFn The output function, taking OfferItem, address, bytes32,
     *               and bytes types.
     */
    function _toOfferItemInput(
        function(ReceivedItem memory, address, bytes32, bytes memory)
            internal inFn
    )
        internal
        pure
        returns (
            function(OfferItem memory, address, bytes32, bytes memory)
                internal outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking ReceivedItem, address, bytes32, and bytes
     *      types (e.g. the _transfer function) into a function taking
     *      ConsiderationItem, address, bytes32, and bytes types.
     *
     * @param inFn The input function, taking ReceivedItem, address, bytes32,
     *             and bytes types (e.g. the _transfer function).
     *
     * @return outFn The output function, taking ConsiderationItem, address,
     *               bytes32, and bytes types.
     */
    function _toConsiderationItemInput(
        function(ReceivedItem memory, address, bytes32, bytes memory)
            internal inFn
    )
        internal
        pure
        returns (
            function(ConsiderationItem memory, address, bytes32, bytes memory)
                internal outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      an OrderParameters type.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning an OrderParameters type.
     */
    function _toOrderParametersReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (OrderParameters memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      an AdvancedOrder type.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning an AdvancedOrder type.
     */
    function _toAdvancedOrderReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (AdvancedOrder memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      a dynamic array of CriteriaResolver types.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning a dynamic array of CriteriaResolver types.
     */
    function _toCriteriaResolversReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (CriteriaResolver[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      a dynamic array of Order types.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning a dynamic array of Order types.
     */
    function _toOrdersReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (Order[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      a nested dynamic array of dynamic arrays of FulfillmentComponent
     *      types.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning a nested dynamic array of dynamic arrays of
     *               FulfillmentComponent types.
     */
    function _toSideFulfillmentComponentsReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (FulfillmentComponent[][] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      a dynamic array of AdvancedOrder types.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning a dynamic array of AdvancedOrder types.
     */
    function _toAdvancedOrdersReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (AdvancedOrder[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    /**
     * @dev Converts a function taking a calldata pointer and returning a memory
     *      pointer into a function taking that calldata pointer and returning
     *      a dynamic array of Fulfillment types.
     *
     * @param inFn The input function, taking an arbitrary calldata pointer and
     *             returning an arbitrary memory pointer.
     *
     * @return outFn The output function, taking an arbitrary calldata pointer
     *               and returning a dynamic array of Fulfillment types.
     */
    function _toFulfillmentsReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (Fulfillment[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }
}
