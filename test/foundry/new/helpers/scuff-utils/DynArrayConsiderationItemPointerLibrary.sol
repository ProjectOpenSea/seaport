pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./ConsiderationItemPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayConsiderationItemPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayConsiderationItemPointerLibrary for DynArrayConsiderationItemPointer global;

/// @dev Library for resolving pointers of encoded ConsiderationItem[]
library DynArrayConsiderationItemPointerLibrary {
  enum ScuffKind { length_DirtyBits, length_MaxValue, element_itemType_DirtyBits, element_itemType_MaxValue, element_token_DirtyBits, element_token_MaxValue, element_recipient_DirtyBits, element_recipient_MaxValue }

  enum ScuffableField { length, element }

  uint256 internal constant CalldataStride = 0xc0;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_itemType_DirtyBits);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_recipient_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `DynArrayConsiderationItemPointer`.
  /// This adds `DynArrayConsiderationItemPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayConsiderationItemPointer) {
    return DynArrayConsiderationItemPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayConsiderationItemPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayConsiderationItemPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the first item's data
  function head(DynArrayConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the beginning of the encoded `ConsiderationItem[]`
  function element(DynArrayConsiderationItemPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `ConsiderationItem[]` at `ptr`.
  function length(DynArrayConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `ConsiderationItem[]` at `ptr` to `length`.
  function setLength(DynArrayConsiderationItemPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `ConsiderationItem[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayConsiderationItemPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `ConsiderationItemPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayConsiderationItemPointer ptr, uint256 index) internal pure returns (ConsiderationItemPointer) {
    return ConsiderationItemPointerLibrary.wrap(head(ptr).offset(index * CalldataStride));
  }

  function addScuffDirectives(DynArrayConsiderationItemPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to length
    directives.push(Scuff.upper(uint256(ScuffKind.length_DirtyBits) + kindOffset, 224, ptr.length(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.length_MaxValue) + kindOffset, 224, ptr.length(), positions));
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      ScuffPositions pos = positions.push(i);
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind, pos);
    }
  }

  function getScuffDirectives(DynArrayConsiderationItemPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.length_DirtyBits) return "length_DirtyBits";
    if (k == ScuffKind.length_MaxValue) return "length_MaxValue";
    if (k == ScuffKind.element_itemType_DirtyBits) return "element_itemType_DirtyBits";
    if (k == ScuffKind.element_itemType_MaxValue) return "element_itemType_MaxValue";
    if (k == ScuffKind.element_token_DirtyBits) return "element_token_DirtyBits";
    if (k == ScuffKind.element_token_MaxValue) return "element_token_MaxValue";
    if (k == ScuffKind.element_recipient_DirtyBits) return "element_recipient_DirtyBits";
    return "element_recipient_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}