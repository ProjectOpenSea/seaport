pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentPointerLibrary.sol";
import "./DynArrayOrderPointerLibrary.sol";
import { Order, Fulfillment } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type MatchOrdersPointer is uint256;

using Scuff for MemoryPointer;
using MatchOrdersPointerLibrary for MatchOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// matchOrders(Order[],Fulfillment[])
library MatchOrdersPointerLibrary {
  enum ScuffKind { orders_head_DirtyBits, orders_head_MaxValue, orders_length_DirtyBits, orders_length_MaxValue, orders_element_head_DirtyBits, orders_element_head_MaxValue, orders_element_parameters_head_DirtyBits, orders_element_parameters_head_MaxValue, orders_element_parameters_offer_head_DirtyBits, orders_element_parameters_offer_head_MaxValue, orders_element_parameters_offer_length_DirtyBits, orders_element_parameters_offer_length_MaxValue, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_consideration_head_DirtyBits, orders_element_parameters_consideration_head_MaxValue, orders_element_parameters_consideration_length_DirtyBits, orders_element_parameters_consideration_length_MaxValue, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_orderType_MaxValue, orders_element_signature_head_DirtyBits, orders_element_signature_head_MaxValue, orders_element_signature_length_DirtyBits, orders_element_signature_length_MaxValue, orders_element_signature_DirtyLowerBits, fulfillments_head_DirtyBits, fulfillments_head_MaxValue, fulfillments_length_DirtyBits, fulfillments_length_MaxValue, fulfillments_element_head_DirtyBits, fulfillments_element_head_MaxValue, fulfillments_element_offerComponents_head_DirtyBits, fulfillments_element_offerComponents_head_MaxValue, fulfillments_element_offerComponents_length_DirtyBits, fulfillments_element_offerComponents_length_MaxValue, fulfillments_element_considerationComponents_head_DirtyBits, fulfillments_element_considerationComponents_head_MaxValue, fulfillments_element_considerationComponents_length_DirtyBits, fulfillments_element_considerationComponents_length_MaxValue }

  enum ScuffableField { orders_head, orders, fulfillments_head, fulfillments }

  bytes4 internal constant FunctionSelector = 0xa8174404;
  string internal constant FunctionName = "matchOrders";
  uint256 internal constant fulfillmentsOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_length_DirtyBits);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_signature_DirtyLowerBits);
  uint256 internal constant MinimumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_length_DirtyBits);
  uint256 internal constant MaximumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_element_considerationComponents_length_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `MatchOrdersPointer`.
  /// This adds `MatchOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (MatchOrdersPointer) {
    return MatchOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `MatchOrdersPointer` back into a `MemoryPointer`.
  function unwrap(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(MatchOrdersPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `matchOrders`to a `MatchOrdersPointer`.
  /// This adds `MatchOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (MatchOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(Order[] memory _orders, Fulfillment[] memory _fulfillments) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("matchOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[],((uint256,uint256)[],(uint256,uint256)[])[])", _orders, _fulfillments);
  }

  /// @dev Encode function call from arguments
  function fromArgs(Order[] memory _orders, Fulfillment[] memory _fulfillments) internal pure returns (MatchOrdersPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_orders, _fulfillments);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `orders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function ordersHead(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayOrderPointer` pointing to the data buffer of `orders`
  function ordersData(MatchOrdersPointer ptr) internal pure returns (DynArrayOrderPointer) {
    return DynArrayOrderPointerLibrary.wrap(ptr.unwrap().offset(ordersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `fulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function fulfillmentsHead(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayFulfillmentPointer` pointing to the data buffer of `fulfillments`
  function fulfillmentsData(MatchOrdersPointer ptr) internal pure returns (DynArrayFulfillmentPointer) {
    return DynArrayFulfillmentPointerLibrary.wrap(ptr.unwrap().offset(fulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(MatchOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to orders head
    directives.push(Scuff.upper(uint256(ScuffKind.orders_head_DirtyBits) + kindOffset, 224, ptr.ordersHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.orders_head_MaxValue) + kindOffset, 229, ptr.ordersHead(), positions));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind, positions);
    /// @dev Add dirty upper bits to fulfillments head
    directives.push(Scuff.upper(uint256(ScuffKind.fulfillments_head_DirtyBits) + kindOffset, 224, ptr.fulfillmentsHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.fulfillments_head_MaxValue) + kindOffset, 229, ptr.fulfillmentsHead(), positions));
    /// @dev Add all nested directives in fulfillments
    ptr.fulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumFulfillmentsScuffKind, positions);
  }

  function getScuffDirectives(MatchOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.orders_head_DirtyBits) return "orders_head_DirtyBits";
    if (k == ScuffKind.orders_head_MaxValue) return "orders_head_MaxValue";
    if (k == ScuffKind.orders_length_DirtyBits) return "orders_length_DirtyBits";
    if (k == ScuffKind.orders_length_MaxValue) return "orders_length_MaxValue";
    if (k == ScuffKind.orders_element_head_DirtyBits) return "orders_element_head_DirtyBits";
    if (k == ScuffKind.orders_element_head_MaxValue) return "orders_element_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_head_DirtyBits) return "orders_element_parameters_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_head_MaxValue) return "orders_element_parameters_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_head_DirtyBits) return "orders_element_parameters_offer_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_head_MaxValue) return "orders_element_parameters_offer_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_length_DirtyBits) return "orders_element_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_length_MaxValue) return "orders_element_parameters_offer_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_MaxValue) return "orders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_head_DirtyBits) return "orders_element_parameters_consideration_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_head_MaxValue) return "orders_element_parameters_consideration_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_length_DirtyBits) return "orders_element_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_length_MaxValue) return "orders_element_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_MaxValue) return "orders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_orderType_MaxValue) return "orders_element_parameters_orderType_MaxValue";
    if (k == ScuffKind.orders_element_signature_head_DirtyBits) return "orders_element_signature_head_DirtyBits";
    if (k == ScuffKind.orders_element_signature_head_MaxValue) return "orders_element_signature_head_MaxValue";
    if (k == ScuffKind.orders_element_signature_length_DirtyBits) return "orders_element_signature_length_DirtyBits";
    if (k == ScuffKind.orders_element_signature_length_MaxValue) return "orders_element_signature_length_MaxValue";
    if (k == ScuffKind.orders_element_signature_DirtyLowerBits) return "orders_element_signature_DirtyLowerBits";
    if (k == ScuffKind.fulfillments_head_DirtyBits) return "fulfillments_head_DirtyBits";
    if (k == ScuffKind.fulfillments_head_MaxValue) return "fulfillments_head_MaxValue";
    if (k == ScuffKind.fulfillments_length_DirtyBits) return "fulfillments_length_DirtyBits";
    if (k == ScuffKind.fulfillments_length_MaxValue) return "fulfillments_length_MaxValue";
    if (k == ScuffKind.fulfillments_element_head_DirtyBits) return "fulfillments_element_head_DirtyBits";
    if (k == ScuffKind.fulfillments_element_head_MaxValue) return "fulfillments_element_head_MaxValue";
    if (k == ScuffKind.fulfillments_element_offerComponents_head_DirtyBits) return "fulfillments_element_offerComponents_head_DirtyBits";
    if (k == ScuffKind.fulfillments_element_offerComponents_head_MaxValue) return "fulfillments_element_offerComponents_head_MaxValue";
    if (k == ScuffKind.fulfillments_element_offerComponents_length_DirtyBits) return "fulfillments_element_offerComponents_length_DirtyBits";
    if (k == ScuffKind.fulfillments_element_offerComponents_length_MaxValue) return "fulfillments_element_offerComponents_length_MaxValue";
    if (k == ScuffKind.fulfillments_element_considerationComponents_head_DirtyBits) return "fulfillments_element_considerationComponents_head_DirtyBits";
    if (k == ScuffKind.fulfillments_element_considerationComponents_head_MaxValue) return "fulfillments_element_considerationComponents_head_MaxValue";
    if (k == ScuffKind.fulfillments_element_considerationComponents_length_DirtyBits) return "fulfillments_element_considerationComponents_length_DirtyBits";
    return "fulfillments_element_considerationComponents_length_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}