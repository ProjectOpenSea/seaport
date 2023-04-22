// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type ValidatePointer is uint256;

using Scuff for MemoryPointer;
using ValidatePointerLibrary for ValidatePointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// validate(Order[])
library ValidatePointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_LengthOverflow, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_Overflow, orders_element_parameters_zone_Overflow, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_LengthOverflow, orders_element_parameters_offer_element_itemType_Overflow, orders_element_parameters_offer_element_token_Overflow, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_LengthOverflow, orders_element_parameters_consideration_element_itemType_Overflow, orders_element_parameters_consideration_element_token_Overflow, orders_element_parameters_consideration_element_recipient_Overflow, orders_element_parameters_orderType_Overflow, orders_element_signature_HeadOverflow, orders_element_signature_LengthOverflow, orders_element_signature_DirtyLowerBits }

  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_LengthOverflow);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_signature_DirtyLowerBits);

  /// @dev Convert a `MemoryPointer` to a `ValidatePointer`.
  /// This adds `ValidatePointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (ValidatePointer) {
    return ValidatePointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `ValidatePointer` back into a `MemoryPointer`.
  function unwrap(ValidatePointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(ValidatePointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `validate`to a `ValidatePointer`.
  /// This adds `ValidatePointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (ValidatePointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `orders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function ordersHead(ValidatePointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayOrderPointer` pointing to the data buffer of `orders`
  function ordersData(ValidatePointer ptr) internal pure returns (DynArrayOrderPointer) {
    return DynArrayOrderPointerLibrary.wrap(ptr.unwrap().offset(ordersHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `orders` (offset relative to parent).
  function addDirtyBitsToOrdersOffset(ValidatePointer ptr) internal pure {
    ordersHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(ValidatePointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(ValidatePointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead()));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind);
  }

  function getScuffDirectives(ValidatePointer ptr) internal pure returns (ScuffDirective[] memory) {
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
    return "orders_element_signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}