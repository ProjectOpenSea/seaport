pragma solidity ^0.8.17;

import "../../../../../contracts/helpers/PointerLibraries.sol";

/// 674:9:9
enum ScuffSide { DirtyUpperBits, DirtyLowerBits }

type ScuffDirectivesArray is uint256;

type ScuffDirective is uint256;

type ScuffPositions is uint256;

type ScuffPositionsCache is uint256;

/// 482:16:9
struct ScuffDescription {
  uint256 pointer;
  bytes32 originalValue;
  bytes32 scuffedValue;
  uint256[] positions;
  string side;
  uint256 bitOffset;
  string kind;
  string functionName;
}

using Scuff for ScuffDirective global;
using Scuff for ScuffDirectivesArray global;
using ScuffPos for ScuffPositions global;
using ScuffPos for ScuffPositionsCache global;

ScuffPositions constant EmptyPositions = ScuffPositions.wrap(0);

function toSideString(ScuffSide side) pure returns (string memory) {
  if (side == ScuffSide.DirtyUpperBits) return "DirtyUpperBits";
  return "DirtyLowerBits";
}

/// ScuffDirective is a 256-bit value that contains the following fields:
/// bits [0:8] kind
/// bits [8:16] side
/// bits [16:24] bit offset
/// bits [24:224] array of indices of fields traversed
/// bits [224:256] pointer in memory of the value to be scuffed
library Scuff {
  uint256 internal constant MaxUint256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant Kind_ExclusionMask = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant Side_ExclusionMask = 0xff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant BitOffset_ExclusionMask = 0xffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant PositionsLength_ExclusionMask = 0xffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant Positions_InclusionMask = 0x000000ffffffffffffffffffffffffffffffffffffffffffffffffff00000000;
  uint256 internal constant Pointer_InclusionMask = 0xffffffff;
  uint256 internal constant Kind_BitsAfter = 248;
  uint256 internal constant Side_BitsAfter = 240;
  uint256 internal constant BitOffset_BitsAfter = 232;
  uint256 internal constant Pointer_BitsAfter = 0;
  uint256 internal constant Kind_Byte = 0;
  uint256 internal constant Side_Byte = 1;
  uint256 internal constant BitOffset_Byte = 2;
  uint256 internal constant PositionsLength_Byte = 3;
  uint256 internal constant ScuffSide_DirtyLowerBits = 0x01;

  function makeUnallocatedArray() internal pure returns (ScuffDirectivesArray arr) {
    assembly {
      arr := mload(0x40)
      mstore(arr, add(arr, 0x20))
    }
  }

  function push(ScuffDirectivesArray arr, ScuffDirective value) internal pure {
    assembly {
      let next := mload(arr)
      mstore(next, value)
      mstore(arr, add(next, 0x20))
    }
  }

  function withKindOffset(ScuffDirective directive, uint256 kindOffset) internal pure returns (ScuffDirective newDirective) {
    uint256 kind = directive.getKind() + kindOffset;
    require(kind < 256, "Scuff: kind overflow");
    assembly {
      kind := byte(Kind_Byte, directive)
      newDirective := or(and(directive, Kind_ExclusionMask), shl(Kind_BitsAfter, kind))
    }
  }

  function assertValid(ScuffDirectivesArray arr) internal pure {
    uint256 freePointer;
    assembly {
      freePointer := mload(0x40)
    }
    require(freePointer == ScuffDirectivesArray.unwrap(arr), "ScuffDirectivesArray: free pointer changed before allocation finalized");
  }

  function finalize(ScuffDirectivesArray arr) internal pure returns (ScuffDirective[] memory decl) {
    assertValid(arr);
    assembly {
      let next := mload(arr)
      mstore(0x40, next)
      let size := sub(next, arr)
      mstore(arr, sub(div(size, 0x20), 1))
      decl := arr
    }
  }

  function decode(ScuffDirective directive) internal pure returns (uint256 kind, ScuffSide side, uint256 bitOffset, ScuffPositions positions, MemoryPointer pointer) {
    assembly {
      kind := byte(Kind_Byte, directive)
      side := byte(Side_Byte, directive)
      bitOffset := byte(BitOffset_Byte, directive)
      positions := and(directive, Positions_InclusionMask)
      pointer := and(directive, Pointer_InclusionMask)
    }
  }

  function decodeWithCache(ScuffDirective directive) internal pure returns (uint256 kind, ScuffSide side, uint256 bitOffset, ScuffPositionsCache positions, MemoryPointer pointer) {
    ScuffPositions positions_;
    (kind, side, bitOffset, positions_, pointer) = decode(directive);
    positions = positions_.cache();
  }

  function encode(uint256 kind, ScuffSide side, uint256 bitOffset, ScuffPositions positions, MemoryPointer pointer) internal pure returns (ScuffDirective directive) {
    assembly {
      directive := or(or(shl(Kind_BitsAfter, kind), shl(Side_BitsAfter, side)), or(or(shl(BitOffset_BitsAfter, bitOffset), pointer), positions))
    }
  }

  /// @dev Create directive to set every bit from 0 to `bitOffset`
  /// on the value stored at `pointer`
  function upper(uint256 kind, uint256 bitOffset, MemoryPointer pointer, ScuffPositions positions) internal pure returns (ScuffDirective directive) {
    return encode(kind, ScuffSide.DirtyUpperBits, bitOffset, positions, pointer);
  }

  /// @dev Create directive to set every bit from `offset` to 255
  /// on the value stored at `pointer`
  function lower(uint256 kind, uint256 bitOffset, MemoryPointer pointer, ScuffPositions positions) internal pure returns (ScuffDirective directive) {
    return encode(kind, ScuffSide.DirtyLowerBits, bitOffset, positions, pointer);
  }

  function getMask(ScuffSide side, uint256 bitOffset) internal pure returns (uint256 mask) {
    assembly {
      let isLower := eq(side, ScuffSide_DirtyLowerBits)
      switch isLower
      case 1 {
        mask := shr(bitOffset, MaxUint256)
      }
      default {
        mask := shl(sub(256, bitOffset), MaxUint256)
      }
    }
  }

  function getKind(ScuffDirective directive) internal pure returns (uint256 kind) {
    assembly {
      kind := byte(Kind_Byte, directive)
    }
  }

  function applyScuff(ScuffDirective directive) internal pure {
    (, ScuffSide side, uint256 bitOffset, , MemoryPointer pointer) = decode(directive);
    uint256 mask = getMask(side, bitOffset);
    assembly {
      mstore(pointer, or(mload(pointer), mask))
    }
  }

  /// @dev Add dirty bits to the value stored at `mPtr` between bits 0 and `offset`
  function addDirtyBitsBefore(MemoryPointer mPtr, uint256 offset) internal pure {
    mPtr.write(mPtr.readUint256() | getMask(ScuffSide.DirtyUpperBits, offset));
  }

  /// @dev Add dirty bits to the value stored at `mPtr` between bits `offset` and 255
  function addDirtyBitsAfter(MemoryPointer mPtr, uint256 offset) internal pure {
    mPtr.write(mPtr.readUint256() | getMask(ScuffSide.DirtyLowerBits, offset));
  }
}

library ScuffPos {
  uint256 internal constant PositionsLength_ExclusionMask = 0xffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant PositionsLengthAndFirstValue_ExclusionMask = 0xffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant PositionsLength_BitsAfter = 224;
  uint256 internal constant PositionsLength_Byte = 3;

  function getLength(ScuffPositions arr) internal pure returns (uint256 length) {
    assembly {
      length := byte(PositionsLength_Byte, arr)
    }
  }

  function push(ScuffPositions arr, uint256 value) internal pure returns (ScuffPositions newArr) {
    uint256 length = arr.getLength() + 1;
    require(length < 25, "Scuff: positions array overflow");
    assembly {
      let bitsAfterNext := sub(PositionsLength_BitsAfter, shl(3, length))
      let insertion := shl(bitsAfterNext, value)
      newArr := or(or(and(arr, PositionsLength_ExclusionMask), shl(PositionsLength_BitsAfter, length)), insertion)
    }
  }

  function shift(ScuffPositions arr) internal pure returns (ScuffPositions newArr, uint256 value) {
    uint256 length = arr.getLength();
    require(length > 0, "Scuff: positions array underflow");
    length -= 1;
    assembly {
      value := byte(4, arr)
      newArr := or(shl(8, and(arr, PositionsLengthAndFirstValue_ExclusionMask)), shl(PositionsLength_BitsAfter, length))
    }
  }

  function get(ScuffPositions arr, uint256 index) internal pure returns (uint256 value) {
    assembly {
      value := byte(add(index, 4), arr)
    }
  }

  function toArray(ScuffPositions arr) internal pure returns (uint256[] memory values) {
    uint256 length = arr.getLength();
    values = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      values[i] = arr.get(i);
    }
  }

  function cache(ScuffPositions arr) internal pure returns (ScuffPositionsCache newArr) {
    assembly {
      newArr := mload(0x40)
      mstore(0x40, add(newArr, 0x20))
      mstore(newArr, arr)
    }
  }

  function read(ScuffPositionsCache arr) internal pure returns (ScuffPositions cached) {
    assembly {
      cached := mload(arr)
    }
  }

  function write(ScuffPositionsCache arr, ScuffPositions value) internal pure {
    assembly {
      mstore(arr, value)
    }
  }

  function getLength(ScuffPositionsCache arr) internal pure returns (uint256 length) {
    return arr.read().getLength();
  }

  function next(ScuffPositionsCache arr) internal pure returns (uint256 value) {
    (ScuffPositions cached, uint256 val) = arr.read().shift();
    arr.write(cached);
    return val;
  }
}