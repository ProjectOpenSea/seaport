// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { FulfillmentComponent } from "../../SeaportSol.sol";
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
            component :=
                or(
                    shl(AMOUNT_SHL_OFFSET, amount),
                    or(shl(ORDER_INDEX_SHL_OFFSET, orderIndex), itemIndex)
                )
        }
    }

    function getAmount(MatchComponent component)
        internal
        pure
        returns (uint256 amount)
    {
        assembly {
            amount := shr(AMOUNT_SHL_OFFSET, component)
        }
    }

    function setAmount(MatchComponent component, uint240 amount)
        internal
        pure
        returns (MatchComponent newComponent)
    {
        assembly {
            newComponent :=
                or(and(component, NOT_AMOUNT_MASK), shl(AMOUNT_SHL_OFFSET, amount))
        }
    }

    function getOrderIndex(MatchComponent component)
        internal
        pure
        returns (uint8 orderIndex)
    {
        assembly {
            orderIndex := and(BYTE_MASK, shr(ORDER_INDEX_SHL_OFFSET, component))
        }
    }

    function setOrderIndex(MatchComponent component, uint8 orderIndex)
        internal
        pure
        returns (MatchComponent newComponent)
    {
        assembly {
            newComponent :=
                or(
                    and(component, NOT_ORDER_INDEX_MASK),
                    shl(ORDER_INDEX_SHL_OFFSET, orderIndex)
                )
        }
    }

    function getItemIndex(MatchComponent component)
        internal
        pure
        returns (uint8 itemIndex)
    {
        assembly {
            itemIndex := and(BYTE_MASK, component)
        }
    }

    function setItemIndex(MatchComponent component, uint8 itemIndex)
        internal
        pure
        returns (MatchComponent newComponent)
    {
        assembly {
            newComponent := or(and(component, NOT_ITEM_INDEX_MASK), itemIndex)
        }
    }

    function unpack(MatchComponent component)
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

    function subtractAmount(MatchComponent minuend, MatchComponent subtrahend)
        internal
        pure
        returns (MatchComponent newComponent)
    {
        uint256 minuendAmount = minuend.getAmount();
        uint256 subtrahendAmount = subtrahend.getAmount();
        uint240 newAmount = uint240(minuendAmount - subtrahendAmount);
        return minuend.setAmount(newAmount);
    }

    function addAmount(MatchComponent target, MatchComponent ref)
        internal
        pure
        returns (MatchComponent)
    {
        uint256 targetAmount = target.getAmount();
        uint256 refAmount = ref.getAmount();
        uint240 newAmount = uint240(targetAmount + refAmount);
        return target.setAmount(newAmount);
    }

    function toFulfillmentComponent(MatchComponent component)
        internal
        pure
        returns (FulfillmentComponent memory)
    {
        (, uint8 orderIndex, uint8 itemIndex) = component.unpack();
        return FulfillmentComponent({
            orderIndex: orderIndex,
            itemIndex: itemIndex
        });
    }

    function toFulfillmentComponents(MatchComponent[] memory components)
        internal
        pure
        returns (FulfillmentComponent[] memory)
    {
        FulfillmentComponent[] memory fulfillmentComponents =
            new FulfillmentComponent[](components.length);
        for (uint256 i = 0; i < components.length; i++) {
            fulfillmentComponents[i] = components[i].toFulfillmentComponent();
        }
        return fulfillmentComponents;
    }

    function toUints(MatchComponent[] memory components)
        internal
        pure
        returns (uint256[] memory uints)
    {
        assembly {
            uints := components
        }
    }

    function fromUints(uint256[] memory uints)
        internal
        pure
        returns (MatchComponent[] memory components)
    {
        assembly {
            components := uints
        }
    }
}
