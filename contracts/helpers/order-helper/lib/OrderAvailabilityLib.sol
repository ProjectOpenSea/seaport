// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import { UnavailableReason } from "seaport-sol/SeaportSol.sol";

import { AdvancedOrder } from "seaport-sol/SeaportStructs.sol";

import { OrderStructureLib, State } from "./OrderStructureLib.sol";

import "forge-std/console.sol";

library OrderAvailabilityLib {
    using OrderStructureLib for AdvancedOrder;

    function isAvailable(
        AdvancedOrder memory order,
        ConsiderationInterface seaport
    ) internal view returns (bool) {
        return unavailableReason(order, seaport) == UnavailableReason.AVAILABLE;
    }

    function unavailableReason(
        AdvancedOrder memory order,
        ConsiderationInterface seaport
    ) internal view returns (UnavailableReason) {
        if (order.parameters.endTime <= block.timestamp) {
            return UnavailableReason.EXPIRED;
        }
        if (order.parameters.startTime > block.timestamp) {
            return UnavailableReason.STARTS_IN_FUTURE;
        }
        if (order.getState(seaport) == State.CANCELLED) {
            return UnavailableReason.CANCELLED;
        }
        if (order.getState(seaport) == State.FULLY_FILLED) {
            return UnavailableReason.ALREADY_FULFILLED;
        }
        return UnavailableReason.AVAILABLE;
    }

    function unavailableReasons(
        AdvancedOrder[] memory orders,
        uint256 maximumFulfilled,
        ConsiderationInterface seaport
    ) internal view returns (UnavailableReason[] memory) {
        UnavailableReason[] memory reasons = new UnavailableReason[](
            orders.length
        );
        uint256 totalAvailable;
        UnavailableReason reason;
        for (uint256 i = 0; i < orders.length; i++) {
            if (totalAvailable < maximumFulfilled) {
                reason = unavailableReason(orders[i], seaport);
            } else {
                reason = UnavailableReason.MAX_FULFILLED_SATISFIED;
            }
            reasons[i] = reason;
            if (reason == UnavailableReason.AVAILABLE) {
                totalAvailable++;
                console.log("available");
                console.log(uint8(reason));
            } else {
                console.log("unavailable");
                console.log(uint8(reason));
            }
        }
        return reasons;
    }
}
