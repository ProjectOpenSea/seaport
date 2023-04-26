pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayDynArrayFulfillmentComponentPointerLibrary.sol";
import "./DynArrayOrderPointerLibrary.sol";
import { Order, FulfillmentComponent } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillAvailableOrdersPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAvailableOrdersPointerLibrary for FulfillAvailableOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAvailableOrders(Order[],FulfillmentComponent[][],FulfillmentComponent[][],bytes32,uint256)
library FulfillAvailableOrdersPointerLibrary {
  enum ScuffKind { orders_element_parameters_offerer_DirtyBits, orders_element_parameters_zone_DirtyBits, orders_element_parameters_offer_element_itemType_DirtyBits, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_offer_element_token_DirtyBits, orders_element_parameters_consideration_element_itemType_DirtyBits, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_consideration_element_token_DirtyBits, orders_element_parameters_consideration_element_recipient_DirtyBits, orders_element_parameters_orderType_DirtyBits, orders_element_parameters_orderType_MaxValue }

  enum ScuffableField { orders }

  bytes4 internal constant FunctionSelector = 0xed98a574;
  string internal constant FunctionName = "fulfillAvailableOrders";
  uint256 internal constant offerFulfillmentsOffset = 0x20;
  uint256 internal constant considerationFulfillmentsOffset = 0x40;
  uint256 internal constant fulfillerConduitKeyOffset = 0x60;
  uint256 internal constant maximumFulfilledOffset = 0x80;
  uint256 internal constant HeadSize = 0xa0;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_element_parameters_offerer_DirtyBits);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_parameters_orderType_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `FulfillAvailableOrdersPointer`.
  /// This adds `FulfillAvailableOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAvailableOrdersPointer) {
    return FulfillAvailableOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAvailableOrdersPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAvailableOrdersPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAvailableOrders`to a `FulfillAvailableOrdersPointer`.
  /// This adds `FulfillAvailableOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAvailableOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(Order[] memory _orders, FulfillmentComponent[][] memory _offerFulfillments, FulfillmentComponent[][] memory _considerationFulfillments, bytes32 _fulfillerConduitKey, uint256 _maximumFulfilled) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("fulfillAvailableOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,uint256)", _orders, _offerFulfillments, _considerationFulfillments, _fulfillerConduitKey, _maximumFulfilled);
  }

  /// @dev Encode function call from arguments
  function fromArgs(Order[] memory _orders, FulfillmentComponent[][] memory _offerFulfillments, FulfillmentComponent[][] memory _considerationFulfillments, bytes32 _fulfillerConduitKey, uint256 _maximumFulfilled) internal pure returns (FulfillAvailableOrdersPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_orders, _offerFulfillments, _considerationFulfillments, _fulfillerConduitKey, _maximumFulfilled);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `orders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function ordersHead(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayOrderPointer` pointing to the data buffer of `orders`
  function ordersData(FulfillAvailableOrdersPointer ptr) internal pure returns (DynArrayOrderPointer) {
    return DynArrayOrderPointerLibrary.wrap(ptr.unwrap().offset(ordersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `offerFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerFulfillmentsHead(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(offerFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `offerFulfillments`
  function offerFulfillmentsData(FulfillAvailableOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(offerFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `considerationFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationFulfillmentsHead(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `considerationFulfillments`
  function considerationFulfillmentsData(FulfillAvailableOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(considerationFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `maximumFulfilled` in memory.
  /// This points to the beginning of the encoded `uint256`
  function maximumFulfilled(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(maximumFulfilledOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillAvailableOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind, positions);
  }

  function getScuffDirectives(FulfillAvailableOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
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
    return "orders_element_parameters_orderType_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}