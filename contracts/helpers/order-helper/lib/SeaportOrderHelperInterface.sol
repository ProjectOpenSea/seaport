// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { CriteriaConstraint, Response } from "./OrderHelperLib.sol";

interface SeaportOrderHelperInterface {
    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaResolver[] memory criteriaResolvers
    ) external returns (Response memory);

    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaConstraint[] memory criteriaConstraints
    ) external returns (Response memory);
}
