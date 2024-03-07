// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics } from "./EventHashes.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

library OrdersMatchedEventsLib {
    event OrdersMatched(bytes32[] orderHashes);

    function getOrdersMatchedEventHash(
        FuzzTestContext memory context
    ) internal pure returns (bytes32 eventHash) {
        uint256 totalAvailableOrders = 0;
        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
                ++totalAvailableOrders;
            }
        }

        bytes32[] memory orderHashes = new bytes32[](totalAvailableOrders);

        totalAvailableOrders = 0;
        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
                orderHashes[totalAvailableOrders++] = context
                    .executionState
                    .orderDetails[i]
                    .orderHash;
            }
        }

        return
            getEventHashWithTopics(
                address(context.seaport), // emitter
                OrdersMatched.selector, // topic0
                keccak256(abi.encode(orderHashes)) // dataHash
            );
    }
}
