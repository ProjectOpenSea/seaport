// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    OrderType,
    ItemType,
    Side
} from "./Enums.sol";

import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferedItem,
    ReceivedItem,
    OrderParameters,
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

import { ProxyInterface } from "./AbridgedProxyInterfaces.sol";

import { EIP1271Interface } from "./EIP1271Interface.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

/// @title ConsiderationInternal contains all internal functions for Consideration.
/// @author 0age
contract ConsiderationInternal is ConsiderationBase {
    /// @dev Derive and set hashes, reference chainId, and associated domain separator during deployment.
    /// @param legacyProxyRegistry A proxy registry that stores per-user proxies that may optionally be used to transfer tokens.
    /// @param requiredProxyImplementation The implementation that this contract will require be set on each per-user proxy.
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationBase(legacyProxyRegistry, requiredProxyImplementation) {}

    /// @dev Internal function to derive and validate an order based on a set of parameters and a primary item for offer and consideration.
    /// @param parameters The parameters of the basic order.
    /// @param offeredItem The primary item being offered.
    /// @param receivedItem The primary item being received as consideration.
    /// @return orderHash The order hash.
    /// @return useOffererProxy A boolean indicating whether to utilize the offerer's proxy.
    function _prepareBasicFulfillment(
        BasicOrderParameters memory parameters,
        OfferedItem memory offeredItem,
        ReceivedItem memory receivedItem
    ) internal returns (bytes32 orderHash, bool useOffererProxy) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Pull frequently used arguments from memory & place them on the stack.
        address payable offerer = parameters.offerer;
        address zone = parameters.zone;
        uint256 startTime = parameters.startTime;
        uint256 endTime = parameters.endTime;

        // Ensure current timestamp falls between order start time and end time.
        _assertValidTime(startTime, endTime);

        // Allocate memory: 1 offer, 1+additionalRecipients consideration items.
        OfferedItem[] memory offer = new OfferedItem[](1);
        ReceivedItem[] memory consideration = new ReceivedItem[](
            1 + parameters.additionalRecipients.length
        );

        // Set primary offer + consideration item as respective first elements.
        offer[0] = offeredItem;
        consideration[0] = receivedItem;

        // Use offered item's info for additional recipients if it is an ERC20.
        if (offeredItem.itemType == ItemType.ERC20) {
            receivedItem.itemType = ItemType.ERC20;
            receivedItem.token = offeredItem.token;
            receivedItem.identifierOrCriteria = 0;
        }

        // Skip overflow checks as for loop is indexed starting at one.
        unchecked {
            // Iterate over each consideration beyond primary one on the order.
            for (uint256 i = 1; i < consideration.length; ++i) {
                // Retrieve additional recipient corresponding to consideration.
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i - 1];

                // Update consideration item w/ info from additional recipient.
                receivedItem.account = additionalRecipient.account;
                receivedItem.startAmount = additionalRecipient.amount;
                receivedItem.endAmount = additionalRecipient.amount;

                // Set new received item as an additional consideration item.
                consideration[i] = receivedItem;
            }
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _getNoncedOrderHash(
            OrderParameters(
                offerer,
                zone,
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
        useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
            parameters.orderType,
            offerer,
            zone
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
        _assertValidTime(order.parameters.startTime, order.parameters.endTime);

        // Ensure that the supplied numerator and denominator are valid.
        if (numerator > denominator || numerator == 0 || denominator == 0) {
            revert BadFraction();
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _getNoncedOrderHash(order.parameters);

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
            order.parameters.orderType,
            order.parameters.offerer,
            order.parameters.zone
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
        _applyCriteriaResolvers(orders, criteriaResolvers);
        order = orders[0];

        // Move the offerer from memory to the stack.
        address offerer = order.parameters.offerer;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each consideration on the order.
        for (uint256 i = 0; i < order.parameters.consideration.length;) {
            // Retrieve the consideration item.
            ReceivedItem memory consideration = order.parameters.consideration[i];

            // Apply order fill fraction to each consideration amount.
            consideration.endAmount = _getFraction(
                fillNumerator,
                fillDenominator,
                consideration.endAmount
            );

            // If consideration expects ETH, reduce ether value available.
            if (consideration.itemType == ItemType.ETH) {
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
            OfferedItem memory offer = order.parameters.offer[i];

            // Apply order fill fraction and set the caller as the receiver.
            ReceivedItem memory item = ReceivedItem(
                offer.itemType,
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
            if (item.itemType == ItemType.ETH) {
                etherRemaining -= item.endAmount;
            }

            // Transfer the item from the offerer to the caller.
            _transfer(
                item,
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
            order.parameters.zone
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
                    orders[i].parameters.zone
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
                ReceivedItem[] memory considerations = orders[i].parameters.consideration;

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
            if (execution.item.itemType == ItemType.ETH) {
                etherRemaining -= execution.item.endAmount;
            }

            // Transfer the item specified by the execution.
            _transfer(
                execution.item,
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
    /// @param item The item to transfer, including the amount and the to address.
    /// @param offerer The account offering the item, i.e. the from address.
    /// @param useProxy A boolean indicating whether to source approvals for the fulfilled token from the offer's proxy.
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        bool useProxy
    ) internal {
        if (item.itemType == ItemType.ETH) {
            // Transfer Ether to the recipient.
            _transferEth(item.account, item.endAmount);
        } else {
            // Place proxy owner on stack (or null address if not using proxy).
            address proxyOwner = useProxy ? offerer : address(0);

            if (item.itemType == ItemType.ERC20) {
                // Transfer ERC20 token from the offerer to the recipient.
                _transferERC20(
                    item.token,
                    offerer,
                    item.account,
                    item.endAmount,
                    proxyOwner
                );
            } else if (item.itemType == ItemType.ERC721) {
                // Transfer ERC721 token from the offerer to the recipient.
                _transferERC721(
                    item.token,
                    offerer,
                    item.account,
                    item.identifierOrCriteria,
                    proxyOwner
                );
            } else {
                // Transfer ERC1155 token from the offerer to the recipient.
                _transferERC1155(
                    item.token,
                    offerer,
                    item.account,
                    item.identifierOrCriteria,
                    item.endAmount,
                    proxyOwner
                );
            }
        }
    }

    /// @dev Internal function to transfer ether to a given recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount to transfer.
    function _transferEth(address payable to, uint256 amount) internal {
        // Attempt to transfer the ether to the recipient.
        (bool ok, bytes memory data) = to.call{value: amount}("");

        // If the call fails...
        if (!ok) {
            // and there's data returned...
            if (data.length != 0) {
                // then bubble up the revert reason.
                assembly {
                    returndatacopy(0, 0, returndatasize()) // Copy returndata to memory.
                    revert(0, returndatasize()) // Revert, supplying returndata.
                }
            } else {
                // Otherwise, revert with a generic error message.
                revert EtherTransferGenericFailure(to, amount);
            }
        }
    }

    /// @dev Internal function to transfer ERC20 tokens from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param token The ERC20 token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount to transfer.
    /// @param proxyOwner An address indicating the owner of the proxy to utilize when performing the transfer, or the null address if no proxy should be utilized.
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Attempt to transfer the ERC20 token via...
        (bool ok, bytes memory data) = (
            // The proxy if a proxy owner is specified...
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
                // otherwise, via the token contract directly.
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

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            ok,
            data.length,
            token,
            from,
            to,
            0,
            amount
        );

        // If data is returned...
        if (data.length >= 32) {
            // and the returned data evaluates to false...
            if (!abi.decode(data, (bool))) {
                // Revert with a "Bad Return Value" error.
                revert BadReturnValueFromERC20OnTransfer(
                    token,
                    from,
                    to,
                    amount
                );
            }
        }
    }

    /// @dev Internal function to transfer an ERC721 token from a given originator to a given recipient. Sufficient approvals must be set, either on the respective proxy or on this contract itself.
    /// @param token The ERC721 token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param identifier The tokenId to transfer.
    /// @param proxyOwner An address indicating the owner of the proxy to utilize when performing the transfer, or the null address if no proxy should be utilized.
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        address proxyOwner
    ) internal {
        // Attempt to transfer the ERC721 token via...
        (bool ok, bytes memory data) = (
            // The proxy if a proxy owner is specified...
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
                // otherwise, via the token contract directly.
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

        // Ensure that the transfer succeeded.
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
    /// @param proxyOwner An address indicating the owner of the proxy to utilize when performing the transfer, or the null address if no proxy should be utilized.
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Attempt to transfer the ERC1155 token via...
        (bool ok, bytes memory data) = (
            // The proxy if a proxy owner is specified...
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
                // otherwise, via the token contract directly.
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

        // Ensure that the transfer succeeded.
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
        // Place elements of the batch execution in memory onto the stack.
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;

        // Retrieve the tokenIds and amounts.
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;

        // Attempt to transfer the ERC1155 token via...
        (bool ok, bytes memory data) = (
            // The proxy if it is specified by the batch execution...
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
                // otherwise, via the token contract directly.
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

        // If the call fails...
        if (!ok) {
            // and there's data returned...
            if (data.length != 0) {
                // then bubble up the revert reason.
                assembly {
                    returndatacopy(0, 0, returndatasize()) // Copy returndata to memory.
                    revert(0, returndatasize()) // Revert, supplying returndata.
                }
            } else {
                // Otherwise, revert with a generic 1155 batch transfer error.
                revert ERC1155BatchTransferGenericFailure(
                    token,
                    from,
                    to,
                    tokenIds,
                    amounts
                );
            }
        }

        // Ensure that a contract is deployed to the token address.
        _assertContractIsDeployed(token, data.length);
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
            parameters.zone
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
            parameters.zone
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
    /// @param zone The zone for the order.
    function _emitOrderFulfilledEventAndClearReentrancyGuard(
        bytes32 orderHash,
        address offerer,
        address zone
    ) internal {
        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(orderHash, offerer, zone);

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /// @dev Internal view function to retrieve the order status and verify it.
    /// @param orderHash The order hash.
    /// @param offerer The offerer for the order.
    /// @param signature A signature from the offerer indicating that the order has been approved.
    /// @param onlyAllowUnused A boolean flag indicating whether partial fills are supported by the calling function.
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

    /// @dev Internal view function to derive the current amount of a given item based on the current price, the starting price, and the ending price. If the start and end prices differ, the current price will be extrapolated on a linear basis.
    /// @param order The original order.
    /// @return adjustedOrder An adjusted order with the current price set.
    function _adjustOrderPrice(
        Order memory order
    ) internal view returns (Order memory adjustedOrder) {
        // Skip checks: for loops indexed at zero and durations are validated.
        unchecked {
            // Derive total order duration and total time elapsed and remaining.
            uint256 duration = order.parameters.endTime - order.parameters.startTime;
            uint256 elapsed = block.timestamp - order.parameters.startTime;
            uint256 remaining = duration - elapsed;

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
                // Adjust offer amounts based on current time (round down).
                order.parameters.offer[i].endAmount = _locateCurrentAmount(
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
                order.parameters.consideration[i].endAmount = _locateCurrentAmount(
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

    /// @dev Internal view function to verify the signature of an order. An ERC-1271 fallback will be attempted should the recovered signature not match the supplied offerer.
    /// Note that only non-malleable 32-byte or 33-byte ECDSA signatures are supported.
    /// @param offerer The offerer for the order.
    /// @param orderHash The order hash.
    /// @param signature A signature from the offerer indicating that the order has been approved.
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

    /// @dev Internal view function to get the EIP-712 domain separator. If the chainId matches the chainId set on deployment, the cached domain separator will be returned; otherwise, it will be derived from scratch.
    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    /// @dev Internal view function to derive the EIP-712 hash for an offererd item.
    /// @param offeredItem The offered item to hash.
    /// @return The hash.
    function _hashOfferedItem(
        OfferedItem memory offeredItem
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _OFFERED_ITEM_TYPEHASH,
                offeredItem.itemType,
                offeredItem.token,
                offeredItem.identifierOrCriteria,
                offeredItem.startAmount,
                offeredItem.endAmount
            )
        );
    }

    /// @dev Internal view function to derive the EIP-712 hash for a received item.
    /// @param receivedItem The received item to hash.
    /// @return The hash.
    function _hashReceivedItem(
        ReceivedItem memory receivedItem
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _RECEIVED_ITEM_TYPEHASH,
                receivedItem.itemType,
                receivedItem.token,
                receivedItem.identifierOrCriteria,
                receivedItem.startAmount,
                receivedItem.endAmount,
                receivedItem.account
            )
        );
    }

    /// @dev Internal view function to derive the order hash for a given order.
    /// @param orderParameters The parameters of the order to hash.
    /// @param nonce The nonce of the order to hash.
    /// @return The hash.
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
                offerHashes[i] = _hashOfferedItem(orderParameters.offer[i]);
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < considerationLength; ++i) {
                considerationHashes[i] = _hashReceivedItem(orderParameters.consideration[i]);
            }
        }

        return keccak256(
            abi.encode(
                _ORDER_HASH,
                orderParameters.offerer,
                orderParameters.zone,
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

    /// @dev Internal view function to retrieve the current nonce for a given order's offerer and zone and use that to derive the order hash.
    /// @param orderParameters The parameters of the order to hash.
    /// @return The hash.
    function _getNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        return _getOrderHash(
            orderParameters,
            _nonces[orderParameters.offerer][orderParameters.zone]
        );
    }

    /// @dev Internal view function to determine if a proxy should be utilized for a given order and to ensure that the submitter is allowed by the order type.
    /// @param orderType The type of the order.
    /// @param offerer The offerer in question.
    /// @param zone The zone in question.
    /// @return useOffererProxy A boolean indicating whether a proxy should be utilized for the order.
    function _determineProxyUtilizationAndEnsureValidSubmitter(
        OrderType orderType,
        address offerer,
        address zone
    ) internal view returns (bool useOffererProxy) {
        uint256 orderTypeAsUint256 = uint256(orderType);

        useOffererProxy = orderTypeAsUint256 > 3;

        if (
            orderTypeAsUint256 > (useOffererProxy ? 5 : 1) &&
            msg.sender != zone &&
            msg.sender != offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }
    }

    /// @dev Internal pure function to derive a hash for comparing transfers to see if they can be batched. Only applies to ERC1155 tokens.
    /// @param token The token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param useProxy A boolean indicating whether to utilize a proxy for the transfer.
    /// @return The hash.
    function _hashBatchableItemIdentifier(
        address token,
        address from,
        address to,
        bool useProxy
    ) internal pure returns (bytes32) {
        // Note: this could use a variant of efficientHash as it's < 64 bytes.
        return keccak256(abi.encode(token, from, to, useProxy));
    }

    /// @dev Internal pure function to derive the current amount of a given item based on the current price, the starting price, and the ending price. If the start and end prices differ, the current price will be extrapolated on a linear basis.
    /// @param startAmount The starting amount of the item.
    /// @param endAmount The ending amount of the item.
    /// @param elapsed The amount of time that has elapsed since the order's start time.
    /// @param remaining The amount of time left until the order's end time.
    /// @param duration The total duration of the order.
    /// @param roundUp A boolean indicating whether the resultant amount should be rounded up or down.
    /// @return The current amount.
    function _locateCurrentAmount(
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

    /// @dev Internal view function to ensure that the sentinel value for the reentrancy guard is not currently set.
    function _assertNonReentrant() internal view {
        // Ensure that the reentrancy guard is not currently set.
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
    }

    /// @dev Internal view function to ensure that the current time falls within an order's valid timespan.
    /// @param startTime The time at which the order becomes active.
    /// @param endTime The time at which the order becomes inactive.
    function _assertValidTime(
        uint256 startTime,
        uint256 endTime
    ) internal view {
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert InvalidTime();
        }
    }

    /// @dev Internal view function to validate whether a token transfer was successful based on the returned status and data. Note that malicious or non-compliant tokens may still return improper data — consider checking token balances before and after for more comprehensive transfer validation.
    /// @param ok The status of the call to transfer.
    /// Note that contract size must be checked on status of true and no returned data to rule out undeployed contracts.
    /// @param dataLength The length of the data returned from the call to transfer.
    /// Note that this value could also be read directly via returndatasize().
    /// @param token The token to transfer.
    /// @param from The originator of the transfer.
    /// @param to The recipient of the transfer.
    /// @param tokenId The tokenId to transfer (if applicable).
    /// @param amount The amount to transfer (if applicable).
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

        _assertContractIsDeployed(token, dataLength);
    }

    /// @dev Internal view function to item that a contract is deployed to a given account.
    /// @param account The account to check.
    /// @param dataLength The length of data returned from the last call to the account.
    function _assertContractIsDeployed(
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

    /// @dev Internal pure function to ensure that partial fills are not attempted on orders that do not support them.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// @param denominator A value indicating the total size of the order.
    /// @param orderType The order type.
    function _assertPartialFillsEnabled(
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

    /// @dev Internal pure function to apply criteria resolvers containing specific token identifiers and associated proofs as well as fulfillments allocating offer components to consideration components.
    /// @param orders The orders to apply criteria resolvers to.
    /// @param criteriaResolvers An array where each element contains a reference to a specific order as well as that order's offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the order's merkle root.
    /// Note that a root of zero indicates that any (transferrable) token identifier is valid and that no proof needs to be supplied.
    function _applyCriteriaResolvers(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
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

                    OfferedItem memory offer = orders[orderIndex].parameters.offer[componentIndex];
                    ItemType itemType = offer.itemType;
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForOfferedItem();
                    }

                    // empty criteria signifies a collection-wide offer (sell any item)
                    if (offer.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            offer.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.offer[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    orders[orderIndex].parameters.offer[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                } else {
                    if (componentIndex >= orders[orderIndex].parameters.consideration.length) {
                        revert ConsiderationCriteriaResolverOutOfRange();
                    }

                    ReceivedItem memory consideration = orders[orderIndex].parameters.consideration[componentIndex];
                    ItemType itemType = consideration.itemType;
                    if (
                        itemType != ItemType.ERC721_WITH_CRITERIA &&
                        itemType != ItemType.ERC1155_WITH_CRITERIA
                    ) {
                        revert CriteriaNotEnabledForConsideredItem();
                    }

                    // empty criteria signifies a collection-wide consideration (buy any item)
                    if (consideration.identifierOrCriteria != uint256(0)) {
                        _verifyProof(
                            criteriaResolver.identifier,
                            consideration.identifierOrCriteria,
                            criteriaResolver.criteriaProof
                        );
                    }

                    orders[orderIndex].parameters.consideration[componentIndex].itemType = (
                        itemType == ItemType.ERC721_WITH_CRITERIA
                            ? ItemType.ERC721
                            : ItemType.ERC1155
                    );

                    orders[orderIndex].parameters.consideration[componentIndex].identifierOrCriteria = criteriaResolver.identifier;
                }
            }

            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    if (uint256(order.parameters.consideration[j].itemType) > 3) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    if (uint256(order.parameters.offer[j].itemType) > 3) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }
        }
    }

    /// @dev Internal pure function to "compress" executions, splitting them into "standard" (or unbatched) executions and "batch" executions.
    /// Note that there may be additional compression that could be performed, such as allowing contrarian orders to cancel one another or to better aggregate standard orders.
    /// @param executions An array of uncompressed executions.
    /// @return standardExecutions An array of executions that could not be compressed.
    /// @return batchExecutions An array of executions (all ERC1155 transfers) that have been compressed into batches.
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
                if (executions[i].item.itemType == ItemType.ERC1155) {
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
            ReceivedItem memory initialItem = initialExecution.item;
            bytes32 hash = _hashBatchableItemIdentifier(
                initialItem.token,
                initialExecution.offerer,
                initialItem.account,
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
                ReceivedItem memory item = execution.item;

                hash = _hashBatchableItemIdentifier(
                    item.token,
                    execution.offerer,
                    item.account,
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

    /// @dev Internal pure function to complete the process of "compressing" executions.
    /// @param executions An array of uncompressed executions.
    /// @param batches An array of elements indicating which executions form the "baseline" for a batch.
    /// @param usedInBatch An array of indices (incremented by one as zero indicates no batching) per execution indicating which batch the execution should be applied to.
    /// @param totalUsedInBatch The total execution elements that can be batched.
    /// @param totalBatches The total number of batch executions.
    /// @return standardExecutions An array of executions that could not be compressed.
    /// @return batchExecutions An array of executions (all ERC1155 transfers) that have been compressed into batches.
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
                            token: execution.item.token,
                            from: execution.offerer,
                            to: execution.item.account,
                            tokenIds: new uint256[](tokenElements),
                            amounts: new uint256[](tokenElements),
                            useProxy: execution.useProxy
                        });
                    }

                    uint256 counter = batchElementCounters[batchUsed]++;

                    executeWithBatch[batchUsed].tokenIds[counter] = execution.item.identifierOrCriteria;
                    executeWithBatch[batchUsed].amounts[counter] = execution.item.endAmount;
                }
            }

            return (executeWithoutBatch, executeWithBatch);
        }
    }

    /// @dev Internal pure function to ensure that an order index is in range and, if so, to return the parameters of the associated order.
    /// @param orders An array of orders.
    /// @param index The order index specified by the fulfillment component.
    /// @return The parameters of the order at the given index.
    function _getOrderParametersByFulfillmentIndex(
        Order[] memory orders,
        uint256 index
    ) internal pure returns (OrderParameters memory) {
        if (index >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

        return orders[index].parameters;
    }

    /// @dev Internal pure function to ensure that an offer component index is in range and, if so, to return the associated offer item.
    /// @param orderParameters The parameters of the order.
    /// @param index The item index specified by the fulfillment component.
    /// @return The offer item at the given index.
    function _getOrderOfferComponentByItemIndex(
        OrderParameters memory orderParameters,
        uint256 index
    ) internal pure returns (OfferedItem memory) {
        if (index >= orderParameters.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }
        return orderParameters.offer[index];
    }

    /// @dev Internal pure function to ensure that a consideration component index is in range and, if so, to return the associated consideration item.
    /// @param orderParameters The parameters of the order.
    /// @param index The item index specified by the fulfillment component.
    /// @return The consideration item at the given index.
    function _getOrderConsiderationComponentByItemIndex(
        OrderParameters memory orderParameters,
        uint256 index
    ) internal pure returns (ReceivedItem memory) {
        if (index >= orderParameters.consideration.length) {
            revert FulfilledOrderConsiderationIndexOutOfRange();
        }
        return orderParameters.consideration[index];
    }

    /// @dev Internal pure function to match offer items to consideration items on a group of orders via a supplied fulfillment.
    /// Note that this function does not support partial filling of orders (though filling the remainder of a partially-filled order is supported).
    /// @param orders The orders to match.
    /// @param fulfillment An element allocating offer components to consideration components.
    /// Note that each consideration component must be fully met in order for the match operation to be valid.
    /// @param useOffererProxyPerOrder An array of booleans indicating whether to source approvals for the fulfilled tokens on each order from their respective proxy.
    /// @return execution A transfer to performed as part of the supplied fulfillment.
    /// Note that this execution object may be compressed further in order to batch transfers.
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

        uint256 currentItemIndex = fulfillment.offerComponents[0].itemIndex;

        OfferedItem memory offeredItem = _getOrderOfferComponentByItemIndex(
            orderWithInitialOffer,
            currentItemIndex
        );

        orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.offerComponents.length;) {
            FulfillmentComponent memory offerComponent = fulfillment.offerComponents[i];
            currentOrderIndex = offerComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentItemIndex = offerComponent.itemIndex;

            OfferedItem memory additionalOfferedItem = _getOrderOfferComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            if (
                orderWithInitialOffer.offerer != subsequentOrder.offerer ||
                offeredItem.itemType != additionalOfferedItem.itemType ||
                offeredItem.token != additionalOfferedItem.token ||
                offeredItem.identifierOrCriteria != additionalOfferedItem.identifierOrCriteria ||
                useProxy != useOffererProxyPerOrder[currentOrderIndex]
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            offeredItem.endAmount += additionalOfferedItem.endAmount;
            orders[currentOrderIndex].parameters.offer[currentItemIndex].endAmount = 0;

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

        currentItemIndex = fulfillment.considerationComponents[0].itemIndex;

        ReceivedItem memory requiredConsideration = _getOrderConsiderationComponentByItemIndex(
            orderWithInitialConsideration,
            currentItemIndex
        );

        orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.considerationComponents.length;) {
            FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[i];
            currentOrderIndex = considerationComponent.orderIndex;

            OrderParameters memory subsequentOrder = _getOrderParametersByFulfillmentIndex(
                orders,
                currentOrderIndex
            );

            currentItemIndex = considerationComponent.itemIndex;

            ReceivedItem memory additionalRequiredConsideration = _getOrderConsiderationComponentByItemIndex(
                subsequentOrder,
                currentItemIndex
            );

            if (
                requiredConsideration.account != additionalRequiredConsideration.account ||
                requiredConsideration.itemType != additionalRequiredConsideration.itemType ||
                requiredConsideration.token != additionalRequiredConsideration.token ||
                requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;
            orders[currentOrderIndex].parameters.consideration[currentItemIndex].endAmount = 0;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        if (requiredConsideration.endAmount > offeredItem.endAmount) {
            FulfillmentComponent memory targetComponent = fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.consideration[targetComponent.itemIndex].endAmount = requiredConsideration.endAmount - offeredItem.endAmount;
            requiredConsideration.endAmount = offeredItem.endAmount;
        } else {
            FulfillmentComponent memory targetComponent = fulfillment.offerComponents[fulfillment.offerComponents.length - 1];
            orders[targetComponent.orderIndex].parameters.offer[targetComponent.itemIndex].endAmount = offeredItem.endAmount - requiredConsideration.endAmount;
        }

        // Return the final execution that will be triggered for relevant items.
        return Execution(
            requiredConsideration,
            orderWithInitialOffer.offerer,
            useProxy
        );
    }

    /// @dev Internal pure function to return a fraction of a given value and to ensure that the resultant value does not have any fractional component.
    /// @param numerator A value indicating the portion of the order that should be filled.
    /// @param denominator A value indicating the total size of the order.
    /// @param value The value for which to compute the fraction.
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

    /// @dev Internal pure function to ensure that a given element is contained in a merkle root via a supplied proof.
    /// @param leaf The element for which to prove inclusion.
    /// @param root The merkle root that inclusion will be proved against.
    /// @param proof The merkle proof.
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

    /// @dev Internal pure function to efficiently hash two bytes32 values.
    /// @param a The first component of the hash.
    /// @param b The second component of the hash.
    /// @return value The hash.
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