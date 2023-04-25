pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderPointerLibrary.sol";
import { Order } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillOrderPointerLibrary for FulfillOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillOrder(Order,bytes32)
library FulfillOrderPointerLibrary {
  enum ScuffKind { order_head_DirtyBits, order_head_MaxValue, order_parameters_head_DirtyBits, order_parameters_head_MaxValue, order_parameters_offer_head_DirtyBits, order_parameters_offer_head_MaxValue, order_parameters_offer_length_DirtyBits, order_parameters_offer_length_MaxValue, order_parameters_offer_element_itemType_MaxValue, order_parameters_consideration_head_DirtyBits, order_parameters_consideration_head_MaxValue, order_parameters_consideration_length_DirtyBits, order_parameters_consideration_length_MaxValue, order_parameters_consideration_element_itemType_MaxValue, order_parameters_orderType_MaxValue, order_signature_head_DirtyBits, order_signature_head_MaxValue, order_signature_length_DirtyBits, order_signature_length_MaxValue, order_signature_DirtyLowerBits }

  enum ScuffableField { order_head, order }

  bytes4 internal constant FunctionSelector = 0xb3a34c4c;
  string internal constant FunctionName = "fulfillOrder";
  uint256 internal constant fulfillerConduitKeyOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOrderScuffKind = uint256(ScuffKind.order_parameters_head_DirtyBits);
  uint256 internal constant MaximumOrderScuffKind = uint256(ScuffKind.order_signature_DirtyLowerBits);

  /// @dev Convert a `MemoryPointer` to a `FulfillOrderPointer`.
  /// This adds `FulfillOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillOrderPointer) {
    return FulfillOrderPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillOrderPointer` back into a `MemoryPointer`.
  function unwrap(FulfillOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillOrderPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillOrder`to a `FulfillOrderPointer`.
  /// This adds `FulfillOrderPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillOrderPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(Order memory _order, bytes32 _fulfillerConduitKey) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32)", _order, _fulfillerConduitKey);
  }

  /// @dev Encode function call from arguments
  function fromArgs(Order memory _order, bytes32 _fulfillerConduitKey) internal pure returns (FulfillOrderPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_order, _fulfillerConduitKey);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `order` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function orderHead(FulfillOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `OrderPointer` pointing to the data buffer of `order`
  function orderData(FulfillOrderPointer ptr) internal pure returns (OrderPointer) {
    return OrderPointerLibrary.wrap(ptr.unwrap().offset(orderHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to order head
    directives.push(Scuff.upper(uint256(ScuffKind.order_head_DirtyBits) + kindOffset, 224, ptr.orderHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.order_head_MaxValue) + kindOffset, 229, ptr.orderHead(), positions));
    /// @dev Add all nested directives in order
    ptr.orderData().addScuffDirectives(directives, kindOffset + MinimumOrderScuffKind, positions);
  }

  function getScuffDirectives(FulfillOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.order_head_DirtyBits) return "order_head_DirtyBits";
    if (k == ScuffKind.order_head_MaxValue) return "order_head_MaxValue";
    if (k == ScuffKind.order_parameters_head_DirtyBits) return "order_parameters_head_DirtyBits";
    if (k == ScuffKind.order_parameters_head_MaxValue) return "order_parameters_head_MaxValue";
    if (k == ScuffKind.order_parameters_offer_head_DirtyBits) return "order_parameters_offer_head_DirtyBits";
    if (k == ScuffKind.order_parameters_offer_head_MaxValue) return "order_parameters_offer_head_MaxValue";
    if (k == ScuffKind.order_parameters_offer_length_DirtyBits) return "order_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.order_parameters_offer_length_MaxValue) return "order_parameters_offer_length_MaxValue";
    if (k == ScuffKind.order_parameters_offer_element_itemType_MaxValue) return "order_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_head_DirtyBits) return "order_parameters_consideration_head_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_head_MaxValue) return "order_parameters_consideration_head_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_length_DirtyBits) return "order_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_length_MaxValue) return "order_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_element_itemType_MaxValue) return "order_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.order_parameters_orderType_MaxValue) return "order_parameters_orderType_MaxValue";
    if (k == ScuffKind.order_signature_head_DirtyBits) return "order_signature_head_DirtyBits";
    if (k == ScuffKind.order_signature_head_MaxValue) return "order_signature_head_MaxValue";
    if (k == ScuffKind.order_signature_length_DirtyBits) return "order_signature_length_DirtyBits";
    if (k == ScuffKind.order_signature_length_MaxValue) return "order_signature_length_MaxValue";
    return "order_signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}