pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayOrderPointerLibrary.sol";
import { Order } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type ValidatePointer is uint256;

using Scuff for MemoryPointer;
using ValidatePointerLibrary for ValidatePointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// validate(Order[])
library ValidatePointerLibrary {
  enum ScuffKind { orders_HeadOverflow, orders_length_DirtyBits, orders_length_MaxValue, orders_element_HeadOverflow, orders_element_parameters_HeadOverflow, orders_element_parameters_offerer_DirtyBits, orders_element_parameters_offerer_MaxValue, orders_element_parameters_zone_DirtyBits, orders_element_parameters_zone_MaxValue, orders_element_parameters_offer_HeadOverflow, orders_element_parameters_offer_length_DirtyBits, orders_element_parameters_offer_length_MaxValue, orders_element_parameters_offer_element_itemType_DirtyBits, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_offer_element_token_DirtyBits, orders_element_parameters_offer_element_token_MaxValue, orders_element_parameters_consideration_HeadOverflow, orders_element_parameters_consideration_length_DirtyBits, orders_element_parameters_consideration_length_MaxValue, orders_element_parameters_consideration_element_itemType_DirtyBits, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_consideration_element_token_DirtyBits, orders_element_parameters_consideration_element_token_MaxValue, orders_element_parameters_consideration_element_recipient_DirtyBits, orders_element_parameters_consideration_element_recipient_MaxValue, orders_element_parameters_orderType_DirtyBits, orders_element_parameters_orderType_MaxValue, orders_element_signature_HeadOverflow }

  enum ScuffableField { orders }

  bytes4 internal constant FunctionSelector = 0x88147732;
  string internal constant FunctionName = "validate";
  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_length_DirtyBits);
  uint256 internal constant MaximumOrdersScuffKind = uint256(ScuffKind.orders_element_signature_HeadOverflow);

  /// @dev Convert a `MemoryPointer` to a `ValidatePointer`.
  /// This adds `ValidatePointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (ValidatePointer) {
    return ValidatePointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `ValidatePointer` back into a `MemoryPointer`.
  function unwrap(ValidatePointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(ValidatePointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `validate`to a `ValidatePointer`.
  /// This adds `ValidatePointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (ValidatePointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function call from arguments
  function fromArgs(Order[] memory orders) internal pure returns (ValidatePointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("validate(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[])", orders);
    ptrOut = fromBytes(data);
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

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(ValidatePointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(ValidatePointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Overflow offset for `orders`
    directives.push(Scuff.lower(uint256(ScuffKind.orders_HeadOverflow) + kindOffset, 224, ptr.ordersHead(), positions));
    /// @dev Add all nested directives in orders
    ptr.ordersData().addScuffDirectives(directives, kindOffset + MinimumOrdersScuffKind, positions);
  }

  function getScuffDirectives(ValidatePointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.orders_HeadOverflow) return "orders_HeadOverflow";
    if (k == ScuffKind.orders_length_DirtyBits) return "orders_length_DirtyBits";
    if (k == ScuffKind.orders_length_MaxValue) return "orders_length_MaxValue";
    if (k == ScuffKind.orders_element_HeadOverflow) return "orders_element_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_HeadOverflow) return "orders_element_parameters_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offerer_DirtyBits) return "orders_element_parameters_offerer_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offerer_MaxValue) return "orders_element_parameters_offerer_MaxValue";
    if (k == ScuffKind.orders_element_parameters_zone_DirtyBits) return "orders_element_parameters_zone_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_zone_MaxValue) return "orders_element_parameters_zone_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_HeadOverflow) return "orders_element_parameters_offer_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_offer_length_DirtyBits) return "orders_element_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_length_MaxValue) return "orders_element_parameters_offer_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_DirtyBits) return "orders_element_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_MaxValue) return "orders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_DirtyBits) return "orders_element_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_element_token_MaxValue) return "orders_element_parameters_offer_element_token_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_HeadOverflow) return "orders_element_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.orders_element_parameters_consideration_length_DirtyBits) return "orders_element_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_length_MaxValue) return "orders_element_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_DirtyBits) return "orders_element_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_MaxValue) return "orders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_DirtyBits) return "orders_element_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_token_MaxValue) return "orders_element_parameters_consideration_element_token_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_DirtyBits) return "orders_element_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_element_recipient_MaxValue) return "orders_element_parameters_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.orders_element_parameters_orderType_DirtyBits) return "orders_element_parameters_orderType_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_orderType_MaxValue) return "orders_element_parameters_orderType_MaxValue";
    return "orders_element_signature_HeadOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}