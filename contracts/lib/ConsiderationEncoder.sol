// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ConsiderationConstants.sol";
import {
    BasicOrderParameters,
    Order,
    CriteriaResolver,
    AdvancedOrder,
    FulfillmentComponent,
    Execution,
    Fulfillment,
    OrderComponents,
    OrderParameters
} from "./ConsiderationStructs.sol";
import "./PointerLibraries.sol";

contract ConsiderationEncoder {
    function toMemoryPointer(
        bytes memory obj
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := obj
        }
    }

    function abi_encode_bytes(
        MemoryPointer src,
        MemoryPointer dst
    ) internal view returns (uint256 size) {
        unchecked {
            size =
                ((src.readUint256() & OffsetOrLengthMask) + AlmostTwoWords) &
                OnlyFullWordMask;
            src.copy(dst, size);
        }
    }

    function abi_encode_generateOrder(
        OrderParameters memory orderParameters,
        bytes memory context
    ) internal view returns (MemoryPointer dst, uint256 size) {
        MemoryPointer src = orderParameters.toMemoryPointer();

        // Get free memory pointer to write calldata to
        dst = getFreeMemoryPointer();

        // Write generateOrder selector and get pointer to start of calldata
        dst.write(generateOrder_selector);
        dst = dst.offset(generateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data
        MemoryPointer dstHead = dst.offset(generateOrder_head_offset);

        // Write `fulfiller` to calldata
        dstHead.write(msg.sender);
        uint256 tailOffset = generateOrder_base_tail_offset;

        unchecked {
            // Write offset to minimumReceived
            dstHead.offset(generateOrder_minimumReceived_head_offset).write(
                tailOffset
            );
            // Get pointer to orderParameters.offer.length
            MemoryPointer srcOfferPointer = src
                .offset(OrderParameters_offer_head_offset)
                .readMemoryPointer();
            // Encode the offer array as SpentItem[]
            uint256 minimumReceivedSize = abi_encode_as_dyn_array_SpentItem(
                srcOfferPointer,
                dstHead.offset(tailOffset)
            );
            tailOffset += minimumReceivedSize;

            // Write offset to maximumSpent
            dstHead.offset(generateOrder_maximumSpent_head_offset).write(
                tailOffset
            );
            MemoryPointer srcConsiderationPointer = src
                .offset(OrderParameters_consideration_head_offset)
                .readMemoryPointer();
            // Encode the offer array as SpentItem[]
            uint256 maximumSpentSize = abi_encode_as_dyn_array_SpentItem(
                srcConsiderationPointer,
                dstHead.offset(tailOffset)
            );
            tailOffset += maximumSpentSize;

            // Write offset to context
            dstHead.offset(generateOrder_context_head_offset).write(tailOffset);
            MemoryPointer srcContext = toMemoryPointer(context);
            uint256 contextSize = abi_encode_bytes(
                srcContext,
                dstHead.offset(tailOffset)
            );
            tailOffset += contextSize;

            size = 4 + tailOffset;
        }
    }

    function abi_encode_as_dyn_array_SpentItem(
        MemoryPointer srcLength,
        MemoryPointer dstLength
    ) internal pure returns (uint256 size) {
        assembly {
            let length := mload(srcLength)
            mstore(dstLength, length)

            // Get pointer to first item's head position in the array, containing
            // the item's pointer in memory. The head pointer will be incremented
            // until it reaches the tail position (start of the array data).
            let mPtrHead := add(srcLength, 0x20)
            // Position in memory to write next item for calldata. Since SpentItem
            // has a fixed length, the array elements do not contain head elements in
            // calldata, they are concatenated together after the array length.
            let cdPtrData := add(dstLength, 0x20)
            // Pointer to end of array head in memory.
            let mPtrHeadEnd := add(mPtrHead, mul(length, 0x20))

            for {

            } lt(mPtrHead, mPtrHeadEnd) {

            } {
                // Read pointer to data for the array element from its head position
                let mPtrTail := mload(mPtrHead)
                // Copy the itemType, token, identifier, amount from the item to calldata
                mstore(cdPtrData, mload(mPtrTail))
                mstore(
                    add(cdPtrData, Common_token_offset),
                    mload(add(mPtrTail, Common_token_offset))
                )
                mstore(
                    add(cdPtrData, Common_identifier_offset),
                    mload(add(mPtrTail, Common_identifier_offset))
                )
                mstore(
                    add(cdPtrData, Common_amount_offset),
                    mload(add(mPtrTail, Common_amount_offset))
                )

                mPtrHead := add(mPtrHead, 0x20)
                cdPtrData := add(cdPtrData, SpentItem_size)
            }
            size := add(0x20, mul(length, SpentItem_size))
        }
    }
}
