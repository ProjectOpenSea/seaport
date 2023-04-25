pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./BytesPointerLibrary.sol";
import "./OrderParametersPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type OrderPointer is uint256;

using Scuff for MemoryPointer;
using OrderPointerLibrary for OrderPointer global;

/// @dev Library for resolving pointers of encoded Order
/// struct Order {
///   OrderParameters parameters;
///   bytes signature;
/// }
library OrderPointerLibrary {
  enum ScuffKind { parameters_HeadOverflow, parameters_offerer_DirtyBits, parameters_offerer_MaxValue, parameters_zone_DirtyBits, parameters_zone_MaxValue, parameters_offer_HeadOverflow, parameters_offer_length_DirtyBits, parameters_offer_length_MaxValue, parameters_offer_element_itemType_DirtyBits, parameters_offer_element_itemType_MaxValue, parameters_offer_element_token_DirtyBits, parameters_offer_element_token_MaxValue, parameters_consideration_HeadOverflow, parameters_consideration_length_DirtyBits, parameters_consideration_length_MaxValue, parameters_consideration_element_itemType_DirtyBits, parameters_consideration_element_itemType_MaxValue, parameters_consideration_element_token_DirtyBits, parameters_consideration_element_token_MaxValue, parameters_consideration_element_recipient_DirtyBits, parameters_consideration_element_recipient_MaxValue, parameters_orderType_DirtyBits, parameters_orderType_MaxValue, signature_HeadOverflow }

  enum ScuffableField { parameters, signature }

  uint256 internal constant signatureOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumParametersScuffKind = uint256(ScuffKind.parameters_offerer_DirtyBits);
  uint256 internal constant MaximumParametersScuffKind = uint256(ScuffKind.parameters_orderType_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `OrderPointer`.
  /// This adds `OrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (OrderPointer) {
    return OrderPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `OrderPointer` back into a `MemoryPointer`.
  function unwrap(OrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(OrderPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `parameters` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function parametersHead(OrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `OrderParametersPointer` pointing to the data buffer of `parameters`
  function parametersData(OrderPointer ptr) internal pure returns (OrderParametersPointer) {
    return OrderParametersPointerLibrary.wrap(ptr.unwrap().offset(parametersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `signature` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function signatureHead(OrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(signatureOffset);
  }

  /// @dev Resolve the `BytesPointer` pointing to the data buffer of `signature`
  function signatureData(OrderPointer ptr) internal pure returns (BytesPointer) {
    return BytesPointerLibrary.wrap(ptr.unwrap().offset(signatureHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(OrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(OrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Overflow offset for `parameters`
    directives.push(Scuff.lower(uint256(ScuffKind.parameters_HeadOverflow) + kindOffset, 224, ptr.parametersHead(), positions));
    /// @dev Add all nested directives in parameters
    ptr.parametersData().addScuffDirectives(directives, kindOffset + MinimumParametersScuffKind, positions);
    /// @dev Overflow offset for `signature`
    directives.push(Scuff.lower(uint256(ScuffKind.signature_HeadOverflow) + kindOffset, 224, ptr.signatureHead(), positions));
  }

  function getScuffDirectives(OrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.parameters_HeadOverflow) return "parameters_HeadOverflow";
    if (k == ScuffKind.parameters_offerer_DirtyBits) return "parameters_offerer_DirtyBits";
    if (k == ScuffKind.parameters_offerer_MaxValue) return "parameters_offerer_MaxValue";
    if (k == ScuffKind.parameters_zone_DirtyBits) return "parameters_zone_DirtyBits";
    if (k == ScuffKind.parameters_zone_MaxValue) return "parameters_zone_MaxValue";
    if (k == ScuffKind.parameters_offer_HeadOverflow) return "parameters_offer_HeadOverflow";
    if (k == ScuffKind.parameters_offer_length_DirtyBits) return "parameters_offer_length_DirtyBits";
    if (k == ScuffKind.parameters_offer_length_MaxValue) return "parameters_offer_length_MaxValue";
    if (k == ScuffKind.parameters_offer_element_itemType_DirtyBits) return "parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.parameters_offer_element_itemType_MaxValue) return "parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.parameters_offer_element_token_DirtyBits) return "parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.parameters_offer_element_token_MaxValue) return "parameters_offer_element_token_MaxValue";
    if (k == ScuffKind.parameters_consideration_HeadOverflow) return "parameters_consideration_HeadOverflow";
    if (k == ScuffKind.parameters_consideration_length_DirtyBits) return "parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.parameters_consideration_length_MaxValue) return "parameters_consideration_length_MaxValue";
    if (k == ScuffKind.parameters_consideration_element_itemType_DirtyBits) return "parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.parameters_consideration_element_itemType_MaxValue) return "parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.parameters_consideration_element_token_DirtyBits) return "parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.parameters_consideration_element_token_MaxValue) return "parameters_consideration_element_token_MaxValue";
    if (k == ScuffKind.parameters_consideration_element_recipient_DirtyBits) return "parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.parameters_consideration_element_recipient_MaxValue) return "parameters_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.parameters_orderType_DirtyBits) return "parameters_orderType_DirtyBits";
    if (k == ScuffKind.parameters_orderType_MaxValue) return "parameters_orderType_MaxValue";
    return "signature_HeadOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}