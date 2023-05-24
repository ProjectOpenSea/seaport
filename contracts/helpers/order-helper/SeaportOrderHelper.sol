// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Merkle } from "murky/Merkle.sol";

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
    Merkle public immutable merkleHelper;

    constructor(
        ConsiderationInterface _seaport,
        SeaportValidatorInterface _validator
    ) {
        seaport = _seaport;
        validator = _validator;
        merkleHelper = new Merkle();
    }

    function run(
        AdvancedOrder[] memory orders,
        address recipient,
        address caller,
        uint256 nativeTokensSupplied,
        uint256 maximumFulfilled,
        CriteriaResolver[] memory criteriaResolvers
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
                    maximumFulfilled,
                    criteriaResolvers
                )
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    function run(
        AdvancedOrder[] memory orders,
        address recipient,
        address caller,
        uint256 nativeTokensSupplied,
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
            maximumFulfilled
        );
        return
            context
                .withInferredCriteria(criteria, merkleHelper)
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    function criteriaRoot(
        uint256[] memory tokenIds
    ) external view returns (bytes32) {
        return tokenIds.criteriaRoot(merkleHelper);
    }

    function criteriaProof(
        uint256[] memory tokenIds,
        uint256 index
    ) external view returns (bytes32[] memory) {
        return tokenIds.criteriaProof(index, merkleHelper);
    }
}
