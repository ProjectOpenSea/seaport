// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayBytes32PointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type CriteriaResolverPointer is uint256;

using Scuff for MemoryPointer;
using CriteriaResolverPointerLibrary for CriteriaResolverPointer global;

/// @dev Library for resolving pointers of encoded CriteriaResolver
/// struct CriteriaResolver {
///   uint256 orderIndex;
///   Side side;
///   uint256 index;
///   uint256 identifier;
///   bytes32[] criteriaProof;
/// }
library CriteriaResolverPointerLibrary {
  enum ScuffKind { side_Overflow, criteriaProof_HeadOverflow, criteriaProof_LengthOverflow }

  uint256 internal constant sideOffset = 0x20;
  uint256 internal constant OverflowedSide = 0x02;
  uint256 internal constant indexOffset = 0x40;
  uint256 internal constant identifierOffset = 0x60;
  uint256 internal constant criteriaProofOffset = 0x80;
  uint256 internal constant HeadSize = 0xa0;
  uint256 internal constant MinimumCriteriaProofScuffKind = uint256(ScuffKind.criteriaProof_LengthOverflow);
  uint256 internal constant MaximumCriteriaProofScuffKind = uint256(ScuffKind.criteriaProof_LengthOverflow);

  /// @dev Convert a `MemoryPointer` to a `CriteriaResolverPointer`.
  /// This adds `CriteriaResolverPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (CriteriaResolverPointer) {
    return CriteriaResolverPointer.wrap(MemoryPointer.unwrap(ptr));
  }

  /// @dev Convert a `CriteriaResolverPointer` back into a `MemoryPointer`.
  function unwrap(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(CriteriaResolverPointer.unwrap(ptr));
  }

  /// @dev Resolve the pointer to the head of `orderIndex` in memory.
  /// This points to the beginning of the encoded `uint256`
  function orderIndex(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the pointer to the head of `side` in memory.
  /// This points to the beginning of the encoded `Side`
  function side(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(sideOffset);
  }

  /// @dev Cause `side` to overflow
  function overflowSide(CriteriaResolverPointer ptr) internal pure {
    side(ptr).write(OverflowedSide);
  }

  /// @dev Resolve the pointer to the head of `index` in memory.
  /// This points to the beginning of the encoded `uint256`
  function index(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(indexOffset);
  }

  /// @dev Resolve the pointer to the head of `identifier` in memory.
  /// This points to the beginning of the encoded `uint256`
  function identifier(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(identifierOffset);
  }

  /// @dev Resolve the pointer to the head of `criteriaProof` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaProofHead(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaProofOffset);
  }

  /// @dev Resolve the `DynArrayBytes32Pointer` pointing to the data buffer of `criteriaProof`
  function criteriaProofData(CriteriaResolverPointer ptr) internal pure returns (DynArrayBytes32Pointer) {
    return DynArrayBytes32PointerLibrary.wrap(ptr.unwrap().offset(criteriaProofHead(ptr).readUint256()));
  }

  /// @dev Add dirty bits to the head for `criteriaProof` (offset relative to parent).
  function addDirtyBitsToCriteriaProofOffset(CriteriaResolverPointer ptr) internal pure {
    criteriaProofHead(ptr).addDirtyBitsBefore(224);
  }

  /// @dev Resolve the pointer to the tail segment of the struct.
  /// This is the beginning of the dynamically encoded data.
  function tail(CriteriaResolverPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(CriteriaResolverPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset) internal pure {
    /// @dev Induce overflow in `side`
    directives.push(Scuff.upper(uint256(ScuffKind.side_Overflow) + kindOffset, 255, ptr.side()));
    /// @dev Overflow offset for `criteriaProof`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaProof_HeadOverflow) + kindOffset, 224, ptr.criteriaProofHead()));
    /// @dev Add all nested directives in criteriaProof
    ptr.criteriaProofData().addScuffDirectives(directives, kindOffset + MinimumCriteriaProofScuffKind);
  }

  function getScuffDirectives(CriteriaResolverPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    addScuffDirectives(ptr, directives, 0);
    return directives.finalize();
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.side_Overflow) return "side_Overflow";
    if (k == ScuffKind.criteriaProof_HeadOverflow) return "criteriaProof_HeadOverflow";
    return "criteriaProof_LengthOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }
}