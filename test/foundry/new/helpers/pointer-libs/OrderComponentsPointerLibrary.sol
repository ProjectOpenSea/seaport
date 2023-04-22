// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayConsiderationItemPointerLibrary.sol";
import "./DynArrayOfferItemPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type OrderComponentsPointer is uint256;

using Scuff for MemoryPointer;
using OrderComponentsPointerLibrary for OrderComponentsPointer global;

/// @dev Library for resolving pointers of encoded OrderComponents
/// struct OrderComponents {
///   address offerer;
///   address zone;
///   OfferItem[] offer;
///   ConsiderationItem[] consideration;
///   OrderType orderType;
///   uint256 startTime;
///   uint256 endTime;
///   bytes32 zoneHash;
///   uint256 salt;
///   bytes32 conduitKey;
///   uint256 counter;
/// }
library OrderComponentsPointerLibrary {
  enum ScuffKind { offerer_Overflow, zone_Overflow, offer_HeadOverflow, offer_LengthOverflow, offer_element_itemType_Overflow, offer_element_token_Overflow, consideration_HeadOverflow, consideration_LengthOverflow, consideration_element_itemType_Overflow, consideration_element_token_Overflow, consideration_element_recipient_Overflow, orderType_Overflow }

  uint256 internal constant OverflowedOfferer = 0x010000000000000000000000000000000000000000;
  uint256 internal constant zoneOffset = 0x20;
  uint256 internal constant OverflowedZone = 0x010000000000000000000000000000000000000000;
  uint256 internal constant offerOffset = 0x40;
  uint256 internal constant considerationOffset = 0x60;
  uint256 internal constant orderTypeOffset = 0x80;
  uint256 internal constant OverflowedOrderType = 0x05;
  uint256 internal constant startTimeOffset = 0xa0;
  uint256 internal constant endTimeOffset = 0xc0;
  uint256 internal constant zoneHashOffset = 0xe0;
  uint256 internal constant saltOffset = 0x0100;
  uint256 internal constant conduitKeyOffset = 0x0120;
  uint256 internal constant counterOffset = 0x0140;
  uint256 internal constant HeadSize = 0x0160;
  uint256 internal constant MinimumOfferScuffKind = uint256(ScuffKind.offer_LengthOverflow);
  uint256 internal constant MaximumOfferScuffKind = uint256(ScuffKind.offer_element_token_Overflow);
  uint256 internal constant MinimumConsiderationScuffKind = uint256(ScuffKind.consideration_LengthOverflow);
  uint256 internal constant MaximumConsiderationScuffKind = uint256(ScuffKind.consideration_element_recipient_Overflow);

  /// @dev Convert a `MemoryPointer` to a `OrderComponentsPointer`.
  /// This adds `OrderComponentsPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (OrderComponentsPointer) {
    return OrderComponentsPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `OrderComponentsPointer` back into a `MemoryPointer`.
  function unwrap(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(OrderComponentsPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `offerer` in memory.
  /// This points to the beginning of the encoded `address`
  function offerer(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Cause `offerer` to overflow
  function overflowOfferer(OrderComponentsPointer ptr) internal pure {
    offerer(ptr).write(OverflowedOfferer);
  }

  /// @dev Resolve the pointer to the head of `zone` in memory.
  /// This points to the beginning of the encoded `address`
  function zone(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(zoneOffset);
  }

  /// @dev Cause `zone` to overflow
  function overflowZone(OrderComponentsPointer ptr) internal pure {
    zone(ptr).write(OverflowedZone);
  }

  /// @dev Resolve the pointer to the head of `offer` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerHead(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(offerOffset);
  }

  /// @dev Resolve the `DynArrayOfferItemPointer` pointing to the data buffer of `offer`
  function offerData(OrderComponentsPointer ptr) internal pure returns (DynArrayOfferItemPointer) {
    return DynArrayOfferItemPointerLibrary.wrap(ptr.unwrap().offset(offerHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `offer` (offset relative to parent).
  function addDirtyBitsToOfferOffset(OrderComponentsPointer ptr) internal pure {
    offerHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `consideration` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationHead(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationOffset);
  }

  /// @dev Resolve the `DynArrayConsiderationItemPointer` pointing to the data buffer of `consideration`
  function considerationData(OrderComponentsPointer ptr) internal pure returns (DynArrayConsiderationItemPointer) {
    return DynArrayConsiderationItemPointerLibrary.wrap(ptr.unwrap().offset(considerationHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `consideration` (offset relative to parent).
  function addDirtyBitsToConsiderationOffset(OrderComponentsPointer ptr) internal pure {
    considerationHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `orderType` in memory.
  /// This points to the beginning of the encoded `OrderType`
  function orderType(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(orderTypeOffset);
  }

  /// @dev Cause `orderType` to overflow
  function overflowOrderType(OrderComponentsPointer ptr) internal pure {
    orderType(ptr).write(OverflowedOrderType);
  }

  /// @dev Resolve the pointer to the head of `startTime` in memory.
  /// This points to the beginning of the encoded `uint256`
  function startTime(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(startTimeOffset);
  }

  /// @dev Resolve the pointer to the head of `endTime` in memory.
  /// This points to the beginning of the encoded `uint256`
  function endTime(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(endTimeOffset);
  }

  /// @dev Resolve the pointer to the head of `zoneHash` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function zoneHash(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(zoneHashOffset);
  }

  /// @dev Resolve the pointer to the head of `salt` in memory.
  /// This points to the beginning of the encoded `uint256`
  function salt(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(saltOffset);
  }

  /// @dev Resolve the pointer to the head of `conduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function conduitKey(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(conduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `counter` in memory.
  /// This points to the beginning of the encoded `uint256`
  function counter(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(counterOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(OrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(OrderComponentsPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `offerer`
    directives.push(Scuff.upper(uint256(ScuffKind.offerer_Overflow) + kindOffset, 96, ptr.offerer()));
    /// @dev Induce overflow in `zone`
    directives.push(Scuff.upper(uint256(ScuffKind.zone_Overflow) + kindOffset, 96, ptr.zone()));
    /// @dev Overflow offset for `offer`
    directives.push(Scuff.lower(uint256(ScuffKind.offer_HeadOverflow) + kindOffset, 224, ptr.offerHead()));
    /// @dev Add all nested directives in offer
    ptr.offerData().addScuffDirectives(directives, kindOffset + MinimumOfferScuffKind);
    /// @dev Overflow offset for `consideration`
    directives.push(Scuff.lower(uint256(ScuffKind.consideration_HeadOverflow) + kindOffset, 224, ptr.considerationHead()));
    /// @dev Add all nested directives in consideration
    ptr.considerationData().addScuffDirectives(directives, kindOffset + MinimumConsiderationScuffKind);
    /// @dev Induce overflow in `orderType`
    directives.push(Scuff.upper(uint256(ScuffKind.orderType_Overflow) + kindOffset, 253, ptr.orderType()));
  }

  function getScuffDirectives(OrderComponentsPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.offerer_Overflow) return "offerer_Overflow";
    if (k == ScuffKind.zone_Overflow) return "zone_Overflow";
    if (k == ScuffKind.offer_HeadOverflow) return "offer_HeadOverflow";
    if (k == ScuffKind.offer_LengthOverflow) return "offer_LengthOverflow";
    if (k == ScuffKind.offer_element_itemType_Overflow) return "offer_element_itemType_Overflow";
    if (k == ScuffKind.offer_element_token_Overflow) return "offer_element_token_Overflow";
    if (k == ScuffKind.consideration_HeadOverflow) return "consideration_HeadOverflow";
    if (k == ScuffKind.consideration_LengthOverflow) return "consideration_LengthOverflow";
    if (k == ScuffKind.consideration_element_itemType_Overflow) return "consideration_element_itemType_Overflow";
    if (k == ScuffKind.consideration_element_token_Overflow) return "consideration_element_token_Overflow";
    if (k == ScuffKind.consideration_element_recipient_Overflow) return "consideration_element_recipient_Overflow";
    return "orderType_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}