// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";

import { ErrorsAndWarnings } from "../../order-validator/SeaportValidator.sol";

import { NavigatorContext } from "./SeaportNavigatorTypes.sol";

library NavigatorSeaportValidatorLib {
    using AdvancedOrderLib for AdvancedOrder;

    /**
     * @dev Validate each order using SeaportValidator and add the results to
     *      the NavigatorResponse.
     */
    function withErrors(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        AdvancedOrder[] memory orders = context.response.orders;

        uint256 ordersLength = orders.length;

        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
           ordersLength
        );
        for (uint256 i; i < ordersLength; i++) {
            errors[i] = context.request.validator.isValidOrder(
                orders[i].toOrder(),
                address(context.request.seaport)
            );
        }
        context.response.validationErrors = errors;
        return context;
    }
}
