// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    BasicOrderParameters,
    OrderParameters
} from "../../../lib/ConsiderationStructs.sol";
import {
    OrderType,
    BasicOrderType,
    ItemType,
    BasicOrderRouteType
} from "../../../lib/ConsiderationEnums.sol";

library SeaportEnumsLib {
    function parseBasicOrderType(
        BasicOrderType basicOrderType
    )
        internal
        pure
        returns (
            OrderType orderType,
            ItemType offerType,
            ItemType considerationType,
            ItemType additionalRecipientsType,
            bool offerTypeIsAdditionalRecipientsType
        )
    {
        assembly {
            // Mask all but 2 least-significant bits to derive the order type.
            orderType := and(basicOrderType, 3)

            // Divide basicOrderType by four to derive the route.
            let route := shr(2, basicOrderType)
            offerTypeIsAdditionalRecipientsType := gt(route, 3)

            // If route > 1 additionalRecipient items are ERC20 (1) else Eth (0)
            additionalRecipientsType := gt(route, 1)

            // If route > 2, receivedItemType is route - 2. If route is 2,
            // the receivedItemType is ERC20 (1). Otherwise, it is Eth (0).
            considerationType := add(
                mul(sub(route, 2), gt(route, 2)),
                eq(route, 2)
            )

            // If route > 3, offeredItemType is ERC20 (1). Route is 2 or 3,
            // offeredItemType = route. Route is 0 or 1, it is route + 2.
            offerType := add(route, mul(iszero(additionalRecipientsType), 2))
        }
    }
}
