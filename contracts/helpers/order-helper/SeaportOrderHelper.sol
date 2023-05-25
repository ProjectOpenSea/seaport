// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";
import {
    AdvancedOrder,
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    SeaportValidatorInterface
} from "../order-validator/SeaportValidator.sol";

import {
    CriteriaConstraint,
    OrderHelperContext,
    OrderHelperContextLib,
    Response
} from "./lib/OrderHelperLib.sol";

import { CriteriaHelperLib } from "./lib/CriteriaHelperLib.sol";

import {
    SeaportOrderHelperInterface
} from "./lib/SeaportOrderHelperInterface.sol";

contract SeaportOrderHelper is SeaportOrderHelperInterface {
    using OrderHelperContextLib for OrderHelperContext;
    using CriteriaHelperLib for uint256[];

    ConsiderationInterface public immutable seaport;
    SeaportValidatorInterface public immutable validator;

    constructor(
        ConsiderationInterface _seaport,
        SeaportValidatorInterface _validator
    ) {
        seaport = _seaport;
        validator = _validator;
    }

    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaResolver[] memory criteriaResolvers
    ) external returns (Response memory) {
        OrderHelperContext memory context = OrderHelperContextLib.from(
            orders,
            seaport,
            validator,
            caller,
            recipient,
            nativeTokensSupplied,
            maximumFulfilled,
            fulfillerConduitKey,
            criteriaResolvers
        );
        return
            context
                .validate()
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaConstraint[] memory criteria
    ) external returns (Response memory) {
        OrderHelperContext memory context = OrderHelperContextLib.from(
            orders,
            seaport,
            validator,
            caller,
            recipient,
            nativeTokensSupplied,
            maximumFulfilled,
            fulfillerConduitKey
        );
        return
            context
                .validate()
                .withInferredCriteria(criteria)
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    function criteriaRoot(
        uint256[] memory tokenIds
    ) external pure returns (bytes32) {
        return tokenIds.criteriaRoot();
    }

    function criteriaProof(
        uint256[] memory tokenIds,
        uint256 index
    ) external pure returns (bytes32[] memory) {
        return tokenIds.criteriaProof(index);
    }
}
