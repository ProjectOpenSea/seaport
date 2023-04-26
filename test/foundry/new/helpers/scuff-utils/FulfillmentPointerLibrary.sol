pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentComponentPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillmentPointer is uint256;

using Scuff for MemoryPointer;
using FulfillmentPointerLibrary for FulfillmentPointer global;

/// @dev Library for resolving pointers of encoded Fulfillment
/// struct Fulfillment {
///   FulfillmentComponent[] offerComponents;
///   FulfillmentComponent[] considerationComponents;
/// }
library FulfillmentPointerLibrary {
  uint256 internal constant considerationComponentsOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;

  /// @dev Convert a `MemoryPointer` to a `FulfillmentPointer`.
  /// This adds `FulfillmentPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillmentPointer) {
    return FulfillmentPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `FulfillmentPointer` back into a `MemoryPointer`.
  function unwrap(FulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillmentPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `offerComponents` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerComponentsHead(FulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayFulfillmentComponentPointer` pointing to the data buffer of `offerComponents`
  function offerComponentsData(FulfillmentPointer ptr) internal pure returns (DynArrayFulfillmentComponentPointer) {
    return DynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(offerComponentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `considerationComponents` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationComponentsHead(FulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationComponentsOffset);
  }

  /// @dev Resolve the `DynArrayFulfillmentComponentPointer` pointing to the data buffer of `considerationComponents`
  function considerationComponentsData(FulfillmentPointer ptr) internal pure returns (DynArrayFulfillmentComponentPointer) {
    return DynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(considerationComponentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }
}