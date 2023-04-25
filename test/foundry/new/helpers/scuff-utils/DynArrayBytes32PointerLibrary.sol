pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayBytes32Pointer is uint256;

using Scuff for MemoryPointer;
using DynArrayBytes32PointerLibrary for DynArrayBytes32Pointer global;

/// @dev Library for resolving pointers of encoded bytes32[]
library DynArrayBytes32PointerLibrary {
  enum ScuffKind { length_DirtyBits, length_MaxValue }

  enum ScuffableField { length }

  uint256 internal constant CalldataStride = 0x20;

  /// @dev Convert a `MemoryPointer` to a `DynArrayBytes32Pointer`.
  /// This adds `DynArrayBytes32PointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayBytes32Pointer) {
    return DynArrayBytes32Pointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayBytes32Pointer` back into a `MemoryPointer`.
  function unwrap(DynArrayBytes32Pointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayBytes32Pointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the first item's data
  function head(DynArrayBytes32Pointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the beginning of the encoded `bytes32[]`
  function element(DynArrayBytes32Pointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `bytes32[]` at `ptr`.
  function length(DynArrayBytes32Pointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `bytes32[]` at `ptr` to `length`.
  function setLength(DynArrayBytes32Pointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `bytes32[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayBytes32Pointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  function addScuffDirectives(DynArrayBytes32Pointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to length
    directives.push(Scuff.upper(uint256(ScuffKind.length_DirtyBits) + kindOffset, 224, ptr.length(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.length_MaxValue) + kindOffset, 229, ptr.length(), positions));
  }

  function getScuffDirectives(DynArrayBytes32Pointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.length_DirtyBits) return "length_DirtyBits";
    return "length_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}