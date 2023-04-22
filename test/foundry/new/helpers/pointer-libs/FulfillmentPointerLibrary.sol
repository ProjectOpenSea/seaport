// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentComponentPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type FulfillmentPointer is uint256;

using Scuff for MemoryPointer;
using FulfillmentPointerLibrary for FulfillmentPointer global;

/// @dev Library for resolving pointers of encoded Fulfillment
/// struct Fulfillment {
///   FulfillmentComponent[] offerComponents;
///   FulfillmentComponent[] considerationComponents;
/// }
library FulfillmentPointerLibrary {
  enum ScuffKind { offerComponents_HeadOverflow, offerComponents_LengthOverflow, considerationComponents_HeadOverflow, considerationComponents_LengthOverflow }

  uint256 internal constant considerationComponentsOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOfferComponentsScuffKind = uint256(ScuffKind.offerComponents_LengthOverflow);
  uint256 internal constant MaximumOfferComponentsScuffKind = uint256(ScuffKind.offerComponents_LengthOverflow);
  uint256 internal constant MinimumConsiderationComponentsScuffKind = uint256(ScuffKind.considerationComponents_LengthOverflow);
  uint256 internal constant MaximumConsiderationComponentsScuffKind = uint256(ScuffKind.considerationComponents_LengthOverflow);

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

  /// @dev Add dirty bits to the head for `offerComponents` (offset relative to parent).
  function addDirtyBitsToOfferComponentsOffset(FulfillmentPointer ptr) internal pure {
    offerComponentsHead(ptr).addDirtyBitsBefore(224);
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

  /// @dev Add dirty bits to the head for `considerationComponents` (offset relative to parent).
  function addDirtyBitsToConsiderationComponentsOffset(FulfillmentPointer ptr) internal pure {
    considerationComponentsHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillmentPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillmentPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `offerComponents`
    directives.push(Scuff.lower(uint256(ScuffKind.offerComponents_HeadOverflow) + kindOffset, 224, ptr.offerComponentsHead()));
    /// @dev Add all nested directives in offerComponents
    ptr.offerComponentsData().addScuffDirectives(directives, kindOffset + MinimumOfferComponentsScuffKind);
    /// @dev Overflow offset for `considerationComponents`
    directives.push(Scuff.lower(uint256(ScuffKind.considerationComponents_HeadOverflow) + kindOffset, 224, ptr.considerationComponentsHead()));
    /// @dev Add all nested directives in considerationComponents
    ptr.considerationComponentsData().addScuffDirectives(directives, kindOffset + MinimumConsiderationComponentsScuffKind);
  }

  function getScuffDirectives(FulfillmentPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.offerComponents_HeadOverflow) return "offerComponents_HeadOverflow";
    if (k == ScuffKind.offerComponents_LengthOverflow) return "offerComponents_LengthOverflow";
    if (k == ScuffKind.considerationComponents_HeadOverflow) return "considerationComponents_HeadOverflow";
    return "considerationComponents_LengthOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}