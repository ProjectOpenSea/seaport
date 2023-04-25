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
  enum ScuffKind { order_HeadOverflow, order_parameters_HeadOverflow, order_parameters_offerer_DirtyBits, order_parameters_offerer_MaxValue, order_parameters_zone_DirtyBits, order_parameters_zone_MaxValue, order_parameters_offer_HeadOverflow, order_parameters_offer_length_DirtyBits, order_parameters_offer_length_MaxValue, order_parameters_offer_element_itemType_DirtyBits, order_parameters_offer_element_itemType_MaxValue, order_parameters_offer_element_token_DirtyBits, order_parameters_offer_element_token_MaxValue, order_parameters_consideration_HeadOverflow, order_parameters_consideration_length_DirtyBits, order_parameters_consideration_length_MaxValue, order_parameters_consideration_element_itemType_DirtyBits, order_parameters_consideration_element_itemType_MaxValue, order_parameters_consideration_element_token_DirtyBits, order_parameters_consideration_element_token_MaxValue, order_parameters_consideration_element_recipient_DirtyBits, order_parameters_consideration_element_recipient_MaxValue, order_parameters_orderType_DirtyBits, order_parameters_orderType_MaxValue, order_signature_HeadOverflow }

  enum ScuffableField { order }

  bytes4 internal constant FunctionSelector = 0xb3a34c4c;
  string internal constant FunctionName = "fulfillOrder";
  uint256 internal constant fulfillerConduitKeyOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOrderScuffKind = uint256(ScuffKind.order_parameters_HeadOverflow);
  uint256 internal constant MaximumOrderScuffKind = uint256(ScuffKind.order_signature_HeadOverflow);

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

  /// @dev Encode function call from arguments
  function fromArgs(Order memory order, bytes32 fulfillerConduitKey) internal pure returns (FulfillOrderPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32)", order, fulfillerConduitKey);
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
    /// @dev Overflow offset for `order`
    directives.push(Scuff.lower(uint256(ScuffKind.order_HeadOverflow) + kindOffset, 224, ptr.orderHead(), positions));
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
    if (k == ScuffKind.order_HeadOverflow) return "order_HeadOverflow";
    if (k == ScuffKind.order_parameters_HeadOverflow) return "order_parameters_HeadOverflow";
    if (k == ScuffKind.order_parameters_offerer_DirtyBits) return "order_parameters_offerer_DirtyBits";
    if (k == ScuffKind.order_parameters_offerer_MaxValue) return "order_parameters_offerer_MaxValue";
    if (k == ScuffKind.order_parameters_zone_DirtyBits) return "order_parameters_zone_DirtyBits";
    if (k == ScuffKind.order_parameters_zone_MaxValue) return "order_parameters_zone_MaxValue";
    if (k == ScuffKind.order_parameters_offer_HeadOverflow) return "order_parameters_offer_HeadOverflow";
    if (k == ScuffKind.order_parameters_offer_length_DirtyBits) return "order_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.order_parameters_offer_length_MaxValue) return "order_parameters_offer_length_MaxValue";
    if (k == ScuffKind.order_parameters_offer_element_itemType_DirtyBits) return "order_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.order_parameters_offer_element_itemType_MaxValue) return "order_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.order_parameters_offer_element_token_DirtyBits) return "order_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.order_parameters_offer_element_token_MaxValue) return "order_parameters_offer_element_token_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_HeadOverflow) return "order_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.order_parameters_consideration_length_DirtyBits) return "order_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_length_MaxValue) return "order_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_element_itemType_DirtyBits) return "order_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_element_itemType_MaxValue) return "order_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_element_token_DirtyBits) return "order_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_element_token_MaxValue) return "order_parameters_consideration_element_token_MaxValue";
    if (k == ScuffKind.order_parameters_consideration_element_recipient_DirtyBits) return "order_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.order_parameters_consideration_element_recipient_MaxValue) return "order_parameters_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.order_parameters_orderType_DirtyBits) return "order_parameters_orderType_DirtyBits";
    if (k == ScuffKind.order_parameters_orderType_MaxValue) return "order_parameters_orderType_MaxValue";
    return "order_signature_HeadOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}