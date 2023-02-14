// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library ArrayLib {
    function setBytes32s(bytes32[] storage array, bytes32[] memory values) internal {
        while (array.length > 0) {
            array.pop();
        }
        for (uint256 i = 0; i < values.length; i++) {
            array.push(values[i]);
        }
    }

    function copy(bytes32[] memory array) internal pure returns (bytes32[] memory) {
        bytes32[] memory copiedArray = new bytes32[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            copiedArray[i] = array[i];
        }
        return copiedArray;
    }
}
