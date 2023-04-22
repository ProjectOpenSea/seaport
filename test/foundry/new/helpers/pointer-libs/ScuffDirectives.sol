// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/../PointerLibraries.sol";

type ScuffDirectivesArray is uint256;

type ScuffDirective is uint256;

using Scuff for ScuffDirective global;
using Scuff for ScuffDirectivesArray global;

library Scuff {
  /// 933:9:9
  enum ScuffSide { DirtyUpperBits, DirtyLowerBits }

  uint256 internal constant MaxUint256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint256 internal constant ScuffDirective_Kind_BitsAfter = 248;
  uint256 internal constant ScuffDirective_Side_BitsAfter = 240;
  uint256 internal constant ScuffDirective_BitOffset_BitsAfter = 232;
  uint256 internal constant ScuffDirective_Pointer_BitsAfter = 0;
  uint256 internal constant ScuffDirective_Kind_Byte = 0;
  uint256 internal constant ScuffDirective_Side_Byte = 1;
  uint256 internal constant ScuffDirective_BitOffset_Byte = 2;
  uint256 internal constant ScuffDirective_Pointer_Mask = 0xffffffff;

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

  function decode(ScuffDirective directive) internal pure returns (uint256 kind, ScuffSide side, uint256 bitOffset, MemoryPointer pointer) {
    assembly {
      kind := byte(ScuffDirective_Kind_Byte, directive)
      side := byte(ScuffDirective_Side_Byte, directive)
      bitOffset := byte(ScuffDirective_BitOffset_Byte, directive)
      pointer := and(directive, ScuffDirective_Pointer_Mask)
    }
  }

  function encode(uint256 kind, ScuffSide side, uint256 bitOffset, MemoryPointer pointer) internal pure returns (ScuffDirective directive) {
    assembly {
      directive := or(or(shl(ScuffDirective_Kind_BitsAfter, kind), shl(ScuffDirective_Side_BitsAfter, side)), or(shl(ScuffDirective_BitOffset_BitsAfter, bitOffset), pointer))
    }
  }

  /// @dev Create directive to set every bit from 0 to `bitOffset`
  /// on the value stored at `pointer`
  function upper(uint256 kind, uint256 bitOffset, MemoryPointer pointer) internal pure returns (ScuffDirective directive) {
    return encode(kind, ScuffSide.DirtyUpperBits, bitOffset, pointer);
  }

  /// @dev Create directive to set every bit from `offset` to 255
  /// on the value stored at `pointer`
  function lower(uint256 kind, uint256 bitOffset, MemoryPointer pointer) internal pure returns (ScuffDirective directive) {
    return encode(kind, ScuffSide.DirtyLowerBits, bitOffset, pointer);
  }

  function getMask(ScuffSide side, uint256 bitOffset) internal pure returns (uint256 mask) {
    assembly {
      switch side
      case 1 {
        mask := shl(sub(256, bitOffset), MaxUint256)
      }
      default {
        mask := shr(bitOffset, MaxUint256)
      }
    }
  }

  function applyScuff(ScuffDirective directive) internal pure {
    (, ScuffSide side, uint256 bitOffset, MemoryPointer pointer) = decode(directive);
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