pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type AdditionalRecipientPointer is uint256;

using Scuff for MemoryPointer;
using AdditionalRecipientPointerLibrary for AdditionalRecipientPointer global;

/// @dev Library for resolving pointers of encoded AdditionalRecipient
/// struct AdditionalRecipient {
///   uint256 amount;
///   address recipient;
/// }
library AdditionalRecipientPointerLibrary {
  enum ScuffKind { recipient_DirtyBits, recipient_MaxValue }

  enum ScuffableField { recipient }

  uint256 internal constant recipientOffset = 0x20;

  /// @dev Convert a `MemoryPointer` to a `AdditionalRecipientPointer`.
  /// This adds `AdditionalRecipientPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (AdditionalRecipientPointer) {
    return AdditionalRecipientPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `AdditionalRecipientPointer` back into a `MemoryPointer`.
  function unwrap(AdditionalRecipientPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(AdditionalRecipientPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `amount` in memory.
  /// This points to the beginning of the encoded `uint256`
  function amount(AdditionalRecipientPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(AdditionalRecipientPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  function addScuffDirectives(AdditionalRecipientPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_DirtyBits) + kindOffset, 96, ptr.recipient(), positions));
    /// @dev Set every bit in `recipient` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.recipient_MaxValue) + kindOffset, 96, ptr.recipient(), positions));
  }

  function getScuffDirectives(AdditionalRecipientPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.recipient_DirtyBits) return "recipient_DirtyBits";
    return "recipient_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}