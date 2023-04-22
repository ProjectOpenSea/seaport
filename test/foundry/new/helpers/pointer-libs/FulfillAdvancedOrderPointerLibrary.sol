// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./AdvancedOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type FulfillAdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAdvancedOrderPointerLibrary for FulfillAdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAdvancedOrder(AdvancedOrder,CriteriaResolver[],bytes32,address)
library FulfillAdvancedOrderPointerLibrary {
  enum ScuffKind { advancedOrder_HeadOverflow, advancedOrder_parameters_HeadOverflow, advancedOrder_parameters_offerer_Overflow, advancedOrder_parameters_zone_Overflow, advancedOrder_parameters_offer_HeadOverflow, advancedOrder_parameters_offer_LengthOverflow, advancedOrder_parameters_offer_element_itemType_Overflow, advancedOrder_parameters_offer_element_token_Overflow, advancedOrder_parameters_consideration_HeadOverflow, advancedOrder_parameters_consideration_LengthOverflow, advancedOrder_parameters_consideration_element_itemType_Overflow, advancedOrder_parameters_consideration_element_token_Overflow, advancedOrder_parameters_consideration_element_recipient_Overflow, advancedOrder_parameters_orderType_Overflow, advancedOrder_numerator_Overflow, advancedOrder_denominator_Overflow, advancedOrder_signature_HeadOverflow, advancedOrder_signature_LengthOverflow, advancedOrder_signature_DirtyLowerBits, advancedOrder_extraData_HeadOverflow, advancedOrder_extraData_LengthOverflow, advancedOrder_extraData_DirtyLowerBits, criteriaResolvers_HeadOverflow, criteriaResolvers_LengthOverflow, criteriaResolvers_element_HeadOverflow, criteriaResolvers_element_side_Overflow, criteriaResolvers_element_criteriaProof_HeadOverflow, criteriaResolvers_element_criteriaProof_LengthOverflow, recipient_Overflow }

  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant fulfillerConduitKeyOffset = 0x40;
  uint256 internal constant recipientOffset = 0x60;
  uint256 internal constant OverflowedRecipient = 0x010000000000000000000000000000000000000000;
  uint256 internal constant HeadSize = 0x80;
  uint256 internal constant MinimumAdvancedOrderScuffKind = uint256(ScuffKind.advancedOrder_parameters_HeadOverflow);
  uint256 internal constant MaximumAdvancedOrderScuffKind = uint256(ScuffKind.advancedOrder_extraData_DirtyLowerBits);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_LengthOverflow);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `FulfillAdvancedOrderPointer`.
  /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAdvancedOrderPointer) {
    return FulfillAdvancedOrderPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAdvancedOrderPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAdvancedOrderPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAdvancedOrder`to a `FulfillAdvancedOrderPointer`.
  /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAdvancedOrderPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `advancedOrder` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function advancedOrderHead(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `AdvancedOrderPointer` pointing to the data buffer of `advancedOrder`
  function advancedOrderData(FulfillAdvancedOrderPointer ptr) internal pure returns (AdvancedOrderPointer) {
    return AdvancedOrderPointerLibrary.wrap(ptr.unwrap().offset(advancedOrderHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `advancedOrder` (offset relative to parent).
  function addDirtyBitsToAdvancedOrderOffset(FulfillAdvancedOrderPointer ptr) internal pure {
    advancedOrderHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(FulfillAdvancedOrderPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `criteriaResolvers` (offset relative to parent).
  function addDirtyBitsToCriteriaResolversOffset(FulfillAdvancedOrderPointer ptr) internal pure {
    criteriaResolversHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Cause `recipient` to overflow
  function overflowRecipient(FulfillAdvancedOrderPointer ptr) internal pure {
    recipient(ptr).write(OverflowedRecipient);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillAdvancedOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `advancedOrder`
    directives.push(Scuff.lower(uint256(ScuffKind.advancedOrder_HeadOverflow) + kindOffset, 224, ptr.advancedOrderHead()));
    /// @dev Add all nested directives in advancedOrder
    ptr.advancedOrderData().addScuffDirectives(directives, kindOffset + MinimumAdvancedOrderScuffKind);
    /// @dev Overflow offset for `criteriaResolvers`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_HeadOverflow) + kindOffset, 224, ptr.criteriaResolversHead()));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind);
    /// @dev Induce overflow in `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_Overflow) + kindOffset, 96, ptr.recipient()));
  }

  function getScuffDirectives(FulfillAdvancedOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.advancedOrder_HeadOverflow) return "advancedOrder_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_HeadOverflow) return "advancedOrder_parameters_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_offerer_Overflow) return "advancedOrder_parameters_offerer_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_zone_Overflow) return "advancedOrder_parameters_zone_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_offer_HeadOverflow) return "advancedOrder_parameters_offer_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_offer_LengthOverflow) return "advancedOrder_parameters_offer_LengthOverflow";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_itemType_Overflow) return "advancedOrder_parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_token_Overflow) return "advancedOrder_parameters_offer_element_token_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_HeadOverflow) return "advancedOrder_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_LengthOverflow) return "advancedOrder_parameters_consideration_LengthOverflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_itemType_Overflow) return "advancedOrder_parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_token_Overflow) return "advancedOrder_parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_recipient_Overflow) return "advancedOrder_parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.advancedOrder_parameters_orderType_Overflow) return "advancedOrder_parameters_orderType_Overflow";
    if (k == ScuffKind.advancedOrder_numerator_Overflow) return "advancedOrder_numerator_Overflow";
    if (k == ScuffKind.advancedOrder_denominator_Overflow) return "advancedOrder_denominator_Overflow";
    if (k == ScuffKind.advancedOrder_signature_HeadOverflow) return "advancedOrder_signature_HeadOverflow";
    if (k == ScuffKind.advancedOrder_signature_LengthOverflow) return "advancedOrder_signature_LengthOverflow";
    if (k == ScuffKind.advancedOrder_signature_DirtyLowerBits) return "advancedOrder_signature_DirtyLowerBits";
    if (k == ScuffKind.advancedOrder_extraData_HeadOverflow) return "advancedOrder_extraData_HeadOverflow";
    if (k == ScuffKind.advancedOrder_extraData_LengthOverflow) return "advancedOrder_extraData_LengthOverflow";
    if (k == ScuffKind.advancedOrder_extraData_DirtyLowerBits) return "advancedOrder_extraData_DirtyLowerBits";
    if (k == ScuffKind.criteriaResolvers_HeadOverflow) return "criteriaResolvers_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_LengthOverflow) return "criteriaResolvers_LengthOverflow";
    if (k == ScuffKind.criteriaResolvers_element_HeadOverflow) return "criteriaResolvers_element_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_side_Overflow) return "criteriaResolvers_element_side_Overflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_HeadOverflow) return "criteriaResolvers_element_criteriaProof_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow) return "criteriaResolvers_element_criteriaProof_LengthOverflow";
    return "recipient_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}