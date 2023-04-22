// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./OrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type FulfillOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillOrderPointerLibrary for FulfillOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillOrder(Order,bytes32)
library FulfillOrderPointerLibrary {
  enum ScuffKind { order_HeadOverflow, order_parameters_HeadOverflow, order_parameters_offerer_Overflow, order_parameters_zone_Overflow, order_parameters_offer_HeadOverflow, order_parameters_offer_LengthOverflow, order_parameters_offer_element_itemType_Overflow, order_parameters_offer_element_token_Overflow, order_parameters_consideration_HeadOverflow, order_parameters_consideration_LengthOverflow, order_parameters_consideration_element_itemType_Overflow, order_parameters_consideration_element_token_Overflow, order_parameters_consideration_element_recipient_Overflow, order_parameters_orderType_Overflow, order_signature_HeadOverflow, order_signature_LengthOverflow, order_signature_DirtyLowerBits }

  uint256 internal constant fulfillerConduitKeyOffset = 0x20;
  uint256 internal constant HeadSize = 0x40;
  uint256 internal constant MinimumOrderScuffKind = uint256(ScuffKind.order_parameters_HeadOverflow);
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

  /// @dev Convert a `bytes` with encoded calldata for `fulfillOrder`to a `FulfillOrderPointer`.
  /// This adds `FulfillOrderPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillOrderPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
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

  /// @dev Add dirty bits to the head for `order` (offset relative to parent).
  function addDirtyBitsToOrderOffset(FulfillOrderPointer ptr) internal pure {
    orderHead(ptr).addDirtyBitsBefore(224);
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

  function addScuffDirectives(FulfillOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `order`
    directives.push(Scuff.lower(uint256(ScuffKind.order_HeadOverflow) + kindOffset, 224, ptr.orderHead()));
    /// @dev Add all nested directives in order
    ptr.orderData().addScuffDirectives(directives, kindOffset + MinimumOrderScuffKind);
  }

  function getScuffDirectives(FulfillOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.order_HeadOverflow) return "order_HeadOverflow";
    if (k == ScuffKind.order_parameters_HeadOverflow) return "order_parameters_HeadOverflow";
    if (k == ScuffKind.order_parameters_offerer_Overflow) return "order_parameters_offerer_Overflow";
    if (k == ScuffKind.order_parameters_zone_Overflow) return "order_parameters_zone_Overflow";
    if (k == ScuffKind.order_parameters_offer_HeadOverflow) return "order_parameters_offer_HeadOverflow";
    if (k == ScuffKind.order_parameters_offer_LengthOverflow) return "order_parameters_offer_LengthOverflow";
    if (k == ScuffKind.order_parameters_offer_element_itemType_Overflow) return "order_parameters_offer_element_itemType_Overflow";
    if (k == ScuffKind.order_parameters_offer_element_token_Overflow) return "order_parameters_offer_element_token_Overflow";
    if (k == ScuffKind.order_parameters_consideration_HeadOverflow) return "order_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.order_parameters_consideration_LengthOverflow) return "order_parameters_consideration_LengthOverflow";
    if (k == ScuffKind.order_parameters_consideration_element_itemType_Overflow) return "order_parameters_consideration_element_itemType_Overflow";
    if (k == ScuffKind.order_parameters_consideration_element_token_Overflow) return "order_parameters_consideration_element_token_Overflow";
    if (k == ScuffKind.order_parameters_consideration_element_recipient_Overflow) return "order_parameters_consideration_element_recipient_Overflow";
    if (k == ScuffKind.order_parameters_orderType_Overflow) return "order_parameters_orderType_Overflow";
    if (k == ScuffKind.order_signature_HeadOverflow) return "order_signature_HeadOverflow";
    if (k == ScuffKind.order_signature_LengthOverflow) return "order_signature_LengthOverflow";
    return "order_signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}