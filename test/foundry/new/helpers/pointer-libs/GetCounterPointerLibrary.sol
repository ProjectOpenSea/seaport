// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "seaport-sol/../PointerLibraries.sol";

type GetCounterPointer is uint256;

using Scuff for MemoryPointer;
using GetCounterPointerLibrary for GetCounterPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getCounter(address)
library GetCounterPointerLibrary {
  enum ScuffKind { offerer_Overflow }

  uint256 internal constant OverflowedOfferer = 0x010000000000000000000000000000000000000000;

  /// @dev Convert a `MemoryPointer` to a `GetCounterPointer`.
  /// This adds `GetCounterPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetCounterPointer) {
    return GetCounterPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetCounterPointer` back into a `MemoryPointer`.
  function unwrap(GetCounterPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetCounterPointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `getCounter`to a `GetCounterPointer`.
  /// This adds `GetCounterPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetCounterPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `offerer` in memory.
  /// This points to the beginning of the encoded `address`
  function offerer(GetCounterPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Cause `offerer` to overflow
  function overflowOfferer(GetCounterPointer ptr) internal pure {
    offerer(ptr).write(OverflowedOfferer);
  }

  function addScuffDirectives(GetCounterPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `offerer`
    directives.push(Scuff.upper(uint256(ScuffKind.offerer_Overflow) + kindOffset, 96, ptr.offerer()));
  }

  function getScuffDirectives(GetCounterPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    return "offerer_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}