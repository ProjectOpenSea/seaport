// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

library RandomBytes {
    uint256 constant MAX_RANDOM_LENGTH = 1000;

    function randomBytes(
        LibPRNG.PRNG memory prng,
        uint256 length
    ) internal pure returns (bytes memory) {
        bytes memory bytesArray = new bytes(length);
        // track the number of bytes we've written
        uint256 i;
        // loop until we've written `length` bytes
        while (i < length) {
            // get a random chunk of 32 bytes
            bytes32 randomChunk = bytes32(LibPRNG.next(prng));
            // loop through the chunk and write each byte to the output
            // stop if we've written `length` bytes
            for (uint256 j; j < 32 && i < length; ) {
                bytesArray[i] = randomChunk[j];
                unchecked {
                    // increment both counters
                    ++i;
                    ++j;
                }
            }
        }
        return bytesArray;
    }

    function randomBytes(
        LibPRNG.PRNG memory prng
    ) internal pure returns (bytes memory) {
        // get a random length between 1 and MAX_RANDOM_LENGTH
        uint256 length = (LibPRNG.next(prng) % MAX_RANDOM_LENGTH) + 1;
        return randomBytes(prng, length);
    }
}
