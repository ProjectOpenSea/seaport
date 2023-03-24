// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FulfillmentComponent } from "../../SeaportStructs.sol";
/**
 * @notice a MatchComponent is a packed uint256 that contains the equivalent struct:
 *
 * struct MatchComponent {
 *     uint240 amount;
 *     uint8 orderIndex;
 *     uint8 itemIndex;
 * }
 *
 * When treated as uint256s, an array of MatchComponents can be sorted by amount, which is useful for generating matchOrder fulfillments.
 */

type MatchComponent is uint256;

using MatchComponentType for MatchComponent global;

struct MatchComponentStruct {
    uint256 amount;
    uint8 orderIndex;
    uint8 itemIndex;
}

library MatchComponentType {
    uint256 private constant AMOUNT_SHL_OFFSET = 16;
    uint256 private constant ORDER_INDEX_SHL_OFFSET = 8;
    uint256 private constant BYTE_MASK = 0xFF;
    uint256 private constant AMOUNT_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000;
    uint256 private constant ORDER_INDEX_MASK = 0xFF00;
    uint256 private constant ITEM_INDEX_MASK = 0xFF;
    uint256 private constant NOT_AMOUNT_MASK = 0xFFFF;
    uint256 private constant NOT_ORDER_INDEX_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FF;
    uint256 private constant NOT_ITEM_INDEX_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;

    function createMatchComponent(
        uint240 amount,
        uint8 orderIndex,
        uint8 itemIndex
    ) internal pure returns (MatchComponent component) {
        assembly {
            component := or(
                shl(AMOUNT_SHL_OFFSET, amount),
                or(shl(ORDER_INDEX_SHL_OFFSET, orderIndex), itemIndex)
            )
        }
    }

    function getAmount(
        MatchComponent component
    ) internal pure returns (uint256 amount) {
        assembly {
            amount := shr(AMOUNT_SHL_OFFSET, component)
        }
    }

    function setAmount(
        MatchComponent component,
        uint240 amount
    ) internal pure returns (MatchComponent newComponent) {
        assembly {
            newComponent := or(
                and(component, NOT_AMOUNT_MASK),
                shl(AMOUNT_SHL_OFFSET, amount)
            )
        }
    }

    function getOrderIndex(
        MatchComponent component
    ) internal pure returns (uint8 orderIndex) {
        assembly {
            orderIndex := and(BYTE_MASK, shr(ORDER_INDEX_SHL_OFFSET, component))
        }
    }

    function setOrderIndex(
        MatchComponent component,
        uint8 orderIndex
    ) internal pure returns (MatchComponent newComponent) {
        assembly {
            newComponent := or(
                and(component, NOT_ORDER_INDEX_MASK),
                shl(ORDER_INDEX_SHL_OFFSET, orderIndex)
            )
        }
    }

    function getItemIndex(
        MatchComponent component
    ) internal pure returns (uint8 itemIndex) {
        assembly {
            itemIndex := and(BYTE_MASK, component)
        }
    }

    function setItemIndex(
        MatchComponent component,
        uint8 itemIndex
    ) internal pure returns (MatchComponent newComponent) {
        assembly {
            newComponent := or(and(component, NOT_ITEM_INDEX_MASK), itemIndex)
        }
    }

    function unpack(
        MatchComponent component
    )
        internal
        pure
        returns (uint240 amount, uint8 orderIndex, uint8 itemIndex)
    {
        assembly {
            amount := shr(AMOUNT_SHL_OFFSET, component)
            orderIndex := and(BYTE_MASK, shr(ORDER_INDEX_SHL_OFFSET, component))
            itemIndex := and(BYTE_MASK, component)
        }
    }

    function subtractAmount(
        MatchComponent minuend,
        MatchComponent subtrahend
    ) internal pure returns (MatchComponent newComponent) {
        uint256 minuendAmount = minuend.getAmount();
        uint256 subtrahendAmount = subtrahend.getAmount();
        uint240 newAmount = uint240(minuendAmount - subtrahendAmount);
        return minuend.setAmount(newAmount);
    }

    function addAmount(
        MatchComponent target,
        MatchComponent ref
    ) internal pure returns (MatchComponent) {
        uint256 targetAmount = target.getAmount();
        uint256 refAmount = ref.getAmount();
        uint240 newAmount = uint240(targetAmount + refAmount);
        return target.setAmount(newAmount);
    }

    function toFulfillmentComponent(
        MatchComponent component
    ) internal pure returns (FulfillmentComponent memory) {
        (, uint8 orderIndex, uint8 itemIndex) = component.unpack();
        return
            FulfillmentComponent({
                orderIndex: orderIndex,
                itemIndex: itemIndex
            });
    }

    function toFulfillmentComponents(
        MatchComponent[] memory components
    ) internal pure returns (FulfillmentComponent[] memory) {
        FulfillmentComponent[]
            memory fulfillmentComponents = new FulfillmentComponent[](
                components.length
            );
        for (uint256 i = 0; i < components.length; i++) {
            fulfillmentComponents[i] = components[i].toFulfillmentComponent();
        }
        return fulfillmentComponents;
    }

    function toUints(
        MatchComponent[] memory components
    ) internal pure returns (uint256[] memory uints) {
        assembly {
            uints := components
        }
    }

    function fromUints(
        uint256[] memory uints
    ) internal pure returns (MatchComponent[] memory components) {
        assembly {
            components := uints
        }
    }

    function toStruct(
        MatchComponent component
    ) internal pure returns (MatchComponentStruct memory) {
        (uint240 amount, uint8 orderIndex, uint8 itemIndex) = component
            .unpack();
        return
            MatchComponentStruct({
                amount: amount,
                orderIndex: orderIndex,
                itemIndex: itemIndex
            });
    }

    function toStructs(
        MatchComponent[] memory components
    ) internal pure returns (MatchComponentStruct[] memory) {
        MatchComponentStruct[] memory structs = new MatchComponentStruct[](
            components.length
        );
        for (uint256 i = 0; i < components.length; i++) {
            structs[i] = components[i].toStruct();
        }
        return structs;
    }

    function getPackedIndexes(
        MatchComponentStruct memory component
    ) internal pure returns (uint256) {
        return (component.orderIndex << 8) | component.itemIndex;
    }

    function sort(MatchComponentStruct[] memory components) internal pure {
        sort(components, getPackedIndexes);
    }

    // Sorts the array in-place with intro-quicksort.
    function sort(
        MatchComponentStruct[] memory a,
        function(MatchComponentStruct memory)
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
                    MatchComponentStruct memory k = a[i];
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
