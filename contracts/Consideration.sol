// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    OrderType,
    AssetType,
    Side
} from "./Enums.sol";

import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferedAsset,
    ReceivedAsset,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    OrderStatus,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "./Structs.sol";

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "./AbridgedTokenInterfaces.sol";

import {
    ProxyRegistryInterface,
    ProxyInterface
} from "./AbridgedProxyInterfaces.sol";

import { EIP1271Interface } from "./EIP1271Interface.sol";

import { ConsiderationInterface } from "./ConsiderationInterface.sol";

/// @title Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
/// It prioritizes minimizing external calls to the greatest extent possible and
/// provides lightweight methods for common routes as well as more heavyweight
/// methods for composing advanced orders.
/// @author 0age
contract Consideration is ConsiderationInterface {
    // TODO: support partial fills as part of matchOrders?
    // TODO: skip redundant order validation when it has already been validated?

    // Declare constants for name, version, and reentrancy sentinel values.
    string internal constant _NAME = "Consideration";
    string internal constant _VERSION = "1";
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFERED_ASSET_TYPEHASH;
    bytes32 internal immutable _RECEIVED_ASSET_TYPEHASH;
    bytes32 internal immutable _ORDER_HASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    // Allow for interaction with user proxies on the legacy proxy registry.
    ProxyRegistryInterface internal immutable _LEGACY_PROXY_REGISTRY;

    // Ensure that user proxies adhere to the required proxy implementation.
    address internal immutable _REQUIRED_PROXY_IMPLEMENTATION;

    // Prevent reentrant calls on protected functions.
    uint256 internal _reentrancyGuard;

    // Track status of each order (validated, cancelled, and fraction filled).
    mapping (bytes32 => OrderStatus) internal _orderStatus;

    // Cancel offerer's orders with given facilitator (offerer => facilitator => nonce).
    mapping (address => mapping (address => uint256)) internal _facilitatorNonces;

    /// @dev Derive and set hashes, reference chainId, and associated domain separator during deployment.
    /// @param legacyProxyRegistry A proxy registry that stores per-user proxies that may optionally be used to approve transfers.
    /// @param requiredProxyImplementation The implementation that this contract will require be set on each per-user proxy.
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) {
        // Derive hashes, reference chainId, and associated domain separator.
        _NAME_HASH = keccak256(bytes(_NAME));
        _VERSION_HASH = keccak256(bytes(_VERSION));
        _EIP_712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        _OFFERED_ASSET_TYPEHASH = keccak256("OfferedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
        _RECEIVED_ASSET_TYPEHASH = keccak256("ReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _ORDER_HASH = keccak256("OrderComponents(address offerer,address facilitator,OfferedAsset[] offer,ReceivedAsset[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,uint256 salt,uint256 nonce)OfferedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)ReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // TODO: validate each of these based on expected codehash
        _LEGACY_PROXY_REGISTRY = ProxyRegistryInterface(legacyProxyRegistry);
        _REQUIRED_PROXY_IMPLEMENTATION = requiredProxyImplementation;

        // Initialize the reentrancy guard in a cleared state.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /// @dev Fulfill an order offering a single ERC721 token by supplying Ether as consideration.
    /// @param etherAmount Ether that will be transferred to the initial consideration account on the fulfilled order.
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
            OfferedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,                     // Amount of 1 for ERC721
                1                      // Amount of 1 for ERC721
            ),
            ReceivedAsset(
                AssetType.ETH,
                address(0),    // No token address for ETH
                0,             // No identifier for ETH
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
    /// @param etherAmount Ether that will be transferred to the initial consideration account on the fulfilled order.
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
            OfferedAsset(
                AssetType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount
            ),
            ReceivedAsset(
                AssetType.ETH,
                address(0),    // No token address for ETH
                0,             // No identifier for ETH
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
    /// @param erc20Amount ERC20 tokens that will be transferred to the initial consideration account on the fulfilled order.
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
            OfferedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,                     // Amount of 1 for ERC721
                1                      // Amount of 1 for ERC721
            ),
            ReceivedAsset(
                AssetType.ERC20,
                erc20Token,
                0,                  // No identifier for ERC20 token
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
    /// @param erc20Amount ERC20 tokens that will be transferred to the initial consideration account on the fulfilled order.
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
            OfferedAsset(
                AssetType.ERC1155,
                parameters.token,
                parameters.identifier,
                erc1155Amount,
                erc1155Amount
            ),
            ReceivedAsset(
                AssetType.ERC20,
                erc20Token,
                0,                  // No identifier for ERC20 token
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
            OfferedAsset(
                AssetType.ERC20,
                erc20Token,
                0,               // No identifier for ERC20 token
                erc20Amount,
                erc20Amount
            ),
            ReceivedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,                     // Amount of 1 for ERC721
                1,                     // Amount of 1 for ERC721
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
            OfferedAsset(
                AssetType.ERC20,
                erc20Token,
                0,               // No identifier for ERC20 token
                erc20Amount,
                erc20Amount
            ),
            ReceivedAsset(
                AssetType.ERC1155,
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
            order,
            1,                          // numerator of 1
            1,                          // denominator of 1
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
            order,
            1,                 // numerator of 1
            1,                 // denominator of 1
            criteriaResolvers, // supply criteria resolvers
            useFulfillerProxy
        );
    }

    /// @dev Partially fill some fraction of an order with an arbitrary number of items for offer and consideration.
    /// Note that an amount less than the desired amount may be filled and that this function does not support criteria-based orders.
    /// @param order The order to fulfill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param denominator A value indicating the total size of the order.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Ensure partial fills are supported by specified order.
        _ensurePartialFillsEnabled(
            numerator,
            denominator,
            order.parameters.orderType
        );

        // Validate and fulfill the order.
        return _fulfillOrder(
            order,
            numerator,
            denominator,
            new CriteriaResolver[](0),  // no criteria resolvers
            useFulfillerProxy
        );
    }

    /// @dev Partially fill some fraction of an order with an arbitrary number of items for offer and consideration alongside criteria resolvers containing specific token identifiers and associated proofs.
    /// Note that an amount less than the desired amount may be filled.
    /// @param order The order to fulfill.
    /// Note that both the offerer and the fulfiller must first approve this contract (or their proxy if indicated by the order) to transfer any relevant tokens on their behalf and that contracts must implement `onERC1155Received` in order to receive ERC1155 tokens.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param denominator A value indicating the total size of the order.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param criteriaResolvers An array where each element contains a reference to a specific offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a criteria of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function fulfillPartialOrderWithCriteria(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable override returns (bool) {
        // Ensure partial fills are supported by specified order.
        _ensurePartialFillsEnabled(
            numerator,
            denominator,
            order.parameters.orderType
        );

        // Validate and fulfill the order.
        return _fulfillOrder(
            order,
            numerator,
            denominator,
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
    /// Note that only the offerer or the facilitator of a given order may cancel it.
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

                // Ensure caller is either offerer or facilitator of the order.
                if (
                    msg.sender != order.offerer &&
                    msg.sender != order.facilitator
                ) {
                    revert OnlyOffererOrFacilitatorMayCancel();
                }

                // Derive order hash using the order parameters and the nonce.
                bytes32 orderHash = _getOrderHash(
                    OrderParameters(
                        order.offerer,
                        order.facilitator,
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
                    order.facilitator
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
                    order.parameters.facilitator
                );
            }
        }

        return true;
    }

    /// @dev Cancel all orders from a given offerer with a given facilitator in bulk by incrementing a nonce.
    /// Note that only the offerer or the facilitator may increment the nonce.
    /// @param offerer The offerer in question.
    /// @param facilitator The facilitator in question.
    /// @return newNonce The new nonce.
    function incrementFacilitatorNonce(
        address offerer,
        address facilitator
    ) external override returns (uint256 newNonce) {
        // Ensure that the reentrancy guard is not currently set.
        _assertNonReentrant();
        if (msg.sender != offerer && msg.sender != facilitator) {
            revert OnlyOffererOrFacilitatorMayIncrementNonce();
        }

        // Increment current nonce for the supplied offerer + facilitator pair.
        newNonce = ++_facilitatorNonces[offerer][facilitator];

        // Emit an event containing the new nonce and return it.
        emit FacilitatorNonceIncremented(offerer, facilitator, newNonce);
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

    /// @dev Retrieve the current nonce for a given combination of offerer and facilitator.
    /// @param offerer The offerer in question.
    /// @param facilitator The facilitator in question.
    /// @return The current nonce.
    function facilitatorNonce(
        address offerer,
        address facilitator
    ) external view override returns (uint256) {
        // Return the nonce for the supplied offerer + facilitator pair.
        return _facilitatorNonces[offerer][facilitator];
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
                order.facilitator,
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

    /// @dev Internal function to derive and validate an order based on a set of parameters and a primary item for offer and consideration.
    /// @param parameters The parameters of the basic order.
    /// @param offeredAsset The primary item being offered.
    /// @param receivedAsset The primary item being received as consideration.
    /// @return orderHash The order hash.
    /// @return useOffererProxy A boolean indicating whether to utilize the offerer's proxy.
    function _prepareBasicFulfillment(
        BasicOrderParameters memory parameters,
        OfferedAsset memory offeredAsset,
        ReceivedAsset memory receivedAsset
    ) internal returns (bytes32 orderHash, bool useOffererProxy) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Pull frequently used arguments from memory & place them on the stack.
        address payable offerer = parameters.offerer;
        address facilitator = parameters.facilitator;
        uint256 startTime = parameters.startTime;
        uint256 endTime = parameters.endTime;

        // Ensure current timestamp falls between order start time and end time.
        _ensureValidTime(startTime, endTime);

        // Allocate memory: 1 offer, 1+additionalRecipients consideration items.
        OfferedAsset[] memory offer = new OfferedAsset[](1);
        ReceivedAsset[] memory consideration = new ReceivedAsset[](
            1 + parameters.additionalRecipients.length
        );

        // Set primary offer + consideration item as respective first elements.
        offer[0] = offeredAsset;
        consideration[0] = receivedAsset;

        // Use offered asset's info for additional recipients if it is an ERC20.
        if (offeredAsset.assetType == AssetType.ERC20) {
            receivedAsset.assetType = AssetType.ERC20;
            receivedAsset.token = offeredAsset.token;
            receivedAsset.identifierOrCriteria = 0;
        }

        // Skip overflow checks as for loop is indexed starting at one.
        unchecked {
            // Iterate over each consideration beyond primary one on the order.
            for (uint256 i = 1; i < consideration.length; ++i) {
                // Retrieve additional recipient corresponding to consideration.
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i - 1];

                // Update consideration item w/ info from additional recipient.
                receivedAsset.account = additionalRecipient.account;
                receivedAsset.startAmount = additionalRecipient.amount;
                receivedAsset.endAmount = additionalRecipient.amount;

                // Set new received item as an additional consideration item.
                consideration[i] = receivedAsset;
            }
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _getNoncedOrderHash(
            OrderParameters(
                offerer,
                facilitator,
                parameters.orderType,
                startTime,
                endTime,
                parameters.salt,
                offer,
                consideration
            )
        );

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            orderHash,
            offerer,
            parameters.signature
        );

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _adjustOrderTypeAndCheckSubmitter(
            parameters.orderType,
            offerer,
            facilitator
        );

        // If the offerer's proxy is being utilized, adjust the order type down.
        if (useOffererProxy) {
            // Skip underflow check: orderType >= 4 when useOffererProxy = true.
            unchecked {
                // Adjust the order type.
                parameters.orderType = OrderType(uint8(parameters.orderType) - 4);
            }
        }

        // Return order hash and a bool for whether to utilize offerer's proxy.
        return (orderHash, useOffererProxy);
    }

    /// @dev Internal function to verify and update the status of a basic order.
    /// @param orderHash The hash of the order.
    /// @param offerer The offerer of the order.
    /// @param signature A signature from the offerer indicating that the order has been approved.
    function _validateBasicOrderAndUpdateStatus(
        bytes32 orderHash,
        address offerer,
        bytes memory signature
    ) internal {
        // Verify the basic order in question.
        _getOrderStatusAndVerify(
            orderHash,
            offerer,
            signature,
            true // Only allow unused orders.
        );

        // Update order status as fully filled, packing struct values.
        _orderStatus[orderHash].isValidated = true;
        _orderStatus[orderHash].isCancelled = false;
        _orderStatus[orderHash].numerator = 1;
        _orderStatus[orderHash].denominator = 1;
    }

    /// @dev Internal function to validate an order, determine what portion to fill, and update its status.
    /// The desired fill amount is supplied as a fraction, and the actual amount to fill is returned as a similar fraction.
    /// @param order The order to validate and update status for.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param denominator A value indicating the total size of the order.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @return orderHash The order hash.
    /// @return newNumerator A value indicating the portion of the order that will be filled.
    /// @return newDenominator A value indicating the total size of the order.
    /// @return useOffererProxy A boolean indicating whether to utilize the offerer's proxy.
    function _validateOrderAndUpdateStatus(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) internal returns (
        bytes32 orderHash,
        uint120 newNumerator,
        uint120 newDenominator,
        bool useOffererProxy
    ) {
        // Ensure current timestamp falls between order start time and end time.
        _ensureValidTime(order.parameters.startTime, order.parameters.endTime);

        // Ensure that the supplied numerator and denominator are valid.
        if (numerator > denominator || numerator == 0 || denominator == 0) {
            revert BadFraction();
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _getNoncedOrderHash(order.parameters);

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _adjustOrderTypeAndCheckSubmitter(
            order.parameters.orderType,
            order.parameters.offerer,
            order.parameters.facilitator
        );

        // If the offerer's proxy is being utilized, adjust the order type down.
        if (useOffererProxy) {
            // Skip underflow check: orderType >= 4 when useOffererProxy = true.
            unchecked {
                // Adjust the order type.
                order.parameters.orderType = OrderType(
                    uint8(order.parameters.orderType) - 4
                );
            }
        }

        // Retrieve the order status and verify it.
        OrderStatus memory orderStatus = _getOrderStatusAndVerify(
            orderHash,
            order.parameters.offerer,
            order.signature,
            false // allow partially used orders
        );

        // If order currently has a non-zero denominator it is partially filled.
        if (orderStatus.denominator != 0) {
            // If denominator of 1 supplied, fill all remaining amount on order.
            if (denominator == 1) {
                // Scale numerator & denominator to match current denominator.
                numerator = orderStatus.denominator;
                denominator = orderStatus.denominator;
            } // Otherwise, if supplied denominator differs from current one...
            else if (orderStatus.denominator != denominator) {
                // scale current numerator by the supplied denominator, then...
                orderStatus.numerator *= denominator;

                // scale supplied numerator & denominator by current denominator.
                numerator *= orderStatus.denominator;
                denominator *= orderStatus.denominator;
            }

            // Once adjusted, if current+supplied numerator exceeds denominator:
            if (orderStatus.numerator + numerator > denominator) {
                // Skip underflow check: denominator >= orderStatus.numerator
                unchecked {
                    // Reduce current numerator so it + supplied = denominator.
                    numerator = denominator - orderStatus.numerator;
                }
            }

            // Skip overflow check: checked above unless numerator is reduced.
            unchecked {
                // Update order status and fill amount, packing struct values.
                _orderStatus[orderHash].isValidated = true;
                _orderStatus[orderHash].isCancelled = false;
                _orderStatus[orderHash].numerator = orderStatus.numerator + numerator;
                _orderStatus[orderHash].denominator = denominator;
            }
        } else {
            // Update order status and fill amount, packing struct values.
            _orderStatus[orderHash].isValidated = true;
            _orderStatus[orderHash].isCancelled = false;
            _orderStatus[orderHash].numerator = numerator;
            _orderStatus[orderHash].denominator = denominator;
        }

        // Return order hash, new numerator and denominator, and proxy boolean.
        return (orderHash, numerator, denominator, useOffererProxy);
    }

    /// @dev Internal function to validate an order and update its status, adjust prices based on current time, apply criteria resolvers, determine what portion to fill, and transfer relevant tokens.
    /// @param order The order to fulfill.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param denominator A value indicating the total size of the order.
    /// Note that all offer and consideration components must divide with no remainder in order for the partial fill to be valid.
    /// @param criteriaResolvers An array where each element contains a reference to a specific offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a criteria of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    /// @param useFulfillerProxy A flag indicating whether to source approvals for the fulfilled tokens from their respective proxy.
    /// @return A boolean indicating whether the order was successfully fulfilled.
    function _fulfillOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) internal returns (bool) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint120 fillNumerator,
            uint120 fillDenominator,
            bool useOffererProxy
        ) = _validateOrderAndUpdateStatus(order, numerator, denominator);

        // Adjust prices based on time, start amount, and end amount.
        _adjustOrderPrice(order);

        // Apply criteria resolvers (requires array of orders to be supplied).
        Order[] memory orders = new Order[](1);
        orders[0] = order;
        order = _applyCriteriaResolvers(orders, criteriaResolvers);

        // Move the offerer from memory to the stack.
        address offerer = order.parameters.offerer;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each consideration on the order.
        for (uint256 i = 0; i < order.parameters.consideration.length;) {
            // Retrieve the consideration item.
            ReceivedAsset memory consideration = order.parameters.consideration[i];

            // Apply order fill fraction to each consideration amount.
            consideration.endAmount = _getFraction(
                fillNumerator,
                fillDenominator,
                consideration.endAmount
            );

            // If consideration expects ETH, reduce ether value available.
            if (consideration.assetType == AssetType.ETH) {
                etherRemaining -= consideration.endAmount;
            }

            // Transfer the item from the caller to the consideration recipient.
            _transfer(
                consideration,
                msg.sender,
                useFulfillerProxy
            );

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < order.parameters.offer.length;) {
            // Retrieve the offer item.
            OfferedAsset memory offer = order.parameters.offer[i];

            // Apply order fill fraction and set the caller as the receiver.
            ReceivedAsset memory asset = ReceivedAsset(
                offer.assetType,
                offer.token,
                offer.identifierOrCriteria,
                0,
                _getFraction(
                    fillNumerator,
                    fillDenominator,
                    offer.endAmount
                ),
                payable(msg.sender)
            );

            // If offer expects ETH, reduce ether value available.
            if (asset.assetType == AssetType.ETH) {
                etherRemaining -= asset.endAmount;
            }

            // Transfer the item from the offerer to the caller.
            _transfer(
                asset,
                offerer,
                useOffererProxy
            );

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }

        // Emit an OrderFulfilled event and clear reentrancy guard.
        _emitOrderFulfilledEventAndClearReentrancyGuard(
            orderHash,
            offerer,
            order.parameters.facilitator
        );

        return true;
    }

    /// @dev Internal function to validate a group of orders, update their statuses, and reduce their amounts by their previously filled fractions.
    /// @param orders The orders to validate and reduce by previously filled amounts.
    /// @return A list of boolean indicating whether to utilize a proxy for each order.
    function _validateOrdersAndApplyPartials(
        Order[] memory orders
    ) internal returns (bool[] memory) {
        // Declare memory region to determine proxy utilization per order.
        bool[] memory useOffererProxyPerOrder = new bool[](orders.length);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < orders.length; ++i) {
                // Retrieve the current order.
                Order memory order = orders[i];

                // Validate it, update status, and determine fraction to fill.
                (
                    bytes32 orderHash,
                    uint120 numerator,
                    uint120 denominator,
                    bool useOffererProxy
                ) = _validateOrderAndUpdateStatus(order, 1, 1); // fill maximum

                // Adjust prices based on time, start amount, and end amount.
                orders[i] = _adjustOrderPrice(order);

                // Mark whether order should utilize offerer's proxy.
                useOffererProxyPerOrder[i] = useOffererProxy;

                // Iterate over each offered item on the order.
                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    // Apply order fill fraction to each offer amount.
                    orders[i].parameters.offer[j].endAmount = _getFraction(
                        numerator,
                        denominator,
                        orders[i].parameters.offer[j].endAmount
                    );
                }

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    // Apply order fill fraction to each consideration amount.
                    orders[i].parameters.consideration[j].endAmount = _getFraction(
                        numerator,
                        denominator,
                        orders[i].parameters.consideration[j].endAmount
                    );
                }

                // Emit an event signifying that the order will be fulfilled.
                emit OrderFulfilled(
                    orderHash,
                    orders[i].parameters.offerer,
                    orders[i].parameters.facilitator
                );
            }
        }

        // Return memory region designating proxy utilization per order.
        return useOffererProxyPerOrder;
    }

    /// @dev Internal function to fulfill an arbitrary number of orders after validating, adjusting, and applying criteria resolvers.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param orders The orders to match.
    /// @param fulfillments An array of elements allocating offer components to consideration components.
    /// Note that each consideration component must be fully met in order for the match operation to be valid.
    /// @param useOffererProxyPerOrder An array of booleans indicating whether to source approvals for the fulfilled tokens on each order from their respective proxy.
    /// @return An array of elements indicating the sequence of non-batch transfers performed as part of matching the given orders.
    /// @return An array of elements indicating the sequence of batch transfers performed as part of matching the given orders.
    function _fulfillOrders(
        Order[] memory orders,
        Fulfillment[] memory fulfillments,
        bool[] memory useOffererProxyPerOrder
    ) internal returns (Execution[] memory, BatchExecution[] memory) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Allocate executions by fulfillment and apply them to each execution.
        Execution[] memory executions = new Execution[](fulfillments.length);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each fulfillment.
            for (uint256 i = 0; i < fulfillments.length; ++i) {
                executions[i] = _applyFulfillment(
                    orders,
                    fulfillments[i],
                    useOffererProxyPerOrder
                );
            }

            // Iterate over each order to ensure all considerations are met.
            for (uint256 i = 0; i < orders.length; ++i) {
                ReceivedAsset[] memory considerations = orders[i].parameters.consideration;

                // Iterate over each consideration on order to ensure it is met.
                for (uint256 j = 0; j < considerations.length; ++j) {
                    // Retrieve the remaining amount on the consideration.
                    uint256 remainingAmount = considerations[j].endAmount;

                    // Revert if the remaining amount is not zero.
                    if (remainingAmount != 0) {
                        revert ConsiderationNotMet(i, j, remainingAmount);
                    }
                }
            }
        }

        // Allocate memory for "standard" (no batch) and "batch" executions.
        Execution[] memory standardExecutions;
        BatchExecution[] memory batchExecutions;

        // Split executions into "standard" (no batch) and "batch" executions.
        (standardExecutions, batchExecutions) = _compressExecutions(executions);

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < standardExecutions.length;) {
            // Retrieve the execution.
            Execution memory execution = standardExecutions[i];

            // If execution transfers ETH, reduce ether value available.
            if (execution.asset.assetType == AssetType.ETH) {
                etherRemaining -= execution.asset.endAmount;
            }

            // Transfer the item specified by the execution.
            _transfer(
                execution.asset,
                execution.offerer,
                execution.useProxy
            );

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each batch execution.
            for (uint256 i = 0; i < batchExecutions.length; ++i) {
                _batchTransferERC1155(batchExecutions[i]);
            }
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;

        // Return the arrays of executions that were triggered.
        return (executions, batchExecutions);
    }

    /// @dev Internal function to transfer a given item.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param asset The item to transfer, including the amount and the to address.
    /// @param offerer The account offering the item, i.e. the from address.
    /// @param useProxy A boolean indicating whether to source approvals for the fulfilled token from the offer's proxy.
    function _transfer(
        ReceivedAsset memory asset,
        address offerer,
        bool useProxy
    ) internal {
        if (asset.assetType == AssetType.ETH) {
            // Transfer Ether to the recipient.
            _transferEth(asset.account, asset.endAmount);
        } else {
            // Place proxy owner on stack (or null address if not using proxy).
            address proxyOwner = useProxy ? offerer : address(0);
            
            if (asset.assetType == AssetType.ERC20) {
                // Transfer ERC20 token from the offerer to the recipient.
                _transferERC20(
                    asset.token,
                    offerer,
                    asset.account,
                    asset.endAmount,
                    proxyOwner
                );
            } else if (asset.assetType == AssetType.ERC721) {
                // Transfer ERC721 token from the offerer to the recipient.
                _transferERC721(
                    asset.token,
                    offerer,
                    asset.account,
                    asset.identifierOrCriteria,
                    proxyOwner
                );
            } else {
                // Transfer ERC1155 token from the offerer to the recipient.
                _transferERC1155(
                    asset.token,
                    offerer,
                    asset.account,
                    asset.identifierOrCriteria,
                    asset.endAmount,
                    proxyOwner
                );
            }
        }
    }

    /// @dev Internal function to transfer ether to a given recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount to transfer.
    function _transferEth(address payable to, uint256 amount) internal {
        (bool ok, bytes memory data) = to.call{value: amount}("");
        if (!ok) {
            if (data.length != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert EtherTransferGenericFailure(to, amount);
            }
        }
    }

    /// @dev Internal function to transfer ERC20 tokens from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param token The ERC20 token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount to transfer.
    /// @param proxyOwner An address indicating the owner of the proxy to use when facilitating the transfer, or the null address if no proxy should be utilized.
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        address proxyOwner
    ) internal {
        (bool ok, bytes memory data) = (
            proxyOwner != address(0)
                ? _callProxy(
                    proxyOwner,
                    abi.encodeWithSelector(
                        ProxyInterface.transferERC20.selector,
                        token,
                        from,
                        to,
                        amount
                    )
                )
                : token.call(
                    abi.encodeCall(
                        ERC20Interface.transferFrom,
                        (
                            from,
                            to,
                            amount
                        )
                    )
                )
        );

        _assertValidTokenTransfer(
            ok,
            data.length,
            token,
            from,
            to,
            0,
            amount
        );

        if (!(
            data.length >= 32 &&
            abi.decode(data, (bool))
        )) {
            revert BadReturnValueFromERC20OnTransfer(token, from, to, amount);
        }
    }

    /// @dev Internal function to transfer an ERC721 token from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param token The ERC721 token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param identifier The tokenId to transfer.
    /// @param proxyOwner An address indicating the owner of the proxy to use when facilitating the transfer, or the null address if no proxy should be utilized.
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        address proxyOwner
    ) internal {
        (bool ok, bytes memory data) = (
            proxyOwner != address(0)
                ? _callProxy(
                    proxyOwner,
                    abi.encodeWithSelector(
                        ProxyInterface.transferERC721.selector,
                        token,
                        from,
                        to,
                        identifier
                    )
                )
                : token.call(
                    abi.encodeCall(
                        ERC721Interface.transferFrom,
                        (
                            from,
                            to,
                            identifier
                        )
                    )
                )
        );

        _assertValidTokenTransfer(
            ok,
            data.length,
            token,
            from,
            to,
            identifier,
            1
        );
    }

    /// @dev Internal function to transfer ERC1155 tokens from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param token The ERC1155 token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param identifier The tokenId to transfer.
    /// @param amount The amount to transfer.
    /// @param proxyOwner An address indicating the owner of the proxy to use when facilitating the transfer, or the null address if no proxy should be utilized.
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address proxyOwner
    ) internal {
        (bool ok, bytes memory data) = (
            proxyOwner != address(0)
                ? _callProxy(
                    proxyOwner,
                    abi.encodeWithSelector(
                        ProxyInterface.transferERC1155.selector,
                        token,
                        from,
                        to,
                        identifier,
                        amount
                    )
                )
                : token.call(
                    abi.encodeWithSelector(
                        ERC1155Interface.safeTransferFrom.selector,
                        from,
                        to,
                        identifier,
                        amount,
                        ""
                    )
                )
        );

        _assertValidTokenTransfer(
            ok,
            data.length,
            token,
            from,
            to,
            identifier,
            amount
        );
    }

    /// @dev Internal function to transfer a batch of ERC1155 tokens from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param batchExecution The batch of 1155 tokens to be transferred.
    function _batchTransferERC1155(
        BatchExecution memory batchExecution
    ) internal {
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;
        (bool ok, bytes memory data) = (
            batchExecution.useProxy
                ? _callProxy(
                    batchExecution.from,
                    abi.encodeWithSelector(
                        ProxyInterface.batchTransferERC1155.selector,
                        token,
                        from,
                        to,
                        tokenIds,
                        amounts
                    )
                )
                : token.call(
                    abi.encodeWithSelector(
                        ERC1155Interface.safeBatchTransferFrom.selector,
                        from,
                        to,
                        tokenIds,
                        amounts,
                        ""
                    )
                )
        );

        if (!ok) {
            if (data.length != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert ERC1155BatchTransferGenericFailure(
                    token,
                    from,
                    to,
                    tokenIds,
                    amounts
                );
            }
        }

        _assetContractIsDeployed(token, data.length);
    }

    /// @dev Internal function to trigger a call to a proxy contract.
    /// @param proxyOwner The original owner of the proxy in question.
    /// Note that this owner may have been modified since the proxy was originally deployed.
    /// @param callData The calldata to supply when calling the proxy.
    function _callProxy(
        address proxyOwner,
        bytes memory callData
    ) internal returns (bool ok, bytes memory data) {
        // Retrieve the user proxy from the registry.
        address proxy = _LEGACY_PROXY_REGISTRY.proxies(proxyOwner);

        // Assert that the user proxy has the correct implementation.
        if (ProxyInterface(proxy).implementation() != _REQUIRED_PROXY_IMPLEMENTATION) {
            revert InvalidUserProxyImplementation();
        }

        // perform the call to the proxy.
        (ok, data) = proxy.call(callData);
    }

    /// @dev Internal function to transfer Ether to a given recipient and to emit an OrderMatched event.
    /// @param orderHash The order hash.
    /// @param amount The amount of Ether to transfer.
    /// @param parameters The parameters of the order.
    function _transferETHAndFinalize(
        bytes32 orderHash,
        uint256 amount,
        BasicOrderParameters memory parameters
    ) internal {
        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length;) {
            // Retrieve the additional recipient.
            AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i];
            
            // Transfer Ether to the additional recipient.
            _transferEth(
                additionalRecipient.account,
                additionalRecipient.amount
            );

            // Reduce ether value available.
            etherRemaining -= additionalRecipient.amount;

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Transfer Ether to the offerer.
        _transferEth(parameters.offerer, amount);

        // If any Ether remains after transfers, return it to the caller.
        if (etherRemaining > amount) {
            // Skip underflow check as etherRemaining > amount.
            unchecked {
                // Transfer remaining Ether to the caller.
                _transferEth(payable(msg.sender), etherRemaining - amount);
            }
        }

        // Emit an OrderFulfilled event and clear reentrancy guard.
        _emitOrderFulfilledEventAndClearReentrancyGuard(
            orderHash,
            parameters.offerer,
            parameters.facilitator
        );
    }

    /// @dev Internal function to transfer ERC20 tokens to a given recipient and to emit an OrderMatched event.
    /// @param from The originator of the ERC20 token transfer.
    /// @param to The recipient of the ERC20 token transfer.
    /// @param orderHash The order hash.
    /// @param erc20Token The ERC20 token to transfer.
    /// @param amount The amount of ERC20 tokens to transfer.
    /// @param parameters The parameters of the order.
    function _transferERC20AndFinalize(
        address from,
        address to,
        bytes32 orderHash,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters memory parameters
    ) internal {
        // Place proxy owner on the stack (or null address if not using proxy).
        address proxyOwner = parameters.useFulfillerProxy ? from : address(0);

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each additional recipient.
            for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
                // Retrieve the additional recipient.
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i];
                
                // Transfer ERC20 tokens to additional recipient given approval.
                _transferERC20(
                    erc20Token,
                    from,
                    additionalRecipient.account,
                    additionalRecipient.amount,
                    proxyOwner
                );
            }
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(
            erc20Token,
            from,
            to,
            amount,
            proxyOwner
        );

        // Emit an OrderFulfilled event and clear reentrancy guard.
        _emitOrderFulfilledEventAndClearReentrancyGuard(
            orderHash,
            from,
            parameters.facilitator
        );
    }

    /// @dev Internal function to ensure that the sentinel value for the reentrancy guard is not currently set and, if not, to set the sentinel value for the reentrancy guard.
    function _setReentrancyGuard() internal {
        // Ensure that the reentrancy guard is not already set.
        _assertNonReentrant();

        // Set the reentrancy guard.
        _reentrancyGuard = _ENTERED;
    }

    /// @dev Internal function to emit an OrderFulfilled event and to clear the reentrancy guard.
    /// @param orderHash The order hash.
    /// @param offerer The offerer for the order.
    /// @param facilitator The facilitator for the order.
    function _emitOrderFulfilledEventAndClearReentrancyGuard(
        bytes32 orderHash,
        address offerer,
        address facilitator
    ) internal {
        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(orderHash, offerer, facilitator);

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /// @dev Internal view function to ensure that the sentinel value for the reentrancy guard is not currently set.
    function _assertNonReentrant() internal view {
        // Ensure that the reentrancy guard is not currently set.
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
    }

    function _getOrderStatusAndVerify(
        bytes32 orderHash,
        address offerer,
        bytes memory signature,
        bool onlyAllowUnused
    ) internal view returns (OrderStatus memory) {
        // Retrieve the order status for the given order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure that the order has not been cancelled.
        if (orderStatus.isCancelled) {
            revert OrderIsCancelled(orderHash);
        }

        // The order must be either entirely unused, or...
        if (
            orderStatus.numerator != 0 &&
            (   // partially unused and able to support partial fills.
                onlyAllowUnused ||
                orderStatus.numerator >= orderStatus.denominator
            )
        ) {
            // A partially filled order indicates no support for partial fills.
            if (orderStatus.numerator < orderStatus.denominator) {
                revert OrderNotUnused(orderHash);
            }

            // Otherwise, the order is fully filled.
            revert OrderUsed(orderHash);
        }

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                offerer, orderHash, signature
            );
        }

        // Return the order status.
        return orderStatus;
    }

    function _assertValidTokenTransfer(
        bool ok,
        uint256 dataLength,
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        if (!ok) {
            if (dataLength != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert TokenTransferGenericFailure(token, from, to, tokenId, amount);
            }
        }

        _assetContractIsDeployed(token, dataLength);
    }

    function _assetContractIsDeployed(
        address account,
        uint256 dataLength
    ) internal view {
        if (dataLength == 0) {
            uint256 size;
            assembly {
                size := extcodesize(account)
            }
            if (size == 0) {
                revert NoContract(account);
            }
        }
    }

    function _adjustOrderPrice(
        Order memory order
    ) internal view returns (Order memory adjustedOrder) {
        // Skip checks: for loops indexed at zero and durations are validated.
        unchecked {
            uint256 duration = order.parameters.endTime - order.parameters.startTime;
            uint256 elapsed = block.timestamp - order.parameters.startTime;
            uint256 remaining = duration - elapsed;

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
                // Adjust offer amounts based on current time (round down).
                order.parameters.offer[i].endAmount = _locateCurrentPrice(
                    order.parameters.offer[i].startAmount,
                    order.parameters.offer[i].endAmount,
                    elapsed,
                    remaining,
                    duration,
                    false // round down
                );
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < order.parameters.consideration.length; ++i) {
                // Adjust consideration aniybts based on current time (round up).
                order.parameters.consideration[i].endAmount = _locateCurrentPrice(
                    order.parameters.consideration[i].startAmount,
                    order.parameters.consideration[i].endAmount,
                    elapsed,
                    remaining,
                    duration,
                    true // round up
                );
            }

            // Return the modified order.
            return order;
        }
    }

    function _ensureValidTime(
        uint256 startTime,
        uint256 endTime
    ) internal view {
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert InvalidTime();
        }
    }

    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
        if (offerer == msg.sender) {
            return;
        }

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), orderHash)
        );

        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signature.length == 65) {
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
        } else if (signature.length == 64) {
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
                s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                v := add(shr(255, vs), 27)
            }
        } else {
            revert BadSignatureLength(signature.length);
        }

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert MalleableSignatureS(uint256(s));
        }
        if (v != 27 && v != 28) {
            revert BadSignatureV(v);
        }

        address signer = ecrecover(digest, v, r, s);

        if (signer == address(0)) {
            revert InvalidSignature();
        } else if (signer != offerer) {
            (bool ok, bytes memory data) = offerer.staticcall(
                abi.encodeWithSelector(
                    EIP1271Interface.isValidSignature.selector,
                    digest,
                    signature
                )
            );

            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert BadContractSignature();
                }
            }

            if (
                data.length != 32 ||
                abi.decode(data, (bytes4)) != EIP1271Interface.isValidSignature.selector
            ) {
                revert BadSignature();
            }
        }
    }

    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _hashOfferedAsset(
        OfferedAsset memory offeredAsset
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _OFFERED_ASSET_TYPEHASH,
                offeredAsset.assetType,
                offeredAsset.token,
                offeredAsset.identifierOrCriteria,
                offeredAsset.startAmount,
                offeredAsset.endAmount
            )
        );
    }

    function _hashReceivedAsset(
        ReceivedAsset memory receivedAsset
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _RECEIVED_ASSET_TYPEHASH,
                receivedAsset.assetType,
                receivedAsset.token,
                receivedAsset.identifierOrCriteria,
                receivedAsset.startAmount,
                receivedAsset.endAmount,
                receivedAsset.account
            )
        );
    }

    function _getNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        return _getOrderHash(
            orderParameters,
            _facilitatorNonces[orderParameters.offerer][orderParameters.facilitator]
        );
    }

    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) internal view returns (bytes32) {
        uint256 offerLength = orderParameters.offer.length;
        uint256 considerationLength = orderParameters.consideration.length;
        bytes32[] memory offerHashes = new bytes32[](offerLength);
        bytes32[] memory considerationHashes = new bytes32[](considerationLength);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each offer on the order.
            for (uint256 i = 0; i < offerLength; ++i) {
                offerHashes[i] = _hashOfferedAsset(orderParameters.offer[i]);
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < considerationLength; ++i) {
                considerationHashes[i] = _hashReceivedAsset(orderParameters.consideration[i]);
            }
        }

        return keccak256(
            abi.encode(
                _ORDER_HASH,
                orderParameters.offerer,
                orderParameters.facilitator,
                keccak256(abi.encodePacked(offerHashes)),
                keccak256(abi.encodePacked(considerationHashes)),
                orderParameters.orderType,
                orderParameters.startTime,
                orderParameters.endTime,
                orderParameters.salt,
                nonce
            )
        );
    }

    function _adjustOrderTypeAndCheckSubmitter(
        OrderType orderType,
        address offerer,
        address facilitator
    ) internal view returns (bool useOffererProxy) {
        uint256 orderTypeAsUint256 = uint256(orderType);

        useOffererProxy = orderTypeAsUint256 > 3;

        if (
            orderTypeAsUint256 > (useOffererProxy ? 5 : 1) &&
            msg.sender != facilitator &&
            msg.sender != offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }
    }

    function _hashBatchableAssetIdentifier(
        address token,
        address from,
        address to,
        bool useProxy
    ) internal pure returns (bytes32) {
        // Note: this could use a variant of efficientHash as it's < 64 bytes
        return keccak256(abi.encode(token, from, to, useProxy));
    }

    function _locateCurrentPrice(
        uint256 startAmount,
        uint256 endAmount,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration,
        bool roundUp
    ) internal pure returns (uint256) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            uint256 durationLessOne = 0;
            if (roundUp) {
                // Skip underflow check: duration cannot be zero.
                unchecked {
                    durationLessOne = duration - 1;
                }
            }

            uint256 totalBeforeDivision = (
                (startAmount * remaining) + (endAmount * elapsed) + durationLessOne
            );

            uint256 newAmount;
            assembly {
                newAmount := div(totalBeforeDivision, duration)
            }
            return newAmount;
        }

        // Return end amount — from here, endAmount is used in place of amount.
        return endAmount;
    }

    function _ensurePartialFillsEnabled(
        uint120 numerator,
        uint120 denominator,
        OrderType orderType
    ) internal pure {
        if (
            numerator < denominator &&
            uint256(orderType) % 2 == 0
        ) {
            revert PartialFillsNotEnabledForOrder();
        }
    }

    function _applyCriteriaResolvers(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (Order memory initialOrder) {
        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each criteria resolver.
            for (uint256 i = 0; i < criteriaResolvers.length; ++i) {
                // Retrieve the criteria resolver.
                CriteriaResolver memory criteriaResolver = criteriaResolvers[i];

                uint256 orderIndex = criteriaResolver.orderIndex;

                if (orderIndex >= orders.length) {
                    revert OrderCriteriaResolverOutOfRange();
                }

                uint256 componentIndex = criteriaResolver.index;

                if (criteriaResolver.side == Side.OFFER) {
                    if (componentIndex >= orders[orderIndex].parameters.offer.length) {
                        revert OfferCriteriaResolverOutOfRange();
                    }

                    OfferedAsset memory offer = orders[orderIndex].parameters.offer[componentIndex];
                    AssetType assetType = offer.assetType;
                    if (
                        assetType != AssetType.ERC721_WITH_CRITERIA &&
                        assetType != AssetType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForOfferedAsset();
                    }

                    // empty criteria signifies a collection-wide offer (sell any asset)
                    if (offer.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            offer.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.offer[componentIndex].assetType = (
                        assetType == AssetType.ERC721_WITH_CRITERIA
                            ? AssetType.ERC721
                            : AssetType.ERC1155
                    );

                    orders[orderIndex].parameters.offer[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                } else {
                    if (componentIndex >= orders[orderIndex].parameters.consideration.length) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    ReceivedAsset memory consideration = orders[orderIndex].parameters.consideration[componentIndex];
                    AssetType assetType = consideration.assetType;
                    if (
                        assetType != AssetType.ERC721_WITH_CRITERIA &&
                        assetType != AssetType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForConsideredAsset();
                    }

                    // empty criteria signifies a collection-wide consideration (buy any asset)
                    if (consideration.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            consideration.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.consideration[componentIndex].assetType = (
                        assetType == AssetType.ERC721_WITH_CRITERIA
                            ? AssetType.ERC721
                            : AssetType.ERC1155
                    );

                    orders[orderIndex].parameters.consideration[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                }
            }

            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    if (uint256(order.parameters.consideration[j].assetType) > 3) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    if (uint256(order.parameters.offer[j].assetType) > 3) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }

            return orders[0];
        }
    }

    function _compressExecutions(
        Execution[] memory executions
    ) internal pure returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            uint256 totalExecutions = executions.length;

            if (totalExecutions < 2) {
                return (executions, new BatchExecution[](0));
            }

            uint256 total1155Executions = 0;
            uint256[] memory indexBy1155 = new uint256[](totalExecutions);

            // Iterate over each execution.
            for (uint256 i = 0; i < executions.length; ++i) {
                if (executions[i].asset.assetType == AssetType.ERC1155) {
                    indexBy1155[total1155Executions] = i;
                    ++total1155Executions;
                }
            }

            if (total1155Executions < 2) {
                return (executions, new BatchExecution[](0));
            }

            Batch[] memory batches = new Batch[](total1155Executions);

            uint256 initialExecutionIndex = indexBy1155[0];
            Execution memory initialExecution = executions[initialExecutionIndex];
            ReceivedAsset memory initialAsset = initialExecution.asset;
            bytes32 hash = _hashBatchableAssetIdentifier(
                initialAsset.token,
                initialExecution.offerer,
                initialAsset.account,
                initialExecution.useProxy
            );

            uint256[] memory executionIndices = new uint256[](1);
            executionIndices[0] = initialExecutionIndex;

            batches[0].hash = hash;
            batches[0].executionIndices = executionIndices;

            uint256 uniqueHashes = 1;

            for (uint256 i = 1; i < total1155Executions; ++i) {
                uint256 executionIndex = indexBy1155[i];
                Execution memory execution = executions[executionIndex];
                ReceivedAsset memory asset = execution.asset;

                hash = _hashBatchableAssetIdentifier(
                    asset.token,
                    execution.offerer,
                    asset.account,
                    execution.useProxy
                );

                bool hasUniqueHash = true;
                for (uint256 j = 0; j < uniqueHashes; ++j) {
                    if (hash == batches[j].hash) {
                        uint256[] memory existingExecutionIndices = batches[j].executionIndices;

                        uint256[] memory newExecutionIndices = new uint256[](existingExecutionIndices.length + 1);
                        for (uint256 k = 0; k < existingExecutionIndices.length; ++k) {
                            newExecutionIndices[k] = existingExecutionIndices[k];
                        }
                        newExecutionIndices[existingExecutionIndices.length] = indexBy1155[j];

                        batches[j].executionIndices = newExecutionIndices;

                        hasUniqueHash = false;
                    }
                }

                if (hasUniqueHash) {
                    executionIndices = new uint256[](1);
                    executionIndices[0] = executionIndex;

                    batches[uniqueHashes++].hash = hash;
                    batches[uniqueHashes].executionIndices = executionIndices;
                }
            }

            if (uniqueHashes == total1155Executions) {
                return (executions, new BatchExecution[](0));
            }

            // add one to the batch ID if it's used in a batch
            uint256[] memory usedInBatch = new uint256[](totalExecutions);

            uint256[] memory totals = new uint256[](2);
            for (uint256 i = 0; i < uniqueHashes; ++i) {
                uint256[] memory indices = batches[i].executionIndices;
                uint256 indicesLength = indices.length;
                if (indicesLength > 1) {
                    ++totals[1];
                    totals[0] += indicesLength;
                    for (uint256 j = 0; j < indicesLength; ++j) {
                        usedInBatch[indices[j]] = i + 1;
                    }
                }
            }

            return _splitExecution(
                executions,
                batches,
                usedInBatch,
                totals[0],
                totals[1]
            );
        }
    }

    function _splitExecution(
        Execution[] memory executions,
        Batch[] memory batches,
        uint256[] memory usedInBatch,
        uint256 totalUsedInBatch,
        uint256 totalBatches
    ) internal pure returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Skip overflow checks as all incremented values start at low amounts.
        unchecked {
            uint256 totalExecutions = executions.length;

            Execution[] memory executeWithoutBatch = new Execution[](
                totalExecutions - totalUsedInBatch
            );
            BatchExecution[] memory executeWithBatch = new BatchExecution[](
                totalBatches
            );

            uint256 lastNoBatchIndex = 0;
            uint256[] memory batchElementCounters = new uint256[](totalBatches);

            // Iterate over each execution.
            for (uint256 i = 0; i < totalExecutions; ++i) {
                uint256 isUsedInBatch = usedInBatch[i];
                if (isUsedInBatch == 0) {
                    executeWithoutBatch[lastNoBatchIndex++] = executions[i];
                } else {
                    uint256 batchUsed = isUsedInBatch - 1;

                    Execution memory execution = executions[i];

                    if (executeWithBatch[batchUsed].token == address(0)) {
                        uint256 tokenElements = batches[batchUsed].executionIndices.length;
                        executeWithBatch[batchUsed] = BatchExecution({
                            token: execution.asset.token,
                            from: execution.offerer,
                            to: execution.asset.account,
                            tokenIds: new uint256[](tokenElements),
                            amounts: new uint256[](tokenElements),
                            useProxy: execution.useProxy
                        });
                    }

                    uint256 counter = batchElementCounters[batchUsed]++;

                    executeWithBatch[batchUsed].tokenIds[counter] = execution.asset.identifierOrCriteria;
                    executeWithBatch[batchUsed].amounts[counter] = execution.asset.endAmount;
                }
            }

            return (executeWithoutBatch, executeWithBatch);
        }
    }

    function _getOrderParametersByFulfillmentIndex(
        Order[] memory orders,
        uint256 index
    ) internal pure returns (OrderParameters memory) {
        if (index >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

        return orders[index].parameters;
    }

    function _getOrderOfferComponentByAssetIndex(
        OrderParameters memory order,
        uint256 index
    ) internal pure returns (OfferedAsset memory) {
        if (index >= order.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }
        return order.offer[index];
    }

    function _getOrderConsiderationComponentByAssetIndex(
        OrderParameters memory order,
        uint256 index
    ) internal pure returns (ReceivedAsset memory) {
        if (index >= order.consideration.length) {
            revert FulfilledOrderConsiderationIndexOutOfRange();
        }
        return order.consideration[index];
    }

    function _applyFulfillment(
        Order[] memory orders,
        Fulfillment memory fulfillment,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        Execution memory execution
    ) {
        if (
            fulfillment.offerComponents.length == 0 ||
            fulfillment.considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        uint256 currentOrderIndex = fulfillment.offerComponents[0].orderIndex;

        OrderParameters memory orderWithInitialOffer = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        bool useProxy = useOffererProxyPerOrder[currentOrderIndex];

        uint256 currentAssetIndex = fulfillment.offerComponents[0].assetIndex;

        OfferedAsset memory offeredAsset = _getOrderOfferComponentByAssetIndex(
            orderWithInitialOffer,
            currentAssetIndex
        );

        orders[currentOrderIndex].parameters.offer[currentAssetIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.offerComponents.length;) {
            FulfillmentComponent memory offerComponent = fulfillment.offerComponents[i];
            currentOrderIndex = offerComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentAssetIndex = offerComponent.assetIndex;

            OfferedAsset memory additionalOfferedAsset = _getOrderOfferComponentByAssetIndex(
                subsequentOrder,
                currentAssetIndex
            );

            if (
                orderWithInitialOffer.offerer != subsequentOrder.offerer ||
                offeredAsset.assetType != additionalOfferedAsset.assetType ||
                offeredAsset.token != additionalOfferedAsset.token ||
                offeredAsset.identifierOrCriteria != additionalOfferedAsset.identifierOrCriteria ||
                useProxy != useOffererProxyPerOrder[currentOrderIndex]
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            offeredAsset.endAmount += additionalOfferedAsset.endAmount;
            orders[currentOrderIndex].parameters.offer[currentAssetIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        currentOrderIndex = fulfillment.considerationComponents[0].orderIndex;

        OrderParameters memory orderWithInitialConsideration = _getOrderParametersByFulfillmentIndex(
            orders,
            currentOrderIndex
        );

        currentAssetIndex = fulfillment.considerationComponents[0].assetIndex;

        ReceivedAsset memory requiredConsideration = _getOrderConsiderationComponentByAssetIndex(
            orderWithInitialConsideration,
            currentAssetIndex
        );

        orders[currentOrderIndex].parameters.consideration[currentAssetIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.considerationComponents.length;) {
            FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[i];
            currentOrderIndex = considerationComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentAssetIndex = considerationComponent.assetIndex;

            ReceivedAsset memory additionalRequiredConsideration = _getOrderConsiderationComponentByAssetIndex(
                subsequentOrder,
                currentAssetIndex
            );

            if (
                requiredConsideration.account != additionalRequiredConsideration.account ||
                requiredConsideration.assetType != additionalRequiredConsideration.assetType ||
                requiredConsideration.token != additionalRequiredConsideration.token ||
                requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;
            orders[currentOrderIndex].parameters.consideration[currentAssetIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        if (requiredConsideration.endAmount > offeredAsset.endAmount) {
            FulfillmentComponent memory targetComponent = fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.consideration[targetComponent.assetIndex].endAmount = requiredConsideration.endAmount - offeredAsset.endAmount;
            requiredConsideration.endAmount = offeredAsset.endAmount;
        } else {
            FulfillmentComponent memory targetComponent = fulfillment.offerComponents[fulfillment.offerComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.offer[targetComponent.assetIndex].endAmount = offeredAsset.endAmount - requiredConsideration.endAmount;
        }

        // Return the final execution that will be triggered for relevant items.
        return Execution(
            requiredConsideration,
            orderWithInitialOffer.offerer,
            useProxy
        );
    }

    function _getFraction(
        uint120 numerator,
        uint120 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * uint256(numerator);

        // Divide (Note: denominator must not be zero!) and check for remainder.
        bool inexact;
        assembly {
            newValue := div(valueTimesNumerator, denominator)
            inexact := iszero(iszero(mulmod(value, numerator, denominator)))
        }

        // Ensure that division gave a final result with no remainder.
        if (inexact) {
            revert InexactFraction();
        }
    }

    function _verifyProof(
        uint256 leaf,
        uint256 root,
        bytes32[] memory proof
    ) internal pure {
        // Convert the supplied leaf element from uint256 to bytes32.
        bytes32 computedHash = bytes32(leaf);

        // Skip overflow check as for loop is indexed starting at zero.
        unchecked {
            // Iterate over each proof element.
            for (uint256 i = 0; i < proof.length; ++i) {
                // Retrieve the proof element.
                bytes32 proofElement = proof[i];

                if (computedHash <= proofElement) {
                    // Hash(current computed hash + current element of proof)
                    computedHash = _efficientHash(computedHash, proofElement);
                } else {
                    // Hash(current element of proof + current computed hash)
                    computedHash = _efficientHash(proofElement, computedHash);
                }
            }
        }

        // Ensure that the final derived hash matches the expected root.
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
        }
    }

    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a) // Place element a in first word of scratch space.
            mstore(0x20, b) // Place element b in second word of scratch space.
            value := keccak256(0x00, 0x40) // Hash scratch space region.
        }
    }
}
