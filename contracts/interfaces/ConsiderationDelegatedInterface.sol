// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    AdvancedOrder,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

interface ConsiderationDelegatedInterface {
    /**
     * @notice External function, only callable from the Consideration contract
     *         via delegatecall, that attempts to fill a group of orders, fully
     *         or partially, with an arbitrary number of items for offer and
     *         consideration per order alongside criteria resolvers containing
     *         specific token identifiers and associated proofs. Any order that
     *         has already been fully filled or cancelled, or where an offer
     *         item cannot be successfully transferred to the fulfiller, will be
     *         skipped. If an order is skipped, all state changes for that order
     *         (including any previously transferred offer items for that order)
     *         will be rolled back and any unapplied criteria resolvers
     *         referencing that order will be ignored. The fulfiller must then
     *         transfer each consideration item on the remaining orders to the
     *         intended recipient — note that a failing transfer of a
     *         consideration item from the fulfiller will cause the entire
     *         transaction to revert.
     *
     * @param advancedOrders    The orders to fulfill along with the fraction of
     *                          those orders to attempt to fill. Note that both
     *                          the offerer and the fulfiller must first approve
     *                          this contract (or their proxy if indicated by
     *                          the order) to transfer any relevant tokens on
     *                          their behalf and that contracts must implement
     *                          `onERC1155Received` in order to receive ERC1155
     *                          tokens as consideration. Also note that all
     *                          offer and consideration components must have no
     *                          remainder after multiplication of the respective
     *                          amount with the supplied fraction for an order's
     *                          partial fill amount to be considered valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the merkle root held
     *                          by the item in question's criteria element. Note
     *                          that an empty criteria indicates that any
     *                          (transferrable) token identifier on the token in
     *                          question is valid and that no associated proof
     *                          needs to be supplied.
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return statuses An array of booleans indicating whether each order has
     *                  been fulfilled.
     */
	function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (bool[] memory statuses);

    /**
     * @dev Revert when called or delegatecalled via any method other than a
     *      delegatecall from Consideration.
     */
     error OnlyDelegatecallFromConsideration();
}
