pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./FulfillmentComponentPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayFulfillmentComponentPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayFulfillmentComponentPointerLibrary for DynArrayFulfillmentComponentPointer global;

/// @dev Library for resolving pointers of encoded FulfillmentComponent[]
library DynArrayFulfillmentComponentPointerLibrary {
  uint256 internal constant CalldataStride = 0x40;

  /// @dev Convert a `MemoryPointer` to a `DynArrayFulfillmentComponentPointer`.
  /// This adds `DynArrayFulfillmentComponentPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayFulfillmentComponentPointer) {
    return DynArrayFulfillmentComponentPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayFulfillmentComponentPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayFulfillmentComponentPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the first item's data
  function head(DynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the beginning of the encoded `FulfillmentComponent[]`
  function element(DynArrayFulfillmentComponentPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `FulfillmentComponent[]` at `ptr`.
  function length(DynArrayFulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `FulfillmentComponent[]` at `ptr` to `length`.
  function setLength(DynArrayFulfillmentComponentPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `FulfillmentComponent[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayFulfillmentComponentPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `FulfillmentComponentPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayFulfillmentComponentPointer ptr, uint256 index) internal pure returns (FulfillmentComponentPointer) {
    return FulfillmentComponentPointerLibrary.wrap(head(ptr).offset(index * CalldataStride));
  }
}