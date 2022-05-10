// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/*
 * -------------------------- Disambiguation & Other Notes ---------------------
 *    - The term "head" is used as it is in the documentation for ABI encoding,
 *      but only in reference to dynamic types, i.e. it always refers to the
 *      offset or pointer to the body of a dynamic type. In calldata, the head
 *      is always an offset (relative to the parent object), while in memory,
 *      the head is always the pointer to the body. More information found here:
 *      https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#argument-encoding
 *        - Note that the length of an array is separate from and precedes the
 *          head of the array.
 *
 *    - The term "body" is used in place of the term "head" used in the ABI
 *      documentation. It refers to the start of the data for a dynamic type,
 *      e.g. the first word of a struct or the first word of the first element
 *      in an array.
 *
 *    - The term "pointer" is used to describe the absolute position of a value
 *      and never an offset relative to another value.
 *        - The suffix "_ptr" refers to a memory pointer.
 *        - The suffix "_cdPtr" refers to a calldata pointer.
 *
 *    - The term "offset" is used to describe the position of a value relative
 *      to some parent value. For example, OrderParameters_conduit_offset is the
 *      offset to the "conduit" value in the OrderParameters struct relative to
 *      the start of the body.
 *        - Note: Offsets are used to derive pointers.
 *
 *    - Some structs have pointers defined for all of their fields in this file.
 *      Lines which are commented out are fields that are not used in the
 *      codebase but have been left in for readability.
 */

// Common Offsets
// Offsets for identically positioned fields shared by:
// OfferItem, ConsiderationItem, SpentItem, ReceivedItem

uint256 constant Common_token_offset = 0x20;
uint256 constant Common_identifier_offset = 0x40;
uint256 constant Common_amount_offset = 0x60;

uint256 constant ReceivedItem_size = 0xa0;
uint256 constant ReceivedItem_amount_offset = 0x60;
uint256 constant ReceivedItem_recipient_offset = 0x80;

uint256 constant ConsiderationItem_recipient_offset = 0xa0;
// Store the same constant in an abbreviated format for a line length fix.
uint256 constant ConsiderItem_recipient_offset = 0xa0;

uint256 constant Execution_offerer_offset = 0x20;
uint256 constant Execution_conduit_offset = 0x40;

uint256 constant OrderParameters_offer_head_offset = 0x40;
uint256 constant OrderParameters_consideration_head_offset = 0x60;
uint256 constant OrderParameters_conduit_offset = 0x120;

uint256 constant Fulfillment_itemIndex_offset = 0x20;

uint256 constant AdvancedOrder_numerator_offset = 0x20;

uint256 constant OneWord = 0x20;
uint256 constant TwoWords = 0x40;
uint256 constant ThreeWords = 0x60;

uint256 constant FreeMemoryPointerSlot = 0x40;
uint256 constant ZeroSlot = 0x60;
uint256 constant DefaultFreeMemoryPointer = 0x80;

uint256 constant BasicOrder_endAmount_cdPtr = 0x104;

uint256 constant BasicOrder_considerationHashesArray_ptr = 0x160;

uint256 constant EIP712_Order_size = 0x180;
uint256 constant EIP712_OfferItem_size = 0xc0;
uint256 constant EIP712_ConsiderationItem_size = 0xe0;
uint256 constant AdditionalRecipients_size = 0x40;

uint256 constant receivedItemsHash_ptr = 0x60;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  data for OrderFulfilled
 *
 *   event OrderFulfilled(
 *     bytes32 orderHash,
 *     address indexed offerer,
 *     address indexed zone,
 *     address fulfiller,
 *     SpentItem[] offer,
 *       > (itemType, token, id, amount)
 *     ReceivedItem[] consideration
 *       > (itemType, token, id, amount, recipient)
 *   )
 *
 *  - 0x00: orderHash
 *  - 0x20: fulfiller
 *  - 0x40: offer offset (0x80)
 *  - 0x60: consideration offset (0x120)
 *  - 0x80: offer.length (1)
 *  - 0xa0: offerItemType
 *  - 0xc0: offerToken
 *  - 0xe0: offerIdentifier
 *  - 0x100: offerAmount
 *  - 0x120: consideration.length (1 + additionalRecipients.length)
 *  - 0x140: considerationItemType
 *  - 0x160: considerationToken
 *  - 0x180: considerationIdentifier
 *  - 0x1a0: considerationAmount
 *  - 0x1c0: considerationRecipient
 *  - ...
 */

// Minimum length of the OrderFulfilled event data.
// Must be added to the size of the ReceivedItem array for additionalRecipients
// (0xa0 * additionalRecipients.length) to calculate full size of the buffer.
uint256 constant OrderFulfilled_baseSize = 0x1e0;
uint256 constant OrderFulfilled_selector = (
    0x9d9af8e38d66c62e2c12f0225249fd9d721c54b83f48d9352c97c6cacdcb6f31
);

// Minimum offset in memory to OrderFulfilled event data.
// Must be added to the size of the EIP712 hash array for additionalRecipients
// (32 * additionalRecipients.length) to calculate the pointer to event data.
uint256 constant OrderFulfilled_baseOffset = 0x180;
uint256 constant OrderFulfilled_consideration_length_baseOffset = 0x2a0;
uint256 constant OrderFulfilled_offer_length_baseOffset = 0x200;

// uint256 constant OrderFulfilled_orderHash_offset = 0x00;
uint256 constant OrderFulfilled_fulfiller_offset = 0x20;
uint256 constant OrderFulfilled_offer_head_offset = 0x40;
uint256 constant OrderFulfilled_offer_body_offset = 0x80;
uint256 constant OrderFulfilled_consideration_head_offset = 0x60;
uint256 constant OrderFulfilled_consideration_body_offset = 0x120;

// BasicOrderParameters
uint256 constant BasicOrder_considerationToken_cdPtr = 0x24;
// uint256 constant BasicOrder_considerationIdentifier_cdPtr = 0x44;
uint256 constant BasicOrder_considerationAmount_cdPtr = 0x64;
uint256 constant BasicOrder_offerer_cdPtr = 0x84;
uint256 constant BasicOrder_zone_cdPtr = 0xa4;
uint256 constant BasicOrder_offerToken_cdPtr = 0xc4;
// uint256 constant BasicOrder_offerIdentifier_cdPtr = 0xe4;
uint256 constant BasicOrder_offerAmount_cdPtr = 0x104;
// uint256 constant BasicOrder_basicOrderType_cdPtr = 0x124;
uint256 constant BasicOrder_startTime_cdPtr = 0x144;
// uint256 constant BasicOrder_endTime_cdPtr = 0x164;
// uint256 constant BasicOrder_zoneHash_cdPtr = 0x184;
// uint256 constant BasicOrder_salt_cdPtr = 0x1a4;
// uint256 constant BasicOrder_offererConduit_cdPtr = 0x1c4;
// uint256 constant BasicOrder_fulfillerConduit_cdPtr = 0x1e4;
uint256 constant BasicOrder_totalOriginalAdditionalRecipients_cdPtr = 0x204;
// uint256 constant BasicOrder_additionalRecipients_head_cdPtr = 0x224;
// uint256 constant BasicOrder_signature_cdPtr = 0x244;
uint256 constant BasicOrder_additionalRecipients_length_cdPtr = 0x264;
uint256 constant BasicOrder_additionalRecipients_data_cdPtr = 0x284;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for ConsiderationItem
 *   - 0x80: ConsiderationItem EIP-712 typehash (constant)
 *   - 0xa0: itemType
 *   - 0xc0: token
 *   - 0xe0: identifier
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 *   - 0x140: recipient
 */
uint256 constant BasicOrder_considerationItem_typeHash_ptr = 0x80; // memoryPtr
uint256 constant BasicOrder_considerationItem_itemType_ptr = 0xa0;
uint256 constant BasicOrder_considerationItem_token_ptr = 0xc0;
uint256 constant BasicOrder_considerationItem_identifier_ptr = 0xe0;
uint256 constant BasicOrder_considerationItem_startAmount_ptr = 0x100;
uint256 constant BasicOrder_considerationItem_endAmount_ptr = 0x120;
// uint256 constant BasicOrder_considerationItem_recipient_ptr = 0x140;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for OfferItem
 *   - 0x80:  OfferItem EIP-712 typehash (constant)
 *   - 0xa0:  itemType
 *   - 0xc0:  token
 *   - 0xe0:  identifier (reused for offeredItemsHash)
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 */
uint256 constant BasicOrder_offerItem_typeHash_ptr = DefaultFreeMemoryPointer;
uint256 constant BasicOrder_offerItem_itemType_ptr = 0xa0;
uint256 constant BasicOrder_offerItem_token_ptr = 0xc0;
// uint256 constant BasicOrder_offerItem_identifier_ptr = 0xe0;
// uint256 constant BasicOrder_offerItem_startAmount_ptr = 0x100;
uint256 constant BasicOrder_offerItem_endAmount_ptr = 0x120;

/*
 *  Memory layout in _prepareBasicFulfillmentFromCalldata of
 *  EIP712 data for Order
 *   - 0x80:   Order EIP-712 typehash (constant)
 *   - 0xa0:   orderParameters.offerer
 *   - 0xc0:   orderParameters.zone
 *   - 0xe0:   keccak256(abi.encodePacked(offerHashes))
 *   - 0x100:  keccak256(abi.encodePacked(considerationHashes))
 *   - 0x120:  orderType
 *   - 0x140:  startTime
 *   - 0x160:  endTime
 *   - 0x180:  zoneHash
 *   - 0x1a0:  salt
 *   - 0x1c0:  conduit
 *   - 0x1e0:  _nonces[orderParameters.offerer] (from storage)
 */
uint256 constant BasicOrder_order_typeHash_ptr = 0x80;
uint256 constant BasicOrder_order_offerer_ptr = 0xa0;
// uint256 constant BasicOrder_order_zone_ptr = 0xc0;
uint256 constant BasicOrder_order_offerHashes_ptr = 0xe0;
uint256 constant BasicOrder_order_considerationHashes_ptr = 0x100;
uint256 constant BasicOrder_order_orderType_ptr = 0x120;
uint256 constant BasicOrder_order_startTime_ptr = 0x140;
// uint256 constant BasicOrder_order_endTime_ptr = 0x160;
// uint256 constant BasicOrder_order_zoneHash_ptr = 0x180;
// uint256 constant BasicOrder_order_salt_ptr = 0x1a0;
// uint256 constant BasicOrder_order_conduit_ptr = 0x1c0;
uint256 constant BasicOrder_order_nonce_ptr = 0x1e0;

// Signature-related
bytes32 constant EIP2098_allButHighestBitMask = (
    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
);

// abi.encodeWithSignature("transferFrom(address,address,uint256)")
uint256 constant ERC20_transferFrom_signature = (
    0x23b872dd00000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC20_transferFrom_sig_ptr = 0x0;
uint256 constant ERC20_transferFrom_from_ptr = 0x04;
uint256 constant ERC20_transferFrom_to_ptr = 0x24;
uint256 constant ERC20_transferFrom_amount_ptr = 0x44;
uint256 constant ERC20_transferFrom_length = 0x64; // 4 + 32 * 3 == 100

// abi.encodeWithSignature(
//     "safeTransferFrom(address,address,uint256,uint256,bytes"
// )
uint256 constant ERC1155_safeTransferFrom_signature = (
    0xf242432a00000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC1155_safeTransferFrom_sig_ptr = 0x0;
uint256 constant ERC1155_safeTransferFrom_from_ptr = 0x04;
uint256 constant ERC1155_safeTransferFrom_to_ptr = 0x24;
uint256 constant ERC1155_safeTransferFrom_id_ptr = 0x44;
uint256 constant ERC1155_safeTransferFrom_amount_ptr = 0x64;
uint256 constant ERC1155_safeTransferFrom_data_offset_ptr = 0x84;
uint256 constant ERC1155_safeTransferFrom_data_length_ptr = 0xa4;
uint256 constant ERC1155_safeTransferFrom_length = 0xc4; // 4 + 32 * 6 == 164
uint256 constant ERC1155_safeTransferFrom_data_length_offset = 0xa0;

uint256 constant ERC1155_safeBatchTransferFrom_signature = (
    0x2eb2c2d600000000000000000000000000000000000000000000000000000000
);

bytes4 constant ERC1155_safeBatchTransferFrom_selector = bytes4(
    bytes32(ERC1155_safeBatchTransferFrom_signature)
);

uint256 constant ERC721_transferFrom_signature = ERC20_transferFrom_signature;
uint256 constant ERC721_transferFrom_sig_ptr = 0x0;
uint256 constant ERC721_transferFrom_from_ptr = 0x04;
uint256 constant ERC721_transferFrom_to_ptr = 0x24;
uint256 constant ERC721_transferFrom_id_ptr = 0x44;
uint256 constant ERC721_transferFrom_length = 0x64; // 4 + 32 * 3 == 100

// abi.encodeWithSignature("NoContract(address)")
uint256 constant NoContract_error_signature = (
    0x5f15d67200000000000000000000000000000000000000000000000000000000
);
uint256 constant NoContract_error_sig_ptr = 0x0;
uint256 constant NoContract_error_token_ptr = 0x4;
uint256 constant NoContract_error_length = 0x24; // 4 + 32 == 36

// abi.encodeWithSignature(
//     "TokenTransferGenericFailure(address,address,address,uint256,uint256)"
// )
uint256 constant TokenTransferGenericFailure_error_signature = (
    0xf486bc8700000000000000000000000000000000000000000000000000000000
);
uint256 constant TokenTransferGenericFailure_error_sig_ptr = 0x0;
uint256 constant TokenTransferGenericFailure_error_token_ptr = 0x4;
uint256 constant TokenTransferGenericFailure_error_from_ptr = 0x24;
uint256 constant TokenTransferGenericFailure_error_to_ptr = 0x44;
uint256 constant TokenTransferGenericFailure_error_id_ptr = 0x64;
uint256 constant TokenTransferGenericFailure_error_amount_ptr = 0x84;

// 4 + 32 * 5 == 164
uint256 constant TokenTransferGenericFailure_error_length = 0xa4;

uint256 constant ERC1155BatchTransferGenericFailure_error_signature = (
    0xafc445e200000000000000000000000000000000000000000000000000000000
);

// abi.encodeWithSignature(
//     "BadReturnValueFromERC20OnTransfer(address,address,address,uint256)"
// )
uint256 constant BadReturnValueFromERC20OnTransfer_error_signature = (
    0x9889192300000000000000000000000000000000000000000000000000000000
);
uint256 constant BadReturnValueFromERC20OnTransfer_error_sig_ptr = 0x0;
uint256 constant BadReturnValueFromERC20OnTransfer_error_token_ptr = 0x4;
uint256 constant BadReturnValueFromERC20OnTransfer_error_from_ptr = 0x24;
uint256 constant BadReturnValueFromERC20OnTransfer_error_to_ptr = 0x44;
uint256 constant BadReturnValueFromERC20OnTransfer_error_amount_ptr = 0x64;

// 4 + 32 * 4 == 132
uint256 constant BadReturnValueFromERC20OnTransfer_error_length = 0x84;
