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

    function abi_decode_bytes(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            mPtrLength := mload(0x40)
            let size := and(
                add(
                    and(calldataload(cdPtrLength), OffsetOrLengthMask),
                    AlmostTwoWords
                ),
                OnlyFullWordMask
            )
            calldatacopy(mPtrLength, cdPtrLength, size)
            mstore(0x40, add(mPtrLength, size))
        }
    }

    function abi_decode_dyn_array_OfferItem(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
            mPtrLength := mload(0x40)
            mstore(mPtrLength, arrLength)
            let mPtrHead := add(mPtrLength, 32)
            let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
            let mPtrTailNext := mPtrTail
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, 0x20),
                mul(arrLength, OfferItem_size)
            )
            let mPtrHeadNext := mPtrHead
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                mstore(mPtrHeadNext, mPtrTailNext)
                mPtrHeadNext := add(mPtrHeadNext, 0x20)
                mPtrTailNext := add(mPtrTailNext, OfferItem_size)
            }
            mstore(0x40, mPtrTailNext)
        }
    }

    function abi_decode_dyn_array_ConsiderationItem(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
            mPtrLength := mload(0x40)
            mstore(mPtrLength, arrLength)
            let mPtrHead := add(mPtrLength, 32)
            let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
            let mPtrTailNext := mPtrTail
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, 0x20),
                mul(arrLength, ConsiderationItem_size)
            )
            let mPtrHeadNext := mPtrHead
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                mstore(mPtrHeadNext, mPtrTailNext)
                mPtrHeadNext := add(mPtrHeadNext, 0x20)
                mPtrTailNext := add(mPtrTailNext, ConsiderationItem_size)
            }
            mstore(0x40, mPtrTailNext)
        }
    }

    function abi_decode_OrderParameters_to(
        CalldataPointer cdPtr,
        MemoryPointer mPtr
    ) internal pure {
        cdPtr.copy(mPtr, OrderParameters_head_size);
        mPtr.offset(OrderParameters_offer_head_offset).write(
            abi_decode_dyn_array_OfferItem(
                cdPtr.pptr(OrderParameters_offer_head_offset)
            )
        );
        mPtr.offset(OrderParameters_consideration_head_offset).write(
            abi_decode_dyn_array_ConsiderationItem(
                cdPtr.pptr(OrderParameters_consideration_head_offset)
            )
        );
    }

    function abi_decode_OrderParameters(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(OrderParameters_head_size);
        abi_decode_OrderParameters_to(cdPtr, mPtr);
    }

    function abi_decode_Order(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(Order_head_size);
        mPtr.write(abi_decode_OrderParameters(cdPtr.pptr()));
        mPtr.offset(Order_signature_offset).write(
            abi_decode_bytes(cdPtr.pptr(Order_signature_offset))
        );
    }

    function abi_decode_AdvancedOrder(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate memory for AdvancedOrder head and OrderParameters head
        mPtr = malloc(AdvancedOrder_head_size + OrderParameters_head_size);

        // Copy order numerator and denominator
        cdPtr.offset(AdvancedOrder_numerator_offset).copy(
            mPtr.offset(AdvancedOrder_numerator_offset),
            AdvancedOrder_fixed_segment_0
        );

        // Get pointer to memory immediately after advanced order
        MemoryPointer mPtrParameters = mPtr.offset(AdvancedOrder_head_size);
        // Write pptr for advanced order parameters
        mPtr.write(mPtrParameters);
        // Copy order parameters to allocated region
        abi_decode_OrderParameters_to(cdPtr.pptr(), mPtrParameters);

        // mPtr.write(abi_decode_OrderParameters(cdPtr.pptr()));
        mPtr.offset(AdvancedOrder_signature_offset).write(
            abi_decode_bytes(cdPtr.pptr(AdvancedOrder_signature_offset))
        );
        mPtr.offset(AdvancedOrder_extraData_offset).write(
            abi_decode_bytes(cdPtr.pptr(AdvancedOrder_extraData_offset))
        );
    }

    function getEmptyBytesOrArray() internal pure returns (MemoryPointer mPtr) {
        mPtr = malloc(32);
        mPtr.write(0);
    }

    function abi_decode_Order_as_AdvancedOrder(
        CalldataPointer cdPtr
    ) internal pure returns (MemoryPointer mPtr) {
        // Allocate memory for AdvancedOrder head and OrderParameters head
        mPtr = malloc(AdvancedOrder_head_size + OrderParameters_head_size);

        // Get pointer to memory immediately after advanced order
        MemoryPointer mPtrParameters = mPtr.offset(AdvancedOrder_head_size);
        // Write pptr for advanced order parameters
        mPtr.write(mPtrParameters);
        // Copy order parameters to allocated region
        abi_decode_OrderParameters_to(cdPtr.pptr(), mPtrParameters);

        mPtr.offset(AdvancedOrder_numerator_offset).write(1);
        mPtr.offset(AdvancedOrder_denominator_offset).write(1);

        // Copy order signature to advanced order signature
        mPtr.offset(AdvancedOrder_signature_offset).write(
            abi_decode_bytes(cdPtr.pptr(Order_signature_offset))
        );

        // Set empty bytes for advanced order extraData
        mPtr.offset(AdvancedOrder_extraData_offset).write(
            getEmptyBytesOrArray()
        );
    }

    function abi_decode_dyn_array_Order_as_dyn_array_AdvancedOrder(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
                mPtrHead.offset(offset).write(
                    abi_decode_Order_as_AdvancedOrder(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_dyn_array_bytes32(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 arrSize = (arrLength + 1) * 32;
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
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
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
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
                mPtrHead.offset(offset).write(
                    abi_decode_Order(cdPtrHead.pptr(offset))
                );
            }
        }
    }

    function abi_decode_dyn_array_FulfillmentComponent(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        assembly {
            let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
            mPtrLength := mload(0x40)
            mstore(mPtrLength, arrLength)
            let mPtrHead := add(mPtrLength, 32)
            let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
            let mPtrTailNext := mPtrTail
            calldatacopy(
                mPtrTail,
                add(cdPtrLength, 0x20),
                mul(arrLength, FulfillmentComponent_mem_tail_size)
            )
            let mPtrHeadNext := mPtrHead
            for {

            } lt(mPtrHeadNext, mPtrTail) {

            } {
                mstore(mPtrHeadNext, mPtrTailNext)
                mPtrHeadNext := add(mPtrHeadNext, 0x20)
                mPtrTailNext := add(
                    mPtrTailNext,
                    FulfillmentComponent_mem_tail_size
                )
            }
            mstore(0x40, mPtrTailNext)
        }
    }

    function abi_decode_dyn_array_dyn_array_FulfillmentComponent(
        CalldataPointer cdPtrLength
    ) internal pure returns (MemoryPointer mPtrLength) {
        unchecked {
            uint256 arrLength = cdPtrLength.readMaskedUint256();
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
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
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
                mPtrHead.offset(offset).write(
                    abi_decode_AdvancedOrder(cdPtrHead.pptr(offset))
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
            uint256 tailOffset = arrLength * 32;
            mPtrLength = malloc(tailOffset + 32);
            mPtrLength.write(arrLength);
            MemoryPointer mPtrHead = mPtrLength.next();
            CalldataPointer cdPtrHead = cdPtrLength.next();
            for (uint256 offset; offset < tailOffset; offset += 32) {
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
            abi_decode_dyn_array_OfferItem(
                cdPtr.pptr(OrderParameters_offer_head_offset)
            )
        );
        MemoryPointer consideration = abi_decode_dyn_array_ConsiderationItem(
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
                offsetConsideration := mload(0x20)

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
                    returndatacopy(0, offsetOffer, 0x20)
                    offerLength := mload(0)

                    // Copy length of consideration array to scratch space.
                    returndatacopy(0x20, offsetConsideration, 0x20)
                    considerationLength := mload(0x20)

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
                    add(offsetOffer, 0x20),
                    offerLength
                )

                consideration := copyReceivedItemsAsConsiderationItems(
                    add(offsetConsideration, 0x20),
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
                        add(32, mul(length, add(OfferItem_size, 32)))
                    )
                )
                // Write length
                mstore(mPtrLength, length)

                // Use offset from length to minimize stack depth
                let headOffsetFromLength := 32

                let headSizeWithLength := mul(add(1, length), 32)
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
                    headOffsetFromLength := add(headOffsetFromLength, 0x20)
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
                        add(32, mul(length, add(ConsiderationItem_size, 32)))
                    )
                )
                // Write length
                mstore(mPtrLength, length)

                // Use offset from length to minimize stack depth
                let headOffsetFromLength := 32

                let headSizeWithLength := mul(add(1, length), 32)
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
                    headOffsetFromLength := add(headOffsetFromLength, 0x20)
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

    function to_OfferItem_input(
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

    function to_ConsiderationItem_input(
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
