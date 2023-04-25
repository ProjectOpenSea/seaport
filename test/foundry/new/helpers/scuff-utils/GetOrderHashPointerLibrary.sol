pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderComponentsPointerLibrary.sol";
import { OrderComponents } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type GetOrderHashPointer is uint256;

using Scuff for MemoryPointer;
using GetOrderHashPointerLibrary for GetOrderHashPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getOrderHash(OrderComponents)
library GetOrderHashPointerLibrary {
  enum ScuffKind { order_head_DirtyBits, order_head_MaxValue, order_offerer_DirtyBits, order_offerer_MaxValue, order_zone_DirtyBits, order_zone_MaxValue, order_offer_head_DirtyBits, order_offer_head_MaxValue, order_offer_length_DirtyBits, order_offer_length_MaxValue, order_offer_element_itemType_DirtyBits, order_offer_element_itemType_MaxValue, order_offer_element_token_DirtyBits, order_offer_element_token_MaxValue, order_consideration_head_DirtyBits, order_consideration_head_MaxValue, order_consideration_length_DirtyBits, order_consideration_length_MaxValue, order_consideration_element_itemType_DirtyBits, order_consideration_element_itemType_MaxValue, order_consideration_element_token_DirtyBits, order_consideration_element_token_MaxValue, order_consideration_element_recipient_DirtyBits, order_consideration_element_recipient_MaxValue, order_orderType_DirtyBits, order_orderType_MaxValue }

  enum ScuffableField { order_head, order }

  bytes4 internal constant FunctionSelector = 0x79df72bd;
  string internal constant FunctionName = "getOrderHash";
  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrderScuffKind = uint256(ScuffKind.order_offerer_DirtyBits);
  uint256 internal constant MaximumOrderScuffKind = uint256(ScuffKind.order_orderType_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `GetOrderHashPointer`.
  /// This adds `GetOrderHashPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetOrderHashPointer) {
    return GetOrderHashPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetOrderHashPointer` back into a `MemoryPointer`.
  function unwrap(GetOrderHashPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetOrderHashPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `getOrderHash`to a `GetOrderHashPointer`.
  /// This adds `GetOrderHashPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetOrderHashPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function call from arguments
  function fromArgs(OrderComponents memory order) internal pure returns (GetOrderHashPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("getOrderHash((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256))", order);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `order` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function orderHead(GetOrderHashPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `OrderComponentsPointer` pointing to the data buffer of `order`
  function orderData(GetOrderHashPointer ptr) internal pure returns (OrderComponentsPointer) {
    return OrderComponentsPointerLibrary.wrap(ptr.unwrap().offset(orderHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(GetOrderHashPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(GetOrderHashPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to order head
    directives.push(Scuff.upper(uint256(ScuffKind.order_head_DirtyBits) + kindOffset, 224, ptr.orderHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.order_head_MaxValue) + kindOffset, 224, ptr.orderHead(), positions));
    /// @dev Add all nested directives in order
    ptr.orderData().addScuffDirectives(directives, kindOffset + MinimumOrderScuffKind, positions);
  }

  function getScuffDirectives(GetOrderHashPointer ptr) internal pure returns (ScuffDirective[] memory) {
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
    if (k == ScuffKind.order_offerer_DirtyBits) return "order_offerer_DirtyBits";
    if (k == ScuffKind.order_offerer_MaxValue) return "order_offerer_MaxValue";
    if (k == ScuffKind.order_zone_DirtyBits) return "order_zone_DirtyBits";
    if (k == ScuffKind.order_zone_MaxValue) return "order_zone_MaxValue";
    if (k == ScuffKind.order_offer_head_DirtyBits) return "order_offer_head_DirtyBits";
    if (k == ScuffKind.order_offer_head_MaxValue) return "order_offer_head_MaxValue";
    if (k == ScuffKind.order_offer_length_DirtyBits) return "order_offer_length_DirtyBits";
    if (k == ScuffKind.order_offer_length_MaxValue) return "order_offer_length_MaxValue";
    if (k == ScuffKind.order_offer_element_itemType_DirtyBits) return "order_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.order_offer_element_itemType_MaxValue) return "order_offer_element_itemType_MaxValue";
    if (k == ScuffKind.order_offer_element_token_DirtyBits) return "order_offer_element_token_DirtyBits";
    if (k == ScuffKind.order_offer_element_token_MaxValue) return "order_offer_element_token_MaxValue";
    if (k == ScuffKind.order_consideration_head_DirtyBits) return "order_consideration_head_DirtyBits";
    if (k == ScuffKind.order_consideration_head_MaxValue) return "order_consideration_head_MaxValue";
    if (k == ScuffKind.order_consideration_length_DirtyBits) return "order_consideration_length_DirtyBits";
    if (k == ScuffKind.order_consideration_length_MaxValue) return "order_consideration_length_MaxValue";
    if (k == ScuffKind.order_consideration_element_itemType_DirtyBits) return "order_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.order_consideration_element_itemType_MaxValue) return "order_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.order_consideration_element_token_DirtyBits) return "order_consideration_element_token_DirtyBits";
    if (k == ScuffKind.order_consideration_element_token_MaxValue) return "order_consideration_element_token_MaxValue";
    if (k == ScuffKind.order_consideration_element_recipient_DirtyBits) return "order_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.order_consideration_element_recipient_MaxValue) return "order_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.order_orderType_DirtyBits) return "order_orderType_DirtyBits";
    return "order_orderType_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}