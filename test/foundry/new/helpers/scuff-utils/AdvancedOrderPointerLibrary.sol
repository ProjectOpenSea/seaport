pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./BytesPointerLibrary.sol";
import "./OrderParametersPointerLibrary.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type AdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using AdvancedOrderPointerLibrary for AdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded AdvancedOrder
/// struct AdvancedOrder {
///   OrderParameters parameters;
///   uint120 numerator;
///   uint120 denominator;
///   bytes signature;
///   bytes extraData;
/// }
library AdvancedOrderPointerLibrary {
  enum ScuffKind { parameters_head_DirtyBits, parameters_head_MaxValue, parameters_offer_head_DirtyBits, parameters_offer_head_MaxValue, parameters_offer_length_DirtyBits, parameters_offer_length_MaxValue, parameters_offer_element_itemType_MaxValue, parameters_consideration_head_DirtyBits, parameters_consideration_head_MaxValue, parameters_consideration_length_DirtyBits, parameters_consideration_length_MaxValue, parameters_consideration_element_itemType_MaxValue, parameters_consideration_element_recipient_DirtyBits, parameters_orderType_MaxValue, signature_head_DirtyBits, signature_head_MaxValue, signature_length_DirtyBits, signature_length_MaxValue, signature_DirtyLowerBits, extraData_head_DirtyBits, extraData_head_MaxValue, extraData_length_DirtyBits, extraData_length_MaxValue, extraData_DirtyLowerBits }

  enum ScuffableField { parameters_head, parameters, signature_head, signature, extraData_head, extraData }

  uint256 internal constant numeratorOffset = 0x20;
  uint256 internal constant denominatorOffset = 0x40;
  uint256 internal constant signatureOffset = 0x60;
  uint256 internal constant extraDataOffset = 0x80;
  uint256 internal constant HeadSize = 0xa0;
  uint256 internal constant MinimumParametersScuffKind = uint256(ScuffKind.parameters_offer_head_DirtyBits);
  uint256 internal constant MaximumParametersScuffKind = uint256(ScuffKind.parameters_orderType_MaxValue);
  uint256 internal constant MinimumSignatureScuffKind = uint256(ScuffKind.signature_length_DirtyBits);
  uint256 internal constant MaximumSignatureScuffKind = uint256(ScuffKind.signature_DirtyLowerBits);
  uint256 internal constant MinimumExtraDataScuffKind = uint256(ScuffKind.extraData_length_DirtyBits);
  uint256 internal constant MaximumExtraDataScuffKind = uint256(ScuffKind.extraData_DirtyLowerBits);

  /// @dev Convert a `MemoryPointer` to a `AdvancedOrderPointer`.
  /// This adds `AdvancedOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (AdvancedOrderPointer) {
    return AdvancedOrderPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `AdvancedOrderPointer` back into a `MemoryPointer`.
  function unwrap(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(AdvancedOrderPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `parameters` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function parametersHead(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `OrderParametersPointer` pointing to the data buffer of `parameters`
  function parametersData(AdvancedOrderPointer ptr) internal pure returns (OrderParametersPointer) {
    return OrderParametersPointerLibrary.wrap(ptr.unwrap().offset(parametersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `numerator` in memory.
  /// This points to the beginning of the encoded `uint120`
  function numerator(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(numeratorOffset);
  }

  /// @dev Resolve the pointer to the head of `denominator` in memory.
  /// This points to the beginning of the encoded `uint120`
  function denominator(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(denominatorOffset);
  }

  /// @dev Resolve the pointer to the head of `signature` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function signatureHead(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(signatureOffset);
  }

  /// @dev Resolve the `BytesPointer` pointing to the data buffer of `signature`
  function signatureData(AdvancedOrderPointer ptr) internal pure returns (BytesPointer) {
    return BytesPointerLibrary.wrap(ptr.unwrap().offset(signatureHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `extraData` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function extraDataHead(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(extraDataOffset);
  }

  /// @dev Resolve the `BytesPointer` pointing to the data buffer of `extraData`
  function extraDataData(AdvancedOrderPointer ptr) internal pure returns (BytesPointer) {
    return BytesPointerLibrary.wrap(ptr.unwrap().offset(extraDataHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(AdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(AdvancedOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to parameters head
    directives.push(Scuff.upper(uint256(ScuffKind.parameters_head_DirtyBits) + kindOffset, 224, ptr.parametersHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.parameters_head_MaxValue) + kindOffset, 229, ptr.parametersHead(), positions));
    /// @dev Add all nested directives in parameters
    ptr.parametersData().addScuffDirectives(directives, kindOffset + MinimumParametersScuffKind, positions);
    /// @dev Add dirty upper bits to signature head
    directives.push(Scuff.upper(uint256(ScuffKind.signature_head_DirtyBits) + kindOffset, 224, ptr.signatureHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.signature_head_MaxValue) + kindOffset, 229, ptr.signatureHead(), positions));
    /// @dev Add all nested directives in signature
    ptr.signatureData().addScuffDirectives(directives, kindOffset + MinimumSignatureScuffKind, positions);
    /// @dev Add dirty upper bits to extraData head
    directives.push(Scuff.upper(uint256(ScuffKind.extraData_head_DirtyBits) + kindOffset, 224, ptr.extraDataHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.extraData_head_MaxValue) + kindOffset, 229, ptr.extraDataHead(), positions));
    /// @dev Add all nested directives in extraData
    ptr.extraDataData().addScuffDirectives(directives, kindOffset + MinimumExtraDataScuffKind, positions);
  }

  function getScuffDirectives(AdvancedOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.parameters_head_DirtyBits) return "parameters_head_DirtyBits";
    if (k == ScuffKind.parameters_head_MaxValue) return "parameters_head_MaxValue";
    if (k == ScuffKind.parameters_offer_head_DirtyBits) return "parameters_offer_head_DirtyBits";
    if (k == ScuffKind.parameters_offer_head_MaxValue) return "parameters_offer_head_MaxValue";
    if (k == ScuffKind.parameters_offer_length_DirtyBits) return "parameters_offer_length_DirtyBits";
    if (k == ScuffKind.parameters_offer_length_MaxValue) return "parameters_offer_length_MaxValue";
    if (k == ScuffKind.parameters_offer_element_itemType_MaxValue) return "parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.parameters_consideration_head_DirtyBits) return "parameters_consideration_head_DirtyBits";
    if (k == ScuffKind.parameters_consideration_head_MaxValue) return "parameters_consideration_head_MaxValue";
    if (k == ScuffKind.parameters_consideration_length_DirtyBits) return "parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.parameters_consideration_length_MaxValue) return "parameters_consideration_length_MaxValue";
    if (k == ScuffKind.parameters_consideration_element_itemType_MaxValue) return "parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.parameters_consideration_element_recipient_DirtyBits) return "parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.parameters_orderType_MaxValue) return "parameters_orderType_MaxValue";
    if (k == ScuffKind.signature_head_DirtyBits) return "signature_head_DirtyBits";
    if (k == ScuffKind.signature_head_MaxValue) return "signature_head_MaxValue";
    if (k == ScuffKind.signature_length_DirtyBits) return "signature_length_DirtyBits";
    if (k == ScuffKind.signature_length_MaxValue) return "signature_length_MaxValue";
    if (k == ScuffKind.signature_DirtyLowerBits) return "signature_DirtyLowerBits";
    if (k == ScuffKind.extraData_head_DirtyBits) return "extraData_head_DirtyBits";
    if (k == ScuffKind.extraData_head_MaxValue) return "extraData_head_MaxValue";
    if (k == ScuffKind.extraData_length_DirtyBits) return "extraData_length_DirtyBits";
    if (k == ScuffKind.extraData_length_MaxValue) return "extraData_length_MaxValue";
    return "extraData_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}