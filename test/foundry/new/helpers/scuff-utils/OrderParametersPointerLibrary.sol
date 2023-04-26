pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayConsiderationItemPointerLibrary.sol";
import "./DynArrayOfferItemPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type OrderParametersPointer is uint256;

using Scuff for MemoryPointer;
using OrderParametersPointerLibrary for OrderParametersPointer global;

/// @dev Library for resolving pointers of encoded OrderParameters
/// struct OrderParameters {
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
///   uint256 totalOriginalConsiderationItems;
/// }
library OrderParametersPointerLibrary {
  enum ScuffKind { offer_head_DirtyBits, offer_head_MaxValue, offer_length_DirtyBits, offer_length_MaxValue, offer_element_itemType_MaxValue, consideration_head_DirtyBits, consideration_head_MaxValue, consideration_length_DirtyBits, consideration_length_MaxValue, consideration_element_itemType_MaxValue, consideration_element_recipient_DirtyBits, orderType_MaxValue }

  enum ScuffableField { offer_head, offer, consideration_head, consideration, orderType }

  uint256 internal constant zoneOffset = 0x20;
  uint256 internal constant offerOffset = 0x40;
  uint256 internal constant considerationOffset = 0x60;
  uint256 internal constant orderTypeOffset = 0x80;
  uint256 internal constant startTimeOffset = 0xa0;
  uint256 internal constant endTimeOffset = 0xc0;
  uint256 internal constant zoneHashOffset = 0xe0;
  uint256 internal constant saltOffset = 0x0100;
  uint256 internal constant conduitKeyOffset = 0x0120;
  uint256 internal constant totalOriginalConsiderationItemsOffset = 0x0140;
  uint256 internal constant HeadSize = 0x0160;
  uint256 internal constant MinimumOfferScuffKind = uint256(ScuffKind.offer_length_DirtyBits);
  uint256 internal constant MaximumOfferScuffKind = uint256(ScuffKind.offer_element_itemType_MaxValue);
  uint256 internal constant MinimumConsiderationScuffKind = uint256(ScuffKind.consideration_length_DirtyBits);
  uint256 internal constant MaximumConsiderationScuffKind = uint256(ScuffKind.consideration_element_recipient_DirtyBits);

  /// @dev Convert a `MemoryPointer` to a `OrderParametersPointer`.
  /// This adds `OrderParametersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (OrderParametersPointer) {
    return OrderParametersPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `OrderParametersPointer` back into a `MemoryPointer`.
  function unwrap(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(OrderParametersPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `offerer` in memory.
  /// This points to the beginning of the encoded `address`
  function offerer(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the pointer to the head of `zone` in memory.
  /// This points to the beginning of the encoded `address`
  function zone(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(zoneOffset);
  }

  /// @dev Resolve the pointer to the head of `offer` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerHead(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(offerOffset);
  }

  /// @dev Resolve the `DynArrayOfferItemPointer` pointing to the data buffer of `offer`
  function offerData(OrderParametersPointer ptr) internal pure returns (DynArrayOfferItemPointer) {
    return DynArrayOfferItemPointerLibrary.wrap(ptr.unwrap().offset(offerHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `consideration` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationHead(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationOffset);
  }

  /// @dev Resolve the `DynArrayConsiderationItemPointer` pointing to the data buffer of `consideration`
  function considerationData(OrderParametersPointer ptr) internal pure returns (DynArrayConsiderationItemPointer) {
    return DynArrayConsiderationItemPointerLibrary.wrap(ptr.unwrap().offset(considerationHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `orderType` in memory.
  /// This points to the beginning of the encoded `OrderType`
  function orderType(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(orderTypeOffset);
  }

  /// @dev Resolve the pointer to the head of `startTime` in memory.
  /// This points to the beginning of the encoded `uint256`
  function startTime(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(startTimeOffset);
  }

  /// @dev Resolve the pointer to the head of `endTime` in memory.
  /// This points to the beginning of the encoded `uint256`
  function endTime(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(endTimeOffset);
  }

  /// @dev Resolve the pointer to the head of `zoneHash` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function zoneHash(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(zoneHashOffset);
  }

  /// @dev Resolve the pointer to the head of `salt` in memory.
  /// This points to the beginning of the encoded `uint256`
  function salt(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(saltOffset);
  }

  /// @dev Resolve the pointer to the head of `conduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function conduitKey(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(conduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `totalOriginalConsiderationItems` in memory.
  /// This points to the beginning of the encoded `uint256`
  function totalOriginalConsiderationItems(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(totalOriginalConsiderationItemsOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(OrderParametersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(OrderParametersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to offer head
    directives.push(Scuff.upper(uint256(ScuffKind.offer_head_DirtyBits) + kindOffset, 224, ptr.offerHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.offer_head_MaxValue) + kindOffset, 229, ptr.offerHead(), positions));
    /// @dev Add all nested directives in offer
    ptr.offerData().addScuffDirectives(directives, kindOffset + MinimumOfferScuffKind, positions);
    /// @dev Add dirty upper bits to consideration head
    directives.push(Scuff.upper(uint256(ScuffKind.consideration_head_DirtyBits) + kindOffset, 224, ptr.considerationHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.consideration_head_MaxValue) + kindOffset, 229, ptr.considerationHead(), positions));
    /// @dev Add all nested directives in consideration
    ptr.considerationData().addScuffDirectives(directives, kindOffset + MinimumConsiderationScuffKind, positions);
    /// @dev Set every bit in `orderType` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.orderType_MaxValue) + kindOffset, 253, ptr.orderType(), positions));
  }

  function getScuffDirectives(OrderParametersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.offer_head_DirtyBits) return "offer_head_DirtyBits";
    if (k == ScuffKind.offer_head_MaxValue) return "offer_head_MaxValue";
    if (k == ScuffKind.offer_length_DirtyBits) return "offer_length_DirtyBits";
    if (k == ScuffKind.offer_length_MaxValue) return "offer_length_MaxValue";
    if (k == ScuffKind.offer_element_itemType_MaxValue) return "offer_element_itemType_MaxValue";
    if (k == ScuffKind.consideration_head_DirtyBits) return "consideration_head_DirtyBits";
    if (k == ScuffKind.consideration_head_MaxValue) return "consideration_head_MaxValue";
    if (k == ScuffKind.consideration_length_DirtyBits) return "consideration_length_DirtyBits";
    if (k == ScuffKind.consideration_length_MaxValue) return "consideration_length_MaxValue";
    if (k == ScuffKind.consideration_element_itemType_MaxValue) return "consideration_element_itemType_MaxValue";
    if (k == ScuffKind.consideration_element_recipient_DirtyBits) return "consideration_element_recipient_DirtyBits";
    return "orderType_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}