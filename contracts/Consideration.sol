// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ConsiderationInterface } from "./interfaces/ConsiderationInterface.sol";

import { ItemType } from "./lib/Enums.sol";

import {
    BasicOrderParameters,
    OfferedItem,
    ReceivedItem,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    Execution,
    Order,
    PartialOrder,
    OrderStatus,
    CriteriaResolver,
    BatchExecution
} from "./lib/Structs.sol";

import { ConsiderationInternal } from "./lib/ConsiderationInternal.sol";

/// @title Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
/// It prioritizes minimizing external calls to the greatest extent possible and
/// provides lightweight methods for common routes as well as more heavyweight
/// methods for composing advanced orders.
/// @author 0age
contract Consideration is ConsiderationInterface, ConsiderationInternal {
    // TODO: support partial fills as part of matchOrders?
    // TODO: skip redundant order validation when it has already been validated?

    /// @dev Derive and set hashes, reference chainId, and associated domain separator during deployment.
    /// @param legacyProxyRegistry A proxy registry that stores per-user proxies that may optionally be used to transfer tokens.
    /// @param requiredProxyImplementation The implementation that this contract will require be set on each per-user proxy.
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationInternal(legacyProxyRegistry, requiredProxyImplementation) {}

    /// @dev Fulfill an order offering a single ERC721 token by supplying Ether as consideration.
    /// @param etherAmount Ether that will be transferred to the initial consideration recipient on the fulfilled order.
    /// Note that msg.value must be greater than this amount if additonal recipients are specified.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer any offered tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicEthForERC721Order(
        uint256 etherAmount,
        BasicOrderParameters memory parameters
    ) external payable override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC721,
                parameters.token,
                parameters.identifier,
                1, // Amount of 1 for ERC721 tokens
                1  // Amount of 1 for ERC721 tokens
            ),
            ReceivedItem(
                ItemType.ETH,
                address(0),   // No token address for ETH
                0,            // No identifier for ETH
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

        // Transfer ETH to recipients, returning excess to caller, and wrap up.
        _transferETHAndFinalize(
            orderHash,
            etherAmount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order offering ERC1155 tokens by supplying Ether as consideration.
    /// @param etherAmount Ether that will be transferred to the initial consideration recipient on the fulfilled order.
    /// Note that msg.value must be greater than this amount if additonal recipients are specified.
    /// @param erc1155Amount Total offererd ERC1155 tokens that will be transferred to the caller.
    /// Note that calling contracts must implement `onERC1155Received` in order to receive tokens.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer any offered tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicEthForERC1155Order(
        uint256 etherAmount,
        uint256 erc1155Amount,
        BasicOrderParameters memory parameters
    ) external payable override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedItem(
                ItemType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount
            ),
            ReceivedItem(
                ItemType.ETH,
                address(0),   // No token address for ETH
                0,            // No identifier for ETH
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

        // Transfer ETH to recipients, returning excess to caller, and wrap up.
        _transferETHAndFinalize(
            orderHash,
            etherAmount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order offering a single ERC721 token by supplying an ERC20 token as consideration.
    /// @param erc20Token The address of the ERC20 token being supplied as consideration.
    /// @param erc20Amount ERC20 tokens that will be transferred to the initial consideration recipient on the fulfilled order.
    /// Note that the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer the tokens on its behalf.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer any offered tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicERC20ForERC721Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
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
            orderHash,
            erc20Token,
            erc20Amount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order offering ERC1155 tokens by supplying an ERC20 token as consideration.
    /// @param erc20Token The address of the ERC20 token being supplied as consideration.
    /// @param erc20Amount ERC20 tokens that will be transferred to the initial consideration recipient on the fulfilled order.
    /// Note that the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer the tokens on its behalf.
    /// @param erc1155Amount Total offererd ERC1155 tokens that will be transferred to the caller.
    /// Note that calling contracts must implement `onERC1155Received` in order to receive tokens.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer any offered tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicERC20ForERC1155Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
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
            orderHash,
            erc20Token,
            erc20Amount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order offering ERC20 tokens by supplying a single ERC721 token as consideration.
    /// @param erc20Token The address of the ERC20 token being offered.
    /// @param erc20Amount ERC20 tokens that will be transferred to the caller.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer the tokens on its behalf.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any supplied tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicERC721ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash,) = _prepareBasicFulfillment(
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
            parameters.useFulfillerProxy ? msg.sender : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            offerer,
            msg.sender,
            orderHash,
            erc20Token,
            erc20Amount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order offering ERC20 tokens by supplying ERC1155 tokens as consideration.
    /// @param erc20Token The address of the ERC20 token being offered.
    /// @param erc20Amount ERC20 tokens that will be transferred to the caller.
    /// Note that the offerer must first approve this contract (or their proxy if indicated by the order) to transfer the tokens on its behalf.
    /// @param erc1155Amount Total offererd ERC1155 tokens that will be transferred to the offerer.
    /// Note that offering contracts must implement `onERC1155Received` in order to receive tokens.
    /// @param parameters Additional information on the fulfilled order.
    /// Note that the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any supplied tokens on its behalf.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillBasicERC1155ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters memory parameters
    ) external override returns (bool) {
        // Move the offerer from memory to the stack.
        address payable offerer = parameters.offerer;

        // Derive and validate order using parameters and update order status.
        (bytes32 orderHash,) = _prepareBasicFulfillment(
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
            parameters.useFulfillerProxy ? msg.sender : address(0)
        );

        // Transfer ERC20 tokens to all recipients and wrap up.
        _transferERC20AndFinalize(
            offerer,
            msg.sender,
            orderHash,
            erc20Token,
            erc20Amount,
            parameters
        );

        return true;
    }

    /// @dev Fulfill an order with an arbitrary number of items for offer and consideration.
    /// Note that this function does not support criteria-based orders or partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param order The order to fulfill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillOrder(
        Order memory order,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Validate and fulfill the order.
        return _fulfillOrder(
            PartialOrder(
                order.parameters,
                1,
                1,
                order.signature
            ),
            new CriteriaResolver[](0),  // no criteria resolvers
            useFulfillerProxy
        );
    }

    /// @dev Fulfill an order with an arbitrary number of items for offer and consideration alongside criteria resolvers containing specific token identifiers and associated proofs.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param order The order to fulfill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// @param criteriaResolvers An array where each element contains a reference to a specific offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a criteria of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Validate and fulfill the order.
        return _fulfillOrder(
            PartialOrder(
                order.parameters,
                1,
                1,
                order.signature
            ),
            criteriaResolvers, // supply criteria resolvers
            useFulfillerProxy
        );
    }

    /// @dev Partially fill some fraction of an order with an arbitrary number of items for offer and consideration.
    /// Note that an amount less than the desired amount may be filled and that this function does not support criteria-based orders.
    /// @param partialOrder The order to fulfill along with the fraction of the order to fill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// Also note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillPartialOrder(
        PartialOrder memory partialOrder,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Ensure partial fills are supported by specified order.
        _assertPartialFillsEnabled(
            partialOrder.numerator,
            partialOrder.denominator,
            partialOrder.parameters.orderType
        );

        // Validate and fulfill the order.
        return _fulfillOrder(
            partialOrder,
            new CriteriaResolver[](0),  // no criteria resolvers
            useFulfillerProxy
        );
    }

    /// @dev Partially fill some fraction of an order with an arbitrary number of items for offer and consideration alongside criteria resolvers containing specific token identifiers and associated proofs.
    /// Note that an amount less than the desired amount may be filled.
    /// @param partialOrder The order to fulfill along with the fraction of the order to fill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// Also note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param criteriaResolvers An array where each element contains a reference to a specific offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a criteria of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillPartialOrderWithCriteria(
        PartialOrder memory partialOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Ensure partial fills are supported by specified order.
        _assertPartialFillsEnabled(
            partialOrder.numerator,
            partialOrder.denominator,
            partialOrder.parameters.orderType
        );

        // Validate and fulfill the order.
        return _fulfillOrder(
            partialOrder,
            criteriaResolvers,
            useFulfillerProxy
        );
    }

    /// @dev Match an arbitrary number of orders, each with an arbitrary number of items for offer and consideration, supplying criteria resolvers containing specific token identifiers and associated proofs as well as fulfillments allocating offer components to consideration components.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param orders The orders to match.
    /// Note that both the offerer and fulfiller on each order must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and each consideration recipient must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// @param criteriaResolvers An array where each element contains a reference to a specific order as well as that order's offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a root of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    /// @param fulfillments An array of elements allocating offer components to consideration components.
    /// Note that each consideration component must be fully met in order for the match operation to be valid.
    /// @return standardExecutions An array of elements indicating the sequence of non-batch transfers performed as part of matching the given orders.
    /// @return batchExecutions An array of elements indicating the sequence of batch transfers performed as part of matching the given orders.
    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable override returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Adjust orders by filled amount and determine if they utilize proxies.
        bool[] memory useProxyPerOrder = _validateOrdersAndApplyPartials(orders);

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(orders, criteriaResolvers);

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillOrders(orders, fulfillments, useProxyPerOrder);
    }

    /// @dev Cancel an arbitrary number of orders.
    /// Note that only the offerer or the zone of a given order may cancel it.
    /// @param orders The orders to cancel.
    /// @return A boolean indicating whether the orders were successfully cancelled.
    function cancel(
        OrderComponents[] memory orders
    ) external override returns (bool) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                OrderComponents memory order = orders[i];

                // Ensure caller is either offerer or zone of the order.
                if (
                    msg.sender != order.offerer &&
                    msg.sender != order.zone
                ) {
                    revert InvalidCanceller();
                }

                // Derive order hash using the order parameters and the nonce.
                bytes32 orderHash = _getOrderHash(
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

                // Update the order status as cancelled.
                _orderStatus[orderHash].isCancelled = true;

                // Emit an event signifying that the order has been cancelled.
                emit OrderCancelled(
                    orderHash,
                    order.offerer,
                    order.zone
                );
            }
        }

        return true;
    }

    /// @dev Validate an arbitrary number of orders, thereby registering them as valid and allowing prospective fulfillers to skip verification.
    /// Note that anyone can validate a signed order but only the offerer can validate an order without supplying a signature.
    /// @param orders The orders to validate.
    /// @return A boolean indicating whether the orders were successfully validated.
    function validate(
        Order[] memory orders
    ) external override returns (bool) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the order.
                Order memory order = orders[i];

                // Get current nonce and use it w/ params to derive order hash.
                bytes32 orderHash = _getNoncedOrderHash(order.parameters);

                // Retrieve the order status and verify it.
                OrderStatus memory orderStatus = _getOrderStatusAndVerify(
                    orderHash,
                    order.parameters.offerer,
                    order.signature,
                    false // Note: partially used orders will fail next check.
                );

                // Ensure that the retrieved order is not already validated.
                if (orderStatus.isValidated) {
                    revert OrderAlreadyValidated(orderHash);
                }

                // Update order status to mark the order as valid.
                _orderStatus[orderHash].isValidated = true;

                // Emit an event signifying order was successfully validated.
                emit OrderValidated(
                    orderHash,
                    order.parameters.offerer,
                    order.parameters.zone
                );
            }
        }

        return true;
    }

    /// @dev Cancel all orders from a given offerer with a given zone in bulk by incrementing a nonce.
    /// Note that only the offerer or the zone may increment the nonce.
    /// @param offerer The offerer in question.
    /// @param zone The zone in question.
    /// @return newNonce The new nonce.
    function incrementNonce(
        address offerer,
        address zone
    ) external override returns (uint256 newNonce) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();
        if (msg.sender != offerer && msg.sender != zone) {
            revert InvalidNonceIncrementor();
        }

        // Increment current nonce for the supplied offerer + zone pair.
        newNonce = ++_nonces[offerer][zone];

        // Emit an event containing the new nonce.
        emit NonceIncremented(newNonce, offerer, zone);

        // Return the new nonce.
        return newNonce;
    }

    /// @dev Retrieve the status of a given order by hash, including whether the order has been cancelled or validated and the fraction of the order that has been filled.
    /// @param orderHash The order hash in question.
    /// @return The status of the order.
    function getOrderStatus(
        bytes32 orderHash
    ) external view override returns (OrderStatus memory) {
        // Return the order status.
        return _orderStatus[orderHash];
    }

    /// @dev Retrieve the current nonce for a given combination of offerer and zone.
    /// @param offerer The offerer in question.
    /// @param zone The zone in question.
    /// @return The current nonce.
    function getNonce(
        address offerer,
        address zone
    ) external view override returns (uint256) {
        // Return the nonce for the supplied offerer + zone pair.
        return _nonces[offerer][zone];
    }

    /// @dev Retrieve the domain separator, used for signing orders via EIP-712.
    /// @return The domain separator.
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        // Get domain separator, either precomputed or derived based on chainId.
        return _domainSeparator();
    }

    /// @dev Retrieve the order hash for a given order.
    /// @param order The components of the order.
    /// @return The order hash.
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

    /// @dev Retrieve the name of this contract.
    /// @return The name of this contract.
    function name() external pure override returns (string memory) {
        // Return the name of the contract.
        return _NAME;
    }

    /// @dev Retrieve the version of this contract.
    /// @return The version of this contract.
    function version() external pure override returns (string memory) {
        // Return the version.
        return _VERSION;
    }
}
