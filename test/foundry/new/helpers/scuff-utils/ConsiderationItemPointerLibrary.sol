pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

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
  enum ScuffKind { itemType_MaxValue }

  enum ScuffableField { itemType }

  uint256 internal constant tokenOffset = 0x20;
  uint256 internal constant identifierOrCriteriaOffset = 0x40;
  uint256 internal constant startAmountOffset = 0x60;
  uint256 internal constant endAmountOffset = 0x80;
  uint256 internal constant recipientOffset = 0xa0;

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

  /// @dev Resolve the pointer to the head of `token` in memory.
  /// This points to the beginning of the encoded `address`
  function token(ConsiderationItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(tokenOffset);
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

  function addScuffDirectives(ConsiderationItemPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Set every bit in `itemType` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.itemType_MaxValue) + kindOffset, 253, ptr.itemType(), positions));
  }

  function getScuffDirectives(ConsiderationItemPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    return "itemType_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}