// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./BytesPointerLibrary.sol";
import "./OrderParametersPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type OrderPointer is uint256;

using Scuff for MemoryPointer;
using OrderPointerLibrary for OrderPointer global;

/// @dev Library for resolving pointers of encoded Order
/// struct Order {
///   OrderParameters parameters;
///   bytes signature;
/// }
library OrderPointerLibrary {
  enum ScuffKind { parameters_HeadOverflow, parameters_offerer_Overflow, parameters_zone_Overflow, parameters_offer_HeadOverflow, parameters_offer_LengthOverflow, parameters_offer_element_itemType_Overflow, parameters_offer_element_token_Overflow, parameters_consideration_HeadOverflow, parameters_consideration_LengthOverflow, parameters_consideration_element_itemType_Overflow, parameters_consideration_element_token_Overflow, parameters_consideration_element_recipient_Overflow, parameters_orderType_Overflow, signature_HeadOverflow, signature_LengthOverflow, signature_DirtyLowerBits }

  uint256 internal constant signatureOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumParametersScuffKind = uint256(ScuffKind.parameters_offerer_Overflow);
  uint256 internal constant MaximumParametersScuffKind = uint256(ScuffKind.parameters_orderType_Overflow);
  uint256 internal constant MinimumSignatureScuffKind = uint256(ScuffKind.signature_LengthOverflow);
  uint256 internal constant MaximumSignatureScuffKind = uint256(ScuffKind.signature_DirtyLowerBits);

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

  /// @dev Add dirty bits to the head for `parameters` (offset relative to parent).
  function addDirtyBitsToParametersOffset(OrderPointer ptr) internal pure {
    parametersHead(ptr).addDirtyBitsBefore(224);
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

  /// @dev Add dirty bits to the head for `signature` (offset relative to parent).
  function addDirtyBitsToSignatureOffset(OrderPointer ptr) internal pure {
    signatureHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(OrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(OrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `parameters`
    directives.push(Scuff.lower(uint256(ScuffKind.parameters_HeadOverflow) + kindOffset, 224, ptr.parametersHead()));
    /// @dev Add all nested directives in parameters
    ptr.parametersData().addScuffDirectives(directives, kindOffset + MinimumParametersScuffKind);
    /// @dev Overflow offset for `signature`
    directives.push(Scuff.lower(uint256(ScuffKind.signature_HeadOverflow) + kindOffset, 224, ptr.signatureHead()));
    /// @dev Add all nested directives in signature
    ptr.signatureData().addScuffDirectives(directives, kindOffset + MinimumSignatureScuffKind);
  }

  function getScuffDirectives(OrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.parameters_HeadOverflow) return "parameters_HeadOverflow";
    if (k == ScuffKind.parameters_offerer_Overflow) return "parameters_offerer_Overflow";
    if (k == ScuffKind.parameters_zone_Overflow) return "parameters_zone_Overflow";
    if (k == ScuffKind.parameters_offer_HeadOverflow) return "parameters_offer_HeadOverflow";
    if (k == ScuffKind.parameters_offer_LengthOverflow) return "parameters_offer_LengthOverflow";
    if (k == ScuffKind.parameters_offer_element_itemType_Overflow) return "parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.parameters_offer_element_token_Overflow) return "parameters_offer_element_token_Overflow";
    if (k == ScuffKind.parameters_consideration_HeadOverflow) return "parameters_consideration_HeadOverflow";
    if (k == ScuffKind.parameters_consideration_LengthOverflow) return "parameters_consideration_LengthOverflow";
    if (k == ScuffKind.parameters_consideration_element_itemType_Overflow) return "parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.parameters_consideration_element_token_Overflow) return "parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.parameters_consideration_element_recipient_Overflow) return "parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.parameters_orderType_Overflow) return "parameters_orderType_Overflow";
    if (k == ScuffKind.signature_HeadOverflow) return "signature_HeadOverflow";
    if (k == ScuffKind.signature_LengthOverflow) return "signature_LengthOverflow";
    return "signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}