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

import {
    SeaportOrderHelperInterface
} from "./lib/SeaportOrderHelperInterface.sol";

contract SeaportOrderHelper is SeaportOrderHelperInterface {
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
        address caller,
        uint256 nativeTokensSupplied,
        uint256 maximumFulfilled
    ) external returns (Response memory) {
        return
            OrderHelperContextLib
                .from(
                    orders,
                    seaport,
                    validator,
                    caller,
                    recipient,
                    nativeTokensSupplied,
                    maximumFulfilled
                )
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }
}
