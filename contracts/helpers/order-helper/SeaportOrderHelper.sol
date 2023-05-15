// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { SeaportInterface, AdvancedOrder } from "seaport-sol/SeaportSol.sol";

import {
    SeaportValidatorInterface
} from "../order-validator/SeaportValidator.sol";

import {
    OrderHelperContext,
    OrderHelperContextLib,
    Response
} from "./lib/OrderHelperLib.sol";

contract SeaportOrderHelper {
    using OrderHelperContextLib for OrderHelperContext;

    SeaportInterface public immutable seaport;
    SeaportValidatorInterface public immutable validator;

    constructor(
        SeaportInterface _seaport,
        SeaportValidatorInterface _validator
    ) {
        seaport = _seaport;
        validator = _validator;
    }

    function run(
        AdvancedOrder[] memory orders,
        address recipient,
        address caller
    ) external returns (Response memory) {
        OrderHelperContext memory context = OrderHelperContextLib
            .from(orders, seaport, validator, caller, recipient)
            .withErrors()
            .withFulfillments()
            .withAction();

        return context.response;
    }
}
