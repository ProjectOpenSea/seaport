pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./FulfillmentPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayFulfillmentPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayFulfillmentPointerLibrary for DynArrayFulfillmentPointer global;

/// @dev Library for resolving pointers of encoded Fulfillment[]
library DynArrayFulfillmentPointerLibrary {
  uint256 internal constant CalldataStride = 0x20;

  /// @dev Convert a `MemoryPointer` to a `DynArrayFulfillmentPointer`.
  /// This adds `DynArrayFulfillmentPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (DynArrayFulfillmentPointer) {
    return DynArrayFulfillmentPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `DynArrayFulfillmentPointer` back into a `MemoryPointer`.
  function unwrap(DynArrayFulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(DynArrayFulfillmentPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of the array.
  /// This points to the head value of the first item in the array
  function head(DynArrayFulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(_OneWord);
  }

  /// @dev Resolve the pointer to the head of `arr[index]` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function elementHead(DynArrayFulfillmentPointer ptr, uint256 index) internal pure returns (MemoryPointer) {
    return head(ptr).offset(index * CalldataStride);
  }

  /// @dev Resolve the pointer for the length of the `Fulfillment[]` at `ptr`.
  function length(DynArrayFulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Set the length for the `Fulfillment[]` at `ptr` to `length`.
  function setLength(DynArrayFulfillmentPointer ptr, uint256 _length) internal pure {
    length(ptr).write(_length);
  }

  /// @dev Set the length for the `Fulfillment[]` at `ptr` to `type(uint256).max`.
  function setMaxLength(DynArrayFulfillmentPointer ptr) internal pure {
    setLength(ptr, type(uint256).max);
  }

  /// @dev Resolve the `FulfillmentPointer` pointing to the data buffer of `arr[index]`
  function elementData(DynArrayFulfillmentPointer ptr, uint256 index) internal pure returns (FulfillmentPointer) {
    return FulfillmentPointerLibrary.wrap(head(ptr).offset(elementHead(ptr, index).readUint256()));
  }

  /// @dev Swap the head values of `i` and `j`
  function swap(DynArrayFulfillmentPointer ptr, uint256 i, uint256 j) internal pure {
    MemoryPointer head_i = elementHead(ptr, i);
    MemoryPointer head_j = elementHead(ptr, j);
    uint256 value_i = head_i.readUint256();
    uint256 value_j = head_j.readUint256();
    head_i.write(value_j);
    head_j.write(value_i);
  }

  /// @dev Resolve the pointer to the tail segment of the array.
  /// This is the beginning of the dynamically encoded data.
  function tail(DynArrayFulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(32 + (length(ptr).readUint256() * CalldataStride));
  }
}