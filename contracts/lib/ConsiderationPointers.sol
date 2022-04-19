// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// Common Offsets
// Offsets to fields within -Item structs

uint256 constant CommonItemTypeOffset = 0x20;
uint256 constant CommonTokenOffset = 0x20;
uint256 constant CommonIdentifierOffset = 0x20;
uint256 constant CommonAmountOffset = 0x20;

uint256 constant OneWord = 0x20;
uint256 constant TwoWords = 0x40;
uint256 constant ThreeWords = 0x60;

uint256 constant DefaultFreeMemoryPointer = 0x80;

uint256 constant BasicOrder_considerationToken_calldataPointer = 0x24;
uint256 constant BasicOrder_considerationIdentifier_calldataPointer = 0x44;
uint256 constant BasicOrder_considerationAmount_calldataPointer = 0x64;

uint256 constant BasicOrder_offerer_calldataPointer = 0x84;
uint256 constant BasicOrder_offerToken_calldataPointer = 0xc4;
uint256 constant BasicOrder_endAmount_calldataPointer = 0x104;
uint256 constant BasicOrder_totalOriginalAdditionalRecipients_calldataPointer = 0x204;

uint256 constant BasicOrder_considerationHashesArray_memoryPointer = 0x160;

uint256 constant ConsiderationItemSize = 0xe0;

/*
 *  EIP712 data for ConsiderationItem
 *   - 0x80: ConsiderationItem EIP-712 typehash (constant)
 *   - 0xa0: itemType
 *   - 0xc0: token
 *   - 0xe0: identifier
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 *   - 0x140: recipient
 */
uint256 constant BasicOrder_considerationItem_typeHash_memoryPointer = DefaultFreeMemoryPointer;
uint256 constant BasicOrder_considerationItem_itemType_memoryPointer = 0xa0;
uint256 constant BasicOrder_considerationItem_token_memoryPointer = 0xc0;
uint256 constant BasicOrder_considerationItem_identifier_memoryPointer = 0xe0;
uint256 constant BasicOrder_considerationItem_startAmount_memoryPointer = 0x100;
uint256 constant BasicOrder_considerationItem_endAmount_memoryPointer = 0x120;
uint256 constant BasicOrder_considerationItem_recipient_memoryPointer = 0x140;

uint256 constant BasicOrder_token_calldataPointer = 0xc0;

/*
 * EIP712 data for OfferItem
 *   - 0x80:  OfferItem EIP-712 typehash (constant)
 *   - 0xa0:  itemType
 *   - 0xc0:  token
 *   - 0xe0:  identifier (reused for offeredItemsHash)
 *   - 0x100: startAmount
 *   - 0x120: endAmount
 */
uint256 constant BasicOrder_offerItem_typeHash_memoryPointer = DefaultFreeMemoryPointer;
uint256 constant BasicOrder_offerItem_itemType_memoryPointer = 0xa0;
uint256 constant BasicOrder_offerItem_token_memoryPointer = 0xc0;
uint256 constant BasicOrder_offerItem_identifier_memoryPointer = 0xe0;
uint256 constant BasicOrder_offerItem_startAmount_memoryPointer = 0x100;
uint256 constant BasicOrder_offerItem_endAmount_memoryPointer = 0x120;

// BasicOrder

uint256 constant BasicOrder_offerItem_token_calldataPointer = 0xc4;
uint256 constant BasicOrder_offerItem_endAmount_calldataPointer = 0x104;

uint256 constant BasicOrder_additionalRecipients_length_calldataPointer = 0x264;
uint256 constant BasicOrder_additionalRecipients_data_calldataPointer = 0x284;
