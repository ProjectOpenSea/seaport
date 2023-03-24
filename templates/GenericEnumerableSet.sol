// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { <T> } from "seaport-sol/SeaportSol.sol";

struct <T>Set {
    mapping(bytes32 => uint256) offByOneIndex;
    <T>[] enumeration;
}

library <T>SetLib {
    error NotPresent();

    function add(
        <T>Set storage set,
        <T> memory value
    ) internal returns (bool added) {
        // add value to enumeration; hash it to set its entry in the offByOneIndex
        bytes32 key = keccak256(abi.encode(value));
        if (set.offByOneIndex[key] == 0) {
            set.enumeration.push(value);
            set.offByOneIndex[key] = set.enumeration.length;
            added = true;
        } else {
            added = false;
        }
    }

    // remove value from enumeration and replace it with last member of enumeration
    // if not last member, update offByOneIndex of last member
    function remove(
        <T>Set storage set,
        <T> memory value
    ) internal returns (bool removed) {
        bytes32 key = keccak256(abi.encode(value));
        uint256 index = set.offByOneIndex[key];
        if (index > 0) {
            uint256 lastIndex = set.enumeration.length - 1;
            <T> memory lastValue = set.enumeration[lastIndex];
            set.enumeration[index - 1] = lastValue;
            bytes32 lastKey = keccak256(abi.encode(lastValue));
            // if lastKey is the same as key, then we are removing the last element; do not update it
            if (lastKey != key) {
                set.offByOneIndex[lastKey] = index;
            }
            set.enumeration.pop();
            delete set.offByOneIndex[key];
            removed = true;
        } else {
            removed = false;
        }
    }

    function removeAll(<T>Set storage set, <T>[] memory values) internal {
        for (uint256 i = 0; i < values.length; i++) {
            remove(set, values[i]);
        }
    }

    function removeAll(<T>Set storage set, <T>[][] memory values) internal {
        for (uint256 i = 0; i < values.length; i++) {
            removeAll(set, values[i]);
        }
    }

    function contains(
        <T>Set storage set,
        <T> memory value
    ) internal view returns (bool) {
        return set.offByOneIndex[keccak256(abi.encode(value))] > 0;
    }

    function length(<T>Set storage set) internal view returns (uint256) {
        return set.enumeration.length;
    }

    function at(
        <T>Set storage set,
        uint256 index
    ) internal view returns (<T> memory) {
        return set.enumeration[index];
    }

    function clear(<T>Set storage set) internal {
        while (set.enumeration.length > 0) {
            <T> memory component = set.enumeration[set.enumeration.length - 1];
            delete set.offByOneIndex[keccak256(abi.encode(component))];
            set.enumeration.pop();
        }
    }
}
