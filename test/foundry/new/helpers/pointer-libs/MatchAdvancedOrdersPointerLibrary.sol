// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentPointerLibrary.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./DynArrayAdvancedOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type MatchAdvancedOrdersPointer is uint256;

using Scuff for MemoryPointer;
using MatchAdvancedOrdersPointerLibrary for MatchAdvancedOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// matchAdvancedOrders(AdvancedOrder[],CriteriaResolver[],Fulfillment[],address)
library MatchAdvancedOrdersPointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_LengthOverflow, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_Overflow, orders_element_parameters_zone_Overflow, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_LengthOverflow, orders_element_parameters_offer_element_itemType_Overflow, orders_element_parameters_offer_element_token_Overflow, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_LengthOverflow, orders_element_parameters_consideration_element_itemType_Overflow, orders_element_parameters_consideration_element_token_Overflow, orders_element_parameters_consideration_element_recipient_Overflow, orders_element_parameters_orderType_Overflow, orders_element_numerator_Overflow, orders_element_denominator_Overflow, orders_element_signature_HeadOverflow, orders_element_signature_LengthOverflow, orders_element_signature_DirtyLowerBits, orders_element_extraData_HeadOverflow, orders_element_extraData_LengthOverflow, orders_element_extraData_DirtyLowerBits, criteriaResolvers_HeadOverflow, criteriaResolvers_LengthOverflow, criteriaResolvers_element_HeadOverflow, criteriaResolvers_element_side_Overflow, criteriaResolvers_element_criteriaProof_HeadOverflow, criteriaResolvers_element_criteriaProof_LengthOverflow, fulfillments_HeadOverflow, fulfillments_LengthOverflow, fulfillments_element_HeadOverflow, fulfillments_element_offerComponents_HeadOverflow, fulfillments_element_offerComponents_LengthOverflow, fulfillments_element_considerationComponents_HeadOverflow, fulfillments_element_considerationComponents_LengthOverflow, recipient_Overflow }

  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant fulfillmentsOffset = 0x40;
  uint256 internal constant recipientOffset = 0x60;
  uint256 internal constant OverflowedRecipient = 0x010000000000000000000000000000000000000000;
  uint256 internal constant HeadSize = 0x80;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_LengthOverflow);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_extraData_DirtyLowerBits);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_LengthOverflow);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow);
  uint256 internal constant MinimumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_LengthOverflow);
  uint256 internal constant MaximumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_element_considerationComponents_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `MatchAdvancedOrdersPointer`.
  /// This adds `MatchAdvancedOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (MatchAdvancedOrdersPointer) {
    return MatchAdvancedOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `MatchAdvancedOrdersPointer` back into a `MemoryPointer`.
  function unwrap(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(MatchAdvancedOrdersPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `matchAdvancedOrders`to a `MatchAdvancedOrdersPointer`.
  /// This adds `MatchAdvancedOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (MatchAdvancedOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `orders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function ordersHead(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayAdvancedOrderPointer` pointing to the data buffer of `orders`
  function ordersData(MatchAdvancedOrdersPointer ptr) internal pure returns (DynArrayAdvancedOrderPointer) {
    return DynArrayAdvancedOrderPointerLibrary.wrap(ptr.unwrap().offset(ordersHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `orders` (offset relative to parent).
  function addDirtyBitsToOrdersOffset(MatchAdvancedOrdersPointer ptr) internal pure {
    ordersHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(MatchAdvancedOrdersPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `criteriaResolvers` (offset relative to parent).
  function addDirtyBitsToCriteriaResolversOffset(MatchAdvancedOrdersPointer ptr) internal pure {
    criteriaResolversHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `fulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function fulfillmentsHead(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayFulfillmentPointer` pointing to the data buffer of `fulfillments`
  function fulfillmentsData(MatchAdvancedOrdersPointer ptr) internal pure returns (DynArrayFulfillmentPointer) {
    return DynArrayFulfillmentPointerLibrary.wrap(ptr.unwrap().offset(fulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `fulfillments` (offset relative to parent).
  function addDirtyBitsToFulfillmentsOffset(MatchAdvancedOrdersPointer ptr) internal pure {
    fulfillmentsHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Cause `recipient` to overflow
  function overflowRecipient(MatchAdvancedOrdersPointer ptr) internal pure {
    recipient(ptr).write(OverflowedRecipient);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(MatchAdvancedOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead()));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind);
    /// @dev Overflow offset for `criteriaResolvers`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_HeadOverflow) + kindOffset, 224, ptr.criteriaResolversHead()));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind);
    /// @dev Overflow offset for `fulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.fulfillments_HeadOverflow) + kindOffset, 224, ptr.fulfillmentsHead()));
    /// @dev Add all nested directives in fulfillments
    ptr.fulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumFulfillmentsScuffKind);
    /// @dev Induce overflow in `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_Overflow) + kindOffset, 96, ptr.recipient()));
  }

  function getScuffDirectives(MatchAdvancedOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.orders_HeadOverflow) return "orders_HeadOverflow";
    if (k == ScuffKind.orders_LengthOverflow) return "orders_LengthOverflow";
    if (k == ScuffKind.orders_element_HeadOverflow) return "orders_element_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_HeadOverflow) return "orders_element_parameters_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offerer_Overflow) return "orders_element_parameters_offerer_Overflow";
    if (k == ScuffKind.orders_element_parameters_zone_Overflow) return "orders_element_parameters_zone_Overflow";
    if (k == ScuffKind.orders_element_parameters_offer_HeadOverflow) return "orders_element_parameters_offer_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offer_LengthOverflow) return "orders_element_parameters_offer_LengthOverflow";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_Overflow) return "orders_element_parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_Overflow) return "orders_element_parameters_offer_element_token_Overflow";
    if (k == ScuffKind.orders_element_parameters_consideration_HeadOverflow) return "orders_element_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_consideration_LengthOverflow) return "orders_element_parameters_consideration_LengthOverflow";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_Overflow) return "orders_element_parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_Overflow) return "orders_element_parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_Overflow) return "orders_element_parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.orders_element_parameters_orderType_Overflow) return "orders_element_parameters_orderType_Overflow";
    if (k == ScuffKind.orders_element_numerator_Overflow) return "orders_element_numerator_Overflow";
    if (k == ScuffKind.orders_element_denominator_Overflow) return "orders_element_denominator_Overflow";
    if (k == ScuffKind.orders_element_signature_HeadOverflow) return "orders_element_signature_HeadOverflow";
    if (k == ScuffKind.orders_element_signature_LengthOverflow) return "orders_element_signature_LengthOverflow";
    if (k == ScuffKind.orders_element_signature_DirtyLowerBits) return "orders_element_signature_DirtyLowerBits";
    if (k == ScuffKind.orders_element_extraData_HeadOverflow) return "orders_element_extraData_HeadOverflow";
    if (k == ScuffKind.orders_element_extraData_LengthOverflow) return "orders_element_extraData_LengthOverflow";
    if (k == ScuffKind.orders_element_extraData_DirtyLowerBits) return "orders_element_extraData_DirtyLowerBits";
    if (k == ScuffKind.criteriaResolvers_HeadOverflow) return "criteriaResolvers_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_LengthOverflow) return "criteriaResolvers_LengthOverflow";
    if (k == ScuffKind.criteriaResolvers_element_HeadOverflow) return "criteriaResolvers_element_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_side_Overflow) return "criteriaResolvers_element_side_Overflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_HeadOverflow) return "criteriaResolvers_element_criteriaProof_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_LengthOverflow) return "criteriaResolvers_element_criteriaProof_LengthOverflow";
    if (k == ScuffKind.fulfillments_HeadOverflow) return "fulfillments_HeadOverflow";
    if (k == ScuffKind.fulfillments_LengthOverflow) return "fulfillments_LengthOverflow";
    if (k == ScuffKind.fulfillments_element_HeadOverflow) return "fulfillments_element_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_HeadOverflow) return "fulfillments_element_offerComponents_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_LengthOverflow) return "fulfillments_element_offerComponents_LengthOverflow";
    if (k == ScuffKind.fulfillments_element_considerationComponents_HeadOverflow) return "fulfillments_element_considerationComponents_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_considerationComponents_LengthOverflow) return "fulfillments_element_considerationComponents_LengthOverflow";
    return "recipient_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}