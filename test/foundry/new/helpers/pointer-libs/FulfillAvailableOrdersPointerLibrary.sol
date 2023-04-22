// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayDynArrayFulfillmentComponentPointerLibrary.sol";
import "./DynArrayOrderPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type FulfillAvailableOrdersPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAvailableOrdersPointerLibrary for FulfillAvailableOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAvailableOrders(Order[],FulfillmentComponent[][],FulfillmentComponent[][],bytes32,uint256)
library FulfillAvailableOrdersPointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_LengthOverflow, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_Overflow, orders_element_parameters_zone_Overflow, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_LengthOverflow, orders_element_parameters_offer_element_itemType_Overflow, orders_element_parameters_offer_element_token_Overflow, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_LengthOverflow, orders_element_parameters_consideration_element_itemType_Overflow, orders_element_parameters_consideration_element_token_Overflow, orders_element_parameters_consideration_element_recipient_Overflow, orders_element_parameters_orderType_Overflow, orders_element_signature_HeadOverflow, orders_element_signature_LengthOverflow, orders_element_signature_DirtyLowerBits, offerFulfillments_HeadOverflow, offerFulfillments_LengthOverflow, offerFulfillments_element_HeadOverflow, offerFulfillments_element_LengthOverflow, considerationFulfillments_HeadOverflow, considerationFulfillments_LengthOverflow, considerationFulfillments_element_HeadOverflow, considerationFulfillments_element_LengthOverflow }

  uint256 internal constant offerFulfillmentsOffset = 0x20;
  uint256 internal constant considerationFulfillmentsOffset = 0x40;
  uint256 internal constant fulfillerConduitKeyOffset = 0x60;
  uint256 internal constant maximumFulfilledOffset = 0x80;
  uint256 internal constant HeadSize = 0xa0;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_LengthOverflow);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_signature_DirtyLowerBits);
  uint256 internal constant MinimumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_LengthOverflow);
  uint256 internal constant MaximumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_element_LengthOverflow);
  uint256 internal constant MinimumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_LengthOverflow);
  uint256 internal constant MaximumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_element_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `FulfillAvailableOrdersPointer`.
  /// This adds `FulfillAvailableOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAvailableOrdersPointer) {
    return FulfillAvailableOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAvailableOrdersPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAvailableOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAvailableOrdersPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAvailableOrders`to a `FulfillAvailableOrdersPointer`.
  /// This adds `FulfillAvailableOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAvailableOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
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

  /// @dev Add dirty bits to the head for `orders` (offset relative to parent).
  function addDirtyBitsToOrdersOffset(FulfillAvailableOrdersPointer ptr) internal pure {
    ordersHead(ptr).addDirtyBitsBefore(224);
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

  /// @dev Add dirty bits to the head for `offerFulfillments` (offset relative to parent).
  function addDirtyBitsToOfferFulfillmentsOffset(FulfillAvailableOrdersPointer ptr) internal pure {
    offerFulfillmentsHead(ptr).addDirtyBitsBefore(224);
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

  /// @dev Add dirty bits to the head for `considerationFulfillments` (offset relative to parent).
  function addDirtyBitsToConsiderationFulfillmentsOffset(FulfillAvailableOrdersPointer ptr) internal pure {
    considerationFulfillmentsHead(ptr).addDirtyBitsBefore(224);
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

  function addScuffDirectives(FulfillAvailableOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead()));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind);
    /// @dev Overflow offset for `offerFulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.offerFulfillments_HeadOverflow) + kindOffset, 224, ptr.offerFulfillmentsHead()));
    /// @dev Add all nested directives in offerFulfillments
    ptr.offerFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumOfferFulfillmentsScuffKind);
    /// @dev Overflow offset for `considerationFulfillments`
    directives.push(Scuff.lower(uint256(ScuffKind.considerationFulfillments_HeadOverflow) + kindOffset, 224, ptr.considerationFulfillmentsHead()));
    /// @dev Add all nested directives in considerationFulfillments
    ptr.considerationFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumConsiderationFulfillmentsScuffKind);
  }

  function getScuffDirectives(FulfillAvailableOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
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
    if (k == ScuffKind.offerFulfillments_HeadOverflow) return "offerFulfillments_HeadOverflow";
    if (k == ScuffKind.offerFulfillments_LengthOverflow) return "offerFulfillments_LengthOverflow";
    if (k == ScuffKind.offerFulfillments_element_HeadOverflow) return "offerFulfillments_element_HeadOverflow";
    if (k == ScuffKind.offerFulfillments_element_LengthOverflow) return "offerFulfillments_element_LengthOverflow";
    if (k == ScuffKind.considerationFulfillments_HeadOverflow) return "considerationFulfillments_HeadOverflow";
    if (k == ScuffKind.considerationFulfillments_LengthOverflow) return "considerationFulfillments_LengthOverflow";
    if (k == ScuffKind.considerationFulfillments_element_HeadOverflow) return "considerationFulfillments_element_HeadOverflow";
    return "considerationFulfillments_element_LengthOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}