// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OfferItemPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type DynArrayOfferItemPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayOfferItemPointerLibrary for DynArrayOfferItemPointer global;

/// @dev Library for resolving pointers of encoded OfferItem[]
library DynArrayOfferItemPointerLibrary {
  enum ScuffKind { LengthOverflow, element_itemType_Overflow, element_token_Overflow }

  uint256 internal constant CalldataStride = 0xa0;
  uint256 internal constant MinimumElementScuffKind = uint256(ScuffKind.element_itemType_Overflow);
  uint256 internal constant MaximumElementScuffKind = uint256(ScuffKind.element_token_Overflow);

  /// @dev Convert a `MemoryPointer` to a `DynArrayOfferItemPointer`.
  /// This adds `DynArrayOfferItemPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayOfferItemPointer) {
    return DynArrayOfferItemPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayOfferItemPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayOfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayOfferItemPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the first item's data
  function head(DynArrayOfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the beginning of the encoded `OfferItem[]`
  function element(DynArrayOfferItemPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset((index * CalldataStride) + 32);
  }

  /// @dev Resolve the pointer for the length of the `OfferItem[]` at `ptr`.
  function length(DynArrayOfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `OfferItem[]` at `ptr` to `length`.
  function setLength(DynArrayOfferItemPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `OfferItem[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayOfferItemPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Add dirty bits from 0 to 224 to the length for the `OfferItem[]` at `ptr`
  function addDirtyBitsToLength(DynArrayOfferItemPointer ptr) internal pure {
    length(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the `OfferItemPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayOfferItemPointer ptr, uint256 index) internal pure returns (OfferItemPointer) {
    return OfferItemPointerLibrary.wrap(element(ptr, index));
  }

  function addScuffDirectives(DynArrayOfferItemPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow length of OfferItem[]
    directives.push(Scuff.lower(uint256(ScuffKind.LengthOverflow) + kindOffset, 224, ptr.length()));
    uint256 len = ptr.length().readUint256();
    for (uint256 i; i < len; i++) {
      /// @dev Add all nested directives in element
      ptr.elementData(i).addScuffDirectives(directives, kindOffset + MinimumElementScuffKind);
    }
  }

  function getScuffDirectives(DynArrayOfferItemPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.LengthOverflow) return "LengthOverflow";
    if (k == ScuffKind.element_itemType_Overflow) return "element_itemType_Overflow";
    return "element_token_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}