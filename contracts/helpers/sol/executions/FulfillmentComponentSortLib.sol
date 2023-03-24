// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FulfillmentComponent } from "../SeaportStructs.sol";

library FulfillmentComponentSortLib {
    function key(
        FulfillmentComponent memory component
    ) internal pure returns (uint256) {
        return (uint256(component.orderIndex) << 8) | component.itemIndex;
    }

    function sort(FulfillmentComponent[] memory components) internal pure {
        sort(components, key);
    }

    // Sorts the array in-place with intro-quicksort.
    function sort(
        FulfillmentComponent[] memory a,
        function(FulfillmentComponent memory)
            internal
            pure
            returns (uint256) accessor
    ) internal pure {
        if (a.length < 2) {
            return;
        }

        uint256[] memory stack = new uint256[](2 * a.length);
        uint256 stackIndex = 0;

        uint256 l = 0;
        uint256 h = a.length - 1;

        stack[stackIndex++] = l;
        stack[stackIndex++] = h;

        while (stackIndex > 0) {
            h = stack[--stackIndex];
            l = stack[--stackIndex];

            if (h - l <= 12) {
                // Insertion sort for small subarrays
                for (uint256 i = l + 1; i <= h; i++) {
                    FulfillmentComponent memory k = a[i];
                    uint256 j = i;
                    while (j > l && accessor(a[j - 1]) > accessor(k)) {
                        a[j] = a[j - 1];
                        j--;
                    }
                    a[j] = k;
                }
            } else {
                // Intro-Quicksort
                uint256 p = (l + h) / 2;

                // Median of 3
                if (accessor(a[l]) > accessor(a[p])) {
                    (a[l], a[p]) = (a[p], a[l]);
                }
                if (accessor(a[l]) > accessor(a[h])) {
                    (a[l], a[h]) = (a[h], a[l]);
                }
                if (accessor(a[p]) > accessor(a[h])) {
                    (a[p], a[h]) = (a[h], a[p]);
                }

                uint256 pivot = accessor(a[p]);
                uint256 i = l;
                uint256 j = h;

                while (i <= j) {
                    while (accessor(a[i]) < pivot) {
                        i++;
                    }
                    while (accessor(a[j]) > pivot) {
                        j--;
                    }
                    if (i <= j) {
                        (a[i], a[j]) = (a[j], a[i]);
                        i++;
                        j--;
                    }
                }

                if (j > l) {
                    stack[stackIndex++] = l;
                    stack[stackIndex++] = j;
                }
                if (i < h) {
                    stack[stackIndex++] = i;
                    stack[stackIndex++] = h;
                }
            }
        }
    }
}
