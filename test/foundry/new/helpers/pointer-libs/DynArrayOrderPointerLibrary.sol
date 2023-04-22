// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type DynArrayOrderPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayOrderPointerLibrary for DynArrayOrderPointer global;

/// @dev Library for resolving pointers of encoded Order[]
library DynArrayOrderPointerLibrary {
  enum ScuffKind { LengthOverflow, element_HeadOverflow, element_parameters_HeadOverflow, element_parameters_offerer_Overflow, element_parameters_zone_Overflow, element_parameters_offer_HeadOverflow, element_parameters_offer_LengthOverflow, element_parameters_offer_element_itemType_Overflow, element_parameters_offer_element_token_Overflow, element_parameters_consideration_HeadOverflow, element_parameters_consideration_LengthOverflow, element_parameters_consideration_element_itemType_Overflow, element_parameters_consideration_element_token_Overflow, element_parameters_consideration_element_recipient_Overflow, element_parameters_orderType_Overflow, element_signature_HeadOverflow, element_signature_LengthOverflow, element_signature_DirtyLowerBits }

  uint256 internal constant CalldataStride = 0x20;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_parameters_HeadOverflow);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_signature_DirtyLowerBits);

  /// @dev Convert a `MemoryPointer` to a `DynArrayOrderPointer`.
  /// This adds `DynArrayOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayOrderPointer) {
    return DynArrayOrderPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayOrderPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayOrderPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayOrderPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset((index * CalldataStride) + 32);
  }

  /// @dev Resolve the pointer for the length of the `Order[]` at `ptr`.
  function length(DynArrayOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `Order[]` at `ptr` to `length`.
  function setLength(DynArrayOrderPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `Order[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayOrderPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Add dirty bits from 0 to 224 to the length for the `Order[]` at `ptr`
  function addDirtyBitsToLength(DynArrayOrderPointer ptr) internal pure {
    length(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the `OrderPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayOrderPointer ptr, uint256 index) internal pure returns (OrderPointer) {
    return OrderPointerLibrary.wrap(ptr.unwrap().offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayOrderPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }

  function addScuffDirectives(DynArrayOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow length of Order[]
    directives.push(Scuff.lower(uint256(ScuffKind.LengthOverflow) + kindOffset, 224, ptr.length()));
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      /// @dev Overflow offset for `element`
      directives.push(Scuff.lower(uint256(ScuffKind.element_HeadOverflow) + kindOffset, 224, ptr.elementHead(i)));
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind);
    }
  }

  function getScuffDirectives(DynArrayOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.LengthOverflow) return "LengthOverflow";
    if (k == ScuffKind.element_HeadOverflow) return "element_HeadOverflow";
    if (k == ScuffKind.element_parameters_HeadOverflow) return "element_parameters_HeadOverflow";
    if (k == ScuffKind.element_parameters_offerer_Overflow) return "element_parameters_offerer_Overflow";
    if (k == ScuffKind.element_parameters_zone_Overflow) return "element_parameters_zone_Overflow";
    if (k == ScuffKind.element_parameters_offer_HeadOverflow) return "element_parameters_offer_HeadOverflow";
    if (k == ScuffKind.element_parameters_offer_LengthOverflow) return "element_parameters_offer_LengthOverflow";
    if (k == ScuffKind.element_parameters_offer_element_itemType_Overflow) return "element_parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.element_parameters_offer_element_token_Overflow) return "element_parameters_offer_element_token_Overflow";
    if (k == ScuffKind.element_parameters_consideration_HeadOverflow) return "element_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.element_parameters_consideration_LengthOverflow) return "element_parameters_consideration_LengthOverflow";
    if (k == ScuffKind.element_parameters_consideration_element_itemType_Overflow) return "element_parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.element_parameters_consideration_element_token_Overflow) return "element_parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.element_parameters_consideration_element_recipient_Overflow) return "element_parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.element_parameters_orderType_Overflow) return "element_parameters_orderType_Overflow";
    if (k == ScuffKind.element_signature_HeadOverflow) return "element_signature_HeadOverflow";
    if (k == ScuffKind.element_signature_LengthOverflow) return "element_signature_LengthOverflow";
    return "element_signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}