// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "contracts/interfaces/AbridgedTokenInterfaces.sol";

import { ConduitInterface } from "contracts/interfaces/ConduitInterface.sol";

import { ProxyInterface } from "contracts/interfaces/AbridgedProxyInterfaces.sol";

import { Side, OrderType, ItemType } from "contracts/lib/ConsiderationEnums.sol";

import { ReferenceTokenTransferrer } from "./ReferenceTokenTransferrer.sol";

import { OrderToExecute, FractionData, AccumulatorStruct } from "./ReferenceConsiderationStructs.sol";

// prettier-ignore
import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver,
    Batch,
    BatchExecution
} from "contracts/lib/ConsiderationStructs.sol";

import { ReferenceConsiderationInternalView } from "./ReferenceConsiderationInternalView.sol";

import "./ReferenceConsiderationConstants.sol";

import { FulfillmentItemTypes, BasicFulfillmentHashes } from "./ReferenceConsiderationStructs.sol";

// prettier-ignore
import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "contracts/conduit/lib/ConduitStructs.sol";

import { ConduitItemType } from "contracts/conduit/lib/ConduitEnums.sol";

/**
 * @title ReferenceConsiderationInternal
 * @author 0age
 * @notice ConsiderationInternal contains all internal functions.
 */
contract ReferenceConsiderationInternal is
    ReferenceConsiderationInternalView,
    ReferenceTokenTransferrer
{
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController           A contract that deploys conduits, or
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC20+721+1155
     *                                    tokens.
     */
    constructor(address conduitController)
        ReferenceConsiderationInternalView(conduitController)
    {}

    /**
     * @dev Modifier to set the reentrancy guard sentinal value for the duration of the call
     */
    modifier nonReentrant() {
        _reentrancyGuard = _ENTERED;
        _;
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Modifier to check that the sentinal value for the reentrancy guard is not currently set
     *      by a previous call
     */
    modifier notEntered() {
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
        _;
    }

    /**
     * @dev Internal function to prepare fulfillment of a basic order with
     *      manual calldata and memory access. This calculates the order hash,
     *      emits an OrderFulfilled event, and asserts basic order validity.
     *      Note that calldata offsets must be validated as this function
     *      accesses constant calldata pointers for dynamic types that match
     *      default ABI encoding, but valid ABI encoding can use arbitrary
     *      offsets. Checking that the offsets were produced by default encoding
     *      will ensure that other functions using Solidity's calldata accessors
     *      (which calculate pointers from the stored offsets) are reading the
     *      same data as the order hash is derived from. Also note that This
     *      function accesses memory directly. It does not clear the expanded
     *      memory regions used, nor does it update the free memory pointer, so
     *      other direct memory access must not assume that unused memory is
     *      empty.
     *
     * @param parameters                   The parameters of the basic order.
     * @param orderType                    The order type.
     * @param receivedItemType             The item type of the initial
     *                                     consideration item on the order.
     * @param additionalRecipientsItemType The item type of any additional
     *                                     consideration item on the order.
     * @param additionalRecipientsToken    The ERC20 token contract adddress (if
     *                                     applicable) for any additional
     *                                     consideration item on the order.
     * @param offeredItemType              The item type of the offered item on
     *                                     the order.
     */
    function _prepareBasicFulfillmentFromCalldata(
        BasicOrderParameters calldata parameters,
        OrderType orderType,
        ItemType receivedItemType,
        ItemType additionalRecipientsItemType,
        address additionalRecipientsToken,
        ItemType offeredItemType
    ) internal {
        // Ensure current timestamp falls between order start time and end time.
        _verifyTime(parameters.startTime, parameters.endTime, true);

        // Verify that calldata offsets for all dynamic types were produced by
        // default encoding. This ensures that the constants we use for calldata
        // pointers to dynamic types are the same as those calculated by
        // Solidity using their offsets.
        _assertValidBasicOrderParameterOffsets();

        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            parameters.additionalRecipients.length + 1,
            parameters.totalOriginalAdditionalRecipients
        );

        // Memory to store hashes
        BasicFulfillmentHashes memory hashes;

        // Store ItemType/Token parameters in a struct in memory to avoid stack issues.
        FulfillmentItemTypes memory fulfillmentItemTypes = FulfillmentItemTypes(
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Array of Received Items for use with OrderFulfilled Event
        ReceivedItem[] memory consideration = new ReceivedItem[](
            parameters.additionalRecipients.length + 1
        );

        {
            // Load consideration item typehash from runtime and place on stack.
            hashes.typeHash = _CONSIDERATION_ITEM_TYPEHASH;

            // Create Consideration Item
            ConsiderationItem memory primaryConsiderationItem = (
                ConsiderationItem(
                    fulfillmentItemTypes.receivedItemType,
                    parameters.considerationToken,
                    parameters.considerationIdentifier,
                    parameters.considerationAmount,
                    parameters.considerationAmount,
                    parameters.offerer
                )
            );

            // Array of all consideration item hashes
            hashes.considerationHashes = new bytes32[](
                parameters.totalOriginalAdditionalRecipients + 1
            );

            // Hash Contents
            hashes.considerationHashes[0] = keccak256(
                abi.encode(
                    hashes.typeHash,
                    primaryConsiderationItem.itemType,
                    primaryConsiderationItem.token,
                    primaryConsiderationItem.identifierOrCriteria,
                    primaryConsiderationItem.startAmount,
                    primaryConsiderationItem.endAmount,
                    primaryConsiderationItem.recipient
                )
            );

            // Declare memory for additionalReceivedItem, additionalRecipientItem
            ReceivedItem memory additionalReceivedItem;
            ConsiderationItem memory additionalRecipientItem;

            // Create Received Item.
            ReceivedItem memory primaryReceivedItem = ReceivedItem(
                fulfillmentItemTypes.receivedItemType,
                primaryConsiderationItem.token,
                primaryConsiderationItem.identifierOrCriteria,
                primaryConsiderationItem.endAmount,
                primaryConsiderationItem.recipient
            );
            // Add the Received Item to the
            // OrderFulfilled ReceivedItem[]
            consideration[0] = primaryReceivedItem;

            // Loop through all additionalRecipients, to generate
            // ReceivedItems for OrderFulfilled Event and
            // ConsiderationItems for hashing
            for (
                uint256 recipientCount = 0;
                recipientCount < parameters.additionalRecipients.length;
                recipientCount++
            ) {
                // Get the next additionalRecipient.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[recipientCount]
                );

                // Create a Received Item for each additional recipients.
                additionalReceivedItem = ReceivedItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );
                // Add additonal received items to the
                // OrderFulfilled ReceivedItem[]
                consideration[recipientCount + 1] = additionalReceivedItem;

                // Skip hashing items not contained in the
                // Original Recipients.
                if (
                    recipientCount >=
                    parameters.totalOriginalAdditionalRecipients
                ) {
                    continue;
                }

                // Create a new consideration Item for each Additional Recipient.
                additionalRecipientItem = ConsiderationItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );

                // Calculate the EIP712 ConsiderationItem hash for
                // each additional recipients.
                hashes.considerationHashes[recipientCount + 1] = keccak256(
                    abi.encode(
                        hashes.typeHash,
                        additionalRecipientItem.itemType,
                        additionalRecipientItem.token,
                        additionalRecipientItem.identifierOrCriteria,
                        additionalRecipientItem.startAmount,
                        additionalRecipientItem.endAmount,
                        additionalRecipientItem.recipient
                    )
                );
            }

            /**
             *  The considerationHashes array now contains
             *  all consideration Item hashes.
             *
             *  The consideration array now contains all receieved
             *  items excluding tips for OrderFulfilled Event.
             */

            // Get hash of all consideration items.
            hashes.receivedItemsHash = keccak256(
                abi.encodePacked(hashes.considerationHashes)
            );

            // Get remainder of additionalRecipients for tips.
            for (
                uint256 additionalTips = parameters
                    .totalOriginalAdditionalRecipients;
                additionalTips < parameters.additionalRecipients.length;
                additionalTips++
            ) {
                // Get the next additionalRecipient.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[additionalTips]
                );

                // Create the ReceivedItem.
                additionalReceivedItem = ReceivedItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );
                // Add additonal received items to the
                // OrderFulfilled ReceivedItem[]
                consideration[additionalTips + 1] = additionalReceivedItem;
            }
        }
        // Now let's handle the offer side.

        // Write the offer to the Event SpentItem array
        SpentItem[] memory offer = new SpentItem[](1);

        {
            // Place offer item typehash on the stack.
            hashes.typeHash = _OFFER_ITEM_TYPEHASH;

            // Create Spent Item
            SpentItem memory offerItem = SpentItem(
                fulfillmentItemTypes.offeredItemType,
                parameters.offerToken,
                parameters.offerIdentifier,
                parameters.offerAmount
            );
            // Add the offer item to the SpentItem Array
            offer[0] = offerItem;

            // Get the hash of the Spent Item, treated as an Offer Item.
            bytes32[1] memory offerItemHashes = [
                keccak256(
                    abi.encode(
                        hashes.typeHash,
                        offerItem.itemType,
                        offerItem.token,
                        offerItem.identifier,
                        offerItem.amount,
                        offerItem.amount //Assembly uses OfferItem instead of SpentItem
                    )
                )
            ];

            // Get hash of all Spent Items
            hashes.offerItemsHash = keccak256(
                abi.encodePacked(offerItemHashes)
            );
        }

        {
            // Create the OrderComponent in order to derive
            // the orderHash

            // Load order typehash from runtime code and place on stack.
            hashes.typeHash = _ORDER_TYPEHASH;

            // Derive the order hash
            hashes.orderHash = _hashOrder(
                hashes,
                parameters,
                fulfillmentItemTypes
            );

            // Emit Event
            emit OrderFulfilled(
                hashes.orderHash,
                parameters.offerer,
                parameters.zone,
                msg.sender,
                offer,
                consideration
            );
        }
        // Determine whether order is restricted and, if so, that it is valid.
        _assertRestrictedBasicOrderValidity(
            hashes.orderHash,
            parameters.zoneHash,
            orderType,
            parameters.offerer,
            parameters.zone
        );

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            hashes.orderHash,
            parameters.offerer,
            parameters.signature
        );
    }

    /**
     * @dev Internal function to calculate the order hash
     *
     * @param hashes                       The array of offerItems and
     *                                     receivedItems hashes.
     * @param parameters                   The parameters of the basic order.
     * @param fulfillmentItemTypes         The fulfillment's item type.
     */
    function _hashOrder(
        BasicFulfillmentHashes memory hashes,
        BasicOrderParameters calldata parameters,
        FulfillmentItemTypes memory fulfillmentItemTypes
    ) internal view returns (bytes32 orderHash) {
        // Read offerer's current nonce from storage and place on the stack.
        uint256 nonce = _nonces[parameters.offerer];

        // Hash the contents to get the orderHash
        orderHash = keccak256(
            abi.encode(
                hashes.typeHash,
                parameters.offerer,
                parameters.zone,
                hashes.offerItemsHash,
                hashes.receivedItemsHash,
                fulfillmentItemTypes.orderType,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash,
                parameters.salt,
                parameters.offererConduitKey,
                nonce
            )
        );
    }

    /**
     * @dev Internal function to verify and update the status of a basic order.
     *
     * @param orderHash The hash of the order.
     * @param offerer   The offerer of the order.
     * @param signature A signature from the offerer indicating that the order
     *                  has been approved.
     */
    function _validateBasicOrderAndUpdateStatus(
        bytes32 orderHash,
        address offerer,
        bytes memory signature
    ) internal {
        // Retrieve the order status for the given order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        _verifyOrderStatus(
            orderHash,
            orderStatus,
            true, // Only allow unused orders when fulfilling basic orders.
            true // Signifies to revert if the order is invalid.
        );

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(offerer, orderHash, signature);
        }

        // Update order status as fully filled, packing struct values.
        _orderStatus[orderHash].isValidated = true;
        _orderStatus[orderHash].isCancelled = false;
        _orderStatus[orderHash].numerator = 1;
        _orderStatus[orderHash].denominator = 1;
    }

    /**
     * @dev Internal function to validate an order, determine what portion to
     *      fill, and update its status. The desired fill amount is supplied as
     *      a fraction, as is the returned amount to fill.
     *
     * @param advancedOrder    The order to fulfill as well as the fraction to
     *                         fill. Note that all offer and consideration
     *                         amounts must divide with no remainder in order
     *                         for a partial fill to be valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the order's merkle
     *                          root. Note that a criteria of zero indicates
     *                          that any (transferrable) token identifier is
     *                          valid and that no proof needs to be supplied.
     * @param revertOnInvalid  A boolean indicating whether to revert if the
     *                         order is invalid due to the time or order status.
     * @param priorOrderHashes The order hashes of each order supplied prior to
     *                         the current order as part of a "match" variety of
     *                         order fulfillment (e.g. this array will be empty
     *                         for single or "fulfill available").
     *
     * @return orderHash      The order hash.
     * @return newNumerator   A value indicating the portion of the order that
     *                        will be filled.
     * @return newDenominator A value indicating the total size of the order.
     */
    function _validateOrderAndUpdateStatus(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid,
        bytes32[] memory priorOrderHashes
    )
        internal
        returns (
            bytes32 orderHash,
            uint256 newNumerator,
            uint256 newDenominator
        )
    {
        // Retrieve the parameters for the order.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Ensure current timestamp falls between order start time and end time.
        if (
            !_verifyTime(
                orderParameters.startTime,
                orderParameters.endTime,
                revertOnInvalid
            )
        ) {
            // Assuming an invalid time and no revert, return zeroed out values.
            return (bytes32(0), 0, 0);
        }

        // Read numerator and denominator from memory and place on the stack.
        uint256 numerator = uint256(advancedOrder.numerator);
        uint256 denominator = uint256(advancedOrder.denominator);

        // Ensure that the supplied numerator and denominator are valid.
        if (numerator > denominator || numerator == 0) {
            revert BadFraction();
        }

        // If attempting partial fill (n < d) check order type & ensure support.
        if (
            numerator < denominator &&
            _doesNotSupportPartialFills(orderParameters.orderType)
        ) {
            // Revert if partial fill was attempted on an unsupported order.
            revert PartialFillsNotEnabledForOrder();
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _assertConsiderationLengthAndGetNoncedOrderHash(
            orderParameters
        );

        // Determine if a proxy should be utilized and ensure a valid submitter.
        _assertRestrictedAdvancedOrderValidity(
            advancedOrder,
            criteriaResolvers,
            priorOrderHashes,
            orderHash,
            orderParameters.zoneHash,
            orderParameters.orderType,
            orderParameters.offerer,
            orderParameters.zone
        );

        // Retrieve the order status using the derived order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and is not cancelled.
        if (
            !_verifyOrderStatus(
                orderHash,
                orderStatus,
                false, // Allow partially used orders to be filled.
                revertOnInvalid
            )
        ) {
            // Assuming an invalid order status and no revert, return zero fill.
            return (orderHash, 0, 0);
        }

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                orderParameters.offerer,
                orderHash,
                advancedOrder.signature
            );
        }

        // Read filled amount as numerator and denominator and put on the stack.
        uint256 filledNumerator = orderStatus.numerator;
        uint256 filledDenominator = orderStatus.denominator;

        // If order currently has a non-zero denominator it is partially filled.
        if (filledDenominator != 0) {
            // If denominator of 1 supplied, fill all remaining amount on order.
            if (denominator == 1) {
                // Scale numerator & denominator to match current denominator.
                numerator = filledDenominator;
                denominator = filledDenominator;
            }
            // Otherwise, if supplied denominator differs from current one...
            else if (filledDenominator != denominator) {
                // scale current numerator by the supplied denominator, then...
                filledNumerator *= denominator;

                // the supplied numerator & denominator by current denominator.
                numerator *= filledDenominator;
                denominator *= filledDenominator;
            }

            // Once adjusted, if current+supplied numerator exceeds denominator:
            if (filledNumerator + numerator > denominator) {
                // Reduce current numerator so it + supplied = denominator.
                numerator = denominator - filledNumerator;
            }

            // Update order status and fill amount, packing struct values.
            _orderStatus[orderHash].isValidated = true;
            _orderStatus[orderHash].isCancelled = false;
            _orderStatus[orderHash].numerator = uint120(
                filledNumerator + numerator
            );
            _orderStatus[orderHash].denominator = uint120(denominator);
        } else {
            // Update order status and fill amount, packing struct values.
            _orderStatus[orderHash].isValidated = true;
            _orderStatus[orderHash].isCancelled = false;
            _orderStatus[orderHash].numerator = uint120(numerator);
            _orderStatus[orderHash].denominator = uint120(denominator);
        }

        // Return order hash, new numerator and denominator, and proxy boolean.
        return (orderHash, numerator, denominator);
    }

    /**
     * @dev Internal function to validate an order and update its status, adjust
     *      prices based on current time, apply criteria resolvers, determine
     *      what portion to fill, and transfer relevant tokens.
     *
     * @param advancedOrder       The order to fulfill as well as the fraction
     *                            to fill. Note that all offer and consideration
     *                            components must divide with no remainder for
     *                            the partial fill to be valid.
     * @param criteriaResolvers   An array where each element contains a
     *                            reference to a specific offer or
     *                            consideration, a token identifier, and a proof
     *                            that the supplied token identifier is
     *                            contained in the order's merkle root. Note
     *                            that a criteria of zero indicates that any
     *                            (transferrable) token identifier is valid and
     *                            that no proof needs to be supplied.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration) and `bytes32(uint256(1)))`
     *                            signifies to utilize the legacy user proxy for
     *                            the fulfiller.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bytes32 fulfillerConduitKey
    ) internal returns (bool) {
        // Declare empty bytes32 array (unused, will remain empty).
        bytes32[] memory priorOrderHashes;

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint256 fillNumerator,
            uint256 fillDenominator
        ) = _validateOrderAndUpdateStatus(
                advancedOrder,
                criteriaResolvers,
                true,
                priorOrderHashes
            );

        // Apply criteria resolvers using generated orders and details arrays.
        _applyCriteriaResolversAdvanced(advancedOrder, criteriaResolvers);

        // Retrieve the order parameters after applying criteria resolvers.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Perform each item transfer with the appropriate fractional amount.
        OrderToExecute memory orderToExecute = _applyFractionsAndTransferEach(
            orderParameters,
            fillNumerator,
            fillDenominator,
            orderParameters.conduitKey,
            fulfillerConduitKey
        );

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderHash,
            orderParameters.offerer,
            orderParameters.zone,
            msg.sender,
            orderToExecute.spentItems,
            orderToExecute.receivedItems
        );

        return true;
    }

    /**
     * @dev Internal function to transfer each item contained in a given single
     *      order fulfillment after applying a respective fraction to the amount
     *      being transferred.
     *
     * @param orderParameters     The parameters for the fulfilled order.
     * @param numerator           A value indicating the portion of the order
     *                            that should be filled.
     * @param denominator         A value indicating the total order size.
     * @param offererConduitKey   An address indicating what conduit, if any, to
     *                            source the offerer's token approvals from. The
     *                            zero hash signifies that no conduit should be
     *                            used (and direct approvals set on
     *                            Consideration) and `bytes32(uint256(1)))`
     *                            signifies to utilize the legacy user proxy for
     *                            the offerer.
     * @param fulfillerConduitKey A bytes32 value indicating what conduit, if
     *                            any, to source the fulfiller's token approvals
     *                            from. The zero hash signifies that no conduit
     *                            should be used (and direct approvals set on
     *                            Consideration) and `bytes32(uint256(1)))`
     *                            signifies to utilize the legacy user proxy for
     *                            the fulfiller.
     *
     * @return orderToExecute     Returns the order of items that are being transferred.
     *                            This will be used for the OrderFulfilled Event.
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        bytes32 offererConduitKey,
        bytes32 fulfillerConduitKey
    ) internal returns (OrderToExecute memory orderToExecute) {
        // Derive order duration, time elapsed, and time remaining.
        // Store in memory to avoid stack too deep issues
        FractionData memory fractionData = FractionData(
            numerator,
            denominator,
            offererConduitKey,
            fulfillerConduitKey,
            (orderParameters.endTime - orderParameters.startTime),
            (block.timestamp - orderParameters.startTime),
            ((orderParameters.endTime - orderParameters.startTime) -
                (block.timestamp - orderParameters.startTime))
        );

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        // Get the offerer of the order.
        address offerer = orderParameters.offerer;

        // Create the array to store the spent items for event
        orderToExecute.spentItems = new SpentItem[](
            orderParameters.offer.length
        );

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each offer on the order.
            for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
                // Retrieve the offer item.
                OfferItem memory offerItem = orderParameters.offer[i];

                // Apply fill fraction to derive offer item amount to transfer.
                uint256 amount = _applyFraction(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    fractionData,
                    false
                );

                // Create Received Item from Offer Item for transfer
                ReceivedItem memory receivedItem = ReceivedItem(
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    amount,
                    payable(msg.sender)
                );

                // Create Spent Item for the OrderFulfilled Event.
                orderToExecute.spentItems[i] = SpentItem(
                    receivedItem.itemType,
                    receivedItem.token,
                    receivedItem.identifier,
                    amount
                );

                // Reduce available value if offer spent ETH or a native token.
                if (receivedItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }
                    // Reduce ether remaining by amount.
                    etherRemaining -= amount;
                }

                // Transfer the item from the offerer to the caller.
                _transfer(
                    receivedItem,
                    offerer,
                    fractionData.offererConduitKey,
                    accumulatorStruct
                );
            }
        }

        // Create the array to store the received items for event
        orderToExecute.receivedItems = new ReceivedItem[](
            orderParameters.consideration.length
        );

        // Declare a nested scope to minimize stack depth.
        {
            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < orderParameters.consideration.length; ++i) {
                // Retrieve the consideration item.
                ConsiderationItem memory considerationItem = (
                    orderParameters.consideration[i]
                );

                // Apply fraction & derive considerationItem amount to transfer.
                uint256 amount = _applyFraction(
                    considerationItem.startAmount,
                    considerationItem.endAmount,
                    fractionData,
                    true
                );

                // Create Received Item from Offer Item
                ReceivedItem memory receivedItem = ReceivedItem(
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    amount,
                    considerationItem.recipient
                );
                // Add ReceivedItem to Structs array.
                orderToExecute.receivedItems[i] = receivedItem;

                // Reduce available value if offer spent ETH or a native token.
                if (receivedItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }
                    // Reduce ether remaining by amount.
                    etherRemaining -= amount;
                }

                // Transfer item from caller to recipient specified by the item.
                _transfer(
                    receivedItem,
                    msg.sender,
                    fractionData.fulfillerConduitKey,
                    accumulatorStruct
                );
            }
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // If any ether remains after fulfillments...
        if (etherRemaining != 0) {
            // return it to the caller.
            _transferEth(payable(msg.sender), etherRemaining);
        }
        // Return the order to execute.
        return orderToExecute;
    }

    /**
     * @dev Internal function to validate a group of orders, update their
     *      statuses, reduce amounts by their previously filled fractions, apply
     *      criteria resolvers, and emit OrderFulfilled events.
     *
     * @param advancedOrders    The advanced orders to validate and reduce by
     *                          their previously filled amounts.
     * @param ordersToExecute   The orders to validate and execute.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific order as well as that order's
     *                          offer or consideration, a token identifier, and
     *                          a proof that the supplied token identifier is
     *                          contained in the order's merkle root. Note that
     *                          a root of zero indicates that any transferrable
     *                          token identifier is valid and that no proof
     *                          needs to be supplied.
     * @param revertOnInvalid   A boolean indicating whether to revert on any
     *                          order being invalid; setting this to false will
     *                          instead cause the invalid order to be skipped.
     * @param maximumFulfilled  The maximum number of orders to fulfill.
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid,
        uint256 maximumFulfilled
    ) internal {
        // Read length of orders array and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Track the order hash for each order being fulfilled.
        bytes32[] memory orderHashes = new bytes32[](totalOrders);

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the current order.
            AdvancedOrder memory advancedOrder = advancedOrders[i];
            // Retreive the order to Execute
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Determine if max number orders have already been fulfilled.
            if (maximumFulfilled == 0) {
                // Mark fill fraction as zero as the order will not be used.
                advancedOrder.numerator = 0;

                // Mark fill fraction as zero as the order will not be used.
                orderToExecute.numerator = 0;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Validate it, update status, and determine fraction to fill.
            (
                bytes32 orderHash,
                uint256 numerator,
                uint256 denominator
            ) = _validateOrderAndUpdateStatus(
                    advancedOrder,
                    criteriaResolvers,
                    revertOnInvalid,
                    orderHashes
                );

            // Do not track hash or adjust prices if order is not fulfilled.
            if (numerator == 0) {
                // Mark fill fraction as zero if the order is not fulfilled.
                advancedOrder.numerator = 0;

                // Mark fill fraction as zero as the order will not be used.
                orderToExecute.numerator = 0;

                // Continue iterating through the remaining orders.
                continue;
            }

            // Otherwise, track the order hash in question.
            orderHashes[i] = orderHash;

            // Decrement the number of fulfilled orders.
            maximumFulfilled--;

            // Place the start time for the order on the stack.
            uint256 startTime = advancedOrder.parameters.startTime;

            // Derive the duration for the order and place it on the stack.
            uint256 duration = advancedOrder.parameters.endTime - startTime;

            // Derive time elapsed since the order started & place on stack.
            uint256 elapsed = block.timestamp - startTime;

            // Derive time remaining until order expires and place on stack.
            uint256 remaining = duration - elapsed;

            // Retrieve array of offer items for the order in question.
            OfferItem[] memory offer = advancedOrder.parameters.offer;

            // Iterate over each offer item on the order.
            for (uint256 j = 0; j < offer.length; ++j) {
                // Retrieve the offer item.
                OfferItem memory offerItem = offer[j];

                // Apply order fill fraction to offer item end amount.
                uint256 endAmount = _getFraction(
                    numerator,
                    denominator,
                    offerItem.endAmount
                );

                // Reuse same fraction if start and end amounts are equal.
                if (offerItem.startAmount == offerItem.endAmount) {
                    // Apply derived amount to both start and end amount.
                    offerItem.startAmount = endAmount;
                } else {
                    // Apply order fill fraction to offer item start amount.
                    offerItem.startAmount = _getFraction(
                        numerator,
                        denominator,
                        offerItem.startAmount
                    );
                }

                // Update end amount in memory to match the derived amount.
                offerItem.endAmount = endAmount;

                // Adjust offer amount using current time; round down.
                offerItem.startAmount = _locateCurrentAmount(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    elapsed,
                    remaining,
                    duration,
                    false // round down
                );

                // Modify the OrderToExecute Spent Item Amount.
                orderToExecute.spentItems[j].amount = offerItem.startAmount;
            }

            // Retrieve array of consideration items for order in question.
            ConsiderationItem[] memory consideration = (
                advancedOrder.parameters.consideration
            );

            // Iterate over each consideration item on the order.
            for (uint256 j = 0; j < consideration.length; ++j) {
                // Retrieve the consideration item.
                ConsiderationItem memory considerationItem = (consideration[j]);

                // Apply fraction to consideration item end amount.
                uint256 endAmount = _getFraction(
                    numerator,
                    denominator,
                    considerationItem.endAmount
                );

                // Reuse same fraction if start and end amounts are equal.
                if (
                    considerationItem.startAmount == considerationItem.endAmount
                ) {
                    // Apply derived amount to both start and end amount.
                    considerationItem.startAmount = endAmount;
                } else {
                    // Apply fraction to consideration item start amount.
                    considerationItem.startAmount = _getFraction(
                        numerator,
                        denominator,
                        considerationItem.startAmount
                    );
                }

                // Update end amount in memory to match the derived amount.
                considerationItem.endAmount = endAmount;

                // Adjust consideration amount using current time; round up.
                considerationItem.startAmount = (
                    _locateCurrentAmount(
                        considerationItem.startAmount,
                        considerationItem.endAmount,
                        elapsed,
                        remaining,
                        duration,
                        true // round up
                    )
                );

                // Modify the OrderToExecute Received Item Amount.
                orderToExecute.receivedItems[j].amount = considerationItem
                    .startAmount;
            }
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(ordersToExecute, criteriaResolvers);
        // Determine the fulfiller (revertOnInvalid ? address(0) : msg.sender).
        address fulfiller = revertOnInvalid ? address(0) : msg.sender;

        // Emit an event for each order signifying that it has been fulfilled.

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Do not emit an event if no order hash is present.
            if (orderHashes[i] == bytes32(0)) {
                continue;
            }

            // Retrieve parameters for the order in question.
            OrderParameters memory orderParameters = (
                advancedOrders[i].parameters
            );

            // Get the array of spentItems from the orderToExecute struct.
            SpentItem[] memory spentItems = ordersToExecute[i].spentItems;

            // Get the array of spentIreceivedItemstems from the orderToExecute struct.
            ReceivedItem[] memory receivedItems = ordersToExecute[i]
                .receivedItems;

            // Emit the event.
            emit OrderFulfilled(
                orderHashes[i],
                orderParameters.offerer,
                orderParameters.zone,
                fulfiller,
                spentItems,
                receivedItems
            );
        }
    }

    /**
     * @dev Internal function to fulfill an arbitrary number of orders, either
     *      full or partial, after validating, adjusting amounts, and applying
     *      criteria resolvers.
     *
     * @param ordersToExecute    The orders to match, including a fraction to
     *                           attempt to fill for each order.
     * @param fulfillments       An array of elements allocating offer
     *                           components to consideration components. Note
     *                           that the final amount of each consideration
     *                           component must be zero for a match operation to
     *                           be considered valid.
     *
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            matching the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            matching the given orders.
     */
    function _fulfillAdvancedOrders(
        OrderToExecute[] memory ordersToExecute,
        Fulfillment[] calldata fulfillments
    )
        internal
        returns (
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Retrieve fulfillments array length and place on the stack.
        uint256 totalFulfillments = fulfillments.length;

        // Allocate executions by fulfillment and apply them to each execution.
        Execution[] memory executions = new Execution[](totalFulfillments);

        // Track number of filtered executions.
        uint256 totalFilteredExecutions = 0;

        // Iterate over each fulfillment.
        for (uint256 i = 0; i < totalFulfillments; ++i) {
            /// Retrieve the fulfillment in question.
            Fulfillment calldata fulfillment = fulfillments[i];

            // Derive the execution corresponding with the fulfillment.
            Execution memory execution = _applyFulfillment(
                ordersToExecute,
                fulfillment.offerComponents,
                fulfillment.considerationComponents
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[i - totalFilteredExecutions] = execution;
            }
        }

        // If some number of executions have been filtered...
        if (totalFilteredExecutions != 0) {
            uint256 executionLength = totalFulfillments -
                totalFilteredExecutions;
            Execution[] memory filteredExecutions = new Execution[](
                executionLength
            );
            // Create new array from Executions
            for (uint256 i = 0; i < executionLength; ++i) {
                filteredExecutions[i] = executions[i];
            }
            // Perform final checks and compress executions into standard and batch.
            (
                ,
                standardExecutions,
                batchExecutions
            ) = _performFinalChecksAndExecuteOrders(
                ordersToExecute,
                filteredExecutions
            );
        } else {
            // Perform final checks and compress executions into standard and batch.
            (
                ,
                standardExecutions,
                batchExecutions
            ) = _performFinalChecksAndExecuteOrders(
                ordersToExecute,
                executions
            );
        }

        // Return both standard and batch ERC1155 executions.
        return (standardExecutions, batchExecutions);
    }

    /**
     * @notice Internal function to attempt to fill a group of orders, fully or
     *         partially, with an arbitrary number of items for offer and
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
     *
     * @param ordersToExecute           The orders to execute.  This is an
     *                                  explicit version of advancedOrders without
     *                                  memory optimization, that provides
     *                                  an array of spentItems and receivedItems
     *                                  for fulfillment and event emission.
     *
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
    function _fulfillAvailableAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        OrderToExecute[] memory ordersToExecute,
        CriteriaResolver[] memory criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        uint256 maximumFulfilled
    )
        internal
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Validate orders, apply amounts, & determine if they utilize conduits
        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
            ordersToExecute,
            criteriaResolvers,
            false, // Signifies that invalid orders should NOT revert.
            maximumFulfilled
        );

        // Aggregate used offer and consideration items and execute transfers.
        (
            availableOrders,
            standardExecutions,
            batchExecutions
        ) = _executeAvailableFulfillments(
            ordersToExecute,
            offerFulfillments,
            considerationFulfillments,
            fulfillerConduitKey
        );

        // Return order fulfillment details and executions.
        return (availableOrders, standardExecutions, batchExecutions);
    }

    /**
     * @dev Internal function to fulfill a group of validated orders, fully or
     *      partially, with an arbitrary number of items for offer and
     *      consideration per order and to execute transfers. Any order that is
     *      not currently active, has already been fully filled, or has been
     *      cancelled will be omitted. Remaining offer and consideration items
     *      will then be aggregated where possible as indicated by the supplied
     *      offer and consideration component arrays and aggregated items will
     *      be transferred to the fulfiller or to each intended recipient,
     *      respectively. Note that a failing item transfer or an issue with
     *      order formatting will cause the entire batch to fail.
     *
     * @param ordersToExecute           The orders to execute.  This is an
     *                                  explicit version of advancedOrders without
     *                                  memory optimization, that provides
     *                                  an array of spentItems and receivedItems
     *                                  for fulfillment and event emission.
     *                                  Note that both the offerer and the
     *                                  fulfiller must first approve this
     *                                  contract (or the conduit if indicated by
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
     *                                  direct approvals set on Consideration)
     *                                  and `bytes32(uint256(1))` signifies to
     *                                  utilize the legacy user proxy for the
     *                                  fulfiller.
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
    function _executeAvailableFulfillments(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        bytes32 fulfillerConduitKey
    )
        internal
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Retrieve length of offer fulfillments array and place on the stack.
        uint256 totalOfferFulfillments = offerFulfillments.length;

        // Retrieve length of consideration fulfillments array & place on stack.
        uint256 totalConsiderationFulfillments = (
            considerationFulfillments.length
        );

        // Allocate an execution for each offer and consideration fulfillment.
        Execution[] memory executions = new Execution[](
            totalOfferFulfillments + totalConsiderationFulfillments
        );

        // Track number of filtered executions.
        uint256 totalFilteredExecutions = 0;

        // Iterate over each offer fulfillment.
        for (uint256 i = 0; i < totalOfferFulfillments; ++i) {
            /// Retrieve the offer fulfillment components in question.
            FulfillmentComponent[] memory components = (offerFulfillments[i]);

            // Derive aggregated execution corresponding with fulfillment.
            Execution memory execution = _aggregateAvailable(
                ordersToExecute,
                Side.OFFER,
                components,
                fulfillerConduitKey
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[i - totalFilteredExecutions] = execution;
            }
        }

        // Iterate over each consideration fulfillment.
        for (uint256 i = 0; i < totalConsiderationFulfillments; ++i) {
            /// Retrieve consideration fulfillment components in question.
            FulfillmentComponent[] memory components = (
                considerationFulfillments[i]
            );

            // Derive aggregated execution corresponding with fulfillment.
            Execution memory execution = _aggregateAvailable(
                ordersToExecute,
                Side.CONSIDERATION,
                components,
                fulfillerConduitKey
            );

            // If offerer and recipient on the execution are the same...
            if (execution.item.recipient == execution.offerer) {
                // increment total filtered executions.
                totalFilteredExecutions += 1;
            } else {
                // Otherwise, assign the execution to the executions array.
                executions[
                    i + totalOfferFulfillments - totalFilteredExecutions
                ] = execution;
            }
        }

        // If some number of executions have been filtered...
        if (totalFilteredExecutions != 0) {
            /**
             *   The following is highly inefficient, but written this way
             *   to show in the most simplest form what the optimized
             *   contract is performing inside it's assembly.
             */

            // Get the total execution length.
            uint256 executionLength = (totalOfferFulfillments +
                totalConsiderationFulfillments) - totalFilteredExecutions;

            // Create an array of executions that will be executed.
            Execution[] memory filteredExecutions = new Execution[](
                executionLength
            );

            // Create new array from the exsiting Executions
            for (uint256 i = 0; i < executionLength; ++i) {
                filteredExecutions[i] = executions[i];
            }

            // Set the executions array to the newly created array.
            executions = filteredExecutions;
        }
        // Revert if no orders are available.
        if (executions.length == 0) {
            revert NoSpecifiedOrdersAvailable();
        }
        // Perform final checks and compress executions into standard and batch.
        return _performFinalChecksAndExecuteOrders(ordersToExecute, executions);
    }

    /**
     * @dev Internal function to perform a final check that each consideration
     *      item for an arbitrary number of fulfilled orders has been met and to
     *      compress and trigger associated execututions, transferring the
     *      respective items.
     *
     * @param ordersToExecute    The orders to check and perform executions.
     * @param executions         An array of uncompressed elements indicating
     *                           the sequence of transfers to perform when
     *                           fulfilling the given orders.
     *
     * @return availableOrders    An array of booleans indicating if each order
     *                            with an index corresponding to the index of
     *                            the returned boolean was fulfillable or not.
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            fulfilling the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            fulfilling the given orders.
     */
    function _performFinalChecksAndExecuteOrders(
        OrderToExecute[] memory ordersToExecute,
        Execution[] memory executions
    )
        internal
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Retrieve the length of the advanced orders array and place on stack.
        uint256 totalOrders = ordersToExecute.length;

        // Initialize array for tracking available orders.
        availableOrders = new bool[](totalOrders);
        // Iterate over orders to ensure all considerations are met.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order in question.
            OrderToExecute memory orderToExecute = ordersToExecute[i];

            // Skip consideration item checks for order if not fulfilled.
            if (orderToExecute.numerator == 0) {
                // Note: orders do not need to be marked as unavailable as a
                // new memory region has been allocated. Review carefully if
                // altering compiler version or managing memory manually.
                continue;
            }

            // Mark the order as available.
            availableOrders[i] = true;

            // Retrieve consideration items to ensure they are fulfilled.
            ReceivedItem[] memory consideration = (
                orderToExecute.receivedItems
            );

            // Iterate over each consideration item to ensure it is met.
            for (uint256 j = 0; j < consideration.length; ++j) {
                // Retrieve remaining amount on the consideration item.
                uint256 unmetAmount = consideration[j].amount;

                // Revert if the remaining amount is not zero.
                if (unmetAmount != 0) {
                    revert ConsiderationNotMet(i, j, unmetAmount);
                }
            }
        }

        // Split executions into "standard" (no batch) and "batch" executions.
        (standardExecutions, batchExecutions) = _compressExecutions(executions);

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Create the accumulator struct.
        AccumulatorStruct memory accumulatorStruct;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < standardExecutions.length; ++i) {
            // Retrieve the execution and the associated received item.
            Execution memory execution = standardExecutions[i];
            ReceivedItem memory item = execution.item;

            // If execution transfers native tokens, reduce value available.
            if (item.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Reduce ether remaining by amount.
                etherRemaining -= item.amount;
            }

            // Transfer the item specified by the execution.
            _transfer(
                item,
                execution.offerer,
                execution.conduitKey,
                accumulatorStruct
            );
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // Iterate over each batch execution.
        for (uint256 i = 0; i < batchExecutions.length; ++i) {
            // Perform the batch transfer.
            _batchTransferERC1155(batchExecutions[i]);
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
            _transferEth(payable(msg.sender), etherRemaining);
        }

        // Return arrays with available orders and triggered executions.
        return (availableOrders, standardExecutions, batchExecutions);
    }

    function _triggerIfArmed(AccumulatorStruct memory accumulatorStruct)
        internal
    {
        // Exit if the accumulator is not "armed".
        if (accumulatorStruct.transfers.length == 0) {
            return;
        }

        // Perform conduit call.
        _trigger(accumulatorStruct);
    }

    function _triggerIfArmedAndNotAccumulatable(
        AccumulatorStruct memory accumulatorStruct,
        bytes32 conduitKey
    ) internal {
        // Perform conduit call if the set key does not match the supplied key.
        if (accumulatorStruct.conduitKey != conduitKey) {
            _triggerIfArmed(accumulatorStruct);
        }
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item                  The item to transfer including an amount and recipient.
     * @param offerer               The account offering the item, i.e. the from address.
     * @param conduitKey            A bytes32 value indicating what corresponding conduit,
     *                              if any, to source token approvals from. The zero hash
     *                              signifies that no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(uint256(1))` signifies to utilize the legacy
     *                              user proxy for the transfer.
     * @param accumulatorStruct     A struct containing conduit transfer data and it's
     *                              corresponding conduitKey.
     */
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // transfer the native tokens to the recipient.
            _transferEth(item.recipient, item.amount);
        } else if (item.itemType == ItemType.ERC20) {
            // Transfer ERC20 tokens from the offerer to the recipient.
            _transferERC20(
                item.token,
                offerer,
                item.recipient,
                item.amount,
                conduitKey,
                accumulatorStruct
            );
        } else if (item.itemType == ItemType.ERC721) {
            // Transfer ERC721 token from the offerer to the recipient.
            _transferERC721(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey,
                accumulatorStruct
            );
        } else {
            // Transfer ERC1155 token from the offerer to the recipient.
            _transferERC1155(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey,
                accumulatorStruct
            );
        }
    }

    /**
     * @dev Internal function to transfer Ether or other native tokens to a
     *      given recipient.
     *
     * @param to     The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function _transferEth(address payable to, uint256 amount) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // Declare a variable indicating whether the call was successful or not.
        (bool success, ) = to.call{ value: amount }("");

        // If the call fails...
        if (!success) {
            // Revert with a generic error message.
            revert EtherTransferGenericFailure(to, amount);
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient using a given conduit if applicable. Sufficient
     *      approvals must be set on this contract, the conduit, or the token
     *      transfer proxy in cases where the conduit is set to `address(1)`.
     *
     * @param token                 The ERC20 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param amount                The amount to transfer.
     * @param conduitKey            A bytes32 value indicating what corresponding conduit,
     *                              if any, to source token approvals from. The zero hash
     *                              signifies that no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(uint256(1))` signifies to utilize the legacy
     *                              user proxy for the transfer.
     * @param accumulatorStruct     A struct containing conduit transfer data and it's
     *                              corresponding conduitKey.
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(accumulatorStruct, conduitKey);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform the token transfer directly.
            _performERC20Transfer(token, from, to, amount);
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                uint256(1),
                token,
                from,
                to,
                uint256(0),
                amount
            );
        }
    }

    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective conduit or on this contract itself.
     *
     * @param token                 The ERC721 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param identifier            The tokenId to transfer.
     * @param amount                The "amount" (this value must be equal to one).
     * @param conduitKey            A bytes32 value indicating what corresponding conduit,
     *                              if any, to source token approvals from. The zero hash
     *                              signifies that no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(uint256(1))` signifies to utilize the legacy
     *                              user proxy for the transfer.
     * @param accumulatorStruct     A struct containing conduit transfer data and it's
     *                              corresponding conduitKey.
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(accumulatorStruct, conduitKey);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Ensure that exactly one 721 item is being transferred.
            if (amount != 1) {
                revert InvalidERC721TransferAmount();
            }

            // Perform transfer via the token contract directly.
            _performERC721Transfer(token, from, to, identifier);
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                uint256(2),
                token,
                from,
                to,
                identifier,
                amount
            );
        }
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective conduit or on this contract itself.
     *
     * @param token                 The ERC1155 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param identifier            The tokenId to transfer.
     * @param amount                The amount to transfer.
     * @param conduitKey            A bytes32 value indicating what corresponding conduit,
     *                              if any, to source token approvals from. The zero hash
     *                              signifies that no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(uint256(1))` signifies to utilize the legacy
     *                              user proxy for the transfer.
     * @param accumulatorStruct     A struct containing conduit transfer data and it's
     *                              corresponding conduitKey.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(accumulatorStruct, conduitKey);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform transfer via the token contract directly.
            _performERC1155Transfer(token, from, to, identifier, amount);
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                uint256(3),
                token,
                from,
                to,
                identifier,
                amount
            );
        }
    }

    function _trigger(AccumulatorStruct memory accumulatorStruct) internal {
        // Call the conduit with all the accumulated transfers.
        ConduitInterface(_getConduit(accumulatorStruct.conduitKey)).execute(
            accumulatorStruct.transfers
        );

        // Reset accumulator length to signal that it is now "disarmed".
        delete accumulatorStruct.transfers;
    }

    function _insert(
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        uint256 itemType,
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal view {
        /**
         *   The following is highly inefficient, but written this way
         *   to show in the most simplest form what the optimized
         *   contract is performing inside it's assembly.
         */

        // Get the current length of the accumulator's transfers.
        uint256 currentTransferLength = accumulatorStruct.transfers.length;

        // Create a new array to "insert" the new transfer.
        ConduitTransfer[] memory newTransfers = (
            new ConduitTransfer[](currentTransferLength + 1)
        );

        // Fill new array with old transfers.
        for (uint256 i = 0; i < currentTransferLength; ++i) {
            // Get the old transfer.
            ConduitTransfer memory oldTransfer = accumulatorStruct.transfers[i];
            // Add the old transfer into the new array.
            newTransfers[i] = ConduitTransfer(
                oldTransfer.itemType,
                oldTransfer.token,
                oldTransfer.from,
                oldTransfer.to,
                oldTransfer.identifier,
                oldTransfer.amount
            );
        }

        // Insert new transfer into array.
        newTransfers[currentTransferLength] = ConduitTransfer(
            ConduitItemType(itemType),
            token,
            from,
            to,
            identifier,
            amount
        );

        // Set accumulator struct transfers to new transfers.
        accumulatorStruct.transfers = newTransfers;
        // Set the conduitkey of the current transfers.
        accumulatorStruct.conduitKey = conduitKey;
    }

    /**
     * @dev Internal function to transfer a batch of ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective conduit or on this contract itself.
     *
     * @param batchExecution The batch of 1155 tokens to be transferred.
     */
    function _batchTransferERC1155(BatchExecution memory batchExecution)
        internal
    {
        // Place elements of the batch execution in memory onto the stack.
        bytes32 conduitKey = batchExecution.conduitKey;
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;

        // Retrieve the tokenIds and amounts.
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;
        // If no conduit has been specified...
        if (batchExecution.conduitKey == bytes32(0)) {
            // Perform transfer via the token contract directly.
            _performERC1155BatchTransfer(token, from, to, tokenIds, amounts);
        } else {
            // Create an array of 1155 transfers.
            ConduitBatch1155Transfer[] memory batchTransfers = (
                new ConduitBatch1155Transfer[](1)
            );

            // Add a ConduitBatch1155Transfer into the array.
            batchTransfers[0] = ConduitBatch1155Transfer(
                token,
                from,
                to,
                tokenIds,
                amounts
            );

            // Perform the call to the conduit.
            ConduitInterface(_getConduit(conduitKey)).executeWithBatch1155(
                new ConduitTransfer[](0),
                batchTransfers
            );
        }
    }

    function _getConduit(bytes32 conduitKey)
        internal
        view
        returns (address conduit)
    {
        conduit = _deriveConduit(conduitKey);

        if (conduit.code.length == 0) {
            revert InvalidConduit(conduitKey, conduit);
        }
    }

    /**
     * @dev Internal function to transfer Ether (or other native tokens) to a
     *      given recipient as part of basic order fulfillment. Note that
     *      proxies are not utilized for native tokens as the transferred amount
     *      must be provided as msg.value.
     *
     * @param amount      The amount to transfer.
     * @param parameters  The parameters of the basic order in question.
     */
    function _transferEthAndFinalize(
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) internal {
        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
            // Retrieve the additional recipient.
            AdditionalRecipient calldata additionalRecipient = (
                parameters.additionalRecipients[i]
            );

            // Read ether amount to transfer to recipient and place on stack.
            uint256 additionalRecipientAmount = additionalRecipient.amount;

            // Ensure that sufficient Ether is available.
            if (additionalRecipientAmount > etherRemaining) {
                revert InsufficientEtherSupplied();
            }

            // Transfer Ether to the additional recipient.
            _transferEth(
                additionalRecipient.recipient,
                additionalRecipientAmount
            );

            // Reduce ether value available.
            etherRemaining -= additionalRecipientAmount;
        }

        // Ensure that sufficient Ether is still available.
        if (amount > etherRemaining) {
            revert InsufficientEtherSupplied();
        }

        // Transfer Ether to the offerer.
        _transferEth(parameters.offerer, amount);

        // If any Ether remains after transfers, return it to the caller.
        if (etherRemaining > amount) {
            // Transfer remaining Ether to the caller.
            _transferEth(payable(msg.sender), etherRemaining - amount);
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens to a given recipient as
     *      part of basic order fulfillment. Note that proxies are not utilized
     *      for ERC20 tokens.
     *
     * @param from                  The originator of the ERC20 token transfer.
     * @param to                    The recipient of the ERC20 token transfer.
     * @param erc20Token            The ERC20 token to transfer.
     * @param amount                The amount of ERC20 tokens to transfer.
     * @param parameters            The parameters of the order.
     * @param fromOfferer           Whether to decrement amount from the offered amount.
     * @param accumulatorStruct     A struct containing conduit transfer data and it's
     *                              corresponding conduitKey.
     */
    function _transferERC20AndFinalize(
        address from,
        address to,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters,
        bool fromOfferer,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // Determine the appropriate conduit to utilize.
        bytes32 conduitKey = fromOfferer
            ? parameters.offererConduitKey
            : parameters.fulfillerConduitKey;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
            // Retrieve the additional recipient.
            AdditionalRecipient calldata additionalRecipient = (
                parameters.additionalRecipients[i]
            );

            // Decrement the amount to transfer to fulfiller if indicated.
            if (fromOfferer) {
                amount -= additionalRecipient.amount;
            }

            // Transfer ERC20 tokens to additional recipient given approval.
            _transferERC20(
                erc20Token,
                from,
                additionalRecipient.recipient,
                additionalRecipient.amount,
                conduitKey,
                accumulatorStruct
            );
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(
            erc20Token,
            from,
            to,
            amount,
            conduitKey,
            accumulatorStruct
        );
    }
}
