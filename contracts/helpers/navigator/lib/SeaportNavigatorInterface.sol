// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    NavigatorRequest,
    NavigatorResponse
} from "./SeaportNavigatorTypes.sol";

interface SeaportNavigatorInterface {
    /**
     * @notice Given a NavigatorRequest struct containing an array of orders and
     *         additional external context parameters, return information useful
     *         for order fulfillment. This function will:
     *
     *         - Validate the orders and return associated errors and warnings.
     *         - Recommend a fulfillment method.
     *         - Suggest fulfillments.
     *         - Calculate and return Execution and OrderDetails structs.
     *         - Generate criteria resolvers based on any provided constraints.
     *
     *         The navigator is designed to return details about a *single* call
     *         to Seaport. You should provide multiple orders only if you intend
     *         to call a method like fulfill available or match, *not* to batch
     *         process multiple individual calls.
     *
     *         The navigator does not yet support contract orders.
     *
     * @param request A NavigatorRequest struct containing an array of orders to
     *                process and additional external context. See struct docs
     *                in SeaportNavigatorTypes.sol for details.
     *
     * @return A NavigatorResponse struct containing data derived by the
     *         navigator. See SeaportNavigatorTypes.sol for details on the
     *         structure of this response.
     */
    function prepare(
        NavigatorRequest memory request
    ) external view returns (NavigatorResponse memory);

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
    ) external pure returns (bytes32);

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
    ) external pure returns (bytes32[] memory);
}
