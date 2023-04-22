// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayOrderComponentsPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type CancelPointer is uint256;

using Scuff for MemoryPointer;
using CancelPointerLibrary for CancelPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// cancel(OrderComponents[])
library CancelPointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_LengthOverflow, orders_element_HeadOverflow, orders_element_offerer_Overflow, orders_element_zone_Overflow, orders_element_offer_HeadOverflow, orders_element_offer_LengthOverflow, orders_element_offer_element_itemType_Overflow, orders_element_offer_element_token_Overflow, orders_element_consideration_HeadOverflow, orders_element_consideration_LengthOverflow, orders_element_consideration_element_itemType_Overflow, orders_element_consideration_element_token_Overflow, orders_element_consideration_element_recipient_Overflow, orders_element_orderType_Overflow }

  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_LengthOverflow);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_orderType_Overflow);

  /// @dev Convert a `MemoryPointer` to a `CancelPointer`.
  /// This adds `CancelPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (CancelPointer) {
    return CancelPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `CancelPointer` back into a `MemoryPointer`.
  function unwrap(CancelPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(CancelPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `cancel`to a `CancelPointer`.
  /// This adds `CancelPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (CancelPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `orders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function ordersHead(CancelPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayOrderComponentsPointer` pointing to the data buffer of `orders`
  function ordersData(CancelPointer ptr) internal pure returns (DynArrayOrderComponentsPointer) {
    return DynArrayOrderComponentsPointerLibrary.wrap(ptr.unwrap().offset(ordersHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `orders` (offset relative to parent).
  function addDirtyBitsToOrdersOffset(CancelPointer ptr) internal pure {
    ordersHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(CancelPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(CancelPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead()));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind);
  }

  function getScuffDirectives(CancelPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.orders_HeadOverflow) return "orders_HeadOverflow";
    if (k == ScuffKind.orders_LengthOverflow) return "orders_LengthOverflow";
    if (k == ScuffKind.orders_element_HeadOverflow) return "orders_element_HeadOverflow";
    if (k == ScuffKind.orders_element_offerer_Overflow) return "orders_element_offerer_Overflow";
    if (k == ScuffKind.orders_element_zone_Overflow) return "orders_element_zone_Overflow";
    if (k == ScuffKind.orders_element_offer_HeadOverflow) return "orders_element_offer_HeadOverflow";
    if (k == ScuffKind.orders_element_offer_LengthOverflow) return "orders_element_offer_LengthOverflow";
    if (k == ScuffKind.orders_element_offer_element_itemType_Overflow) return "orders_element_offer_element_itemType_Overflow";
    if (k == ScuffKind.orders_element_offer_element_token_Overflow) return "orders_element_offer_element_token_Overflow";
    if (k == ScuffKind.orders_element_consideration_HeadOverflow) return "orders_element_consideration_HeadOverflow";
    if (k == ScuffKind.orders_element_consideration_LengthOverflow) return "orders_element_consideration_LengthOverflow";
    if (k == ScuffKind.orders_element_consideration_element_itemType_Overflow) return "orders_element_consideration_element_itemType_Overflow";
    if (k == ScuffKind.orders_element_consideration_element_token_Overflow) return "orders_element_consideration_element_token_Overflow";
    if (k == ScuffKind.orders_element_consideration_element_recipient_Overflow) return "orders_element_consideration_element_recipient_Overflow";
    return "orders_element_orderType_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}