pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillmentComponentPointer is uint256;

using Scuff for MemoryPointer;
using FulfillmentComponentPointerLibrary for FulfillmentComponentPointer global;

/// @dev Library for resolving pointers of encoded FulfillmentComponent
/// struct FulfillmentComponent {
///   uint256 orderIndex;
///   uint256 itemIndex;
/// }
library FulfillmentComponentPointerLibrary {
  uint256 internal constant itemIndexOffset = 0x20;

  /// @dev Convert a `MemoryPointer` to a `FulfillmentComponentPointer`.
  /// This adds `FulfillmentComponentPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillmentComponentPointer) {
    return FulfillmentComponentPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `FulfillmentComponentPointer` back into a `MemoryPointer`.
  function unwrap(FulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillmentComponentPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `orderIndex` in memory.
  /// This points to the beginning of the encoded `uint256`
  function orderIndex(FulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the pointer to the head of `itemIndex` in memory.
  /// This points to the beginning of the encoded `uint256`
  function itemIndex(FulfillmentComponentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(itemIndexOffset);
  }
}