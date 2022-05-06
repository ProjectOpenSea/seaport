// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    ConsiderationInterface
} from "../interfaces/ConsiderationInterface.sol";

// prettier-ignore
import {
    OrderType,
    ItemType,
    BasicOrderRouteType
} from "../lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    BatchExecution
} from "../lib/ConsiderationStructs.sol";

// prettier-ignore
import {
    ReferenceConsiderationInternal
} from "./lib/ReferenceConsiderationInternal.sol";

import { OrderToExecute } from "./lib/ReferenceConsiderationStructs.sol";

/**
 * @title ReferenceConsideration
 * @author 0age
 * @custom:coauthor d1ll0n
 * @custom:coauthor transmissions11
 * @custom:version rc-1
 * @notice Consideration is a generalized ETH/ERC20/ERC721/ERC1155 marketplace.
 *         It minimizes external calls to the greatest extent possible and
 *         provides lightweight methods for common routes as well as more
 *         flexible methods for composing advanced orders or groups of orders.
 *         Each order contains an arbitrary number of items that may be spent
 *         (the "offer") along with an arbitrary number of items that must be
 *         received back by the indicated recipients (the "consideration").
 */
contract ReferenceConsideration is
    ConsiderationInterface,
    ReferenceConsiderationInternal
{
    /**
     * @notice Derive and set hashes, reference chainId, and associated domain
     *         separator during deployment.
     *
     * @param conduitController           A contract that deploys conduits, or
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC20+721+1155
     *                                    tokens.
     */
    constructor(address conduitController)
        ReferenceConsiderationInternal(conduitController)
    {}

    /**
     * @notice Fulfill an order offering an ERC20, ERC721, or ERC1155 item by
     *         supplying Ether (or other native tokens), ERC20 tokens, an ERC721
     *         item, or an ERC1155 item as consideration. Six permutations are
     *         supported: Native token to ERC721, Native token to ERC1155, ERC20
     *         to ERC721, ERC20 to ERC1155, ERC721 to ERC20, and ERC1155 to
     *         ERC20 (with native tokens supplied as msg.value). For an order to
     *         be eligible for fulfillment via this method, it must contain a
     *         single offer item (though that item may have a greater amount if
     *         the item is not an ERC721). An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive native
     *         tokens or ERC20 items from the fulfiller as consideration. Refer
     *         to the documentation for a more comprehensive summary of how to
     *         utilize with this method and what orders are compatible with it.
     *
     * @param parameters Additional information on the fulfilled order. Note
     *                   that the offerer and the fulfiller must first approve
     *                   this contract (or their chosen conduit if indicated)
     *                   before any tokens can be transferred. Also note that
     *                   contract recipients of ERC1155 consideration items must
     *                   implement `onERC1155Received` in order to receive those
     *                   items.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillBasicOrder(BasicOrderParameters calldata parameters)
        external
        payable
        override
        notEntered
        nonReentrant
        returns (bool)
    {
        // Declare enums for order type & route to extract from basicOrderType.
        BasicOrderRouteType route = BasicOrderRouteType(
            uint8(parameters.basicOrderType) / 4
        );

        OrderType orderType = OrderType(uint8(parameters.basicOrderType) % 4);

        // Declare additional recipient item type to derive from the route type.
        ItemType additionalRecipientsItemType = ItemType(
            uint8(route) > 1 ? 1 : 0
        );

        {
            // Declare temporary variable for enforcing payable status.
            bool correctPayableStatus = (msg.value != 0 &&
                additionalRecipientsItemType == ItemType.NATIVE) ||
                (msg.value == 0 &&
                    additionalRecipientsItemType == ItemType.ERC20);

            // Revert if msg.value has not been supplied as part of payable
            // routes or has been supplied as part of non-payable routes.
            if (!correctPayableStatus) {
                revert InvalidMsgValue(msg.value);
            }
        }

        // Declare more arguments that will be derived from route and calldata.
        address additionalRecipientsToken = uint8(route) > 3
            ? parameters.offerToken
            : parameters.considerationToken;

        ItemType receivedItemType = uint8(route) > 2
            ? ItemType(uint8(route) - 2)
            : (
                route == BasicOrderRouteType.ERC20_TO_ERC721
                    ? ItemType.ERC20
                    : ItemType.NATIVE
            );

        ItemType offeredItemType = uint8(route) > 3
            ? ItemType.ERC20
            : (
                uint8(route) > 1
                    ? ItemType(uint8(route))
                    : ItemType(uint8(route) + 2)
            );

        // Derive & validate order using parameters and update order status.
        _prepareBasicFulfillmentFromCalldata(
            parameters,
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Read offerer from calldata and place on the stack.
        address payable offerer = parameters.offerer;

        // Declare conduitKey argument used by transfer functions.
        bytes32 conduitKey = uint8(route) > 3
            ? parameters.fulfillerConduitKey
            : parameters.offererConduitKey;

        // Transfer tokens based on the route.
        if (route == BasicOrderRouteType.ETH_TO_ERC721) {
            // Transfer ERC721 to caller using offerer's conduit if applicable.
            _transferERC721(
                parameters.offerToken,
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey
            );

            // Transfer native to recipients, return excess to caller & wrap up.
            _transferEthAndFinalize(parameters.considerationAmount, parameters);
        } else if (route == BasicOrderRouteType.ETH_TO_ERC1155) {
            // Transfer ERC1155 to caller using offerer's conduit if applicable.
            _transferERC1155(
                parameters.offerToken,
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey
            );

            // Transfer native to recipients, return excess to caller & wrap up.
            _transferEthAndFinalize(parameters.considerationAmount, parameters);
        } else if (route == BasicOrderRouteType.ERC20_TO_ERC721) {
            // Transfer ERC721 to caller using offerer's conduit if applicable.
            _transferERC721(
                parameters.offerToken,
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                offerer,
                parameters.considerationToken,
                parameters.considerationAmount,
                parameters,
                false // Send full amount indicated by all consideration items.
            );
        } else if (route == BasicOrderRouteType.ERC20_TO_ERC1155) {
            // Transfer ERC1155 to caller using offerer's conduit if applicable.
            _transferERC1155(
                parameters.offerToken,
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                offerer,
                parameters.considerationToken,
                parameters.considerationAmount,
                parameters,
                false // Send full amount indicated by all consideration items.
            );
        } else if (route == BasicOrderRouteType.ERC721_TO_ERC20) {
            // Transfer ERC721 to offerer using caller's conduit if applicable.
            _transferERC721(
                parameters.considerationToken,
                msg.sender,
                offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                offerer,
                msg.sender,
                parameters.offerToken,
                parameters.offerAmount,
                parameters,
                true // Reduce amount sent to fulfiller by additional amounts.
            );
        } else {
            // route == BasicOrderRouteType.ERC1155_TO_ERC20

            // Transfer ERC1155 to offerer using caller's conduit if applicable.
            _transferERC1155(
                parameters.considerationToken,
                msg.sender,
                offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                offerer,
                msg.sender,
                parameters.offerToken,
                parameters.offerAmount,
                parameters,
                true // Reduce amount sent to fulfiller by additional amounts.
            );
        }

        return true;
    }

    /**
     * @notice Fulfill an order with an arbitrary number of items for offer and
     *         consideration. Note that this function does not support
     *         criteria-based orders or partial filling of orders (though
     *         filling the remainder of a partially-filled order is supported).
     *
     * @param order               The order to fulfill. Note that both the
     *                            offerer and the fulfiller must first approve
     *                            this contract (or the corresponding conduit if
     *                            indicated) to transfer any relevant tokens on
     *                            their behalf and that contracts must implement
     *                            `onERC1155Received` to receive ERC1155 tokens
     *                            as consideration.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration).
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey)
        external
        payable
        override
        notEntered
        nonReentrant
        returns (bool)
    {
        // Convert order to "advanced" order, then validate and fulfill it.
        // prettier-ignore
        return _validateAndFulfillAdvancedOrder(
            _convertOrderToAdvanced(order),
            new CriteriaResolver[](0), // No criteria resolvers supplied.
            fulfillerConduitKey
        );

        // TODO: Make these work with Orders To Execute
    }

    /**
     * @notice Fill an order, fully or partially, with an arbitrary number of
     *         items for offer and consideration alongside criteria resolvers
     *         containing specific token identifiers and associated proofs.
     *
     * @param advancedOrder       The order to fulfill along with the fraction
     *                            of the order to attempt to fill. Note that
     *                            both the offerer and the fulfiller must first
     *                            approve this contract (or their proxy if
     *                            indicated by the order) to transfer any
     *                            relevant tokens on their behalf and that
     *                            contracts must implement `onERC1155Received`
     *                            to receive ERC1155 tokens as consideration.
     *                            Also note that all offer and consideration
     *                            components must have no remainder after
     *                            multiplication of the respective amount with
     *                            the supplied fraction for the partial fill to
     *                            be considered valid.
     * @param criteriaResolvers   An array where each element contains a
     *                            reference to a specific offer or
     *                            consideration, a token identifier, and a proof
     *                            that the supplied token identifier is
     *                            contained in the merkle root held by the item
     *                            in question's criteria element. Note that an
     *                            empty criteria indicates that any
     *                            (transferrable) token identifier on the token
     *                            in question is valid and that no associated
     *                            proof needs to be supplied.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration).
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey
    ) external payable override notEntered nonReentrant returns (bool) {
        // Validate and fulfill the order.
        return
            _validateAndFulfillAdvancedOrder(
                advancedOrder,
                criteriaResolvers,
                fulfillerConduitKey
            );

        // TODO: Make these work with Orders To Execute
    }

    /**
     * @notice Attempt to fill a group of orders, each with an arbitrary number
     *         of items for offer and consideration. Any order that is not
     *         currently active, has already been fully filled, or has been
     *         cancelled will be omitted. Remaining offer and consideration
     *         items will then be aggregated where possible as indicated by the
     *         supplied offer and consideration component arrays and aggregated
     *         items will be transferred to the fulfiller or to each intended
     *         recipient, respectively. Note that a failing item transfer or an
     *         issue with order formatting will cause the entire batch to fail.
     *         Note that this function does not support criteria-based orders or
     *         partial filling of orders (though filling the remainder of a
     *         partially-filled order is supported).
     *
     * @param orders                    The orders to fulfill. Note that both
     *                                  the offerer and the fulfiller must first
     *                                  approve this contract (or the
     *                                  corresponding conduit if indicated) to
     *                                  transfer any relevant tokens on their
     *                                  behalf and that contracts must implement
     *                                  `onERC1155Received` to receive ERC1155
     *                                  tokens as consideration.
     * @param offerFulfillments         An array of FulfillmentComponent arrays
     *                                  indicating which offer items to attempt
     *                                  to aggregate when preparing executions.
     * @param considerationFulfillments An array of FulfillmentComponent arrays
     *                                  indicating which consideration items to
     *                                  attempt to aggregate when preparing
     *                                  executions.
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used (and
     *                                  direct approvals set on Consideration).
     * @param maximumFulfilled          The maximum number of orders to fulfill.
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
    function fulfillAvailableOrders(
        Order[] calldata orders,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        uint256 maximumFulfilled
    )
        external
        payable
        override
        notEntered
        nonReentrant
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Convert orders to "advanced" orders.
        AdvancedOrder[] memory advancedOrders = _convertOrdersToAdvanced(
            orders
        );
        // Convert Advanced Orders to Orders To Execute
        OrderToExecute[]
            memory ordersToExecute = _convertAdvancedtoOrdersToExecute(
                advancedOrders
            );

        // Fulfill all available orders.
        return
            _fulfillAvailableAdvancedOrders(
                advancedOrders,
                ordersToExecute,
                new CriteriaResolver[](0), // No criteria resolvers supplied.
                offerFulfillments,
                considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
            );
    }

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
     * @param fulfillerConduitKey       A bytes32 value indicating what conduit,
     *                                  if any, to source the fulfiller's token
     *                                  approvals from. The zero hash signifies
     *                                  that no conduit should be used (and
     *                                  direct approvals set on Consideration).
     * @param maximumFulfilled          The maximum number of orders to fulfill.
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
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] calldata criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        uint256 maximumFulfilled
    )
        external
        payable
        override
        notEntered
        nonReentrant
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Convert Advanced Orders to Orders to Execute
        OrderToExecute[]
            memory ordersToExecute = _convertAdvancedtoOrdersToExecute(
                advancedOrders
            );

        // Fulfill all available orders.
        return
            _fulfillAvailableAdvancedOrders(
                advancedOrders,
                ordersToExecute,
                criteriaResolvers,
                offerFulfillments,
                considerationFulfillments,
                fulfillerConduitKey,
                maximumFulfilled
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
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        override
        notEntered
        nonReentrant
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Convert orders to "advanced" orders.
        AdvancedOrder[] memory advancedOrders = _convertOrdersToAdvanced(
            orders
        );

        // Convert advanced orders to orders to execute.
        OrderToExecute[]
            memory ordersToExecute = _convertAdvancedtoOrdersToExecute(
                advancedOrders
            );

        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            ordersToExecute,
            new CriteriaResolver[](0), // No criteria resolvers supplied.
            true, // Signifies that invalid orders should revert.
            advancedOrders.length
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(ordersToExecute, fulfillments);
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
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    )
        external
        payable
        override
        notEntered
        nonReentrant
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Convert Advanced Orders to Orders to Execute
        OrderToExecute[]
            memory ordersToExecute = _convertAdvancedtoOrdersToExecute(
                advancedOrders
            );

        // Validate orders, apply amounts, & determine if they utilize conduits.
        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            ordersToExecute,
            criteriaResolvers,
            true, // Signifies that invalid orders should revert.
            advancedOrders.length
        );

        // Fulfill the orders using the supplied fulfillments.
        return _fulfillAdvancedOrders(ordersToExecute, fulfillments);
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
    function cancel(OrderComponents[] calldata orders)
        external
        override
        notEntered
        returns (bool)
    {
        address offerer;
        address zone;

        // Read length of the orders array from memory and place on stack.
        uint256 totalOrders = orders.length;

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order.
            OrderComponents calldata order = orders[i];

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
                    order.offer,
                    order.consideration,
                    order.orderType,
                    order.startTime,
                    order.endTime,
                    order.zoneHash,
                    order.salt,
                    order.conduitKey,
                    order.consideration.length
                ),
                order.nonce
            );

            // Update the order status as not valid and cancelled.
            _orderStatus[orderHash].isValidated = false;
            _orderStatus[orderHash].isCancelled = true;

            // Emit an event signifying that the order has been cancelled.
            emit OrderCancelled(orderHash, offerer, zone);
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
    function validate(Order[] calldata orders)
        external
        override
        notEntered
        returns (bool)
    {
        // Declare variables outside of the loop.
        bytes32 orderHash;
        address offerer;

        // Read length of the orders array from memory and place on stack.
        uint256 totalOrders = orders.length;

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order.
            Order calldata order = orders[i];

            // Retrieve the order parameters.
            OrderParameters calldata orderParameters = order.parameters;

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
                _verifySignature(offerer, orderHash, order.signature);

                // Update order status to mark the order as valid.
                _orderStatus[orderHash].isValidated = true;

                // Emit an event signifying the order has been validated.
                emit OrderValidated(orderHash, offerer, orderParameters.zone);
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
    function incrementNonce()
        external
        override
        notEntered
        returns (uint256 newNonce)
    {
        // Increment current nonce for the supplied offerer.
        newNonce = ++_nonces[msg.sender];

        // Emit an event containing the new nonce.
        emit NonceIncremented(newNonce, msg.sender);
    }

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @param order The components of the order.
     *
     * @return The order hash.
     */
    function getOrderHash(OrderComponents memory order)
        external
        view
        override
        returns (bytes32)
    {
        // Derive order hash by supplying order parameters along with the nonce.
        // prettier-ignore
        return _getOrderHash(
            OrderParameters(
                order.offerer,
                order.zone,
                order.offer,
                order.consideration,
                order.orderType,
                order.startTime,
                order.endTime,
                order.zoneHash,
                order.salt,
                order.conduitKey,
                order.consideration.length
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
    function getOrderStatus(bytes32 orderHash)
        external
        view
        override
        returns (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        )
    {
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
     * @notice Retrieve the current nonce for a given offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return The current nonce.
     */
    function getNonce(address offerer)
        external
        view
        override
        returns (uint256)
    {
        // Return the nonce for the supplied offerer.
        return _nonces[offerer];
    }

    /**
     * @notice Retrieve configuration information for this contract.
     *
     * @return version           The contract version.
     * @return domainSeparator   The domain separator for this contract.
     * @return conduitController The conduit Controller set for this contract.
     */
    function information()
        external
        view
        override
        returns (
            string memory version,
            bytes32 domainSeparator,
            address conduitController
        )
    {
        version = _VERSION;
        domainSeparator = _domainSeparator();
        conduitController = address(_CONDUIT_CONTROLLER);
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
}
