// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// prettier-ignore
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../interfaces/AbridgedTokenInterfaces.sol";

import { ConduitInterface } from "../../interfaces/ConduitInterface.sol";

import { ProxyInterface } from "../../interfaces/AbridgedProxyInterfaces.sol";

import { Side, OrderType, ItemType } from "../../lib/ConsiderationEnums.sol";

import { ReferenceTokenTransferrer } from "./ReferenceTokenTransferrer.sol";

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
} from "../../lib/ConsiderationStructs.sol";

import { ReferenceConsiderationInternalView } from "./ReferenceConsiderationInternalView.sol";

import "./ReferenceConsiderationConstants.sol";

import { FulfillmentItemTypes, BasicFulfillmentHashes } from "./ReferenceConsiderationStructs.sol";

// prettier-ignore
import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../../conduit/lib/ConduitStructs.sol";

import { ConduitItemType } from "../../conduit/lib/ConduitEnums.sol";

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

        BasicFulfillmentHashes memory hashes;

        // Store ItemType/Token parameters in a struct in memory to avoid stack issues.
        FulfillmentItemTypes memory fulfillmentItemTypes = FulfillmentItemTypes(
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Create ReceivedItem for Primary Consideration
        // Array of Received Items for use with OrderFulfilled Event
        ReceivedItem[] memory consideration = new ReceivedItem[](
            parameters.additionalRecipients.length + 1
        );

        // Write the offer to the Event SpentItem array
        SpentItem[] memory offer = new SpentItem[](1);

        {
            /**
             * First, handle consideration items. Memory Layout:
             *  0x60: final hash of the array of consideration item hashes
             *  0x80-0x160: reused space for EIP712 hashing of each item
             *   - 0x80: ConsiderationItem EIP-712 typehash (constant)
             *   - 0xa0: itemType
             *   - 0xc0: token
             *   - 0xe0: identifier
             *   - 0x100: startAmount
             *   - 0x120: endAmount
             *   - 0x140: recipient
             *  0x160-END_ARR: array of consideration item hashes
             *   - 0x160: primary consideration item EIP712 hash
             *   - 0x180-END_ARR: additional recipient item EIP712 hashes
             *  END_ARR: beginning of data for OrderFulfilled event
             *   - END_ARR + 0x120: length of ReceivedItem array
             *   - END_ARR + 0x140: beginning of data for first ReceivedItem
             * (Note: END_ARR = 0x180 + RECIPIENTS_LENGTH * 0x20)
             */

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

            ReceivedItem memory additionalReceivedItem;
            ConsiderationItem memory additionalRecipientItem;

            // Create Received Item
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

            for (
                uint256 recipientCount = 0;
                recipientCount < parameters.additionalRecipients.length;
                recipientCount++
            ) {
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[recipientCount]
                );

                // Create a Received Item for each additional recipients
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

                if (
                    recipientCount >=
                    parameters.totalOriginalAdditionalRecipients
                ) {
                    continue;
                }

                // Create a new consideration Item for each Additional Recipient
                additionalRecipientItem = ConsiderationItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );

                // Calculate the EIP712 ConsiderationItem hash for
                // each additional recipients
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

            // The considerationItems array should now contain the
            // Primary Received Item along with all additional recipients.

            // The considerationHashes array now contains
            // all consideration Item hashes.

            // The consideration array now contains all receieved
            // items for OrderFulfilled Event.

            // Get hash of all consideration items
            hashes.receivedItemsHash = keccak256(
                abi.encodePacked(hashes.considerationHashes)
            );

            // Get remainder of additionalRecipients for tips
            for (
                uint256 additionalTips = parameters
                    .totalOriginalAdditionalRecipients;
                additionalTips < parameters.additionalRecipients.length;
                additionalTips++
            ) {
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[additionalTips]
                );

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

        {
            // Now let's handle the offer side.

            // Place offer item typehash on the stack.
            hashes.typeHash = _OFFER_ITEM_TYPEHASH;

            // Create Spent Item
            SpentItem memory offerItem = SpentItem(
                fulfillmentItemTypes.offeredItemType,
                parameters.offerToken,
                parameters.offerIdentifier,
                parameters.offerAmount
            );

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

    function _hashOrder(
        BasicFulfillmentHashes memory hashes,
        BasicOrderParameters calldata parameters,
        FulfillmentItemTypes memory fulfillmentItemTypes
    ) internal view returns (bytes32 orderHash) {
        // Read offerer's current nonce from storage and place on the stack.
        uint256 nonce = _nonces[parameters.offerer];

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

        // Create an array with length 1 containing the order.
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = advancedOrder;

        // Apply criteria resolvers using generated orders and details arrays.
        _applyCriteriaResolvers(advancedOrders, criteriaResolvers);

        // Retrieve the order parameters after applying criteria resolvers.
        OrderParameters memory orderParameters = advancedOrders[0].parameters;

        // Perform each item transfer with the appropriate fractional amount.
        _applyFractionsAndTransferEach(
            orderParameters,
            fillNumerator,
            fillDenominator,
            orderParameters.conduitKey,
            fulfillerConduitKey
        );

        // Emit an event signifying that the order has been fulfilled.
        _emitOrderFulfilledEvent(
            orderHash,
            orderParameters.offerer,
            orderParameters.zone,
            msg.sender,
            orderParameters.offer,
            orderParameters.consideration
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
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        bytes32 offererConduitKey,
        bytes32 fulfillerConduitKey
    ) internal {
        // Derive order duration, time elapsed, and time remaining.
        uint256 duration = orderParameters.endTime - orderParameters.startTime;
        uint256 elapsed = block.timestamp - orderParameters.startTime;
        uint256 remaining = duration - elapsed;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // As of solidity 0.6.0, inline assembly can not directly access function
        // definitions, but can still access locally scoped function variables.
        // This means that in order to recast the type of a function, we need to
        // create a local variable to reference the internal function definition
        // (using the same type) and a local variable with the desired type,
        // and then cast the original function pointer to the desired type.

        /**
         * Repurpose existing OfferItem memory regions on the offer array for
         * the order by overriding the _transfer function pointer to accept a
         * modified OfferItem argument in place of the usual ReceivedItem:
         *
         *   ========= OfferItem ==========   ====== ReceivedItem ======
         *   ItemType itemType; ------------> ItemType itemType;
         *   address token; ----------------> address token;
         *   uint256 identifierOrCriteria; -> uint256 identifier;
         *   uint256 startAmount; ----------> uint256 amount;
         *   uint256 endAmount; ------------> address recipient;
         */

        // Declare a nested scope to minimize stack depth.
        {
            // Declare a virtual function pointer taking an OfferItem argument.
            function(OfferItem memory, address, bytes32)
                internal _transferOfferItem;

            // Assign _transfer function to a new function pointer (it takes a
            // ReceivedItem as its initial argument)
            function(ReceivedItem memory, address, bytes32)
                internal _transferReceivedItem = _transfer;

            // Utilize assembly to override the virtual function pointer.
            assembly {
                // Cast initial ReceivedItem argument type to an OfferItem type.
                _transferOfferItem := _transferReceivedItem
            }

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
                // Retrieve the offer item.
                OfferItem memory offerItem = orderParameters.offer[i];

                // Apply fill fraction to derive offer item amount to transfer.
                uint256 amount = _applyFraction(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    numerator,
                    denominator,
                    elapsed,
                    remaining,
                    duration,
                    false
                );

                // TODO: Stack too deep
                //offerItem.startAmount = amount;
                //offerItem.endAmount = uint256(uint160(address(msg.sender)));

                // Utilize assembly to set overloaded offerItem arguments.
                assembly {
                    // Write derived fractional amount to startAmount as amount.
                    mstore(add(offerItem, 0x60), amount)
                    // Write fulfiller (i.e. caller) to endAmount as recipient.
                    mstore(add(offerItem, 0x80), caller())
                }

                // Reduce available value if offer spent ETH or a native token.
                if (offerItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }

                    etherRemaining -= amount;
                }

                // Transfer the item from the offerer to the caller.
                _transferOfferItem(
                    offerItem,
                    orderParameters.offerer,
                    offererConduitKey
                );
            }
        }

        /**
         * Repurpose existing ConsiderationItem memory regions on the
         * consideration array for the order by overriding the _transfer
         * function pointer to accept a modified ConsiderationItem argument in
         * place of the usual ReceivedItem:
         *
         *   ====== ConsiderationItem =====   ====== ReceivedItem ======
         *   ItemType itemType; ------------> ItemType itemType;
         *   address token; ----------------> address token;
         *   uint256 identifierOrCriteria;--> uint256 identifier;
         *   uint256 startAmount; ----------> uint256 amount;
         *   uint256 endAmount;        /----> address recipient;
         *   address recipient; ------/
         */

        // Declare a nested scope to minimize stack depth.
        {
            // Declare virtual function pointer with ConsiderationItem argument.
            function(ConsiderationItem memory, address, bytes32)
                internal _transferConsiderationItem;

            // Reassign _transfer function to a new function pointer (it takes a
            /// ReceivedItem as its initial argument).
            function(ReceivedItem memory, address, bytes32)
                internal _transferReceivedItem = _transfer;

            // Utilize assembly to override the virtual function pointer.
            assembly {
                // Cast ReceivedItem argument type to ConsiderationItem type.
                _transferConsiderationItem := _transferReceivedItem
            }

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
                    numerator,
                    denominator,
                    elapsed,
                    remaining,
                    duration,
                    true
                );

                // TODO: Stack too deep
                //considerationItem.startAmount = amount;
                //considerationItem.endAmount = uint256(uint160(address(considerationItem.recipient)));

                // Use assembly to set overloaded considerationItem arguments.
                assembly {
                    // Write derived fractional amount to startAmount as amount.
                    mstore(add(considerationItem, 0x60), amount)

                    // Write original recipient to endAmount as recipient.
                    mstore(
                        add(considerationItem, 0x80),
                        mload(add(considerationItem, 0xa0))
                    )
                }

                // Reduce available value if offer spent ETH or a native token.
                if (considerationItem.itemType == ItemType.NATIVE) {
                    // Ensure that sufficient native tokens are still available.
                    if (amount > etherRemaining) {
                        revert InsufficientEtherSupplied();
                    }

                    etherRemaining -= amount;
                }

                // Transfer item from caller to recipient specified by the item.
                _transferConsiderationItem(
                    considerationItem,
                    msg.sender,
                    fulfillerConduitKey
                );
            }
        }

        // If any ether remains after fulfillments...
        if (etherRemaining != 0) {
            // return it to the caller.
            _transferEth(payable(msg.sender), etherRemaining);
        }
    }

    /**
     * @dev Internal function to validate a group of orders, update their
     *      statuses, reduce amounts by their previously filled fractions, apply
     *      criteria resolvers, and emit OrderFulfilled events.
     *
     * @param advancedOrders    The advanced orders to validate and reduce by
     *                          their previously filled amounts.
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
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid,
        uint256 maximumFulfilled
    ) internal {
        // Read length of orders array and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Track the order hash for each order being fulfilled.
        bytes32[] memory orderHashes = new bytes32[](totalOrders);

        // Override orderHashes length to zero after memory has been allocated.
        assembly {
            mstore(orderHashes, 0)
        }

        // Iterate over each order.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the current order.
            AdvancedOrder memory advancedOrder = advancedOrders[i];

            // Determine if max number orders have already been fulfilled.
            if (maximumFulfilled == 0) {
                // Mark fill fraction as zero as the order will not be used.
                advancedOrder.numerator = 0;

                // Update the length of the orderHashes array.
                assembly {
                    mstore(orderHashes, add(i, 1))
                }

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

            // Update the length of the orderHashes array.
            assembly {
                mstore(orderHashes, add(i, 1))
            }

            // Do not track hash or adjust prices if order is not fulfilled.
            if (numerator == 0) {
                // Mark fill fraction as zero if the order is not fulfilled.
                advancedOrder.numerator = 0;

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
                // TODO: Stack too deep
                //considerationItem.startAmount = amount;
                //considerationItem.endAmount = uint256(uint160(address(considerationItem.recipient)));

                // Utilize assembly to manually "shift" the recipient value.
                assembly {
                    // Write recipient to endAmount, as endAmount is not
                    // used from this point on and can be repurposed to fit
                    // the layout of a ReceivedItem.
                    mstore(
                        add(considerationItem, 0x80), // endAmount
                        mload(add(considerationItem, 0xa0)) // recipient
                    )
                }
            }
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(advancedOrders, criteriaResolvers);

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

            // Emit an OrderFulfilled event.
            _emitOrderFulfilledEvent(
                orderHashes[i],
                orderParameters.offerer,
                orderParameters.zone,
                fulfiller,
                orderParameters.offer,
                orderParameters.consideration
            );
        }
    }

    /**
     * @dev Internal function to fulfill an arbitrary number of orders, either
     *      full or partial, after validating, adjusting amounts, and applying
     *      criteria resolvers.
     *
     * @param advancedOrders     The orders to match, including a fraction to
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
        AdvancedOrder[] memory advancedOrders,
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
                advancedOrders,
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
            // reduce the total length of the executions array.
            assembly {
                mstore(
                    executions,
                    sub(mload(executions), totalFilteredExecutions)
                )
            }
        }

        // Perform final checks and compress executions into standard and batch.
        (
            ,
            standardExecutions,
            batchExecutions
        ) = _performFinalChecksAndExecuteOrders(advancedOrders, executions);

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
        // Validate orders, apply amounts, & determine if they utilize conduits.
        _validateOrdersAndPrepareToFulfill(
            advancedOrders,
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
            advancedOrders,
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
     * @param advancedOrders            The orders to fulfill along with the
     *                                  fraction of those orders to attempt to
     *                                  fill. Note that both the offerer and the
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
        AdvancedOrder[] memory advancedOrders,
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
                advancedOrders,
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
                advancedOrders,
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
            // reduce the total length of the executions array.
            assembly {
                mstore(
                    executions,
                    sub(mload(executions), totalFilteredExecutions)
                )
            }
        }

        // Revert if no orders are available.
        if (executions.length == 0) {
            revert NoSpecifiedOrdersAvailable();
        }

        // Perform final checks, compress executions, and return.
        return _performFinalChecksAndExecuteOrders(advancedOrders, executions);
    }

    /**
     * @dev Internal function to perform a final check that each consideration
     *      item for an arbitrary number of fulfilled orders has been met and to
     *      compress and trigger associated execututions, transferring the
     *      respective items.
     *
     * @param advancedOrders     The orders to check and perform executions for.
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
        AdvancedOrder[] memory advancedOrders,
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
        uint256 totalOrders = advancedOrders.length;

        // Initialize array for tracking available orders.
        availableOrders = new bool[](totalOrders);
        // Iterate over orders to ensure all considerations are met.
        for (uint256 i = 0; i < totalOrders; ++i) {
            // Retrieve the order in question.
            AdvancedOrder memory advancedOrder = advancedOrders[i];

            // Skip consideration item checks for order if not fulfilled.
            if (advancedOrder.numerator == 0) {
                // Note: orders do not need to be marked as unavailable as a
                // new memory region has been allocated. Review carefully if
                // altering compiler version or managing memory manually.
                continue;
            }

            // Mark the order as available.
            availableOrders[i] = true;

            // Retrieve consideration items to ensure they are fulfilled.
            ConsiderationItem[] memory consideration = (
                advancedOrder.parameters.consideration
            );

            // Iterate over each consideration item to ensure it is met.
            for (uint256 j = 0; j < consideration.length; ++j) {
                // Retrieve remaining amount on the consideration item.
                uint256 unmetAmount = consideration[j].startAmount;

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

                etherRemaining -= item.amount;
            }

            // Transfer the item specified by the execution.
            _transfer(item, execution.offerer, execution.conduitKey);
        }

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

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item       The item to transfer including an amount and recipient.
     * @param offerer    The account offering the item, i.e. the from address.
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. The zero hash
     *                   signifies that no conduit should be used (and direct
     *                   approvals set on Consideration) and
     *                   `bytes32(uint256(1))` signifies to utilize the legacy
     *                   user proxy for the transfer.
     */
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        bytes32 conduitKey
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
                conduitKey
            );
        } else if (item.itemType == ItemType.ERC721) {
            // Transfer ERC721 token from the offerer to the recipient.
            _transferERC721(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey
            );
        } else {
            // Transfer ERC1155 token from the offerer to the recipient.
            _transferERC1155(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey
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
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. The zero hash
     *                   signifies that no conduit should be used (and direct
     *                   approvals set on Consideration) and
     *                   `bytes32(uint256(1))` signifies to utilize the legacy
     *                   user proxy for the transfer.
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes32 conduitKey
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform the token transfer directly.
            _performERC20Transfer(token, from, to, amount);
        } else {
            ConduitTransfer[] memory transfers = (new ConduitTransfer[](1));

            transfers[0] = ConduitTransfer(
                ConduitItemType.ERC20,
                token,
                from,
                to,
                0,
                amount
            );

            // Perform the call to the conduit.
            ConduitInterface(_getConduit(conduitKey)).execute(transfers);
        }
    }

    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective conduit or on this contract itself.
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The "amount" (this value must be equal to one).
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. The zero hash
     *                   signifies that no conduit should be used (and direct
     *                   approvals set on Consideration) and
     *                   `bytes32(uint256(1))` signifies to utilize the legacy
     *                   user proxy for the transfer.
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey
    ) internal {
        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Ensure that exactly one 721 item is being transferred.
            if (amount != 1) {
                revert InvalidERC721TransferAmount();
            }

            // Perform transfer via the token contract directly.
            _performERC721Transfer(token, from, to, identifier);
        } else {
            ConduitTransfer[] memory transfers = (new ConduitTransfer[](1));

            transfers[0] = ConduitTransfer(
                ConduitItemType.ERC721,
                token,
                from,
                to,
                identifier,
                amount
            );

            // Perform the call to the conduit.
            ConduitInterface(_getConduit(conduitKey)).execute(transfers);
        }
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective conduit or on this contract itself.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The amount to transfer.
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. The zero hash
     *                   signifies that no conduit should be used (and direct
     *                   approvals set on Consideration) and
     *                   `bytes32(uint256(1))` signifies to utilize the legacy
     *                   user proxy for the transfer.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform transfer via the token contract directly.
            _performERC1155Transfer(token, from, to, identifier, amount);
        } else {
            ConduitTransfer[] memory transfers = (new ConduitTransfer[](1));

            transfers[0] = ConduitTransfer(
                ConduitItemType.ERC1155,
                token,
                from,
                to,
                identifier,
                amount
            );

            // Perform the call to the conduit.
            ConduitInterface(_getConduit(conduitKey)).execute(transfers);
        }
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
        if (conduitKey == bytes32(0)) {
            // Perform transfer via the token contract directly.
            _performERC1155BatchTransfer(token, from, to, tokenIds, amounts);
        } else {
            ConduitBatch1155Transfer[] memory batchTransfers = (
                new ConduitBatch1155Transfer[](1)
            );

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
     * @param from        The originator of the ERC20 token transfer.
     * @param to          The recipient of the ERC20 token transfer.
     * @param erc20Token  The ERC20 token to transfer.
     * @param amount      The amount of ERC20 tokens to transfer.
     * @param parameters  The parameters of the order.
     * @param fromOfferer Whether to decrement amount from the offered amount.
     */
    function _transferERC20AndFinalize(
        address from,
        address to,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters,
        bool fromOfferer
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
                conduitKey
            );
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(erc20Token, from, to, amount, conduitKey);
    }

    /**
     * @dev Internal function to emit an OrderFulfilled event. OfferItems are
     *      translated into SpentItems and ConsiderationItems are translated
     *      into ReceivedItems.
     *
     * @param orderHash     The order hash.
     * @param offerer       The offerer for the order.
     * @param zone          The zone for the order.
     * @param fulfiller     The fulfiller of the order, or the null address if
     *                      the order was fulfilled via order matching.
     * @param offer         The offer items for the order.
     * @param consideration The consideration items for the order.
     */
    function _emitOrderFulfilledEvent(
        bytes32 orderHash,
        address offerer,
        address zone,
        address fulfiller,
        OfferItem[] memory offer,
        ConsiderationItem[] memory consideration
    ) internal {
        // Cast already-modified offer memory region as spent items.
        SpentItem[] memory spentItems;
        assembly {
            spentItems := offer
        }

        // Cast already-modified consideration memory region as received items.
        ReceivedItem[] memory receivedItems;
        assembly {
            receivedItems := consideration
        }

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderHash,
            offerer,
            zone,
            fulfiller,
            spentItems,
            receivedItems
        );
    }
}
