// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    FulfillAvailableAdvancedOrdersParams
} from "../helpers/SeaportRouterStructs.sol";

import { Execution } from "../lib/ConsiderationStructs.sol";

interface SeaportRouterInterface {
    /**
     * @dev Fallback function to receive excess ether, in case total amount of
     *      ether sent is more than the amount required to fulfill the order.
     */
    receive() external payable;

    /**
     * @notice Fulfill available advanced orders through multiple Seaport
     *         versions.
     *         See {SeaportInterface-fulfillAvailableAdvancedOrders}
     *
     * @param params The parameters for fulfilling available advanced orders.
     */
    function fulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersParams calldata params
    )
        external
        payable
        returns (
            bool[][] memory availableOrders,
            Execution[][] memory executions
        );

    /**
     * @notice Returns the Seaport contracts allowed to be used through this
     *         router.
     */
    function getAllowedSeaportContracts()
        external
        view
        returns (address[] memory);
}
