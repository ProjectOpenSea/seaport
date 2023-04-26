pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./AdvancedOrderPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayAdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayAdvancedOrderPointerLibrary for DynArrayAdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded AdvancedOrder[]
library DynArrayAdvancedOrderPointerLibrary {
  enum ScuffKind { element_parameters_offerer_DirtyBits, element_parameters_zone_DirtyBits, element_parameters_offer_element_itemType_DirtyBits, element_parameters_offer_element_itemType_MaxValue, element_parameters_offer_element_token_DirtyBits, element_parameters_consideration_element_itemType_DirtyBits, element_parameters_consideration_element_itemType_MaxValue, element_parameters_consideration_element_token_DirtyBits, element_parameters_consideration_element_recipient_DirtyBits, element_parameters_orderType_DirtyBits, element_parameters_orderType_MaxValue, element_numerator_DirtyBits, element_denominator_DirtyBits }

  enum ScuffableField { element }

  uint256 internal constant CalldataStride = 0x20;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_parameters_offerer_DirtyBits);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_denominator_DirtyBits);

  /// @dev Convert a `MemoryPointer` to a `DynArrayAdvancedOrderPointer`.
  /// This adds `DynArrayAdvancedOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayAdvancedOrderPointer) {
    return DynArrayAdvancedOrderPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayAdvancedOrderPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayAdvancedOrderPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayAdvancedOrderPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `AdvancedOrder[]` at `ptr`.
  function length(DynArrayAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `AdvancedOrder[]` at `ptr` to `length`.
  function setLength(DynArrayAdvancedOrderPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `AdvancedOrder[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayAdvancedOrderPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `AdvancedOrderPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayAdvancedOrderPointer ptr, uint256 index) internal pure returns (AdvancedOrderPointer) {
    return AdvancedOrderPointerLibrary.wrap(head(ptr).offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayAdvancedOrderPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }

  function addScuffDirectives(DynArrayAdvancedOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      ScuffPositions pos = positions.push(i);
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind, pos);
    }
  }

  function getScuffDirectives(DynArrayAdvancedOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.element_parameters_offerer_DirtyBits) return "element_parameters_offerer_DirtyBits";
    if (k == ScuffKind.element_parameters_zone_DirtyBits) return "element_parameters_zone_DirtyBits";
    if (k == ScuffKind.element_parameters_offer_element_itemType_DirtyBits) return "element_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.element_parameters_offer_element_itemType_MaxValue) return "element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.element_parameters_offer_element_token_DirtyBits) return "element_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.element_parameters_consideration_element_itemType_DirtyBits) return "element_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.element_parameters_consideration_element_itemType_MaxValue) return "element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.element_parameters_consideration_element_token_DirtyBits) return "element_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.element_parameters_consideration_element_recipient_DirtyBits) return "element_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.element_parameters_orderType_DirtyBits) return "element_parameters_orderType_DirtyBits";
    if (k == ScuffKind.element_parameters_orderType_MaxValue) return "element_parameters_orderType_MaxValue";
    if (k == ScuffKind.element_numerator_DirtyBits) return "element_numerator_DirtyBits";
    return "element_denominator_DirtyBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}