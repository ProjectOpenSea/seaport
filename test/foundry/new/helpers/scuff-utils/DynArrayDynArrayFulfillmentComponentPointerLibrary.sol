pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentComponentPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayDynArrayFulfillmentComponentPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayDynArrayFulfillmentComponentPointerLibrary for DynArrayDynArrayFulfillmentComponentPointer global;

/// @dev Library for resolving pointers of encoded FulfillmentComponent[][]
library DynArrayDynArrayFulfillmentComponentPointerLibrary {
  enum ScuffKind { length_DirtyBits, length_MaxValue, element_HeadOverflow, element_length_DirtyBits, element_length_MaxValue }

  enum ScuffableField { length, element }

  uint256 internal constant CalldataStride = 0x20;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_length_DirtyBits);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_length_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `DynArrayDynArrayFulfillmentComponentPointer`.
  /// This adds `DynArrayDynArrayFulfillmentComponentPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayDynArrayFulfillmentComponentPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayDynArrayFulfillmentComponentPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayDynArrayFulfillmentComponentPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `FulfillmentComponent[][]` at `ptr`.
  function length(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `FulfillmentComponent[][]` at `ptr` to `length`.
  function setLength(DynArrayDynArrayFulfillmentComponentPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `FulfillmentComponent[][]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `DynArrayFulfillmentComponentPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayDynArrayFulfillmentComponentPointer ptr, uint256 index) internal pure returns (DynArrayFulfillmentComponentPointer) {
    return DynArrayFulfillmentComponentPointerLibrary.wrap(head(ptr).offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayDynArrayFulfillmentComponentPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }

  function addScuffDirectives(DynArrayDynArrayFulfillmentComponentPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to length
    directives.push(Scuff.upper(uint256(ScuffKind.length_DirtyBits) + kindOffset, 224, ptr.length(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.length_MaxValue) + kindOffset, 224, ptr.length(), positions));
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      ScuffPositions pos = positions.push(i);
      /// @dev Overflow offset for `element`
      directives.push(Scuff.lower(uint256(ScuffKind.element_HeadOverflow) + kindOffset, 224, ptr.elementHead(i), pos));
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind, pos);
    }
  }

  function getScuffDirectives(DynArrayDynArrayFulfillmentComponentPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.length_DirtyBits) return "length_DirtyBits";
    if (k == ScuffKind.length_MaxValue) return "length_MaxValue";
    if (k == ScuffKind.element_HeadOverflow) return "element_HeadOverflow";
    if (k == ScuffKind.element_length_DirtyBits) return "element_length_DirtyBits";
    return "element_length_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}