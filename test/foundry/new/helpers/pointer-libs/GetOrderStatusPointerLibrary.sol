// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/../PointerLibraries.sol";

type GetOrderStatusPointer is uint256;

using GetOrderStatusPointerLibrary for GetOrderStatusPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getOrderStatus(bytes32)
library GetOrderStatusPointerLibrary {
  /// @dev Convert a `MemoryPointer` to a `GetOrderStatusPointer`.
  /// This adds `GetOrderStatusPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetOrderStatusPointer) {
    return GetOrderStatusPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetOrderStatusPointer` back into a `MemoryPointer`.
  function unwrap(GetOrderStatusPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetOrderStatusPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `getOrderStatus`to a `GetOrderStatusPointer`.
  /// This adds `GetOrderStatusPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetOrderStatusPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `orderHash` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function orderHash(GetOrderStatusPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }
}