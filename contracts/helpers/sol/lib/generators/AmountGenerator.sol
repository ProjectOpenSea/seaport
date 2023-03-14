// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Amount } from "../../SpaceEnums.sol";
import { AmountDegree } from "../../SpaceEnums.sol";
import { OfferItemLib } from "../OfferItemLib.sol";
import { ConsiderationItemLib } from "../ConsiderationItemLib.sol";
import { AmountDegreeGenerator } from "./AmountDegreeGenerator.sol";

import { OfferItem, ConsiderationItem } from "../../SeaportStructs.sol";

library AmountGenerator {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    function generate(
        OfferItem memory item,
        Amount amount,
        AmountDegree degree,
        uint256 high,
        uint256 low
    ) internal pure returns (OfferItem memory) {
        high = AmountDegreeGenerator.generate(degree, high);
        low = AmountDegreeGenerator.generate(degree, low);

        if (amount == Amount.FIXED) {
            return item.withStartAmount(high).withEndAmount(high);
        }
        if (amount == Amount.ASCENDING) {
            return item.withStartAmount(low).withEndAmount(high);
        }
        if (amount == Amount.DESCENDING) {
            return item.withStartAmount(high).withEndAmount(low);
        }
        return item;
    }

    function generate(
        ConsiderationItem memory item,
        Amount amount,
        AmountDegree degree,
        uint256 high,
        uint256 low
    ) internal pure returns (ConsiderationItem memory) {
        high = AmountDegreeGenerator.generate(degree, high);
        low = AmountDegreeGenerator.generate(degree, low);

        if (amount == Amount.FIXED) {
            return item.withStartAmount(high).withEndAmount(high);
        }
        if (amount == Amount.ASCENDING) {
            return item.withStartAmount(low).withEndAmount(high);
        }
        if (amount == Amount.DESCENDING) {
            return item.withStartAmount(high).withEndAmount(low);
        }
        return item;
    }
}
