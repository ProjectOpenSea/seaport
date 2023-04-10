// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { RandomBytes } from "./RandomBytes.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

contract RandomBytesTest is Test {
    function testRandomBytes() public {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(0);
        bytes memory bytesArray = RandomBytes.randomBytes(prng, 100);
        assertEq(bytesArray.length, 100, "randomBytes length");
        // assert not more than 5 0 bytes in a row
        // this will fail 1/2^40 times
        uint256 zeroCount = 0;
        for (uint256 i = 0; i < bytesArray.length; i++) {
            if (bytesArray[i] == 0) {
                zeroCount++;
            } else {
                zeroCount = 0;
            }
            assertLt(zeroCount, 6, "randomBytes zero count");
        }
    }

    function testRandomBytes(uint256 seed) public {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(seed);
        bytes memory bytesArray = RandomBytes.randomBytes(prng, 100);
        assertEq(bytesArray.length, 100, "randomBytes length");
        // assert not more than 5 0 bytes in a row
        // this will fail 1/2^40 times :(
        uint256 zeroCount = 0;
        for (uint256 i = 0; i < bytesArray.length; i++) {
            if (bytesArray[i] == 0) {
                zeroCount++;
            } else {
                zeroCount = 0;
            }
            assertLt(zeroCount, 6, "randomBytes zero count");
        }
    }

    function testRandomBytesRandomLength() public {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(0);
        bytes memory bytesArray = RandomBytes.randomBytes(prng);
        assertLt(bytesArray.length, 1001, "randomBytes length");
        assertGt(bytesArray.length, 0, "randomBytes length");
        // assert not more than 5 0 bytes in a row
        // this will fail 1/2^40 times
        uint256 zeroCount = 0;
        for (uint256 i = 0; i < bytesArray.length; i++) {
            if (bytesArray[i] == 0) {
                zeroCount++;
            } else {
                zeroCount = 0;
            }
            assertLt(zeroCount, 6, "randomBytes zero count");
        }
    }

    function testRandomBytesRandomLength(uint256 seed) public {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG(seed);
        bytes memory bytesArray = RandomBytes.randomBytes(prng);
        assertLt(bytesArray.length, 1001, "randomBytes length");
        assertGt(bytesArray.length, 0, "randomBytes length");
        // assert not more than 5 0 bytes in a row
        // this will fail 1/2^40 times
        uint256 zeroCount = 0;
        for (uint256 i = 0; i < bytesArray.length; i++) {
            if (bytesArray[i] == 0) {
                zeroCount++;
            } else {
                zeroCount = 0;
            }
            assertLt(zeroCount, 6, "randomBytes zero count");
        }
    }
}
