// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "seaport-sol/../PointerLibraries.sol";

type AdditionalRecipientPointer is uint256;

using Scuff for MemoryPointer;
using AdditionalRecipientPointerLibrary for AdditionalRecipientPointer global;

/// @dev Library for resolving pointers of encoded AdditionalRecipient
/// struct AdditionalRecipient {
///   uint256 amount;
///   address recipient;
/// }
library AdditionalRecipientPointerLibrary {
  enum ScuffKind { recipient_Overflow }

  uint256 internal constant recipientOffset = 0x20;
  uint256 internal constant OverflowedRecipient = 0x010000000000000000000000000000000000000000;

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

  /// @dev Cause `recipient` to overflow
  function overflowRecipient(AdditionalRecipientPointer ptr) internal pure {
    recipient(ptr).write(OverflowedRecipient);
  }

  function addScuffDirectives(AdditionalRecipientPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_Overflow) + kindOffset, 96, ptr.recipient()));
  }

  function getScuffDirectives(AdditionalRecipientPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    return "recipient_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}