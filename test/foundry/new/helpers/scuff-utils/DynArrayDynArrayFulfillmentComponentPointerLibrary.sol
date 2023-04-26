pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentComponentPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type DynArrayDynArrayFulfillmentComponentPointer is uint256;

using Scuff for MemoryPointer;
using DynArrayDynArrayFulfillmentComponentPointerLibrary for DynArrayDynArrayFulfillmentComponentPointer global;

/// @dev Library for resolving pointers of encoded FulfillmentComponent[][]
library DynArrayDynArrayFulfillmentComponentPointerLibrary {
  uint256 internal constant CalldataStride = 0x20;

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
}