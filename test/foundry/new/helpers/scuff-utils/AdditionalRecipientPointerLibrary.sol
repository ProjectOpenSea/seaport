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
}