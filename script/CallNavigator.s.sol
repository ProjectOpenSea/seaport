// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";

import {
    ConsiderationInterface,
    NavigatorRequest,
    SeaportNavigatorInterface,
    SeaportValidatorInterface
} from "../contracts/helpers/navigator/SeaportNavigator.sol";

import {
    NavigatorAdvancedOrder,
    NavigatorConsiderationItem,
    NavigatorOfferItem,
    NavigatorOrderParameters
} from "../contracts/helpers/navigator/lib/SeaportNavigatorTypes.sol";

import {
    AggregationStrategy,
    FulfillAvailableStrategy,
    FulfillmentStrategy,
    MatchStrategy
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

import { OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

contract CallNavigator is Script {
    address private constant GOERLI_NAVIGATOR =
        0x76093Af4C8330D69676d920d550d9901110792D5;

    function run() public view {
        // Create an empty request.
        NavigatorRequest memory request;

        // Set Seaport and SeaportValidator addresses.
        request.seaport = ConsiderationInterface(
            0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC
        );
        request.validator = SeaportValidatorInterface(
            0xBa7a3AD8aDD5D37a89a73d76e9Fb4270aeD264Ad
        );

        // Set up orders, using navigator order structs.
        NavigatorAdvancedOrder[] memory orders = new NavigatorAdvancedOrder[](
            1
        );
        orders[0] = NavigatorAdvancedOrder({
            parameters: NavigatorOrderParameters({
                offerer: 0xcc476d5Adc341B31405891E78694186454775926,
                zone: address(0),
                offer: new NavigatorOfferItem[](0),
                consideration: new NavigatorConsiderationItem[](0),
                orderType: OrderType.FULL_OPEN,
                startTime: 1686684156,
                endTime: 1686687756,
                zoneHash: bytes32(0),
                salt: uint256(
                    0x10a16a76000000000000000000000000000000000000000000000000af0f8c13
                ),
                conduitKey: bytes32(0),
                totalOriginalConsiderationItems: 0
            }),
            numerator: 1,
            denominator: 1,
            signature: (
                hex"3c792711cff5e3b9ca789b3fc08f345d069ca3f161d0a3b3e2700ad95c"
                hex"691c6c8079a4c12149a9834797d50a4c0856cc11430bdd28bcf02b0798"
                hex"7aefb6d21ab2"
            ),
            extraData: ""
        });
        request.orders = orders;

        // Set up call context data
        request.caller = 0xcc476d5Adc341B31405891E78694186454775926;
        request.recipient = 0xcc476d5Adc341B31405891E78694186454775926;
        request.maximumFulfilled = 1;

        // Set fulfillment parameters
        request.fulfillmentStrategy = FulfillmentStrategy(
            AggregationStrategy.MAXIMUM,
            FulfillAvailableStrategy.KEEP_ALL,
            MatchStrategy.MAX_INCLUSION
        );
        request.preferMatch = true;

        // Call the navigator with the configured request.
        SeaportNavigatorInterface(GOERLI_NAVIGATOR).prepare(request);
    }
}
