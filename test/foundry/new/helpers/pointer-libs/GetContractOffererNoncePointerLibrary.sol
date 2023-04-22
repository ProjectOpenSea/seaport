// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "seaport-sol/../PointerLibraries.sol";

type GetContractOffererNoncePointer is uint256;

using Scuff for MemoryPointer;
using GetContractOffererNoncePointerLibrary for GetContractOffererNoncePointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getContractOffererNonce(address)
library GetContractOffererNoncePointerLibrary {
  enum ScuffKind { contractOfferer_Overflow }

  uint256 internal constant OverflowedContractOfferer = 0x010000000000000000000000000000000000000000;

  /// @dev Convert a `MemoryPointer` to a `GetContractOffererNoncePointer`.
  /// This adds `GetContractOffererNoncePointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetContractOffererNoncePointer) {
    return GetContractOffererNoncePointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetContractOffererNoncePointer` back into a `MemoryPointer`.
  function unwrap(GetContractOffererNoncePointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetContractOffererNoncePointer.unwrap(ptr));
  }

  /// @dev Convert a `bytes` with encoded calldata for `getContractOffererNonce`to a `GetContractOffererNoncePointer`.
  /// This adds `GetContractOffererNoncePointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetContractOffererNoncePointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Resolve the pointer to the head of `contractOfferer` in memory.
  /// This points to the beginning of the encoded `address`
  function contractOfferer(GetContractOffererNoncePointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Cause `contractOfferer` to overflow
  function overflowContractOfferer(GetContractOffererNoncePointer ptr) internal pure {
    contractOfferer(ptr).write(OverflowedContractOfferer);
  }

  function addScuffDirectives(GetContractOffererNoncePointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `contractOfferer`
    directives.push(Scuff.upper(uint256(ScuffKind.contractOfferer_Overflow) + kindOffset, 96, ptr.contractOfferer()));
  }

  function getScuffDirectives(GetContractOffererNoncePointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    return "contractOfferer_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}