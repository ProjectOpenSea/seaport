pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

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
  uint256 internal constant tokenOffset = 0x20;
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

  /// @dev Resolve the pointer to the head of `token` in memory.
  /// This points to the beginning of the encoded `address`
  function token(OfferItemPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(tokenOffset);
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
}