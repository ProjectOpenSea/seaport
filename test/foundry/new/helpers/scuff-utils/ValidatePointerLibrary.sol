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
  enum ScuffKind { orders_head_DirtyBits, orders_head_MaxValue, orders_length_DirtyBits, orders_length_MaxValue, orders_element_head_DirtyBits, orders_element_head_MaxValue, orders_element_parameters_head_DirtyBits, orders_element_parameters_head_MaxValue, orders_element_parameters_offer_head_DirtyBits, orders_element_parameters_offer_head_MaxValue, orders_element_parameters_offer_length_DirtyBits, orders_element_parameters_offer_length_MaxValue, orders_element_parameters_offer_element_itemType_MaxValue, orders_element_parameters_consideration_head_DirtyBits, orders_element_parameters_consideration_head_MaxValue, orders_element_parameters_consideration_length_DirtyBits, orders_element_parameters_consideration_length_MaxValue, orders_element_parameters_consideration_element_itemType_MaxValue, orders_element_parameters_orderType_MaxValue, orders_element_signature_head_DirtyBits, orders_element_signature_head_MaxValue, orders_element_signature_length_DirtyBits, orders_element_signature_length_MaxValue, orders_element_signature_DirtyLowerBits }

  enum ScuffableField { orders_head, orders }

  bytes4 internal constant FunctionSelector = 0x88147732;
  string internal constant FunctionName = "validate";
  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumOrdersScuffKind = uint256(ScuffKind.orders_length_DirtyBits);
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

  /// @dev Encode function calldata
  function encodeFunctionCall(Order[] memory _orders) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("validate(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[])", _orders);
  }

  /// @dev Encode function call from arguments
  function fromArgs(Order[] memory _orders) internal pure returns (ValidatePointer ptrOut) {
    bytes memory data = encodeFunctionCall(_orders);
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
    /// @dev Add dirty upper bits to orders head
    directives.push(Scuff.upper(uint256(ScuffKind.orders_head_DirtyBits) + kindOffset, 224, ptr.ordersHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.orders_head_MaxValue) + kindOffset, 229, ptr.ordersHead(), positions));
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
    if (k == ScuffKind.orders_head_DirtyBits) return "orders_head_DirtyBits";
    if (k == ScuffKind.orders_head_MaxValue) return "orders_head_MaxValue";
    if (k == ScuffKind.orders_length_DirtyBits) return "orders_length_DirtyBits";
    if (k == ScuffKind.orders_length_MaxValue) return "orders_length_MaxValue";
    if (k == ScuffKind.orders_element_head_DirtyBits) return "orders_element_head_DirtyBits";
    if (k == ScuffKind.orders_element_head_MaxValue) return "orders_element_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_head_DirtyBits) return "orders_element_parameters_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_head_MaxValue) return "orders_element_parameters_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_head_DirtyBits) return "orders_element_parameters_offer_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_head_MaxValue) return "orders_element_parameters_offer_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_length_DirtyBits) return "orders_element_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_offer_length_MaxValue) return "orders_element_parameters_offer_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_offer_element_itemType_MaxValue) return "orders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_head_DirtyBits) return "orders_element_parameters_consideration_head_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_head_MaxValue) return "orders_element_parameters_consideration_head_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_length_DirtyBits) return "orders_element_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.orders_element_parameters_consideration_length_MaxValue) return "orders_element_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.orders_element_parameters_consideration_element_itemType_MaxValue) return "orders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.orders_element_parameters_orderType_MaxValue) return "orders_element_parameters_orderType_MaxValue";
    if (k == ScuffKind.orders_element_signature_head_DirtyBits) return "orders_element_signature_head_DirtyBits";
    if (k == ScuffKind.orders_element_signature_head_MaxValue) return "orders_element_signature_head_MaxValue";
    if (k == ScuffKind.orders_element_signature_length_DirtyBits) return "orders_element_signature_length_DirtyBits";
    if (k == ScuffKind.orders_element_signature_length_MaxValue) return "orders_element_signature_length_MaxValue";
    return "orders_element_signature_DirtyLowerBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}