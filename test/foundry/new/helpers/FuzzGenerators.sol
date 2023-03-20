// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import {
    AdvancedOrdersSpace,
    OrderComponentsSpace,
    OfferItemSpace,
    ConsiderationItemSpace
} from "seaport-sol/StructSpace.sol";

import "seaport-sol/SeaportSol.sol";

uint256 constant UINT256_MAX = type(uint256).max;

// @dev Implementation cribbed from forge-std bound
function bound(
    uint256 x,
    uint256 min,
    uint256 max
) pure returns (uint256 result) {
    require(min <= max, "Max is less than min.");
    // If x is between min and max, return x directly. This is to ensure that dictionary values
    // do not get shifted if the min is nonzero.
    if (x >= min && x <= max) return x;

    uint256 size = max - min + 1;

    // If the value is 0, 1, 2, 3, warp that to min, min+1, min+2, min+3. Similarly for the UINT256_MAX side.
    // This helps ensure coverage of the min/max values.
    if (x <= 3 && size > x) return min + x;
    if (x >= UINT256_MAX - 3 && size > UINT256_MAX - x)
        return max - (UINT256_MAX - x);

    // Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
    if (x > max) {
        uint256 diff = x - max;
        uint256 rem = diff % size;
        if (rem == 0) return max;
        result = min + rem - 1;
    } else if (x < min) {
        uint256 diff = min - x;
        uint256 rem = diff % size;
        if (rem == 0) return min;
        result = max - rem + 1;
    }
}

library AdvancedOrdersSpaceGenerator {
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;

    using OrderComponentsSpaceGenerator for OrderComponentsSpace;

    function generate(
        AdvancedOrdersSpace memory space
    ) internal pure returns (AdvancedOrder[] memory) {
        uint256 len = bound(space.orders.length, 0, 10);
        AdvancedOrder[] memory orders = new AdvancedOrder[](len);

        for (uint256 i; i < len; ++i) {
            orders[i] = OrderLib
                .empty()
                .withParameters(space.orders[i].generate())
                .toAdvancedOrder({
                    numerator: 0,
                    denominator: 0,
                    extraData: bytes("")
                });
        }
        return orders;
    }
}

library OrderComponentsSpaceGenerator {
    using OrderParametersLib for OrderParameters;

    using OfferItemSpaceGenerator for OfferItemSpace[];
    using ConsiderationItemSpaceGenerator for ConsiderationItemSpace[];

    function generate(
        OrderComponentsSpace memory space
    ) internal pure returns (OrderParameters memory) {
        return
            OrderParametersLib
                .empty()
                .withOffer(space.offer.generate())
                .withConsideration(space.consideration.generate());
    }
}

library OfferItemSpaceGenerator {
    using OfferItemLib for OfferItem;

    function generate(
        OfferItemSpace[] memory space
    ) internal pure returns (OfferItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        OfferItem[] memory offerItems = new OfferItem[](len);

        for (uint256 i; i < len; ++i) {
            offerItems[i] = generate(space[i]);
        }
        return offerItems;
    }

    function generate(
        OfferItemSpace memory space
    ) internal pure returns (OfferItem memory) {
        return OfferItemLib.empty().withItemType(space.itemType);
    }
}

library ConsiderationItemSpaceGenerator {
    using ConsiderationItemLib for ConsiderationItem;

    function generate(
        ConsiderationItemSpace[] memory space
    ) internal pure returns (ConsiderationItem[] memory) {
        uint256 len = bound(space.length, 0, 10);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            len
        );

        for (uint256 i; i < len; ++i) {
            considerationItems[i] = generate(space[i]);
        }
        return considerationItems;
    }

    function generate(
        ConsiderationItemSpace memory space
    ) internal pure returns (ConsiderationItem memory) {
        return ConsiderationItemLib.empty().withItemType(space.itemType);
    }
}
