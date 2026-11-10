// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface
} from "seaport-types/src/interfaces/AbridgedTokenInterfaces.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { AdjustedAmountOfferer } from "./AdjustedAmountOfferer.sol";

/**
 * @dev Contract offerer that echoes the requested items back, like
 *      AdjustedAmountOfferer with no adjustment, except that it can change the
 *      item type, token or identifier of the first offer or consideration
 *      item it returns.
 */
contract AlteredItemOfferer is AdjustedAmountOfferer {
    enum Field {
        NONE,
        ITEM_TYPE,
        TOKEN,
        IDENTIFIER
    }

    bool public alterConsideration;
    Field public field;
    address public immutable otherToken;

    constructor(
        address[] memory seaports,
        ERC20Interface _token1,
        ERC20Interface _token2,
        address _otherToken
    ) AdjustedAmountOfferer(seaports, _token1, _token2, 0, 0) {
        otherToken = _otherToken;
    }

    function setAlteration(bool _alterConsideration, Field _field) external {
        alterConsideration = _alterConsideration;
        field = _field;
    }

    function generateOrder(
        address,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata c
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        (offer, consideration) =
            previewOrder(address(this), address(this), a, b, c);

        if (field == Field.NONE) {
            return (offer, consideration);
        }

        if (alterConsideration) {
            ReceivedItem memory item = consideration[0];
            if (field == Field.ITEM_TYPE) {
                item.itemType = ItemType.ERC1155;
            } else if (field == Field.TOKEN) {
                item.token = otherToken;
            } else {
                item.identifier = 1;
            }
        } else {
            SpentItem memory item = offer[0];
            if (field == Field.ITEM_TYPE) {
                item.itemType = ItemType.ERC1155;
            } else if (field == Field.TOKEN) {
                item.token = otherToken;
            } else {
                item.identifier = 1;
            }
        }
    }
}
