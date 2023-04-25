pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type GetCounterPointer is uint256;

using Scuff for MemoryPointer;
using GetCounterPointerLibrary for GetCounterPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getCounter(address)
library GetCounterPointerLibrary {
  enum ScuffKind { offerer_DirtyBits, offerer_MaxValue }

  enum ScuffableField { offerer }

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

  /// @dev Encode function call from arguments
  function fromArgs(address offerer) internal pure returns (GetCounterPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("getCounter(address)", offerer);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `offerer` in memory.
  /// This points to the beginning of the encoded `address`
  function offerer(GetCounterPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  function addScuffDirectives(GetCounterPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to `offerer`
    directives.push(Scuff.upper(uint256(ScuffKind.offerer_DirtyBits) + kindOffset, 96, ptr.offerer(), positions));
    /// @dev Set every bit in `offerer` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.offerer_MaxValue) + kindOffset, 96, ptr.offerer(), positions));
  }

  function getScuffDirectives(GetCounterPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.offerer_DirtyBits) return "offerer_DirtyBits";
    return "offerer_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}