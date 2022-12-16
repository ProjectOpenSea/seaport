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
    /**
     * @dev Takes a bytes array and casts it to a memory pointer.
     *
     * @param obj A bytes array in memory.
     *
     * @return ptr A memory pointer to the start of the bytes array in memory.
     */
    function toMemoryPointer(
        bytes memory obj
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := obj
        }
    }

    /**
     * @dev Takes an array of bytes32 types and casts it to a memory pointer.
     *
     * @param obj An array of bytes32 types in memory.
     *
     * @return ptr A memory pointer to the start of the array of bytes32 types
     *             in memory.
     */
    function toMemoryPointer(
        bytes32[] memory obj
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := obj
        }
    }

    /**
     * @dev Takes a bytes array in memory and copies it to a new location in
     *      memory.
     *
     * @param src A memory pointer referencing the bytes array to be copied (and
     *            pointing to the length of the bytes array).
     * @param src A memory pointer referencing the location in memory to copy
     *            the bytes array to (and pointing to the length of the copied
     *            bytes array).
     *
     * @return size The size of the bytes array.
     */
    function _encodeBytes(
        MemoryPointer src,
        MemoryPointer dst
    ) internal view returns (uint256 size) {
        unchecked {
            // Mask the length of the bytes array to protect against overflow
            // and round up to the nearest word.
            size =
                ((src.readUint256() & OffsetOrLengthMask) + AlmostTwoWords) &
                OnlyFullWordMask;

            // Copy the bytes array to the new memory location.
            src.copy(dst, size);
        }
    }

    /**
     * @dev Takes an OrderParameters struct and a context bytes array in memory
     *      and encodes it as `generateOrder` calldata.
     *
     * @param orderParameters The OrderParameters struct used to construct the
     *                        encoded `generateOrder` calldata.
     * @param context         The context bytes array used to construct the
     *                        encoded `generateOrder` calldata.
     *
     * @return dst  A memory pointer referencing the encoded `generateOrder`
     *              calldata.
     * @return size The size of the bytes array.
     */
    function _encodeGenerateOrder(
        OrderParameters memory orderParameters,
        bytes memory context
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // Get the memory pointer for the OrderParameters struct.
        MemoryPointer src = orderParameters.toMemoryPointer();

        // Get free memory pointer to write calldata to.
        dst = getFreeMemoryPointer();

        // Write generateOrder selector and get pointer to start of calldata.
        dst.write(generateOrder_selector);
        dst = dst.offset(generateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data.
        MemoryPointer dstHead = dst.offset(generateOrder_head_offset);

        // Write `fulfiller` to calldata.
        dstHead.write(msg.sender);

        // Initialize tail offset, used to populate the minimumReceived array.
        uint256 tailOffset = generateOrder_base_tail_offset;

        // Write offset to minimumReceived.
        dstHead.offset(generateOrder_minimumReceived_head_offset).write(
            tailOffset
        );

        // Get memory pointer to `orderParameters.offer.length`.
        MemoryPointer srcOfferPointer = src
            .offset(OrderParameters_offer_head_offset)
            .readMemoryPointer();

        // Encode the offer array as a `SpentItem[]`.
        uint256 minimumReceivedSize = abi_encode_as_dyn_array_SpentItem(
            srcOfferPointer,
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate maximumSpent array.
            tailOffset += minimumReceivedSize;
        }

        // Write offset to maximumSpent.
        dstHead.offset(generateOrder_maximumSpent_head_offset).write(
            tailOffset
        );

        // Get memory pointer to `orderParameters.consideration.length`.
        MemoryPointer srcConsiderationPointer = src
            .offset(OrderParameters_consideration_head_offset)
            .readMemoryPointer();

        // Encode the consideration array as a `SpentItem[]`.
        uint256 maximumSpentSize = abi_encode_as_dyn_array_SpentItem(
            srcConsiderationPointer,
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate context array.
            tailOffset += maximumSpentSize;
        }

        // Write offset to context.
        dstHead.offset(generateOrder_context_head_offset).write(tailOffset);

        // Get memory pointer to context.
        MemoryPointer srcContext = toMemoryPointer(context);

        // Encode context as a bytes array.
        uint256 contextSize = _encodeBytes(
            srcContext,
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment the tail offset, now used to determine final size.
            tailOffset += contextSize;

            // Derive the final size by including the selector.
            size = 4 + tailOffset;
        }
    }

    /**
     * @dev Takes an order hash (e.g. offerer + contract nonce in the case of
     *      contract orders), OrderParameters struct, context bytes array, and
     *      array of order hashes for each order included as part of the current
     *      fulfillment and encodes it as `ratifyOrder` calldata.
     *
     * @param orderHash       The order hash (e.g. offerer + contract nonce).
     * @param orderParameters The OrderParameters struct used to construct the
     *                        encoded `ratifyOrder` calldata.
     * @param context         The context bytes array used to construct the
     *                        encoded `ratifyOrder` calldata.
     * @param orderHashes     An array of bytes32 values representing the order
     *                        hashes of all orders included as part of the
     *                        current fulfillment.
     *
     * @return dst  A memory pointer referencing the encoded `ratifyOrder`
     *              calldata.
     * @return size The size of the bytes array.
     */
    function _encodeRatifyOrder(
        bytes32 orderHash, // e.g. offerer + contract nonce
        OrderParameters memory orderParameters,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // Get free memory pointer to write calldata to. This isn't allocated as
        // it is only used for a single function call.
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata.
        dst.write(ratifyOrder_selector);
        dst = dst.offset(ratifyOrder_selector_offset);

        // Get pointer to the beginning of the encoded data.
        MemoryPointer dstHead = dst.offset(ratifyOrder_head_offset);

        // Write contractNonce to calldata.
        dstHead.offset(ratifyOrder_contractNonce_offset).write(
            uint96(uint256(orderHash))
        );

        // Initialize tail offset, used to populate the offer array.
        uint256 tailOffset = ratifyOrder_base_tail_offset;
        MemoryPointer src = orderParameters.toMemoryPointer();

        // Write offset to `offer`.
        dstHead.write(tailOffset);

        // Get memory pointer to `orderParameters.offer.length`.
        MemoryPointer srcOfferPointer = src
            .offset(OrderParameters_offer_head_offset)
            .readMemoryPointer();

        // Encode the offer array as a `SpentItem[]`.
        uint256 offerSize = abi_encode_as_dyn_array_SpentItem(
            srcOfferPointer,
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate consideration array.
            tailOffset += offerSize;
        }

        // Write offset to consideration.
        dstHead.offset(ratifyOrder_consideration_head_offset).write(tailOffset);

        // Get pointer to `orderParameters.consideration.length`.
        MemoryPointer srcConsiderationPointer = src
            .offset(OrderParameters_consideration_head_offset)
            .readMemoryPointer();

        // Encode the consideration array as a `ReceivedItem[]`.
        uint256 considerationSize = abi_encode_dyn_array_ConsiderationItem_as_dyn_array_ReceivedItem(
                srcConsiderationPointer,
                dstHead.offset(tailOffset)
            );

        unchecked {
            // Increment tail offset, now used to populate context array.
            tailOffset += considerationSize;
        }

        // Write offset to context.
        dstHead.offset(ratifyOrder_context_head_offset).write(tailOffset);

        // Encode context.
        uint256 contextSize = _encodeBytes(
            toMemoryPointer(context),
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate orderHashes array.
            tailOffset += contextSize;
        }

        // Write offset to orderHashes.
        dstHead.offset(ratifyOrder_orderHashes_head_offset).write(tailOffset);

        // Encode orderHashes.
        uint256 orderHashesSize = abi_encode_dyn_array_fixed_member(
            toMemoryPointer(orderHashes),
            dstHead.offset(tailOffset),
            32
        );

        unchecked {
            // Increment the tail offset, now used to determine final size.
            tailOffset += orderHashesSize;

            // Derive the final size by including the selector.
            size = 4 + tailOffset;
        }
    }

    /**
     * @dev Takes an order hash, OrderParameters struct, extraData bytes array,
     *      and array of order hashes for each order included as part of the
     *      current fulfillment and encodes it as `validateOrder` calldata.
     *
     * @param orderHash       The order hash.
     * @param orderParameters The OrderParameters struct used to construct the
     *                        encoded `validateOrder` calldata.
     * @param extraData       The extraData bytes array used to construct the
     *                        encoded `validateOrder` calldata.
     * @param orderHashes     An array of bytes32 values representing the order
     *                        hashes of all orders included as part of the
     *                        current fulfillment.
     *
     * @return dst  A memory pointer referencing the encoded `validateOrder`
     *              calldata.
     * @return size The size of the bytes array.
     */
    function _encodeValidateOrder(
        bytes32 orderHash,
        OrderParameters memory orderParameters,
        bytes memory extraData,
        bytes32[] memory orderHashes
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // Get free memory pointer to write calldata to. This isn't allocated as
        // it is only used for a single function call.
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata.
        dst.write(validateOrder_selector);
        dst = dst.offset(validateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data.
        MemoryPointer dstHead = dst.offset(validateOrder_head_offset);

        // Write offset to zoneParameters to start of calldata.
        dstHead.write(validateOrder_zoneParameters_offset);

        // Reuse `dstHead` as pointer to zoneParameters.
        dstHead = dstHead.offset(validateOrder_zoneParameters_offset);

        // Write orderHash and fulfiller to zoneParameters.
        dstHead.writeBytes(orderHash);
        dstHead.offset(ZoneParameters_fulfiller_offset).write(msg.sender);

        // Get the memory pointer to the order paramaters struct.
        MemoryPointer src = orderParameters.toMemoryPointer();

        // Copy offerer, startTime, endTime and zoneHash to zoneParameters.
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

        // Initialize tail offset, used to populate the offer array.
        uint256 tailOffset = ZoneParameters_base_tail_offset;

        // Write offset to `offer`.
        dstHead.offset(ZoneParameters_offer_head_offset).write(tailOffset);

        // Get pointer to `orderParameters.offer.length`.
        MemoryPointer srcOfferPointer = src
            .offset(OrderParameters_offer_head_offset)
            .readMemoryPointer();

        // Encode the offer array as a `SpentItem[]`.
        uint256 offerSize = abi_encode_as_dyn_array_SpentItem(
            srcOfferPointer,
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate consideration array.
            tailOffset += offerSize;
        }

        // Write offset to consideration.
        dstHead.offset(ZoneParameters_consideration_head_offset).write(
            tailOffset
        );

        // Get pointer to `orderParameters.consideration.length`.
        MemoryPointer srcConsiderationPointer = src
            .offset(OrderParameters_consideration_head_offset)
            .readMemoryPointer();

        // Encode the consideration array as a `ReceivedItem[]`.
        uint256 considerationSize = abi_encode_dyn_array_ConsiderationItem_as_dyn_array_ReceivedItem(
                srcConsiderationPointer,
                dstHead.offset(tailOffset)
            );

        unchecked {
            // Increment tail offset, now used to populate extraData array.
            tailOffset += considerationSize;
        }

        // Write offset to extraData.
        dstHead.offset(ZoneParameters_extraData_head_offset).write(tailOffset);
        // Copy extraData.
        uint256 extraDataSize = _encodeBytes(
            toMemoryPointer(extraData),
            dstHead.offset(tailOffset)
        );

        unchecked {
            // Increment tail offset, now used to populate orderHashes array.
            tailOffset += extraDataSize;
        }

        // Write offset to orderHashes.
        dstHead.offset(ZoneParameters_orderHashes_head_offset).write(
            tailOffset
        );

        // Encode the order hashes array.
        uint256 orderHashesSize = abi_encode_dyn_array_fixed_member(
            toMemoryPointer(orderHashes),
            dstHead.offset(tailOffset),
            32
        );

        unchecked {
            // Increment the tail offset, now used to determine final size.
            tailOffset += orderHashesSize;

            // Derive final size including selector and ZoneParameters pointer.
            size = 0x24 + tailOffset;
        }
    }

    /**
     * @dev Takes an order hash and BasicOrderParameters struct (from calldata)
     *      and encodes it as `validateOrder` calldata.
     *
     * @param orderHash  The order hash.
     * @param parameters The BasicOrderParameters struct used to construct the
     *                   encoded `validateOrder` calldata.
     *
     * @return dst  A memory pointer referencing the encoded `validateOrder`
     *              calldata.
     * @return size The size of the bytes array.
     */
    function _encodeValidateBasicOrder(
        bytes32 orderHash,
        BasicOrderParameters calldata parameters
    ) internal view returns (MemoryPointer dst, uint256 size) {
        // Get free memory pointer to write calldata to. This isn't allocated as
        // it is only used for a single function call.
        dst = getFreeMemoryPointer();

        // Write ratifyOrder selector and get pointer to start of calldata.
        dst.write(validateOrder_selector);
        dst = dst.offset(validateOrder_selector_offset);

        // Get pointer to the beginning of the encoded data.
        MemoryPointer dstHead = dst.offset(validateOrder_head_offset);

        // Write offset to zoneParameters to start of calldata.
        dstHead.write(validateOrder_zoneParameters_offset);

        // Reuse `dstHead` as pointer to zoneParameters.
        dstHead = dstHead.offset(validateOrder_zoneParameters_offset);

        // Write offerer, orderHash and fulfiller to zoneParameters.
        dstHead.writeBytes(orderHash);
        dstHead.offset(ZoneParameters_offerer_offset).write(parameters.offerer);
        dstHead.offset(ZoneParameters_fulfiller_offset).write(msg.sender);

        // Copy startTime, endTime and zoneHash to zoneParameters.
        CalldataPointer.wrap(BasicOrder_startTime_cdPtr).copy(
            dstHead.offset(ZoneParameters_startTime_offset),
            0x60
        );

        // Initialize tail offset, used for the offer + consideration arrays.
        uint256 tailOffset = ZoneParameters_base_tail_offset;

        // Write offset to offer from event data into target calldata.
        dstHead.offset(ZoneParameters_offer_head_offset).write(tailOffset);

        // Write consideration offset next (located 5 words after offer).
        dstHead.offset(ZoneParameters_consideration_head_offset).write(
            tailOffset + 0xa0
        );

        // Retrieve the offset to the length of additional recipients.
        uint256 additionalRecipientsLength = CalldataPointer
            .wrap(BasicOrder_additionalRecipients_length_cdPtr)
            .readUint256();

        unchecked {
            // Derive offset to event data using base offset & total recipients.
            uint256 offerDataOffset = OrderFulfilled_offer_length_baseOffset +
                additionalRecipientsLength *
                OneWord;

            // Derive size of offer and consideration data.
            // 2 words (lengths) + 4 (offer data) + 5 (consideration 1) + 5 * ar
            uint256 offerAndConsiderationSize = OrderFulfilled_baseDataSize +
                (additionalRecipientsLength * ReceivedItem_size);

            // Copy offer and consideration data from event data to calldata.
            MemoryPointer.wrap(offerDataOffset).copy(
                dstHead.offset(tailOffset),
                offerAndConsiderationSize
            );

            // Increment tail offset, now used to populate extraData array.
            tailOffset += offerAndConsiderationSize;
        }

        // Write empty bytes for extraData.
        dstHead.offset(ZoneParameters_extraData_head_offset).write(tailOffset);
        dstHead.offset(tailOffset).write(0);

        unchecked {
            // Increment tail offset, now used to populate orderHashes array.
            tailOffset += 32;
        }

        // Write offset to orderHashes.
        dstHead.offset(ZoneParameters_orderHashes_head_offset).write(
            tailOffset
        );

        // Write length = 1 to the orderHashes array.
        dstHead.offset(tailOffset).write(1);

        unchecked {
            // Write the single order hash to the orderHashes array.
            dstHead.offset(tailOffset + 32).writeBytes(orderHash);

            // Final size: selector, ZoneParameters pointer, orderHashes & tail.
            size = 0x64 + tailOffset;
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
    ) internal view returns (uint256 size) {
        unchecked {
            uint256 length = srcLength.readUint256();
            dstLength.write(length);

            // Get pointer to first item's head position in the array, containing
            // the item's pointer in memory. The head pointer will be incremented
            // until it reaches the tail position (start of the array data).
            MemoryPointer srcHead = srcLength.next();
            MemoryPointer srcHeadEnd = srcHead.offset(length * OneWord);
            // Position in memory to write next item for calldata. Since ReceivedItem
            // has a fixed length, the array elements do not contain offsets in
            // calldata, they are concatenated together after the array length.
            MemoryPointer dstHead = dstLength.next();
            while (srcHead.lt(srcHeadEnd)) {
                MemoryPointer srcTail = srcHead.pptr();
                srcTail.copy(dstHead, ReceivedItem_size);
                srcHead = srcHead.next();
                dstHead = dstHead.offset(ReceivedItem_size);
            }
            size = 32 + (length * ReceivedItem_size);
        }
    }
}
