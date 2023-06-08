// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperSeaportValidatorLib } from "./OrderHelperLib.sol";

import { OrderHelperContext } from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

import { Order } from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    SeaportValidatorInterface
} from "../../order-validator/SeaportValidator.sol";

contract ValidatorHelper is HelperInterface {
    using OrderHelperSeaportValidatorLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.withErrors(address(this));
    }

    function validateAndRevert(
        SeaportValidatorInterface validator,
        Order memory order,
        address seaport
    ) external {
        bytes memory callData = abi.encodeCall(
            validator.isValidOrder,
            (order, seaport)
        );
        (bool success, bytes memory returnData) = address(validator).call(
            callData
        );
        bytes memory revertData = abi.encode(success, returnData);
        assembly {
            revert(add(revertData, 0x20), mload(revertData))
        }
    }
}
