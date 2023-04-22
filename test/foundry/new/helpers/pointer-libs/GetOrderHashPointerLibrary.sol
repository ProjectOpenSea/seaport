// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderComponentsPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type GetOrderHashPointer is uint256;

using Scuff for MemoryPointer;
using GetOrderHashPointerLibrary for GetOrderHashPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getOrderHash(OrderComponents)
library GetOrderHashPointerLibrary {
  enum ScuffKind { order_HeadOverflow, order_offerer_Overflow, order_zone_Overflow, order_offer_HeadOverflow, order_offer_LengthOverflow, order_offer_element_itemType_Overflow, order_offer_element_token_Overflow, order_consideration_HeadOverflow, order_consideration_LengthOverflow, order_consideration_element_itemType_Overflow, order_consideration_element_token_Overflow, order_consideration_element_recipient_Overflow, order_orderType_Overflow }

  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrderScuffKind = uint256(ScuffKind.order_offerer_Overflow);
  uint256 internal constant MaximumOrderScuffKind = uint256(ScuffKind.order_orderType_Overflow);

  /// @dev Convert a `MemoryPointer` to a `GetOrderHashPointer`.
  /// This adds `GetOrderHashPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetOrderHashPointer) {
    return GetOrderHashPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetOrderHashPointer` back into a `MemoryPointer`.
  function unwrap(GetOrderHashPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetOrderHashPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `getOrderHash`to a `GetOrderHashPointer`.
  /// This adds `GetOrderHashPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetOrderHashPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
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

  /// @dev Add dirty bits to the head for `order` (offset relative to parent).
  function addDirtyBitsToOrderOffset(GetOrderHashPointer ptr) internal pure {
    orderHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(GetOrderHashPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(GetOrderHashPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `order`
    directives.push(Scuff.lower(uint256(ScuffKind.order_HeadOverflow) + kindOffset, 224, ptr.orderHead()));
    /// @dev Add all nested directives in order
    ptr.orderData().addScuffDirectives(directives, kindOffset + MinimumOrderScuffKind);
  }

  function getScuffDirectives(GetOrderHashPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.order_HeadOverflow) return "order_HeadOverflow";
    if (k == ScuffKind.order_offerer_Overflow) return "order_offerer_Overflow";
    if (k == ScuffKind.order_zone_Overflow) return "order_zone_Overflow";
    if (k == ScuffKind.order_offer_HeadOverflow) return "order_offer_HeadOverflow";
    if (k == ScuffKind.order_offer_LengthOverflow) return "order_offer_LengthOverflow";
    if (k == ScuffKind.order_offer_element_itemType_Overflow) return "order_offer_element_itemType_Overflow";
    if (k == ScuffKind.order_offer_element_token_Overflow) return "order_offer_element_token_Overflow";
    if (k == ScuffKind.order_consideration_HeadOverflow) return "order_consideration_HeadOverflow";
    if (k == ScuffKind.order_consideration_LengthOverflow) return "order_consideration_LengthOverflow";
    if (k == ScuffKind.order_consideration_element_itemType_Overflow) return "order_consideration_element_itemType_Overflow";
    if (k == ScuffKind.order_consideration_element_token_Overflow) return "order_consideration_element_token_Overflow";
    if (k == ScuffKind.order_consideration_element_recipient_Overflow) return "order_consideration_element_recipient_Overflow";
    return "order_orderType_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}