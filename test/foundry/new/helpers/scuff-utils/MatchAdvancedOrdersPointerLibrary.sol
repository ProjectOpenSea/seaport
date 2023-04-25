pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentPointerLibrary.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./DynArrayAdvancedOrderPointerLibrary.sol";
import { AdvancedOrder, CriteriaResolver, Fulfillment } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type MatchAdvancedOrdersPointer is uint256;

using Scuff for MemoryPointer;
using MatchAdvancedOrdersPointerLibrary for MatchAdvancedOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// matchAdvancedOrders(AdvancedOrder[],CriteriaResolver[],Fulfillment[],address)
library MatchAdvancedOrdersPointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_length_DirtyBits, orders_length_MaxValue, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_DirtyBits, orders_element_parameters_offerer_MaxValue, orders_element_parameters_zone_DirtyBits, orders_element_parameters_zone_MaxValue, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_length_DirtyBits, orders_element_parameters_offer_length_MaxValue, orders_element_parameters_offer_element_itemType_DirtyBits, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_offer_element_token_DirtyBits, orders_element_parameters_offer_element_token_MaxValue, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_length_DirtyBits, orders_element_parameters_consideration_length_MaxValue, orders_element_parameters_consideration_element_itemType_DirtyBits, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_consideration_element_token_DirtyBits, orders_element_parameters_consideration_element_token_MaxValue, orders_element_parameters_consideration_element_recipient_DirtyBits, orders_element_parameters_consideration_element_recipient_MaxValue, orders_element_parameters_orderType_DirtyBits, orders_element_parameters_orderType_MaxValue, orders_element_numerator_DirtyBits, orders_element_numerator_MaxValue, orders_element_denominator_DirtyBits, orders_element_denominator_MaxValue, orders_element_signature_HeadOverflow, orders_element_extraData_HeadOverflow, criteriaResolvers_HeadOverflow, criteriaResolvers_length_DirtyBits, criteriaResolvers_length_MaxValue, criteriaResolvers_element_HeadOverflow, criteriaResolvers_element_side_DirtyBits, criteriaResolvers_element_side_MaxValue, criteriaResolvers_element_criteriaProof_HeadOverflow, criteriaResolvers_element_criteriaProof_length_DirtyBits, criteriaResolvers_element_criteriaProof_length_MaxValue, fulfillments_HeadOverflow, fulfillments_length_DirtyBits, fulfillments_length_MaxValue, fulfillments_element_HeadOverflow, fulfillments_element_offerComponents_HeadOverflow, fulfillments_element_offerComponents_length_DirtyBits, fulfillments_element_offerComponents_length_MaxValue, fulfillments_element_considerationComponents_HeadOverflow, fulfillments_element_considerationComponents_length_DirtyBits, fulfillments_element_considerationComponents_length_MaxValue, recipient_DirtyBits, recipient_MaxValue }

  enum ScuffableField { orders, criteriaResolvers, fulfillments, recipient }

  bytes4 internal constant FunctionSelector = 0xf2d12b12;
  string internal constant FunctionName = "matchAdvancedOrders";
  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant fulfillmentsOffset = 0x40;
  uint256 internal constant recipientOffset = 0x60;
  uint256 internal constant HeadSize = 0x80;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_length_DirtyBits);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_extraData_HeadOverflow);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_length_DirtyBits);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue);
  uint256 internal constant MinimumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_length_DirtyBits);
  uint256 internal constant MaximumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_element_considerationComponents_length_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `MatchAdvancedOrdersPointer`.
  /// This adds `MatchAdvancedOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (MatchAdvancedOrdersPointer) {
    return MatchAdvancedOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `MatchAdvancedOrdersPointer` back into a `MemoryPointer`.
  function unwrap(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(MatchAdvancedOrdersPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `matchAdvancedOrders`to a `MatchAdvancedOrdersPointer`.
  /// This adds `MatchAdvancedOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (MatchAdvancedOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function call from arguments
  function fromArgs(AdvancedOrder[] memory orders, CriteriaResolver[] memory criteriaResolvers, Fulfillment[] memory fulfillments, address recipient) internal pure returns (MatchAdvancedOrdersPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("matchAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],((uint256,uint256)[],(uint256,uint256)[])[],address)", orders, criteriaResolvers, fulfillments, recipient);
    ptrOut = fromBytes(data);
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

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(MatchAdvancedOrdersPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
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

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(MatchAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(MatchAdvancedOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead(), positions));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind, positions);
    /// @dev Overflow offset for `criteriaResolvers`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_HeadOverflow) + kindOffset, 224, ptr.criteriaResolversHead(), positions));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind, positions);
    /// @dev Overflow offset for `fulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.fulfillments_HeadOverflow) + kindOffset, 224, ptr.fulfillmentsHead(), positions));
    /// @dev Add all nested directives in fulfillments
    ptr.fulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumFulfillmentsScuffKind, positions);
    /// @dev Add dirty upper bits to `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_DirtyBits) + kindOffset, 96, ptr.recipient(), positions));
    /// @dev Set every bit in `recipient` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.recipient_MaxValue) + kindOffset, 96, ptr.recipient(), positions));
  }

  function getScuffDirectives(MatchAdvancedOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.orders_HeadOverflow) return "orders_HeadOverflow";
    if (k == ScuffKind.orders_length_DirtyBits) return "orders_length_DirtyBits";
    if (k == ScuffKind.orders_length_MaxValue) return "orders_length_MaxValue";
    if (k == ScuffKind.orders_element_HeadOverflow) return "orders_element_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_HeadOverflow) return "orders_element_parameters_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offerer_DirtyBits) return "orders_element_parameters_offerer_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offerer_MaxValue) return "orders_element_parameters_offerer_MaxValue";
    if (k == ScuffKind.orders_element_parameters_zone_DirtyBits) return "orders_element_parameters_zone_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_zone_MaxValue) return "orders_element_parameters_zone_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_HeadOverflow) return "orders_element_parameters_offer_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offer_length_DirtyBits) return "orders_element_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_length_MaxValue) return "orders_element_parameters_offer_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_DirtyBits) return "orders_element_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_MaxValue) return "orders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_DirtyBits) return "orders_element_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_MaxValue) return "orders_element_parameters_offer_element_token_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_HeadOverflow) return "orders_element_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_consideration_length_DirtyBits) return "orders_element_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_length_MaxValue) return "orders_element_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_DirtyBits) return "orders_element_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_MaxValue) return "orders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_DirtyBits) return "orders_element_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_MaxValue) return "orders_element_parameters_consideration_element_token_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_DirtyBits) return "orders_element_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_MaxValue) return "orders_element_parameters_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.orders_element_parameters_orderType_DirtyBits) return "orders_element_parameters_orderType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_orderType_MaxValue) return "orders_element_parameters_orderType_MaxValue";
    if (k == ScuffKind.orders_element_numerator_DirtyBits) return "orders_element_numerator_DirtyBits";
    if (k == ScuffKind.orders_element_numerator_MaxValue) return "orders_element_numerator_MaxValue";
    if (k == ScuffKind.orders_element_denominator_DirtyBits) return "orders_element_denominator_DirtyBits";
    if (k == ScuffKind.orders_element_denominator_MaxValue) return "orders_element_denominator_MaxValue";
    if (k == ScuffKind.orders_element_signature_HeadOverflow) return "orders_element_signature_HeadOverflow";
    if (k == ScuffKind.orders_element_extraData_HeadOverflow) return "orders_element_extraData_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_HeadOverflow) return "criteriaResolvers_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_length_DirtyBits) return "criteriaResolvers_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_length_MaxValue) return "criteriaResolvers_length_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_HeadOverflow) return "criteriaResolvers_element_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_side_DirtyBits) return "criteriaResolvers_element_side_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_side_MaxValue) return "criteriaResolvers_element_side_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_HeadOverflow) return "criteriaResolvers_element_criteriaProof_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_DirtyBits) return "criteriaResolvers_element_criteriaProof_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue) return "criteriaResolvers_element_criteriaProof_length_MaxValue";
    if (k == ScuffKind.fulfillments_HeadOverflow) return "fulfillments_HeadOverflow";
    if (k == ScuffKind.fulfillments_length_DirtyBits) return "fulfillments_length_DirtyBits";
    if (k == ScuffKind.fulfillments_length_MaxValue) return "fulfillments_length_MaxValue";
    if (k == ScuffKind.fulfillments_element_HeadOverflow) return "fulfillments_element_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_HeadOverflow) return "fulfillments_element_offerComponents_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_length_DirtyBits) return "fulfillments_element_offerComponents_length_DirtyBits";
    if (k == ScuffKind.fulfillments_element_offerComponents_length_MaxValue) return "fulfillments_element_offerComponents_length_MaxValue";
    if (k == ScuffKind.fulfillments_element_considerationComponents_HeadOverflow) return "fulfillments_element_considerationComponents_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_considerationComponents_length_DirtyBits) return "fulfillments_element_considerationComponents_length_DirtyBits";
    if (k == ScuffKind.fulfillments_element_considerationComponents_length_MaxValue) return "fulfillments_element_considerationComponents_length_MaxValue";
    if (k == ScuffKind.recipient_DirtyBits) return "recipient_DirtyBits";
    return "recipient_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}