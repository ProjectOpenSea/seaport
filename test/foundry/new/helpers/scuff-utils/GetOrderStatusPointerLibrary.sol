pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type GetOrderStatusPointer is uint256;

using Scuff for MemoryPointer;
using GetOrderStatusPointerLibrary for GetOrderStatusPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getOrderStatus(bytes32)
library GetOrderStatusPointerLibrary {
  bytes4 internal constant FunctionSelector = 0x46423aa7;
  string internal constant FunctionName = "getOrderStatus";

  /// @dev Convert a `MemoryPointer` to a `GetOrderStatusPointer`.
  /// This adds `GetOrderStatusPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetOrderStatusPointer) {
    return GetOrderStatusPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetOrderStatusPointer` back into a `MemoryPointer`.
  function unwrap(GetOrderStatusPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetOrderStatusPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `getOrderStatus`to a `GetOrderStatusPointer`.
  /// This adds `GetOrderStatusPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetOrderStatusPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(bytes32 _orderHash) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("getOrderStatus(bytes32)", _orderHash);
  }

  /// @dev Encode function call from arguments
  function fromArgs(bytes32 _orderHash) internal pure returns (GetOrderStatusPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_orderHash);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `orderHash` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function orderHash(GetOrderStatusPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }
}