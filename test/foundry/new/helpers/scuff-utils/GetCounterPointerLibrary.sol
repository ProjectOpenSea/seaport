pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type GetCounterPointer is uint256;

using Scuff for MemoryPointer;
using GetCounterPointerLibrary for GetCounterPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getCounter(address)
library GetCounterPointerLibrary {
  bytes4 internal constant FunctionSelector = 0xf07ec373;
  string internal constant FunctionName = "getCounter";

  /// @dev Convert a `MemoryPointer` to a `GetCounterPointer`.
  /// This adds `GetCounterPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetCounterPointer) {
    return GetCounterPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetCounterPointer` back into a `MemoryPointer`.
  function unwrap(GetCounterPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetCounterPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `getCounter`to a `GetCounterPointer`.
  /// This adds `GetCounterPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetCounterPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(address _offerer) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("getCounter(address)", _offerer);
  }

  /// @dev Encode function call from arguments
  function fromArgs(address _offerer) internal pure returns (GetCounterPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_offerer);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `offerer` in memory.
  /// This points to the beginning of the encoded `address`
  function offerer(GetCounterPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }
}