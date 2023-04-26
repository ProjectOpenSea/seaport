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
  enum ScuffKind { orders_element_parameters_offerer_DirtyBits, orders_element_parameters_zone_DirtyBits, orders_element_parameters_offer_element_itemType_DirtyBits, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_offer_element_token_DirtyBits, orders_element_parameters_consideration_element_itemType_DirtyBits, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_consideration_element_token_DirtyBits, orders_element_parameters_consideration_element_recipient_DirtyBits, orders_element_parameters_orderType_DirtyBits, orders_element_parameters_orderType_MaxValue, orders_element_numerator_DirtyBits, orders_element_denominator_DirtyBits, criteriaResolvers_element_side_DirtyBits, criteriaResolvers_element_side_MaxValue, recipient_DirtyBits }

  enum ScuffableField { orders, criteriaResolvers, recipient }

  bytes4 internal constant FunctionSelector = 0xf2d12b12;
  string internal constant FunctionName = "matchAdvancedOrders";
  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant fulfillmentsOffset = 0x40;
  uint256 internal constant recipientOffset = 0x60;
  uint256 internal constant HeadSize = 0x80;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_element_parameters_offerer_DirtyBits);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_denominator_DirtyBits);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_side_DirtyBits);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_side_MaxValue);

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

  /// @dev Encode function calldata
  function encodeFunctionCall(AdvancedOrder[] memory _orders, CriteriaResolver[] memory _criteriaResolvers, Fulfillment[] memory _fulfillments, address _recipient) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("matchAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],((uint256,uint256)[],(uint256,uint256)[])[],address)", _orders, _criteriaResolvers, _fulfillments, _recipient);
  }

  /// @dev Encode function call from arguments
  function fromArgs(AdvancedOrder[] memory _orders, CriteriaResolver[] memory _criteriaResolvers, Fulfillment[] memory _fulfillments, address _recipient) internal pure returns (MatchAdvancedOrdersPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_orders, _criteriaResolvers, _fulfillments, _recipient);
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
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind, positions);
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind, positions);
    /// @dev Add dirty upper bits to `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_DirtyBits) + kindOffset, 96, ptr.recipient(), positions));
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
    if (k == ScuffKind.orders_element_parameters_offerer_DirtyBits) return "orders_element_parameters_offerer_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_zone_DirtyBits) return "orders_element_parameters_zone_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_DirtyBits) return "orders_element_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_MaxValue) return "orders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_DirtyBits) return "orders_element_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_DirtyBits) return "orders_element_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_MaxValue) return "orders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_DirtyBits) return "orders_element_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_DirtyBits) return "orders_element_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_orderType_DirtyBits) return "orders_element_parameters_orderType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_orderType_MaxValue) return "orders_element_parameters_orderType_MaxValue";
    if (k == ScuffKind.orders_element_numerator_DirtyBits) return "orders_element_numerator_DirtyBits";
    if (k == ScuffKind.orders_element_denominator_DirtyBits) return "orders_element_denominator_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_side_DirtyBits) return "criteriaResolvers_element_side_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_side_MaxValue) return "criteriaResolvers_element_side_MaxValue";
    return "recipient_DirtyBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}