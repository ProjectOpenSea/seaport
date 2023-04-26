// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FulfillmentComponent } from "../SeaportStructs.sol";

struct FulfillmentComponentSet {
    mapping(bytes32 => uint256) offByOneIndex;
    FulfillmentComponent[] enumeration;
}

library FulfillmentComponentSetLib {
    error NotPresent();

    function add(
        FulfillmentComponentSet storage set,
        FulfillmentComponent memory value
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
        FulfillmentComponentSet storage set,
        FulfillmentComponent memory value
    ) internal returns (bool removed) {
        bytes32 key = keccak256(abi.encode(value));
        uint256 index = set.offByOneIndex[key];
        if (index > 0) {
            uint256 lastIndex = set.enumeration.length - 1;
            FulfillmentComponent memory lastValue = set.enumeration[lastIndex];
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

    function removeAll(
        FulfillmentComponentSet storage set,
        FulfillmentComponent[] memory values
    ) internal {
        for (uint256 i = 0; i < values.length; i++) {
            remove(set, values[i]);
        }
    }

    function removeAll(
        FulfillmentComponentSet storage set,
        FulfillmentComponent[][] memory values
    ) internal {
        for (uint256 i = 0; i < values.length; i++) {
            removeAll(set, values[i]);
        }
    }

    function contains(
        FulfillmentComponentSet storage set,
        FulfillmentComponent memory value
    ) internal view returns (bool) {
        return set.offByOneIndex[keccak256(abi.encode(value))] > 0;
    }

    function length(
        FulfillmentComponentSet storage set
    ) internal view returns (uint256) {
        return set.enumeration.length;
    }

    function at(
        FulfillmentComponentSet storage set,
        uint256 index
    ) internal view returns (FulfillmentComponent memory) {
        return set.enumeration[index];
    }

    function clear(FulfillmentComponentSet storage set) internal {
        while (set.enumeration.length > 0) {
            FulfillmentComponent memory component = set.enumeration[
                set.enumeration.length - 1
            ];
            delete set.offByOneIndex[keccak256(abi.encode(component))];
            set.enumeration.pop();
        }
    }
}
