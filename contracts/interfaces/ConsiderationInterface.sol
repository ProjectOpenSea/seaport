// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    BasicOrderParameters,
    BasicOrderParameters2,
    OrderComponents,
    Fulfillment,
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
  // todo: review basic order fn natspec
    /**
     * @notice Fulfill an order offering a single ERC721 token by supplying
     *         Ether (or the native token for the given chain) as consideration
     *         for the order. An arbitrary number of "additional recipients" may
     *         also be supplied which will each receive the native token from
     *         the fulfiller as consideration.
     *
     * @param parameters  Additional information on the fulfilled order. Note
     *                    that the offerer must first approve this contract (or
     *                    their proxy if indicated by the order) in order for
     *                    their offered ERC721 token to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicEthForERC721Order(
        BasicOrderParameters2 calldata parameters
    ) external payable returns (bool);

    /**
     * @notice Fulfill an order offering ERC1155 tokens by supplying Ether (or
     *         the native token for the given chain) as consideration for the
     *         order. An arbitrary number of "additional recipients" may also be
     *         supplied which will each receive native tokens from the fulfiller
     *         as consideration.
     * @param parameters    Additional information on the fulfilled order. Note
     *                      that the offerer must first approve this contract
     *                      (or their proxy if indicated by the order) in order
     *                      for their offered ERC1155 tokens to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicEthForERC1155Order(
        BasicOrderParameters2 calldata parameters
    ) external payable returns (bool);

    /**
     * @notice Fulfill an order offering a single ERC721 token by supplying
     *         ERC20 tokens as consideration. An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive ERC20
     *         tokens from the fulfiller as consideration.
     *
     * @param parameters  Additional information on the fulfilled order. Note
     *                    that the offerer must first approve this contract (or
     *                    their proxy if indicated by the order) in order for
     *                    their offered ERC721 token to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicERC20ForERC721Order(
        BasicOrderParameters2 calldata parameters
    ) external returns (bool);

    /**
     * @notice Fulfill an order offering some amount of a specific ERC1155 token
     *         by supplying ERC20 tokens as consideration. An arbitrary number
     *         of "additional recipients" may also be supplied which will each
     *         receive ERC20 tokens from the fulfiller as consideration.
     *
     * @param erc20Token    The address of the ERC20 token being supplied as
     *                      consideration to the offerer of the fulfilled order.
     * @param erc20Amount   ERC20 tokens that will be transferred to the
     *                      offerer of the fulfilled order. Note that the
     *                      fulfiller must first approve this contract before
     *                      the ERC20 tokens required as consideration can be
     *                      transferred.
     * @param erc1155Amount Total offererd ERC1155 tokens that will be
     *                      transferred to the caller. Also note that calling
     *                      contracts must implement `onERC1155Received` in
     *                      order to receive tokens.
     * @param parameters    Additional information on the fulfilled order. Note
     *                      that the offerer must first approve this contract
     *                      (or their proxy if indicated by the order) in order
     *                      for their offered ERC1155 tokens to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicERC20ForERC1155Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters calldata parameters
    ) external returns (bool);

    /**
     * @notice Fulfill an order offering ERC20 tokens by supplying a single
     *         ERC721 token as consideration. An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive ERC20
     *         tokens from the offerer as consideration.
     *
     * @param erc20Token        The address of the ERC20 token being offered.
     * @param erc20Amount       ERC20 tokens that will be transferred from the
     *                          offerer to the fulfiller and any additional
     *                          recipients. Note that the offerer must first
     *                          approve this contract before their offered ERC20
     *                          tokens to be transferred. Also note that the
     *                          amount transferred to the fulfiller will be less
     *                          than this amount if additional recipients have
     *                          been specified.
     * @param parameters        Additional information on the fulfilled order.
     *                          Note that the fulfiller must first approve this
     *                          contract (or their proxy if indicated by the
     *                          order) before the ERC721 token required as
     *                          consideration can be transferred. Also note that
     *                          the sum of all additional recipient amounts
     *                          cannot exceed `erc20Amount`.
     * @param useFulfillerProxy A boolean indicating whether to utilize the
     *                          fulfiller's proxy when transferring the ERC721
     *                          item from the fulfiller to the offerer.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicERC721ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters memory parameters,
        bool useFulfillerProxy
    ) external returns (bool);

    /**
     * @notice Fulfill an order offering ERC20 tokens by supplying ERC1155
     *         tokens as consideration. An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive ERC20
     *         tokens from the offerer as consideration.
     *
     * @param erc20Token        The address of the ERC20 token being offered.
     * @param erc20Amount       ERC20 tokens that will be transferred from the
     *                          offerer to the fulfiller and any additional
     *                          recipients. Note that the offerer must first
     *                          approve this contract before their offered ERC20
     *                          tokens to be transferred. Also note that the
     *                          amount transferred to the fulfiller will be less
     *                          than this amount if additional recipients have
     *                          been specified.
     * @param erc1155Amount     Total ERC1155 tokens required to be transferred
     *                          to the offerer as consideration. Note that
     *                          offering contracts must implement
     *                          `onERC1155Received` in order to receive tokens.
     * @param parameters        Additional information on the fulfilled order.
     *                          Note that the fulfiller must first approve this
     *                          contract (or their proxy if indicated by the
     *                          order) before the ERC1155 token required as
     *                          consideration can be transferred. Also note that
     *                          the sum of all additional recipient amounts
     *                          cannot exceed `erc20Amount`.
     * @param useFulfillerProxy A boolean indicating whether to utilize the
     *                          fulfiller's proxy when transferring the ERC1155
     *                          item from the fulfiller to the offerer.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicERC1155ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters memory parameters,
        bool useFulfillerProxy
    ) external returns (bool);

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
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillOrder(
        Order calldata order,
        bool useFulfillerProxy
    ) external payable returns (bool);

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
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (bool);

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
    ) external payable returns (
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
    ) external payable returns (
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
    function cancel(
        OrderComponents[] calldata orders
    ) external returns (bool);

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
        Order[] calldata orders
    ) external returns (bool);

    /**
     * @notice Cancel all orders from a given offerer with a given zone in bulk
     *         by incrementing a nonce. Note that only the offerer or the zone
     *         may increment the nonce.
     *
     * @param offerer The offerer in question.
     * @param zone    The zone in question.
     *
     * @return newNonce The new nonce.
     */
    function incrementNonce(
        address offerer,
        address zone
    ) external returns (uint256 newNonce);

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @param order The components of the order.
     *
     * @return The order hash.
     */
    function getOrderHash(
        OrderComponents calldata order
    ) external view returns (bytes32);

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
    function getOrderStatus(
        bytes32 orderHash
    ) external view returns (
        bool isValidated,
        bool isCancelled,
        uint256 totalFilled,
        uint256 totalSize
    );

    /**
     * @notice Retrieve the current nonce for a given offerer + zone pair.
     *
     * @param offerer The offerer in question.
     * @param zone    The zone in question.
     *
     * @return The current nonce.
     */
    function getNonce(
        address offerer,
        address zone
    ) external view returns (uint256);

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