// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "seaport-sol/../PointerLibraries.sol";

type OfferItemPointer is uint256;

using Scuff for MemoryPointer;
using OfferItemPointerLibrary for OfferItemPointer global;

/// @dev Library for resolving pointers of encoded OfferItem
/// struct OfferItem {
///   ItemType itemType;
///   address token;
///   uint256 identifierOrCriteria;
///   uint256 startAmount;
///   uint256 endAmount;
/// }
library OfferItemPointerLibrary {
  enum ScuffKind { itemType_Overflow, token_Overflow }

  uint256 internal constant OverflowedItemType = 0x06;
  uint256 internal constant tokenOffset = 0x20;
  uint256 internal constant OverflowedToken = 0x010000000000000000000000000000000000000000;
  uint256 internal constant identifierOrCriteriaOffset = 0x40;
  uint256 internal constant startAmountOffset = 0x60;
  uint256 internal constant endAmountOffset = 0x80;

  /// @dev Convert a `MemoryPointer` to a `OfferItemPointer`.
  /// This adds `OfferItemPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (OfferItemPointer) {
    return OfferItemPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `OfferItemPointer` back into a `MemoryPointer`.
  function unwrap(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(OfferItemPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `itemType` in memory.
  /// This points to the beginning of the encoded `ItemType`
  function itemType(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Cause `itemType` to overflow
  function overflowItemType(OfferItemPointer ptr) internal pure {
    itemType(ptr).write(OverflowedItemType);
  }

  /// @dev Resolve the pointer to the head of `token` in memory.
  /// This points to the beginning of the encoded `address`
  function token(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(tokenOffset);
  }

  /// @dev Cause `token` to overflow
  function overflowToken(OfferItemPointer ptr) internal pure {
    token(ptr).write(OverflowedToken);
  }

  /// @dev Resolve the pointer to the head of `identifierOrCriteria` in memory.
  /// This points to the beginning of the encoded `uint256`
  function identifierOrCriteria(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(identifierOrCriteriaOffset);
  }

  /// @dev Resolve the pointer to the head of `startAmount` in memory.
  /// This points to the beginning of the encoded `uint256`
  function startAmount(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(startAmountOffset);
  }

  /// @dev Resolve the pointer to the head of `endAmount` in memory.
  /// This points to the beginning of the encoded `uint256`
  function endAmount(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(endAmountOffset);
  }

  function addScuffDirectives(OfferItemPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `itemType`
    directives.push(Scuff.upper(uint256(ScuffKind.itemType_Overflow) + kindOffset, 253, ptr.itemType()));
    /// @dev Induce overflow in `token`
    directives.push(Scuff.upper(uint256(ScuffKind.token_Overflow) + kindOffset, 96, ptr.token()));
  }

  function getScuffDirectives(OfferItemPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.itemType_Overflow) return "itemType_Overflow";
    return "token_Overflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}