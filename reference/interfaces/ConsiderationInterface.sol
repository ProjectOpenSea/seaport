// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// prettier-ignore
import {
    BasicOrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    BatchExecution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

/**
 * @title ConsiderationInterface
 * @author 0age
 * @custom:version 1
 * @notice Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
 *         It minimizes external calls to the greatest extent possible and
 *         provides lightweight methods for common routes as well as more
 *         flexible methods for composing advanced orders.
 *
 * @dev ConsiderationInterface contains all external function interfaces for
 *      Consideration.
 */
interface ConsiderationInterface {
    /**
     * @notice Fulfill an order offering an ERC721 token by supplying Ether (or
     *         the native token for the given chain) as consideration for the
     *         order. An arbitrary number of "additional recipients" may also be
     *         supplied which will each receive native tokens from the fulfiller
     *         as consideration.
     *
     * @param parameters Additional information on the fulfilled order. Note
     *                   that the offerer must first approve this contract (or
     *                   their proxy if indicated by the order) in order for
     *                   their offered ERC721 token to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicOrder(BasicOrderParameters calldata parameters)
        external
        payable
        returns (bool);

    /**
     * @notice Fulfill an order with an arbitrary number of items for offer and
     *         consideration. Note that this function does not support
     *         criteria-based orders or partial filling of orders (though
     *         filling the remainder of a partially-filled order is supported).
     *
     * @param order             The order to fulfill. Note that both the offerer
     *                          and the fulfiller must first approve this
     *                          contract (or their proxy if indicated by the
     *                          order) to transfer any relevant tokens on their
     *                          behalf and that contracts must implement
     *                          `onERC1155Received` in order to receive ERC1155
     *                          tokens as consideration.
     * @param fulfillerConduit A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillOrder(Order calldata order, address fulfillerConduit)
        external
        payable
        returns (bool);

    /**
     * @notice Fill an order, fully or partially, with an arbitrary number of
     *         items for offer and consideration alongside criteria resolvers
     *         containing specific token identifiers and associated proofs.
     *
     * @param advancedOrder     The order to fulfill along with the fraction of
     *                          the order to attempt to fill. Note that both the
     *                          offerer and the fulfiller must first approve
     *                          this contract (or their proxy if indicated by
     *                          the order) to transfer any relevant tokens on
     *                          their behalf and that contracts must implement
     *                          `onERC1155Received` in order to receive ERC1155
     *                          tokens as consideration. Also note that all
     *                          offer and consideration components must have no
     *                          remainder after multiplication of the respective
     *                          amount with the supplied fraction in order for
     *                          the partial fill to be considered valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the merkle root held
     *                          by the item in question's criteria element. Note
     *                          that an empty criteria indicates that any
     *                          (transferrable) token identifier on the token in
     *                          question is valid and that no associated proof
     *                          needs to be supplied.
     * @param fulfillerConduit A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        address fulfillerConduit
    ) external payable returns (bool);

    /**
     * @notice Attempt to fill a group of orders, fully or partially, with an
     *         arbitrary number of items for offer and consideration per order
     *         alongside criteria resolvers containing specific token
     *         identifiers and associated proofs. Any order that is not
     *         currently active, has already been fully filled, or has been
     *         cancelled will be omitted. Remaining offer and consideration
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
     * @param fulfillerConduit         A flag indicating whether to source
     *                                  approvals for fulfilled tokens from an
     *                                  associated proxy.
     *
     * @return availableOrders    An array of booleans indicating if each order
     *                            with an index corresponding to the index of
     *                            the returned boolean was fulfillable or not.
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            matching the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            matching the given orders.
     */
    function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] calldata advancedOrders,
        CriteriaResolver[] calldata criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        address fulfillerConduit
    )
        external
        payable
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        );

    /**
     * @notice Match an arbitrary number of orders, each with an arbitrary
     *         number of items for offer and consideration along with as set of
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
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        );

    /**
     * @notice Match an arbitrary number of full or partial orders, each with an
     *         arbitrary number of items for offer and consideration, supplying
     *         criteria resolvers containing specific token identifiers and
     *         associated proofs as well as fulfillments allocating offer
     *         components to consideration components.
     *
     * @param orders            The advanced orders to match. Note that both the
     *                          offerer and fulfiller on each order must first
     *                          approve this contract (or their proxy if
     *                          indicated by the order) to transfer any relevant
     *                          tokens on their behalf and each consideration
     *                          recipient must implement `onERC1155Received` in
     *                          order toreceive ERC1155 tokens. Also note that
     *                          the offer and consideration components for each
     *                          order must have no remainder after multiplying
     *                          the respective amount with the supplied fraction
     *                          in order for the group of partial fills to be
     *                          considered valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          an empty root indicates that any (transferrable)
     *                          token identifier is valid and that no associated
     *                          proof needs to be supplied.
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
    function matchAdvancedOrders(
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        );

    /**
     * @notice Cancel an arbitrary number of orders. Note that only the offerer
     * or the zone of a given order may cancel it.
     *
     * @param orders The orders to cancel.
     *
     * @return A boolean indicating whether the supplied orders were
     *         successfully cancelled.
     */
    function cancel(OrderComponents[] calldata orders) external returns (bool);

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
    function validate(Order[] calldata orders) external returns (bool);

    /**
     * @notice Cancel all orders from a given offerer with a given zone in bulk
     *         by incrementing a nonce. Note that only the offerer may increment
     *         the nonce.
     *
     * @return newNonce The new nonce.
     */
    function incrementNonce() external returns (uint256 newNonce);

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @param order The components of the order.
     *
     * @return The order hash.
     */
    function getOrderHash(OrderComponents calldata order)
        external
        view
        returns (bytes32);

    /**
     * @notice Retrieve the status of a given order by hash, including whether
     *         the order has been cancelled or validated and the fraction of the
     *         order that has been filled.
     *
     * @param orderHash The order hash in question.
     *
     * @return isValidated A boolean indicating whether the order in question
     *                     has been validated (i.e. previously approved or
     *                     partially filled).
     * @return isCancelled A boolean indicating whether the order in question
     *                     has been cancelled.
     * @return totalFilled The total portion of the order that has been filled
     *                     (i.e. the "numerator").
     * @return totalSize   The total size of the order that is either filled or
     *                     unfilled (i.e. the "denominator").
     */
    function getOrderStatus(bytes32 orderHash)
        external
        view
        returns (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        );

    /**
     * @notice Retrieve the current nonce for a given offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return The current nonce.
     */
    function getNonce(address offerer) external view returns (uint256);

    /**
     * @notice Retrieve the name of this contract.
     *
     * @return The name of this contract.
     */
    function name() external view returns (string memory);

    /**
     * @notice Retrieve the version of this contract.
     *
     * @return The version of this contract.
     */
    function version() external view returns (string memory);

    /**
     * @notice Retrieve the domain separator, used for signing and verifying
     * signed orders via EIP-712.
     *
     * @return The domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
