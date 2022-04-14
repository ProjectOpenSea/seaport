// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ConsiderationInterface } from "../interfaces/ConsiderationInterface.sol";

import { ConsiderationDelegatedInterface } from "../interfaces/ConsiderationDelegatedInterface.sol";

import { Order, AdvancedOrder, OrderComponents, OrderParameters, OrderStatus, CriteriaResolver, Fulfillment, FulfillmentComponent, FulfillmentDetail, Execution, BatchExecution } from "./ConsiderationStructs.sol";

import { ConsiderationInternal } from "./ConsiderationInternal.sol";

/**
 * @title ConsiderationDelegated
 * @author 0age
 * @notice ConsiderationDelegated contains all delegated functions that cannot
 *         be included in the core Consideration contract due to contract size
 *         restraints introduced by EIP-170.
 */
contract ConsiderationDelegated is
    ConsiderationDelegatedInterface,
    ConsiderationInternal
{
    // Only delegator may call this contract (stricter than using a library).
    address internal immutable _DELEGATOR;

    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationInternal(legacyProxyRegistry, requiredProxyImplementation) {
        // Set the deployer as the allowed delegator.
        _DELEGATOR = msg.sender;
    }

    /**
     * @notice External function, only callable from the Consideration contract
     *         via delegatecall, that attempts to fill a group of orders, fully
     *         or partially, with an arbitrary number of items for offer and
     *         consideration per order alongside criteria resolvers containing
     *         specific token identifiers and associated proofs. Any order that
     *         is not currently active, has already been fully filled, or has
     *         been cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible as indicated by the
     *         supplied offer and consideration component arrays and aggregated
     *         items will be transferred to the fulfiller or to each intended
     *         recipient, respectively. Note that a failing item transfer or an
     *         issue with order formatting will cause the entire batch to fail.
     *
     * @param advancedOrders            The orders to fulfill along with the
     *                                  fraction of those orders to attempt to
     *                                  fill. Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or their proxy if indicated by
     *                                  the order) to transfer any relevant
     *                                  tokens on their behalf and that
     *                                  contracts must implement
     *                                  `onERC1155Received` in order to receive
     *                                  ERC1155 tokens as consideration. Also
     *                                  note that all offer and consideration
     *                                  components must have no remainder after
     *                                  multiplication of the respective amount
     *                                  with the supplied fraction for an
     *                                  order's partial fill amount to be
     *                                  considered valid.
     * @param criteriaResolvers         An array where each element contains a
     *                                  reference to a specific offer or
     *                                  consideration, a token identifier, and a
     *                                  proof that the supplied token identifier
     *                                  is contained in the merkle root held by
     *                                  the item in question's criteria element.
     *                                  Note that an empty criteria indicates
     *                                  that any (transferrable) token
     *                                  identifier on the token in question is
     *                                  valid and that no associated proof needs
     *                                  to be supplied.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param useFulfillerProxy         A flag indicating whether to source
     *                                  approvals for fulfilled tokens from an
     *                                  associated proxy.
     *
     * @return fulfillmentDetails A array of FulfillmentDetail structs, each
     *                            indicating whether the associated order has
     *                            been fulfilled and whether a proxy was used.
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            matching the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            matching the given orders.
     */
    function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        bool useFulfillerProxy
    )
        external
        payable
        override
        returns (
            FulfillmentDetail[] memory fulfillmentDetails,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Ensure that only delegatecalls from Consideration are allowed.
        _assertDelegatecallFromConsideration();

        // Validate orders, apply amounts, & determine if they utilize proxies.
        fulfillmentDetails = _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            criteriaResolvers,
            false // Signifies that invalid orders should NOT revert.
        );

        // Apply criteria resolvers to orders.
        _applyCriteriaResolvers(
            advancedOrders,
            criteriaResolvers,
            fulfillmentDetails
        );

        // Aggregate used offer and consideration items and execute transfers.
        (standardExecutions, batchExecutions) = _fulfillAvailableOrders(
            advancedOrders,
            offerFulfillments,
            considerationFulfillments,
            fulfillmentDetails,
            useFulfillerProxy
        );

        // Return order fulfillment details and executions.
        return (fulfillmentDetails, standardExecutions, batchExecutions);
    }

    /**
     * @dev Override the view function to get the EIP-712 domain separator so
     *      that it uses the address of the original Consideration contract as
     *      the verifying address.
     *
     * @return The domain separator on the Consideration contract.
     */
    function _deriveInitialDomainSeparator()
        internal
        view
        override
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _EIP_712_DOMAIN_TYPEHASH,
                    _NAME_HASH,
                    _VERSION_HASH,
                    block.chainid,
                    msg.sender
                )
            );
    }

    /**
     * @dev Override the view function to get the EIP-712 domain separator so
     *      that it uses the address of the original Consideration contract as
     *      the verifying address.
     *
     * @return The domain separator on the Consideration contract.
     */
    function _deriveDomainSeparator() internal view override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _EIP_712_DOMAIN_TYPEHASH,
                    _NAME_HASH,
                    _VERSION_HASH,
                    block.chainid,
                    _DELEGATOR
                )
            );
    }

    /**
     * @dev Internal view function to ensure that Consideration is performing a
     *      delegatecall into the given function.
     */
    function _assertDelegatecallFromConsideration() internal view {
        // Ensure that only delegatecalls from Consideration are allowed.
        if (address(this) != _DELEGATOR) {
            revert OnlyDelegatecallFromConsideration();
        }
    }
}
