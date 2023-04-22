// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayFulfillmentPointerLibrary.sol";
import "./DynArrayOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type MatchOrdersPointer is uint256;

using Scuff for MemoryPointer;
using MatchOrdersPointerLibrary for MatchOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// matchOrders(Order[],Fulfillment[])
library MatchOrdersPointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_LengthOverflow, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_Overflow, orders_element_parameters_zone_Overflow, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_LengthOverflow, orders_element_parameters_offer_element_itemType_Overflow, orders_element_parameters_offer_element_token_Overflow, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_LengthOverflow, orders_element_parameters_consideration_element_itemType_Overflow, orders_element_parameters_consideration_element_token_Overflow, orders_element_parameters_consideration_element_recipient_Overflow, orders_element_parameters_orderType_Overflow, orders_element_signature_HeadOverflow, orders_element_signature_LengthOverflow, orders_element_signature_DirtyLowerBits, fulfillments_HeadOverflow, fulfillments_LengthOverflow, fulfillments_element_HeadOverflow, fulfillments_element_offerComponents_HeadOverflow, fulfillments_element_offerComponents_LengthOverflow, fulfillments_element_considerationComponents_HeadOverflow, fulfillments_element_considerationComponents_LengthOverflow }

  uint256 internal constant fulfillmentsOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_LengthOverflow);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_signature_DirtyLowerBits);
  uint256 internal constant MinimumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_LengthOverflow);
  uint256 internal constant MaximumFulfillmentsScuffKind = uint256(ScuffKind.fulfillments_element_considerationComponents_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `MatchOrdersPointer`.
  /// This adds `MatchOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (MatchOrdersPointer) {
    return MatchOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `MatchOrdersPointer` back into a `MemoryPointer`.
  function unwrap(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(MatchOrdersPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `matchOrders`to a `MatchOrdersPointer`.
  /// This adds `MatchOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (MatchOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
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

  /// @dev Add dirty bits to the head for `orders` (offset relative to parent).
  function addDirtyBitsToOrdersOffset(MatchOrdersPointer ptr) internal pure {
    ordersHead(ptr).addDirtyBitsBefore(224);
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

  /// @dev Add dirty bits to the head for `fulfillments` (offset relative to parent).
  function addDirtyBitsToFulfillmentsOffset(MatchOrdersPointer ptr) internal pure {
    fulfillmentsHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(MatchOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(MatchOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead()));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind);
    /// @dev Overflow offset for `fulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.fulfillments_HeadOverflow) + kindOffset, 224, ptr.fulfillmentsHead()));
    /// @dev Add all nested directives in fulfillments
    ptr.fulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumFulfillmentsScuffKind);
  }

  function getScuffDirectives(MatchOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
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
    if (k == ScuffKind.orders_element_signature_HeadOverflow) return "orders_element_signature_HeadOverflow";
    if (k == ScuffKind.orders_element_signature_LengthOverflow) return "orders_element_signature_LengthOverflow";
    if (k == ScuffKind.orders_element_signature_DirtyLowerBits) return "orders_element_signature_DirtyLowerBits";
    if (k == ScuffKind.fulfillments_HeadOverflow) return "fulfillments_HeadOverflow";
    if (k == ScuffKind.fulfillments_LengthOverflow) return "fulfillments_LengthOverflow";
    if (k == ScuffKind.fulfillments_element_HeadOverflow) return "fulfillments_element_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_HeadOverflow) return "fulfillments_element_offerComponents_HeadOverflow";
    if (k == ScuffKind.fulfillments_element_offerComponents_LengthOverflow) return "fulfillments_element_offerComponents_LengthOverflow";
    if (k == ScuffKind.fulfillments_element_considerationComponents_HeadOverflow) return "fulfillments_element_considerationComponents_HeadOverflow";
    return "fulfillments_element_considerationComponents_LengthOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}