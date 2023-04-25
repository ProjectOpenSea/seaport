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
  enum ScuffKind { offerComponents_head_DirtyBits, offerComponents_head_MaxValue, offerComponents_length_DirtyBits, offerComponents_length_MaxValue, considerationComponents_head_DirtyBits, considerationComponents_head_MaxValue, considerationComponents_length_DirtyBits, considerationComponents_length_MaxValue }

  enum ScuffableField { offerComponents_head, offerComponents, considerationComponents_head, considerationComponents }

  uint256 internal constant considerationComponentsOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOfferComponentsScuffKind = uint256(ScuffKind.offerComponents_length_DirtyBits);
  uint256 internal constant MaximumOfferComponentsScuffKind = uint256(ScuffKind.offerComponents_length_MaxValue);
  uint256 internal constant MinimumConsiderationComponentsScuffKind = uint256(ScuffKind.considerationComponents_length_DirtyBits);
  uint256 internal constant MaximumConsiderationComponentsScuffKind = uint256(ScuffKind.considerationComponents_length_MaxValue);

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

  function addScuffDirectives(FulfillmentPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to offerComponents head
    directives.push(Scuff.upper(uint256(ScuffKind.offerComponents_head_DirtyBits) + kindOffset, 224, ptr.offerComponentsHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.offerComponents_head_MaxValue) + kindOffset, 229, ptr.offerComponentsHead(), positions));
    /// @dev Add all nested directives in offerComponents
    ptr.offerComponentsData().addScuffDirectives(directives, kindOffset + MinimumOfferComponentsScuffKind, positions);
    /// @dev Add dirty upper bits to considerationComponents head
    directives.push(Scuff.upper(uint256(ScuffKind.considerationComponents_head_DirtyBits) + kindOffset, 224, ptr.considerationComponentsHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.considerationComponents_head_MaxValue) + kindOffset, 229, ptr.considerationComponentsHead(), positions));
    /// @dev Add all nested directives in considerationComponents
    ptr.considerationComponentsData().addScuffDirectives(directives, kindOffset + MinimumConsiderationComponentsScuffKind, positions);
  }

  function getScuffDirectives(FulfillmentPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.offerComponents_head_DirtyBits) return "offerComponents_head_DirtyBits";
    if (k == ScuffKind.offerComponents_head_MaxValue) return "offerComponents_head_MaxValue";
    if (k == ScuffKind.offerComponents_length_DirtyBits) return "offerComponents_length_DirtyBits";
    if (k == ScuffKind.offerComponents_length_MaxValue) return "offerComponents_length_MaxValue";
    if (k == ScuffKind.considerationComponents_head_DirtyBits) return "considerationComponents_head_DirtyBits";
    if (k == ScuffKind.considerationComponents_head_MaxValue) return "considerationComponents_head_MaxValue";
    if (k == ScuffKind.considerationComponents_length_DirtyBits) return "considerationComponents_length_DirtyBits";
    return "considerationComponents_length_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}