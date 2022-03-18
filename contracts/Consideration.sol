// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ConsiderationInterface } from "./interfaces/ConsiderationInterface.sol";

import { ItemType } from "./lib/ConsiderationEnums.sol";

import {
    BasicOrderParameters,
    OfferedItem,
    ReceivedItem,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    BatchExecution
} from "./lib/ConsiderationStructs.sol";

import { ConsiderationInternal } from "./lib/ConsiderationInternal.sol";

/**
 * @title Consideration
 * @author 0age
 * @custom:version 1
 * @notice Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
 *         It minimizes external calls to the greatest extent possible and
 *         provides lightweight methods for common routes as well as more
 *         flexible methods for composing advanced orders.
 */
contract Consideration is ConsiderationInterface, ConsiderationInternal {
    /**
     * @notice Derive and set hashes, reference chainId, and associated domain
     *         separator during deployment.
     *
     * @param legacyProxyRegistry         A proxy registry that stores per-user
     *                                    proxies that may optionally be used to
     *                                    transfer approved tokens.
     * @param requiredProxyImplementation The implementation that must be set on
     *                                    each proxy in order to utilize it.
     */
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationInternal(legacyProxyRegistry, requiredProxyImplementation) {}

    /**
     * @notice Fulfill an order offering a single ERC721 token by supplying
     *         Ether (or the native token for the given chain) as consideration
     *         for the order. An arbitrary number of "additional recipients" may
     *         also be supplied which will each receive the native token from
     *         the fulfiller as consideration.
     *
     * @param etherAmount Ether (or the native token for the given chain) that
     *                    will be transferred to the offerer of the fulfilled
     *                    order. Note that msg.value must exceed this amount if
     *                    additonal recipients are specified.
     * @param parameters  Additional information on the fulfilled order. Note
     *                    that the offerer must first approve this contract (or
     *                    their proxy if indicated by the order) in order for
     *                    their offered ERC721 token to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicEthForERC721Order(
        uint256 etherAmount,
        BasicOrderParameters memory parameters
    ) external payable override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        bool useOffererProxy = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC721,
                parameters.token,
                parameters.identifier,
                1, // Amount of 1 for ERC721 tokens
                1  // Amount of 1 for ERC721 tokens
            ),
            ReceivedItem(
                ItemType.NATIVE,
                address(0),   // No token address for ETH or other native tokens
                0,            // No identifier for ETH or other native tokens
                etherAmount,
                etherAmount,
                offerer
            )
        );

        // Transfer ERC721 to caller, using offerer's proxy if applicable.
        _transferERC721(
            parameters.token,
            offerer,
            msg.sender,
            parameters.identifier,
            useOffererProxy ? offerer : address(0)
        );

        // Transfer native to recipients, return excess to caller, and wrap up.
        _transferEthAndFinalize(
            etherAmount,
            parameters
        );

        return true;
    }

    /**
     * @notice Fulfill an order offering ERC1155 tokens by supplying Ether (or
     *         the native token for the given chain) as consideration for the
     *         order. An arbitrary number of "additional recipients" may also be
     *         supplied which will each receive native tokens from the fulfiller
     *         as consideration.
     *
     * @param etherAmount   Ether (or the native token for the given chain) that
     *                      will be transferred to the offerer of the fulfilled
     *                      order. Note that msg.value must exceed this amount
     *                      if additonal recipients are specified.
     * @param erc1155Amount Total offererd ERC1155 tokens that will be
     *                      transferred to the fulfiller. Also note that calling
     *                      contracts must implement `onERC1155Received` in
     *                      order to receive tokens.
     * @param parameters    Additional information on the fulfilled order. Note
     *                      that the offerer must first approve this contract
     *                      (or their proxy if indicated by the order) in order
     *                      for their offered ERC1155 tokens to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicEthForERC1155Order(
        uint256 etherAmount,
        uint256 erc1155Amount,
        BasicOrderParameters memory parameters
    ) external payable override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        bool useOffererProxy = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount
            ),
            ReceivedItem(
                ItemType.NATIVE,
                address(0),   // No token address for ETH or other native tokens
                0,            // No identifier for ETH or other native tokens
                etherAmount,
                etherAmount,
                offerer
            )
        );

        // Transfer ERC1155 to caller, using offerer's proxy if applicable.
        _transferERC1155(
            parameters.token,
            offerer,
            msg.sender,
            parameters.identifier,
            erc1155Amount,
            useOffererProxy ? offerer : address(0)
        );

        // Transfer native to recipients, return excess to caller, and wrap up.
        _transferEthAndFinalize(
            etherAmount,
            parameters
        );

        return true;
    }

    /**
     * @notice Fulfill an order offering a single ERC721 token by supplying
     *         ERC20 tokens as consideration. An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive ERC20
     *         tokens from the fulfiller as consideration.
     *
     * @param erc20Token  The address of the ERC20 token being supplied as
     *                    consideration to the offerer of the fulfilled order.
     * @param erc20Amount ERC20 tokens that will be transferred to the offerer
     *                    of the fulfilled order. Note that the fulfiller must
     *                    first approve this contract before the ERC20 tokens
     *                    required as consideration can be transferred.
     * @param parameters  Additional information on the fulfilled order. Note
     *                    that the offerer must first approve this contract (or
     *                    their proxy if indicated by the order) in order for
     *                    their offered ERC721 token to be transferred.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicERC20ForERC721Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Derive and validate order using parameters and update order status.
        bool useOffererProxy = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC721,
                parameters.token,
                parameters.identifier,
                1, // Amount of 1 for ERC721 tokens
                1  // Amount of 1 for ERC721 tokens
            ),
            ReceivedItem(
                ItemType.ERC20,
                erc20Token,
                0, // No identifier for ERC20 tokens
                erc20Amount,
                erc20Amount,
                parameters.offerer
            )
        );

        // Transfer ERC721 to caller, using offerer's proxy if applicable.
        _transferERC721(
            parameters.token,
            parameters.offerer,
            msg.sender,
            parameters.identifier,
            useOffererProxy ? parameters.offerer : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            msg.sender,
            parameters.offerer,
            erc20Token,
            erc20Amount,
            parameters,
            false // Transfer full amount indicated by all consideration items.
        );

        return true;
    }

    /**
     * @notice Fulfill an order offering ERC1155 tokens by supplying ERC20
     *         tokens as consideration. An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive ERC20
     *         tokens from the fulfiller as consideration.
     *
     * @param erc20Token    The address of the ERC20 token being supplied as
     *                      consideration to the offerer of the fulfilled order.
     * @param erc20Amount   ERC20 tokens that will be transferred to the offerer
     *                      of the fulfilled order. Note that the fulfiller must
     *                      first approve this contract before the ERC20 tokens
     *                      required as consideration can be transferred.
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
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Derive and validate order using parameters and update order status.
        bool useOffererProxy = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount
            ),
            ReceivedItem(
                ItemType.ERC20,
                erc20Token,
                0, // No identifier for ERC20 tokens
                erc20Amount,
                erc20Amount,
                parameters.offerer
            )
        );

        // Transfer ERC1155 to caller, using offerer's proxy if applicable.
        _transferERC1155(
            parameters.token,
            parameters.offerer,
            msg.sender,
            parameters.identifier,
            erc1155Amount,
            useOffererProxy ? parameters.offerer : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            msg.sender,
            parameters.offerer,
            erc20Token,
            erc20Amount,
            parameters,
            false // Transfer full amount indicated by all consideration items.
        );

        return true;
    }

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
    ) external override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC20,
                erc20Token,
                0, // No identifier for ERC20 tokens
                erc20Amount,
                erc20Amount
            ),
            ReceivedItem(
                ItemType.ERC721,
                parameters.token,
                parameters.identifier,
                1, // Amount of 1 for ERC721 tokens
                1, // Amount of 1 for ERC721 tokens
                offerer
            )
        );

        // Transfer ERC721 to offerer, using caller's proxy if applicable.
        _transferERC721(
            parameters.token,
            msg.sender,
            offerer,
            parameters.identifier,
            useFulfillerProxy ? msg.sender : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            offerer,
            msg.sender,
            erc20Token,
            erc20Amount,
            parameters,
            true // Reduce erc20Amount sent to fulfiller by additional amounts.
        );

        return true;
    }

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
    ) external override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC20,
                erc20Token,
                0, // No identifier for ERC20 tokens
                erc20Amount,
                erc20Amount
            ),
            ReceivedItem(
                ItemType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount,
                offerer
            )
        );

        // Transfer ERC1155 to offerer, using caller's proxy if applicable.
        _transferERC1155(
            parameters.token,
            msg.sender,
            offerer,
            parameters.identifier,
            erc1155Amount,
            useFulfillerProxy ? msg.sender : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            offerer,
            msg.sender,
            erc20Token,
            erc20Amount,
            parameters,
            true // Reduce erc20Amount sent to fulfiller by additional amounts.
        );

        return true;
    }

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
        Order memory order,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Convert order to "advanced" order, then validate and fulfill it.
        return _validateAndFulfillAdvancedOrder(
            _convertOrderToAdvanced(order),
            new CriteriaResolver[](0), // No criteria resolvers are supplied.
            useFulfillerProxy
        );
    }

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
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Validate and fulfill the order.
        return _validateAndFulfillAdvancedOrder(
            advancedOrder,
            criteriaResolvers,
            useFulfillerProxy
        );
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
        // Convert orders to "advanced" orders.
        AdvancedOrder[] memory advancedOrders = _convertOrdersToAdvanced(orders);

        // Validate orders, apply amounts, & determine if they utilize proxies.
        bool[] memory useProxyPerOrder = _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            new CriteriaResolver[](0) // No criteria resolvers are supplied.
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(
            advancedOrders,
            fulfillments,
            useProxyPerOrder
        );
    }

    /**
     * @notice Match an arbitrary number of full or partial orders, each with an
     *         arbitrary number of items for offer and consideration, supplying
     *         criteria resolvers containing specific token identifiers and
     *         associated proofs as well as fulfillments allocating offer
     *         components to consideration components.
     *
     * @param advancedOrders    The advanced orders to match. Note that both the
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
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable override returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Validate orders, apply amounts, & determine if they utilize proxies.
        bool[] memory useProxyPerOrder = _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            criteriaResolvers
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(
            advancedOrders,
            fulfillments,
            useProxyPerOrder
        );
    }

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
        OrderComponents[] memory orders
    ) external override returns (bool) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        address offerer;
        address zone;

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                OrderComponents memory order = orders[i];

                offerer = order.offerer;
                zone = order.zone;

                // Ensure caller is either offerer or zone of the order.
                if (msg.sender != offerer && msg.sender != zone) {
                    revert InvalidCanceller();
                }

                // Derive order hash using the order parameters and the nonce.
                bytes32 orderHash = _getOrderHash(
                    OrderParameters(
                        offerer,
                        zone,
                        order.orderType,
                        order.startTime,
                        order.endTime,
                        order.salt,
                        order.offer,
                        order.consideration
                    ),
                    order.nonce
                );

                // Update the order status as not valid and cancelled.
                _orderStatus[orderHash].isValidated = false;
                _orderStatus[orderHash].isCancelled = true;

                // Emit an event signifying that the order has been cancelled.
                emit OrderCancelled(orderHash, offerer, zone);
            }
        }

        return true;
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
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Declare variables outside of the loop.
        bytes32 orderHash;
        address offerer;

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                Order memory order = orders[i];

                // Retrieve the order parameters.
                OrderParameters memory orderParameters = order.parameters;

                // Move offerer from memory to the stack.
                offerer = orderParameters.offerer;

                // Get current nonce and use it w/ params to derive order hash.
                orderHash = _getNoncedOrderHash(orderParameters);

                // Retrieve the order status using the derived order hash.
                OrderStatus memory orderStatus = _orderStatus[orderHash];

                // Ensure order is fillable and retrieve the filled amount.
                _verifyOrderStatus(
                    orderHash,
                    orderStatus,
                    false // Signifies that partially filled orders are valid.
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
            }
        }

        return true;
    }

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
    ) external override returns (uint256 newNonce) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();
        if (msg.sender != offerer && msg.sender != zone) {
            revert InvalidNonceIncrementor();
        }

        // No need to check for overflow; nonce cannot be incremented that far.
        unchecked {
            // Increment current nonce for the supplied offerer + zone pair.
            newNonce = ++_nonces[offerer][zone];
        }

        // Emit an event containing the new nonce.
        emit NonceIncremented(newNonce, offerer, zone);
    }

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @param order The components of the order.
     *
     * @return The order hash.
     */
    function getOrderHash(
        OrderComponents memory order
    ) external view override returns (bytes32) {
        // Derive order hash by supplying order parameters along with the nonce.
        return _getOrderHash(
            OrderParameters(
                order.offerer,
                order.zone,
                order.orderType,
                order.startTime,
                order.endTime,
                order.salt,
                order.offer,
                order.consideration
            ),
            order.nonce
        );
    }

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
    ) external view override returns (
        bool isValidated,
        bool isCancelled,
        uint256 totalFilled,
        uint256 totalSize
    ) {
        // Retrieve the order status using the order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Return the fields on the order status.
        return (
            orderStatus.isValidated,
            orderStatus.isCancelled,
            orderStatus.numerator,
            orderStatus.denominator
        );
    }

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
    ) external view override returns (uint256) {
        // Return the nonce for the supplied offerer + zone pair.
        return _nonces[offerer][zone];
    }

    /**
     * @notice Retrieve the name of this contract.
     *
     * @return The name of this contract.
     */
    function name() external pure override returns (string memory) {
        // Return the name of the contract.
        return _NAME;
    }

    /**
     * @notice Retrieve the version of this contract.
     *
     * @return The version of this contract.
     */
    function version() external pure override returns (string memory) {
        // Return the version.
        return _VERSION;
    }

    /**
     * @notice Retrieve the domain separator, used for signing and verifying
     * signed orders via EIP-712.
     *
     * @return The domain separator.
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        // Get domain separator, either precomputed or derived based on chainId.
        return _domainSeparator();
    }
}
