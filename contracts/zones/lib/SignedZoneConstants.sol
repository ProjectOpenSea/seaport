// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @dev ECDSA signature offsets.
uint256 constant ECDSA_MaxLength = 65;
uint256 constant ECDSA_signature_s_offset = 0x40;
uint256 constant ECDSA_signature_v_offset = 0x60;

/// @dev Helpers for memory offsets.
uint256 constant OneWord = 0x20;
uint256 constant TwoWords = 0x40;
uint256 constant ThreeWords = 0x60;
uint256 constant FourWords = 0x80;
uint256 constant FiveWords = 0xa0;
uint256 constant Signature_lower_v = 27;
uint256 constant MaxUint8 = 0xff;
bytes32 constant EIP2098_allButHighestBitMask = (
    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
);
uint256 constant Ecrecover_precompile = 1;
uint256 constant Ecrecover_args_size = 0x80;
uint256 constant FreeMemoryPointerSlot = 0x40;
uint256 constant ZeroSlot = 0x60;
uint256 constant Slot0x80 = 0x80;

/// @dev The EIP-712 digest offsets.
uint256 constant EIP712_DomainSeparator_offset = 0x02;
uint256 constant EIP712_SignedOrderHash_offset = 0x22;
uint256 constant EIP712_DigestPayload_size = 0x42;
uint256 constant EIP_712_PREFIX = (
    0x1901000000000000000000000000000000000000000000000000000000000000
);

// @dev Function selectors used in the fallback function..
bytes4 constant UPDATE_SIGNER_SELECTOR = 0xf460590b;
bytes4 constant GET_ACTIVE_SIGNERS_SELECTOR = 0xa784b80c;
bytes4 constant IS_ACTIVE_SIGNER_SELECTOR = 0x7dff5a79;
bytes4 constant SUPPORTS_INTERFACE_SELECTOR = 0x01ffc9a7;

/*
 *  error InvalidController()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 * Revert buffer is memory[0x1c:0x20]
 */
uint256 constant InvalidController_error_selector = 0x6d5769be;
uint256 constant InvalidController_error_length = 0x04;

/*
 *  error InvalidFulfiller(address expectedFulfiller, address actualFulfiller, bytes32 orderHash)
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: expectedFulfiller
 *    - 0x40: actualFullfiller
 *    - 0x60: orderHash
 * Revert buffer is memory[0x1c:0x80]
 */
uint256 constant InvalidFulfiller_error_selector = 0x1bcf9bb7;
uint256 constant InvalidFulfiller_error_expectedFulfiller_ptr = 0x20;
uint256 constant InvalidFulfiller_error_actualFulfiller_ptr = 0x40;
uint256 constant InvalidFulfiller_error_orderHash_ptr = 0x60;
uint256 constant InvalidFulfiller_error_length = 0x64;

/*
 *  error InvalidReceivedItem(uint256 expectedReceivedIdentifier, uint256 actualReceievedIdentifier, bytes32 orderHash)
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: expectedReceivedIdentifier
 *    - 0x40: actualReceievedIdentifier
 *    - 0x60: orderHash
 * Revert buffer is memory[0x1c:0x80]
 */
uint256 constant InvalidReceivedItem_error_selector = 0xb36c03e8;
uint256 constant InvalidReceivedItem_error_expectedReceivedItem_ptr = 0x20;
uint256 constant InvalidReceivedItem_error_actualReceivedItem_ptr = 0x40;
uint256 constant InvalidReceivedItem_error_orderHash_ptr = 0x60;
uint256 constant InvalidReceivedItem_error_length = 0x64;

/*
 *  error InvalidZoneParameterEncoding()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 * Revert buffer is memory[0x1c:0x20]
 */
uint256 constant InvalidZoneParameterEncoding_error_selector = 0x46d5d895;
uint256 constant InvalidZoneParameterEncoding_error_length = 0x04;

/*
 * error InvalidExtraDataLength()
 *   - Defined in SignedZoneEventsAndErrors.sol
 * Memory layout:
 *   - 0x00: Left-padded selector (data begins at 0x1c)
 *   - 0x20: orderHash
 * Revert buffer is memory[0x1c:0x40]
 */
uint256 constant InvalidExtraDataLength_error_selector = 0xd232fd2c;
uint256 constant InvalidExtraDataLength_error_orderHash_ptr = 0x20;
uint256 constant InvalidExtraDataLength_error_length = 0x24;
uint256 constant InvalidExtraDataLength_epected_length = 0x7e;

uint256 constant ExtraData_expiration_offset = 0x35;
uint256 constant ExtraData_substandard_version_byte_offset = 0x7d;
/*
 *  error InvalidSIP6Version()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: orderHash
 * Revert buffer is memory[0x1c:0x40]
 */
uint256 constant InvalidSIP6Version_error_selector = 0x64115774;
uint256 constant InvalidSIP6Version_error_orderHash_ptr = 0x20;
uint256 constant InvalidSIP6Version_error_length = 0x24;

/*
 *  error InvalidSubstandardVersion()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: orderHash
 * Revert buffer is memory[0x1c:0x40]
 */
uint256 constant InvalidSubstandardVersion_error_selector = 0x26787999;
uint256 constant InvalidSubstandardVersion_error_orderHash_ptr = 0x20;
uint256 constant InvalidSubstandardVersion_error_length = 0x24;

/*
 *  error InvalidSubstandardSupport()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: reason
 *    - 0x40: substandardVersion
 *    - 0x60: orderHash
 * Revert buffer is memory[0x1c:0xe0]
 */
uint256 constant InvalidSubstandardSupport_error_selector = 0x2be76224;
uint256 constant InvalidSubstandardSupport_error_reason_offset_ptr = 0x20;
uint256 constant InvalidSubstandardSupport_error_substandard_version_ptr = 0x40;
uint256 constant InvalidSubstandardSupport_error_orderHash_ptr = 0x60;
uint256 constant InvalidSubstandardSupport_error_reason_length_ptr = 0x80;
uint256 constant InvalidSubstandardSupport_error_reason_ptr = 0xa0;
uint256 constant InvalidSubstandardSupport_error_reason_2_ptr = 0xc0;
uint256 constant InvalidSubstandardSupport_error_length = 0xc4;

/*
 * error SignatureExpired()
 *   - Defined in SignedZoneEventsAndErrors.sol
 * Memory layout:
 *   - 0x00: Left-padded selector (data begins at 0x1c)
 *   - 0x20: expiration
 *   - 0x40: orderHash
 * Revert buffer is memory[0x1c:0x60]
 */
uint256 constant SignatureExpired_error_selector = 0x16546071;
uint256 constant SignatureExpired_error_expiration_ptr = 0x20;
uint256 constant SignatureExpired_error_orderHash_ptr = 0x40;
uint256 constant SignatureExpired_error_length = 0x44;

/*
 *  error UnsupportedFunctionSelector()
 *    - Defined in SignedZoneEventsAndErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 * Revert buffer is memory[0x1c:0x20]
 */
uint256 constant UnsupportedFunctionSelector_error_selector = 0x54c91b87;
uint256 constant UnsupportedFunctionSelector_error_length = 0x04;

// Zone parameter calldata pointers
uint256 constant Zone_parameters_cdPtr = 0x04;
uint256 constant Zone_parameters_fulfiller_cdPtr = 0x44;
uint256 constant Zone_consideration_head_cdPtr = 0xa4;
uint256 constant Zone_extraData_cdPtr = 0xc4;

// Zone parameter memory pointers
uint256 constant Zone_parameters_ptr = 0x20;

// Zone parameter offsets
uint256 constant Zone_parameters_offset = 0x24;
uint256 constant expectedFulfiller_offset = 0x45;
uint256 constant actualReceivedIdentifier_offset = 0x84;
uint256 constant expectedReceivedIdentifier_offset = 0xa2;
