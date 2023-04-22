// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayDynArrayFulfillmentComponentPointerLibrary.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./DynArrayAdvancedOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type FulfillAvailableAdvancedOrdersPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAvailableAdvancedOrdersPointerLibrary for FulfillAvailableAdvancedOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAvailableAdvancedOrders(AdvancedOrder[],CriteriaResolver[],FulfillmentComponent[][],FulfillmentComponent[][],bytes32,address,uint256)
library FulfillAvailableAdvancedOrdersPointerLibrary {
  enum ScuffKind { advancedOrders_HeadOverflow, advancedOrders_LengthOverflow, advancedOrders_element_HeadOverflow, advancedOrders_element_parameters_HeadOverflow, advancedOrders_element_parameters_offerer_Overflow, advancedOrders_element_parameters_zone_Overflow, advancedOrders_element_parameters_offer_HeadOverflow, advancedOrders_element_parameters_offer_LengthOverflow, advancedOrders_element_parameters_offer_element_itemType_Overflow, advancedOrders_element_parameters_offer_element_token_Overflow, advancedOrders_element_parameters_consideration_HeadOverflow, advancedOrders_element_parameters_consideration_LengthOverflow, advancedOrders_element_parameters_consideration_element_itemType_Overflow, advancedOrders_element_parameters_consideration_element_token_Overflow, advancedOrders_element_parameters_consideration_element_recipient_Overflow, advancedOrders_element_parameters_orderType_Overflow, advancedOrders_element_numerator_Overflow, advancedOrders_element_denominator_Overflow, advancedOrders_element_signature_HeadOverflow, advancedOrders_element_signature_LengthOverflow, advancedOrders_element_signature_DirtyLowerBits, advancedOrders_element_extraData_HeadOverflow, advancedOrders_element_extraData_LengthOverflow, advancedOrders_element_extraData_DirtyLowerBits, criteriaResolvers_HeadOverflow, criteriaResolvers_LengthOverflow, criteriaResolvers_element_HeadOverflow, criteriaResolvers_element_side_Overflow, criteriaResolvers_element_criteriaProof_HeadOverflow, criteriaResolvers_element_criteriaProof_LengthOverflow, offerFulfillments_HeadOverflow, offerFulfillments_LengthOverflow, offerFulfillments_element_HeadOverflow, offerFulfillments_element_LengthOverflow, considerationFulfillments_HeadOverflow, considerationFulfillments_LengthOverflow, considerationFulfillments_element_HeadOverflow, considerationFulfillments_element_LengthOverflow, recipient_Overflow }

  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant offerFulfillmentsOffset = 0x40;
  uint256 internal constant considerationFulfillmentsOffset = 0x60;
  uint256 internal constant fulfillerConduitKeyOffset = 0x80;
  uint256 internal constant recipientOffset = 0xa0;
  uint256 internal constant OverflowedRecipient = 0x010000000000000000000000000000000000000000;
  uint256 internal constant maximumFulfilledOffset = 0xc0;
  uint256 internal constant HeadSize = 0xe0;
  uint256 internal constant MinimumAdvancedOrdersScuffKind = uint256(ScuffKind.advancedOrders_LengthOverflow);
  uint256 internal constant MaximumAdvancedOrdersScuffKind = uint256(ScuffKind.advancedOrders_element_extraData_DirtyLowerBits);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_LengthOverflow);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow);
  uint256 internal constant MinimumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_LengthOverflow);
  uint256 internal constant MaximumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_element_LengthOverflow);
  uint256 internal constant MinimumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_LengthOverflow);
  uint256 internal constant MaximumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_element_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `FulfillAvailableAdvancedOrdersPointer`.
  /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAvailableAdvancedOrdersPointer) {
    return FulfillAvailableAdvancedOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAvailableAdvancedOrdersPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAvailableAdvancedOrdersPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAvailableAdvancedOrders`to a `FulfillAvailableAdvancedOrdersPointer`.
  /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAvailableAdvancedOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `advancedOrders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function advancedOrdersHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayAdvancedOrderPointer` pointing to the data buffer of `advancedOrders`
  function advancedOrdersData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayAdvancedOrderPointer) {
    return DynArrayAdvancedOrderPointerLibrary.wrap(ptr.unwrap().offset(advancedOrdersHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `advancedOrders` (offset relative to parent).
  function addDirtyBitsToAdvancedOrdersOffset(FulfillAvailableAdvancedOrdersPointer ptr) internal pure {
    advancedOrdersHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `criteriaResolvers` (offset relative to parent).
  function addDirtyBitsToCriteriaResolversOffset(FulfillAvailableAdvancedOrdersPointer ptr) internal pure {
    criteriaResolversHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `offerFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerFulfillmentsHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(offerFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `offerFulfillments`
  function offerFulfillmentsData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(offerFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `offerFulfillments` (offset relative to parent).
  function addDirtyBitsToOfferFulfillmentsOffset(FulfillAvailableAdvancedOrdersPointer ptr) internal pure {
    offerFulfillmentsHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `considerationFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationFulfillmentsHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `considerationFulfillments`
  function considerationFulfillmentsData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(considerationFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `considerationFulfillments` (offset relative to parent).
  function addDirtyBitsToConsiderationFulfillmentsOffset(FulfillAvailableAdvancedOrdersPointer ptr) internal pure {
    considerationFulfillmentsHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Cause `recipient` to overflow
  function overflowRecipient(FulfillAvailableAdvancedOrdersPointer ptr) internal pure {
    recipient(ptr).write(OverflowedRecipient);
  }

  /// @dev Resolve the pointer to the head of `maximumFulfilled` in memory.
  /// This points to the beginning of the encoded `uint256`
  function maximumFulfilled(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(maximumFulfilledOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillAvailableAdvancedOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `advancedOrders`
    directives.push(Scuff.lower(uint256(ScuffKind.advancedOrders_HeadOverflow) + kindOffset, 224, ptr.advancedOrdersHead()));
    /// @dev Add all nested directives in advancedOrders
    ptr.advancedOrdersData().addScuffDirectives(directives, kindOffset + MinimumAdvancedOrdersScuffKind);
    /// @dev Overflow offset for `criteriaResolvers`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_HeadOverflow) + kindOffset, 224, ptr.criteriaResolversHead()));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind);
    /// @dev Overflow offset for `offerFulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.offerFulfillments_HeadOverflow) + kindOffset, 224, ptr.offerFulfillmentsHead()));
    /// @dev Add all nested directives in offerFulfillments
    ptr.offerFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumOfferFulfillmentsScuffKind);
    /// @dev Overflow offset for `considerationFulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.considerationFulfillments_HeadOverflow) + kindOffset, 224, ptr.considerationFulfillmentsHead()));
    /// @dev Add all nested directives in considerationFulfillments
    ptr.considerationFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumConsiderationFulfillmentsScuffKind);
    /// @dev Induce overflow in `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_Overflow) + kindOffset, 96, ptr.recipient()));
  }

  function getScuffDirectives(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.advancedOrders_HeadOverflow) return "advancedOrders_HeadOverflow";
    if (k == ScuffKind.advancedOrders_LengthOverflow) return "advancedOrders_LengthOverflow";
    if (k == ScuffKind.advancedOrders_element_HeadOverflow) return "advancedOrders_element_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_HeadOverflow) return "advancedOrders_element_parameters_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_offerer_Overflow) return "advancedOrders_element_parameters_offerer_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_zone_Overflow) return "advancedOrders_element_parameters_zone_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_HeadOverflow) return "advancedOrders_element_parameters_offer_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_LengthOverflow) return "advancedOrders_element_parameters_offer_LengthOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_element_itemType_Overflow) return "advancedOrders_element_parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_element_token_Overflow) return "advancedOrders_element_parameters_offer_element_token_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_HeadOverflow) return "advancedOrders_element_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_LengthOverflow) return "advancedOrders_element_parameters_consideration_LengthOverflow";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_element_itemType_Overflow) return "advancedOrders_element_parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_element_token_Overflow) return "advancedOrders_element_parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_element_recipient_Overflow) return "advancedOrders_element_parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.advancedOrders_element_parameters_orderType_Overflow) return "advancedOrders_element_parameters_orderType_Overflow";
    if (k == ScuffKind.advancedOrders_element_numerator_Overflow) return "advancedOrders_element_numerator_Overflow";
    if (k == ScuffKind.advancedOrders_element_denominator_Overflow) return "advancedOrders_element_denominator_Overflow";
    if (k == ScuffKind.advancedOrders_element_signature_HeadOverflow) return "advancedOrders_element_signature_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_signature_LengthOverflow) return "advancedOrders_element_signature_LengthOverflow";
    if (k == ScuffKind.advancedOrders_element_signature_DirtyLowerBits) return "advancedOrders_element_signature_DirtyLowerBits";
    if (k == ScuffKind.advancedOrders_element_extraData_HeadOverflow) return "advancedOrders_element_extraData_HeadOverflow";
    if (k == ScuffKind.advancedOrders_element_extraData_LengthOverflow) return "advancedOrders_element_extraData_LengthOverflow";
    if (k == ScuffKind.advancedOrders_element_extraData_DirtyLowerBits) return "advancedOrders_element_extraData_DirtyLowerBits";
    if (k == ScuffKind.criteriaResolvers_HeadOverflow) return "criteriaResolvers_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_LengthOverflow) return "criteriaResolvers_LengthOverflow";
    if (k == ScuffKind.criteriaResolvers_element_HeadOverflow) return "criteriaResolvers_element_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_side_Overflow) return "criteriaResolvers_element_side_Overflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_HeadOverflow) return "criteriaResolvers_element_criteriaProof_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow) return "criteriaResolvers_element_criteriaProof_LengthOverflow";
    if (k == ScuffKind.offerFulfillments_HeadOverflow) return "offerFulfillments_HeadOverflow";
    if (k == ScuffKind.offerFulfillments_LengthOverflow) return "offerFulfillments_LengthOverflow";
    if (k == ScuffKind.offerFulfillments_element_HeadOverflow) return "offerFulfillments_element_HeadOverflow";
    if (k == ScuffKind.offerFulfillments_element_LengthOverflow) return "offerFulfillments_element_LengthOverflow";
    if (k == ScuffKind.considerationFulfillments_HeadOverflow) return "considerationFulfillments_HeadOverflow";
    if (k == ScuffKind.considerationFulfillments_LengthOverflow) return "considerationFulfillments_LengthOverflow";
    if (k == ScuffKind.considerationFulfillments_element_HeadOverflow) return "considerationFulfillments_element_HeadOverflow";
    if (k == ScuffKind.considerationFulfillments_element_LengthOverflow) return "considerationFulfillments_element_LengthOverflow";
    return "recipient_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}