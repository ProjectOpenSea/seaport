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
    OrderParameters,
    SpentItem,
    ReceivedItem
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

    function toMemoryPointer(
        bytes32[] memory obj
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := obj
        }
    }

    function toMemoryPointer(
        SpentItem[] memory obj
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := obj
        }
    }

    function toMemoryPointer(
        ReceivedItem[] memory obj
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
            // Encode the consideration array as SpentItem[]
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

    function abi_encode_ratifyOrder(
        bytes32 orderHash, // e.g. offerer + contract nonce
        OrderParameters memory orderParameters,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // Get free memory pointer to write calldata to
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata
        dst.write(ratifyOrder_selector);
        dst = dst.offset(ratifyOrder_selector_offset);

        // Get pointer to the beginning of the encoded data
        MemoryPointer dstHead = dst.offset(ratifyOrder_head_offset);

        // Write contractNonce to calldata
        dstHead.offset(ratifyOrder_contractNonce_offset).write(
            uint96(uint256(orderHash))
        );

        uint256 tailOffset = ratifyOrder_base_tail_offset;
        MemoryPointer src = orderParameters.toMemoryPointer();

        unchecked {
            // Write offset to `offer`
            dstHead.write(tailOffset);
            // Get pointer to orderParameters.offer.length
            MemoryPointer srcOfferPointer = src
                .offset(OrderParameters_offer_head_offset)
                .readMemoryPointer();
            // Encode the offer array as SpentItem[]
            uint256 offerSize = abi_encode_as_dyn_array_SpentItem(
                srcOfferPointer,
                dstHead.offset(tailOffset)
            );
            tailOffset += offerSize;
        }

        unchecked {
            // Write offset to consideration
            dstHead.offset(ratifyOrder_consideration_head_offset).write(
                tailOffset
            );
            // Get pointer to orderParameters.consideration.length
            MemoryPointer srcConsiderationPointer = src
                .offset(OrderParameters_consideration_head_offset)
                .readMemoryPointer();
            // Encode the consideration array as ReceivedItem[]
            uint256 considerationSize = abi_encode_dyn_array_ConsiderationItem_as_dyn_array_ReceivedItem(
                    srcConsiderationPointer,
                    dstHead.offset(tailOffset)
                );
            tailOffset += considerationSize;
        }

        unchecked {
            // Write offset to context
            dstHead.offset(ratifyOrder_context_head_offset).write(tailOffset);
            // Encode context
            uint256 contextSize = abi_encode_bytes(
                toMemoryPointer(context),
                dstHead.offset(tailOffset)
            );
            tailOffset += contextSize;
        }

        unchecked {
            dstHead.offset(ratifyOrder_orderHashes_head_offset).write(
                tailOffset
            );
            uint256 orderHashesSize = abi_encode_dyn_array_fixed_member(
                toMemoryPointer(orderHashes),
                dstHead.offset(tailOffset),
                32
            );
            tailOffset += orderHashesSize;

            size = 4 + tailOffset;
        }
    }

    function abi_encode_validateOrder(
        bytes32 orderHash,
        OrderParameters memory orderParameters,
        bytes memory extraData,
        bytes32[] memory orderHashes
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // @todo Dedupe some of this
        // Get free memory pointer to write calldata to
        // This isn't allocated as it is only used for a single function call
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata
        dst.write(validateOrder_selector);
        dst = dst.offset(validateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data
        MemoryPointer dstHead = dst.offset(validateOrder_head_offset);
        // Write offset to zoneParameters to start of calldata
        dstHead.write(validateOrder_zoneParameters_offset);
        // Reuse `dstHead` as pointer to zoneParameters
        dstHead = dstHead.offset(validateOrder_zoneParameters_offset);

        // Write orderHash and fulfiller to zoneParameters
        dstHead.writeBytes(orderHash);
        dstHead.offset(ZoneParameters_fulfiller_offset).write(msg.sender);

        MemoryPointer src = orderParameters.toMemoryPointer();

        // Copy offerer, startTime, endTime and zoneHash to zoneParameters
        dstHead.offset(ZoneParameters_offerer_offset).write(src.readUint256());
        dstHead.offset(ZoneParameters_startTime_offset).write(
            src.offset(OrderParameters_startTime_offset).readUint256()
        );
        dstHead.offset(ZoneParameters_endTime_offset).write(
            src.offset(OrderParameters_endTime_offset).readUint256()
        );
        dstHead.offset(ZoneParameters_zoneHash_offset).write(
            src.offset(OrderParameters_zoneHash_offset).readUint256()
        );

        uint256 tailOffset = ZoneParameters_base_tail_offset;

        unchecked {
            // Write offset to `offer`
            dstHead.offset(ZoneParameters_offer_head_offset).write(tailOffset);
            // Get pointer to orderParameters.offer.length
            MemoryPointer srcOfferPointer = src
                .offset(OrderParameters_offer_head_offset)
                .readMemoryPointer();
            // Encode the offer array as SpentItem[]
            uint256 offerSize = abi_encode_as_dyn_array_SpentItem(
                srcOfferPointer,
                dstHead.offset(tailOffset)
            );
            tailOffset += offerSize;
        }

        unchecked {
            // Write offset to consideration
            dstHead.offset(ZoneParameters_consideration_head_offset).write(
                tailOffset
            );
            MemoryPointer srcConsiderationPointer = src
                .offset(OrderParameters_consideration_head_offset)
                .readMemoryPointer();
            // Encode the consideration array as ReceivedItem[]
            uint256 considerationSize = abi_encode_dyn_array_ConsiderationItem_as_dyn_array_ReceivedItem(
                    srcConsiderationPointer,
                    dstHead.offset(tailOffset)
                );
            tailOffset += considerationSize;
        }

        unchecked {
            // Write offset to extraData
            dstHead.offset(ZoneParameters_extraData_head_offset).write(
                tailOffset
            );
            // Copy extraData
            uint256 extraDataSize = abi_encode_bytes(
                toMemoryPointer(extraData),
                dstHead.offset(tailOffset)
            );
            tailOffset += extraDataSize;
        }
        unchecked {
            // Write offset to orderHashes
            dstHead.offset(ZoneParameters_orderHashes_head_offset).write(
                tailOffset
            );
            // Encode the consideration array as ReceivedItem[]
            uint256 orderHashesSize = abi_encode_dyn_array_fixed_member(
                toMemoryPointer(orderHashes),
                dstHead.offset(tailOffset),
                32
            );
            tailOffset += orderHashesSize;

            size = 0x24 + tailOffset;
        }
    }

    function abi_encode_validateOrder(
        bytes32 orderHash,
        BasicOrderParameters calldata parameters
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // @todo Dedupe some of this
        // Get free memory pointer to write calldata to
        // This isn't allocated as it is only used for a single function call
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata
        dst.write(validateOrder_selector);
        dst = dst.offset(validateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data
        MemoryPointer dstHead = dst.offset(validateOrder_head_offset);
        // Write offset to zoneParameters to start of calldata
        dstHead.write(validateOrder_zoneParameters_offset);
        // Reuse `dstHead` as pointer to zoneParameters
        dstHead = dstHead.offset(validateOrder_zoneParameters_offset);

        // Write offerer, orderHash and fulfiller to zoneParameters
        dstHead.writeBytes(orderHash);
        dstHead.offset(ZoneParameters_offerer_offset).write(parameters.offerer);
        dstHead.offset(ZoneParameters_fulfiller_offset).write(msg.sender);

        // Copy startTime, endTime and zoneHash to zoneParameters
        CalldataPointer.wrap(BasicOrder_startTime_cdPtr).copy(
            dstHead.offset(ZoneParameters_startTime_offset),
            0x60
        );

        uint256 tailOffset = ZoneParameters_base_tail_offset;

        unchecked {
            uint256 additionalRecipientsLength = CalldataPointer
                .wrap(BasicOrder_additionalRecipients_length_cdPtr)
                .readUint256();
            // Copy offer & consideration from event data into target callData.
            // 2 words (lengths) + 4 (offer data) + 5 (consideration 1) + 5 * ar
            uint256 offerAndConsiderationSize = OrderFulfilled_baseDataSize +
                (additionalRecipientsLength * ReceivedItem_size);
            dstHead.offset(ZoneParameters_offer_head_offset).write(tailOffset);
            // Consideration is 5 words after offer
            dstHead.offset(ZoneParameters_consideration_head_offset).write(
                tailOffset + 0xa0
            );
            uint256 offerDataOffset = OrderFulfilled_offer_length_baseOffset +
                additionalRecipientsLength *
                OneWord;
            MemoryPointer.wrap(offerDataOffset).copy(
                dstHead.offset(tailOffset),
                offerAndConsiderationSize
            );
            tailOffset += offerAndConsiderationSize;
        }
        unchecked {
            // Write empty bytes for extraData
            dstHead.offset(ZoneParameters_extraData_head_offset).write(
                tailOffset
            );
            dstHead.offset(tailOffset).write(0);
            tailOffset += 32;
        }

        unchecked {
            // Write offset to orderHashes
            dstHead.offset(ZoneParameters_orderHashes_head_offset).write(
                tailOffset
            );
            dstHead.offset(tailOffset).write(1);
            dstHead.offset(tailOffset + 32).writeBytes(orderHash);
            tailOffset += 64;

            size = 0x24 + tailOffset;
        }
    }

    function abi_encode_dyn_array_fixed_member(
        MemoryPointer srcLength,
        MemoryPointer dstLength,
        uint256 calldataStride
    ) internal view returns (uint256 size) {
        uint256 length = srcLength.readUint256();
        dstLength.write(length);
        unchecked {
            uint256 headSize = length * 32;
            uint256 tailSize = calldataStride * length;
            srcLength.next().offset(headSize).copy(dstLength.next(), tailSize);
            size = tailSize + 32;
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

    function abi_encode_dyn_array_ConsiderationItem_as_dyn_array_ReceivedItem(
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
            // Position in memory to write next item for calldata. Since ReceivedItem
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
                mstore(
                    add(cdPtrData, ReceivedItem_recipient_offset),
                    mload(add(mPtrTail, Common_endAmount_offset))
                )

                mPtrHead := add(mPtrHead, 0x20)
                cdPtrData := add(cdPtrData, ReceivedItem_size)
            }
            size := add(0x20, mul(length, ReceivedItem_size))
        }
    }
}
