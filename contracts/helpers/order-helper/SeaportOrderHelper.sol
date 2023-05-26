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

import { OrderHelperContextLib } from "./lib/OrderHelperLib.sol";

import { CriteriaHelperLib } from "./lib/CriteriaHelperLib.sol";

import {
    CriteriaConstraint,
    OrderHelperContext,
    Response
} from "./lib/SeaportOrderHelperTypes.sol";

import {
    SeaportOrderHelperInterface
} from "./lib/SeaportOrderHelperInterface.sol";

/**
 * @notice SeaportOrderHelper is a helper contract that generates additional
 *         information useful for fulfilling Seaport orders. Given an array of
 *         orders and external parameters like caller, recipient, and native
 *         tokens supplied, SeaportOrderHelper will validate the orders and
 *         return associated errors and warnings, recommend a fulfillment
 *         method, suggest fulfillments, provide execution and order details,
 *         and optionally generate criteria resolvers from provided token IDs.
 */
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

    /**
     * @notice Given an array of orders, return additional information useful
     *         for order fulfillment. This function will:
     *
     *         - Validate the orders and return associated errors and warnings.
     *         - Recommend a fulfillment method.
     *         - Suggest fulfillments.
     *         - Calculate and return `Execution` and `OrderDetails` structs.
     *         - Generate criteria resolvers based on the provided constraints.
     *
     *         "Criteria constraints" are an array of structs specifying:
     *
     *         - An order index, side (i.e. offer/consideration), and item index
     *           describing which item is associated with the constraint.
     *         - An array of eligible token IDs used to generate the criteria.
     *         - The actual token ID that will be provided at fulfillment time.
     *
     *         The order helper will calculate criteria merkle roots and proofs
     *         for each constraint, modify orders in place to add the roots as
     *         item `identifierOrCriteria`, and return the calculated proofs and
     *         criteria resolvers.
     *
     *         The order helper is designed to return details about a *single*
     *         call to Seaport. You should provide multiple orders only if you
     *         intend to call a method like fulfill available or match, *not* to
     *         batch process multiple individual calls. If you are retrieving
     *         helper data for a single order, there is a convenience function
     *         below that accepts a single order rather than an array.
     *
     *         The order helper does not yet support contract orders.
     *
     * @param orders               An array of orders to process. Only provide
     *                             multiple orders if you intend to call a
     *                             fulfill/match method.
     * @param caller               Address that will make the call to Seaport.
     * @param nativeTokensSupplied Quantity of native tokens supplied to Seaport
     *                             by the caller.
     * @param fulfillerConduitKey  Optional fulfiller conduit key.
     * @param recipient            Optional recipient address.
     * @param maximumFulfilled     Optional maximumFulfilled amount.
     * @param criteriaConstraints  An array of "criteria constraint" structs,
     *                             which describe the criteria to apply to
     *                             specific order/side/item combinations.
     *
     * @return A Response struct containing data derived by the OrderHelper. See
     *         SeaportOrderHelperTypes.sol for details on the structure of this
     *         response object.
     */
    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaConstraint[] memory criteriaConstraints
    ) public returns (Response memory) {
        OrderHelperContext memory context = OrderHelperContextLib
            .from(orders, seaport, validator)
            .withCallContext(
                caller,
                nativeTokensSupplied,
                fulfillerConduitKey,
                recipient,
                maximumFulfilled
            );
        return
            context
                .validate()
                .withInferredCriteria(criteriaConstraints)
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    /**
     * @notice Same as the above function, but accepts explicit criteria
     *         resolvers instead of criteria constraints. Skips criteria
     *         resolver generation and does not modify the provided orders. Use
     *         this if you don't want to automatically generate resolvers from
     *         token IDs.
     *
     * @param orders               An array of orders to process. Only provide
     *                             multiple orders if you intend to call a
     *                             fulfill/match method.
     * @param caller               Address that will make the call to Seaport.
     * @param nativeTokensSupplied Quantity of native tokens supplied to Seaport
     *                             by the caller.
     * @param fulfillerConduitKey  Optional fulfiller conduit key.
     * @param recipient            Optional recipient address.
     * @param maximumFulfilled     Optional maximumFulfilled amount.
     * @param criteriaResolvers    An array of explicit criteria resolvers for
     *                             the provided orders.
     *
     * @return A Response struct containing data derived by the OrderHelper. See
     *         SeaportOrderHelperTypes.sol for details on the structure of this
     *         response object.
     */
    function run(
        AdvancedOrder[] memory orders,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled,
        CriteriaResolver[] memory criteriaResolvers
    ) public returns (Response memory) {
        OrderHelperContext memory context = OrderHelperContextLib
            .from(orders, seaport, validator)
            .withCallContext(
                caller,
                nativeTokensSupplied,
                fulfillerConduitKey,
                recipient,
                maximumFulfilled
            );
        return
            context
                .validate()
                .withCriteriaResolvers(criteriaResolvers)
                .withDetails()
                .withErrors()
                .withFulfillments()
                .withSuggestedAction()
                .withExecutions()
                .response;
    }

    /**
     * @notice Convenience function for single orders.
     *
     * @param order                A single order to process.
     * @param caller               Address that will make the call to Seaport.
     * @param nativeTokensSupplied Quantity of native tokens supplied to Seaport
     *                             by the caller.
     * @param fulfillerConduitKey  Optional fulfiller conduit key.
     * @param recipient            Optional recipient address.
     * @param criteriaConstraints  An array of "criteria constraint" structs,
     *                             which describe the criteria to apply to
     *                             specific order/side/item combinations.
     *                             the provided orders.
     *
     * @return A Response struct containing data derived by the OrderHelper. See
     *         SeaportOrderHelperTypes.sol for details on the structure of this
     *         response object.
     */
    function run(
        AdvancedOrder memory order,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        CriteriaConstraint[] memory criteriaConstraints
    ) external returns (Response memory) {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order;
        return
            run(
                orders,
                caller,
                nativeTokensSupplied,
                fulfillerConduitKey,
                recipient,
                type(uint256).max,
                criteriaConstraints
            );
    }

    /**
     * @notice Convenience function for single orders.
     *
     * @param order                A single order to process.
     * @param caller               Address that will make the call to Seaport.
     * @param nativeTokensSupplied Quantity of native tokens supplied to Seaport
     *                             by the caller.
     * @param fulfillerConduitKey  Optional fulfiller conduit key.
     * @param recipient            Optional recipient address.
     * @param criteriaResolvers    An array of explicit criteria resolvers for
     *                             the provided orders.
     *
     * @return A Response struct containing data derived by the OrderHelper. See
     *         SeaportOrderHelperTypes.sol for details on the structure of this
     *         response object.
     */
    function run(
        AdvancedOrder memory order,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        CriteriaResolver[] memory criteriaResolvers
    ) external returns (Response memory) {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order;
        return
            run(
                orders,
                caller,
                nativeTokensSupplied,
                fulfillerConduitKey,
                recipient,
                type(uint256).max,
                criteriaResolvers
            );
    }

    /**
     * @notice Generate a criteria merkle root from an array of `tokenIds`. Use
     *         this helper to construct an order item's `identifierOrCriteria`.
     *
     * @param tokenIds An array of integer token IDs to be converted to a merkle
     *                 root.
     *
     * @return The bytes32 merkle root of a criteria tree containing the given
     *         token IDs.
     */
    function criteriaRoot(
        uint256[] memory tokenIds
    ) external pure returns (bytes32) {
        return tokenIds.criteriaRoot();
    }

    /**
     * @notice Generate a criteria merkle proof that `id` is a member of
     *        `tokenIds`. Reverts if `id` is not a member of `tokenIds`. Use
     *         this helper to construct proof data for criteria resolvers.
     *
     * @param tokenIds An array of integer token IDs.
     * @param id       The integer token ID to generate a proof for.
     *
     * @return Merkle proof that the given token ID is  amember of the criteria
     *         tree containing the given token IDs.
     */
    function criteriaProof(
        uint256[] memory tokenIds,
        uint256 id
    ) external pure returns (bytes32[] memory) {
        return tokenIds.criteriaProof(id);
    }
}
