pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type GetContractOffererNoncePointer is uint256;

using Scuff for MemoryPointer;
using GetContractOffererNoncePointerLibrary for GetContractOffererNoncePointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// getContractOffererNonce(address)
library GetContractOffererNoncePointerLibrary {
  enum ScuffKind { contractOfferer_DirtyBits }

  enum ScuffableField { contractOfferer }

  bytes4 internal constant FunctionSelector = 0xa900866b;
  string internal constant FunctionName = "getContractOffererNonce";

  /// @dev Convert a `MemoryPointer` to a `GetContractOffererNoncePointer`.
  /// This adds `GetContractOffererNoncePointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (GetContractOffererNoncePointer) {
    return GetContractOffererNoncePointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `GetContractOffererNoncePointer` back into a `MemoryPointer`.
  function unwrap(GetContractOffererNoncePointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(GetContractOffererNoncePointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `getContractOffererNonce`to a `GetContractOffererNoncePointer`.
  /// This adds `GetContractOffererNoncePointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (GetContractOffererNoncePointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(address _contractOfferer) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("getContractOffererNonce(address)", _contractOfferer);
  }

  /// @dev Encode function call from arguments
  function fromArgs(address _contractOfferer) internal pure returns (GetContractOffererNoncePointer ptrOut) {
    bytes memory data = encodeFunctionCall(_contractOfferer);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `contractOfferer` in memory.
  /// This points to the beginning of the encoded `address`
  function contractOfferer(GetContractOffererNoncePointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  function addScuffDirectives(GetContractOffererNoncePointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to `contractOfferer`
    directives.push(Scuff.upper(uint256(ScuffKind.contractOfferer_DirtyBits) + kindOffset, 96, ptr.contractOfferer(), positions));
  }

  function getScuffDirectives(GetContractOffererNoncePointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    return "contractOfferer_DirtyBits";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}