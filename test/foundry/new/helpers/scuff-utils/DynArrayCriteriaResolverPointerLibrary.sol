pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./CriteriaResolverPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayCriteriaResolverPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayCriteriaResolverPointerLibrary for DynArrayCriteriaResolverPointer global;

/// @dev Library for resolving pointers of encoded CriteriaResolver[]
library DynArrayCriteriaResolverPointerLibrary {
  enum ScuffKind { element_side_DirtyBits, element_side_MaxValue }

  enum ScuffableField { element }

  uint256 internal constant CalldataStride = 0x20;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_side_DirtyBits);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_side_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `DynArrayCriteriaResolverPointer`.
  /// This adds `DynArrayCriteriaResolverPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayCriteriaResolverPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayCriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayCriteriaResolverPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayCriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayCriteriaResolverPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `CriteriaResolver[]` at `ptr`.
  function length(DynArrayCriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `CriteriaResolver[]` at `ptr` to `length`.
  function setLength(DynArrayCriteriaResolverPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `CriteriaResolver[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayCriteriaResolverPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `CriteriaResolverPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayCriteriaResolverPointer ptr, uint256 index) internal pure returns (CriteriaResolverPointer) {
    return CriteriaResolverPointerLibrary.wrap(head(ptr).offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayCriteriaResolverPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayCriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }

  function addScuffDirectives(DynArrayCriteriaResolverPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      ScuffPositions pos = positions.push(i);
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind, pos);
    }
  }

  function getScuffDirectives(DynArrayCriteriaResolverPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.element_side_DirtyBits) return "element_side_DirtyBits";
    return "element_side_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}