// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    ConsiderationInterface
} from "../interfaces/ConsiderationInterface.sol";

import {
    ConsiderationDelegatedInterface
} from "../interfaces/ConsiderationDelegatedInterface.sol";

import {
    Order,
    AdvancedOrder,
    OrderComponents,
    OrderParameters,
    OrderStatus,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
    FulfillmentDetail,
    Execution,
    BatchExecution
} from "./ConsiderationStructs.sol";

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
    ConsiderationInternal {
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
     * @notice Match an arbitrary number of orders, each with an arbitrary
     *         number of items for offer and consideration along with a set of
     *         fulfillments allocating offer components to consideration
     *         components. Note that this function does not support
     *         criteria-based or partial filling of orders (though filling the
     *         remainder of a partially-filled order is supported).
     *
     * @param orders            The orders to match. Note that both the offerer
     *                          and fulfiller on each order must first approve
     *                          this contract (or their proxy if indicated by
     *                          the order) to transfer any relevant tokens on
     *                          their behalf and each consideration recipient
     *                          must implement `onERC1155Received` in order to
     *                          receive ERC1155 tokens.
     * @param fulfillments      An array of elements allocating offer components
     *                          to consideration components. Note that each
     *                          consideration component must be fully met in
     *                          order for the match operation to be valid.
     *
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            matching the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            matching the given orders.
     */
    function matchOrders(
        Order[] memory orders,
        Fulfillment[] memory fulfillments
    ) external payable override returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Ensure that only delegatecalls from Consideration are allowed.
        if (address(this) != _DELEGATOR) {
            revert OnlyDelegatecallFromConsideration();
        }

        // Convert orders to "advanced" orders.
        AdvancedOrder[] memory advancedOrders = _convertOrdersToAdvanced(
            orders
        );

        // Validate orders, apply amounts, & determine if they utilize proxies.
        FulfillmentDetail[] memory fulfillOrdersAndUseProxy = (
            _validateOrdersAndPrepareToFulfill(
                advancedOrders,
                new CriteriaResolver[](0), // No criteria resolvers supplied.
                true // Signifies that invalid orders should revert.
            )
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(
            advancedOrders,
            fulfillments,
            fulfillOrdersAndUseProxy
        );
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
    ) external payable override returns (
        FulfillmentDetail[] memory fulfillmentDetails,
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Ensure that only delegatecalls from Consideration are allowed.
        if (address(this) != _DELEGATOR) {
            revert OnlyDelegatecallFromConsideration();
        }

        // Validate orders, apply amounts, & determine if they utilize proxies.
        fulfillmentDetails = _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            criteriaResolvers,
            false // Signifies that invalid orders should NOT revert.
        );

        // Apply criteria resolvers to orders regardless of fulfillment details.
        _applyCriteriaResolvers(advancedOrders, criteriaResolvers);

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
     * @notice Validate an arbitrary number of orders, thereby registering them
     *         as valid and allowing the fulfiller to skip verification. Note
     *         that anyone can validate a signed order but only the offerer can
     *         validate an order without supplying a signature.
     *
     * @param orders The orders to validate.
     *
     * @return A boolean indicating whether the supplied orders were
     *         successfully validated.
     */
    function validate(
        Order[] memory orders
    ) external override returns (bool) {
        // Ensure that only delegatecalls from Consideration are allowed.
        if (address(this) != _DELEGATOR) {
            revert OnlyDelegatecallFromConsideration();
        }

        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Declare variables outside of the loop.
        bytes32 orderHash;
        address offerer;

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Read length of the orders array from memory and place on stack.
            uint256 totalOrders = orders.length;

            // Iterate over each order.
            for (uint256 i = 0; i < totalOrders;) {
                // Retrieve the order.
                Order memory order = orders[i];

                // Retrieve the order parameters.
                OrderParameters memory orderParameters = order.parameters;

                // Move offerer from memory to the stack.
                offerer = orderParameters.offerer;

                // Get current nonce and use it w/ params to derive order hash.
                orderHash = _assertConsiderationLengthAndGetNoncedOrderHash(
                    orderParameters
                );

                // Retrieve the order status using the derived order hash.
                OrderStatus memory orderStatus = _orderStatus[orderHash];

                // Ensure order is fillable and retrieve the filled amount.
                _verifyOrderStatus(
                    orderHash,
                    orderStatus,
                    false, // Signifies that partially filled orders are valid.
                    true // Signifies to revert if the order is invalid.
                );

                // If the order has not already been validated...
                if (!orderStatus.isValidated) {
                    // Verify the supplied signature.
                    _verifySignature(
                        offerer, orderHash, order.signature
                    );

                    // Update order status to mark the order as valid.
                    _orderStatus[orderHash].isValidated = true;

                    // Emit an event signifying the order has been validated.
                    emit OrderValidated(
                        orderHash,
                        offerer,
                        orderParameters.zone
                    );
                }

                // Increment counter inside body of the loop for gas efficiency.
                ++i;
            }
        }

        return true;
    }

    /**
     * @notice Cancel all orders from a given offerer with a given zone in bulk
     *         by incrementing a nonce. Note that only the offerer may increment
     *         the nonce.
     *
     * @return newNonce The new nonce.
     */
    function incrementNonce() external override returns (uint256 newNonce) {
        // Ensure that only delegatecalls from Consideration are allowed.
        if (address(this) != _DELEGATOR) {
            revert OnlyDelegatecallFromConsideration();
        }

        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // No need to check for overflow; nonce cannot be incremented that far.
        unchecked {
            // Increment current nonce for the supplied offerer.
            newNonce = ++_nonces[msg.sender];
        }

        // Emit an event containing the new nonce.
        emit NonceIncremented(newNonce, msg.sender);
    }

    /**
     * @dev Override the view function to get the EIP-712 domain separator so
     *      that it uses the address of the original Consideration contract as
     *      the verifying address.
     *
     * @return The domain separator on the Consideration contract.
     */
    function _deriveInitialDomainSeparator() internal view override returns (
        bytes32
    ) {
        return keccak256(
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
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                _DELEGATOR
            )
        );
    }
}