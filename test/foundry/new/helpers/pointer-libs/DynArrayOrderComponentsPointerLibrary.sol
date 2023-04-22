// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderComponentsPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type DynArrayOrderComponentsPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayOrderComponentsPointerLibrary for DynArrayOrderComponentsPointer global;

/// @dev Library for resolving pointers of encoded OrderComponents[]
library DynArrayOrderComponentsPointerLibrary {
  enum ScuffKind { LengthOverflow, element_HeadOverflow, element_offerer_Overflow, element_zone_Overflow, element_offer_HeadOverflow, element_offer_LengthOverflow, element_offer_element_itemType_Overflow, element_offer_element_token_Overflow, element_consideration_HeadOverflow, element_consideration_LengthOverflow, element_consideration_element_itemType_Overflow, element_consideration_element_token_Overflow, element_consideration_element_recipient_Overflow, element_orderType_Overflow }

  uint256 internal constant CalldataStride = 0x20;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_offerer_Overflow);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_orderType_Overflow);

  /// @dev Convert a `MemoryPointer` to a `DynArrayOrderComponentsPointer`.
  /// This adds `DynArrayOrderComponentsPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayOrderComponentsPointer) {
    return DynArrayOrderComponentsPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayOrderComponentsPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayOrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayOrderComponentsPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayOrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayOrderComponentsPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset((index * CalldataStride) + 32);
  }

  /// @dev Resolve the pointer for the length of the `OrderComponents[]` at `ptr`.
  function length(DynArrayOrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `OrderComponents[]` at `ptr` to `length`.
  function setLength(DynArrayOrderComponentsPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `OrderComponents[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayOrderComponentsPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Add dirty bits from 0 to 224 to the length for the `OrderComponents[]` at `ptr`
  function addDirtyBitsToLength(DynArrayOrderComponentsPointer ptr) internal pure {
    length(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the `OrderComponentsPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayOrderComponentsPointer ptr, uint256 index) internal pure returns (OrderComponentsPointer) {
    return OrderComponentsPointerLibrary.wrap(ptr.unwrap().offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayOrderComponentsPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayOrderComponentsPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }

  function addScuffDirectives(DynArrayOrderComponentsPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow length of OrderComponents[]
    directives.push(Scuff.lower(uint256(ScuffKind.LengthOverflow) + kindOffset, 224, ptr.length()));
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      /// @dev Overflow offset for `element`
      directives.push(Scuff.lower(uint256(ScuffKind.element_HeadOverflow) + kindOffset, 224, ptr.elementHead(i)));
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind);
    }
  }

  function getScuffDirectives(DynArrayOrderComponentsPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.LengthOverflow) return "LengthOverflow";
    if (k == ScuffKind.element_HeadOverflow) return "element_HeadOverflow";
    if (k == ScuffKind.element_offerer_Overflow) return "element_offerer_Overflow";
    if (k == ScuffKind.element_zone_Overflow) return "element_zone_Overflow";
    if (k == ScuffKind.element_offer_HeadOverflow) return "element_offer_HeadOverflow";
    if (k == ScuffKind.element_offer_LengthOverflow) return "element_offer_LengthOverflow";
    if (k == ScuffKind.element_offer_element_itemType_Overflow) return "element_offer_element_itemType_Overflow";
    if (k == ScuffKind.element_offer_element_token_Overflow) return "element_offer_element_token_Overflow";
    if (k == ScuffKind.element_consideration_HeadOverflow) return "element_consideration_HeadOverflow";
    if (k == ScuffKind.element_consideration_LengthOverflow) return "element_consideration_LengthOverflow";
    if (k == ScuffKind.element_consideration_element_itemType_Overflow) return "element_consideration_element_itemType_Overflow";
    if (k == ScuffKind.element_consideration_element_token_Overflow) return "element_consideration_element_token_Overflow";
    if (k == ScuffKind.element_consideration_element_recipient_Overflow) return "element_consideration_element_recipient_Overflow";
    return "element_orderType_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}