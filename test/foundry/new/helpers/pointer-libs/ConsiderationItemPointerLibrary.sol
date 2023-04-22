// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "seaport-sol/../PointerLibraries.sol";

type ConsiderationItemPointer is uint256;

using Scuff for MemoryPointer;
using ConsiderationItemPointerLibrary for ConsiderationItemPointer global;

/// @dev Library for resolving pointers of encoded ConsiderationItem
/// struct ConsiderationItem {
///   ItemType itemType;
///   address token;
///   uint256 identifierOrCriteria;
///   uint256 startAmount;
///   uint256 endAmount;
///   address recipient;
/// }
library ConsiderationItemPointerLibrary {
  enum ScuffKind { itemType_Overflow, token_Overflow, recipient_Overflow }

  uint256 internal constant OverflowedItemType = 0x06;
  uint256 internal constant tokenOffset = 0x20;
  uint256 internal constant OverflowedToken = 0x010000000000000000000000000000000000000000;
  uint256 internal constant identifierOrCriteriaOffset = 0x40;
  uint256 internal constant startAmountOffset = 0x60;
  uint256 internal constant endAmountOffset = 0x80;
  uint256 internal constant recipientOffset = 0xa0;
  uint256 internal constant OverflowedRecipient = 0x010000000000000000000000000000000000000000;

  /// @dev Convert a `MemoryPointer` to a `ConsiderationItemPointer`.
  /// This adds `ConsiderationItemPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (ConsiderationItemPointer) {
    return ConsiderationItemPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `ConsiderationItemPointer` back into a `MemoryPointer`.
  function unwrap(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(ConsiderationItemPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `itemType` in memory.
  /// This points to the beginning of the encoded `ItemType`
  function itemType(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Cause `itemType` to overflow
  function overflowItemType(ConsiderationItemPointer ptr) internal pure {
    itemType(ptr).write(OverflowedItemType);
  }

  /// @dev Resolve the pointer to the head of `token` in memory.
  /// This points to the beginning of the encoded `address`
  function token(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(tokenOffset);
  }

  /// @dev Cause `token` to overflow
  function overflowToken(ConsiderationItemPointer ptr) internal pure {
    token(ptr).write(OverflowedToken);
  }

  /// @dev Resolve the pointer to the head of `identifierOrCriteria` in memory.
  /// This points to the beginning of the encoded `uint256`
  function identifierOrCriteria(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(identifierOrCriteriaOffset);
  }

  /// @dev Resolve the pointer to the head of `startAmount` in memory.
  /// This points to the beginning of the encoded `uint256`
  function startAmount(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(startAmountOffset);
  }

  /// @dev Resolve the pointer to the head of `endAmount` in memory.
  /// This points to the beginning of the encoded `uint256`
  function endAmount(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(endAmountOffset);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Cause `recipient` to overflow
  function overflowRecipient(ConsiderationItemPointer ptr) internal pure {
    recipient(ptr).write(OverflowedRecipient);
  }

  function addScuffDirectives(ConsiderationItemPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `itemType`
    directives.push(Scuff.upper(uint256(ScuffKind.itemType_Overflow) + kindOffset, 253, ptr.itemType()));
    /// @dev Induce overflow in `token`
    directives.push(Scuff.upper(uint256(ScuffKind.token_Overflow) + kindOffset, 96, ptr.token()));
    /// @dev Induce overflow in `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_Overflow) + kindOffset, 96, ptr.recipient()));
  }

  function getScuffDirectives(ConsiderationItemPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.itemType_Overflow) return "itemType_Overflow";
    if (k == ScuffKind.token_Overflow) return "token_Overflow";
    return "recipient_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}