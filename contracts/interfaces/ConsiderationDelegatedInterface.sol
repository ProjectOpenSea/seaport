// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    AdvancedOrder,
    CriteriaResolver,
    FulfillmentDetail
} from "../lib/ConsiderationStructs.sol";

interface ConsiderationDelegatedInterface {
    /**
     * @notice External function, only callable from the Consideration contract
     *         via delegatecall, that attempts to fill a group of orders, fully
     *         or partially, with an arbitrary number of items for offer and
     *         consideration per order alongside criteria resolvers containing
     *         specific token identifiers and associated proofs. Any order that
     *         is not currently active, has already been fully filled, or has
     *         been cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible, and aggregated
     *         offer items will be transferred to the fulfiller. Finally, the
     *         fulfiller will transfer each aggregated consideration item to the
     *         intended recipient. Note that a failing item transfer or issue
     *         with order validation will cause the entire batch to revert.
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
     * @return fulfillmentDetails A array of FulfillmentDetail structs, each
     *                            indicating whether the associated order has
     *                            been fulfilled and whether a proxy was used.
     */
    function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (FulfillmentDetail[] memory fulfillmentDetails);

    /**
     * @dev Revert when called or delegatecalled via any method other than a
     *      delegatecall from Consideration.
     */
     error OnlyDelegatecallFromConsideration();
}
