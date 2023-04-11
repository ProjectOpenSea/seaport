// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { FuzzTestContext } from "../FuzzTestContextLib.sol";

import { getEventHashWithTopics } from "./EventHashes.sol";

library OrdersMatchedEventsLib {
    event OrdersMatched(bytes32[] orderHashes);

    function getOrdersMatchedEventHash(
        FuzzTestContext memory context
    ) internal pure returns (bytes32 eventHash) {
        if (
            context.expectedAvailableOrders.length !=
            context.orderHashes.length
        ) {
            revert("OrdersMatchedEventsLib: available array length != hashes");
        }

        uint256 totalAvailableOrders = 0;
        for (uint256 i = 0; i < context.expectedAvailableOrders.length; ++i) {
            if (context.expectedAvailableOrders[i]) {
                ++totalAvailableOrders;
            }
        }

        bytes32[] memory orderHashes = new bytes32[](
            totalAvailableOrders
        );

        totalAvailableOrders = 0;
        for (uint256 i = 0; i < context.orderHashes.length; ++i) {
            if (context.expectedAvailableOrders[i]) {
                orderHashes[totalAvailableOrders++] = context.orderHashes[i];
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
