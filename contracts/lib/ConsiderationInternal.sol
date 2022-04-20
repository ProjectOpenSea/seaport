// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Side } from "./ConsiderationEnums.sol";

import { ERC20Interface, ERC721Interface, ERC1155Interface } from "../interfaces/AbridgedTokenInterfaces.sol";

import { ProxyInterface } from "../interfaces/AbridgedProxyInterfaces.sol";

import { OrderType, ItemType } from "./ConsiderationEnums.sol";

import { AdditionalRecipient, BasicOrderParameters, OfferItem, ConsiderationItem, SpentItem, ReceivedItem, OrderParameters, Fulfillment, FulfillmentComponent, Execution, Order, AdvancedOrder, OrderStatus, CriteriaResolver, Batch, BatchExecution } from "./ConsiderationStructs.sol";

import { ConsiderationInternalView } from "./ConsiderationInternalView.sol";

import "./ConsiderationPointers.sol";

/**
 * @title ConsiderationInternal
 * @author 0age
 * @notice ConsiderationInternal contains all internal functions.
 */
contract ConsiderationInternal is ConsiderationInternalView {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
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
    )
        ConsiderationInternalView(
            legacyProxyRegistry,
            requiredProxyImplementation
        )
    {}

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
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Ensure current timestamp falls between order start time and end time.
        _verifyTime(parameters.startTime, parameters.endTime, true);

        // Ensure calldata offsets were produced by default encoding.
        _assertValidBasicOrderParameterOffsets();

        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            parameters.additionalRecipients.length + 1,
            parameters.totalOriginalAdditionalRecipients
        );

        // Declare stack element for the order hash.
        bytes32 orderHash;

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
            bytes32 typeHash = _CONSIDERATION_ITEM_TYPEHASH;

            // Utilize assembly to enable reuse of memory regions when possible.
            assembly {
                // 1. Write first ReceivedItem hash to the consideration array.
                // Write ConsiderationItem type hash and item type to memory.
                mstore(BasicOrder_considerationItem_typeHash_ptr, typeHash)
                mstore(
                    BasicOrder_considerationItem_itemType_ptr,
                    receivedItemType
                )

                // Copy calldata region with token, identifier, and startAmount.
                calldatacopy(
                    BasicOrder_considerationItem_token_ptr,
                    BasicOrder_considerationToken_cdPtr,
                    ThreeWords
                )

                // Copy calldata region with endAmount (reused) and recipient.
                calldatacopy(
                    BasicOrder_considerationItem_endAmount_ptr,
                    BasicOrder_considerationAmount_cdPtr,
                    TwoWords
                )

                // Set keccak256(abi.encode(receivedItem)) as first item hash.
                mstore(
                    BasicOrder_considerationHashesArray_ptr,
                    keccak256(
                        BasicOrder_considerationItem_typeHash_ptr,
                        EIP712_ConsiderationItem_size
                    )
                )

                // 2. Write first ReceivedItem to OrderFulfilled data.
                // Get the length of the additional recipients array.
                let len := calldataload(
                    BasicOrder_additionalRecipients_length_cdPtr
                )

                // END_ARR + 0x120 = 0x2a0 + len*0x20
                let eventArrPtr := add(
                    OrderFulfilled_consideration_length_baseOffset,
                    mul(0x20, len)
                )
                mstore(
                    eventArrPtr,
                    add(
                        calldataload(
                            BasicOrder_additionalRecipients_length_cdPtr
                        ),
                        1
                    )
                ) // length

                // Set pointer to data portion of the initial ReceivedItem.
                eventArrPtr := add(eventArrPtr, 0x20)

                // Set item type at start of the ReceivedItem memory region.
                mstore(eventArrPtr, receivedItemType)

                // Copy calldata region (token, identifier, amount & recipient).
                calldatacopy(
                    add(eventArrPtr, 0x20),
                    BasicOrder_considerationToken_cdPtr,
                    0x80
                )

                // 3. Handle additional recipients.
                // Set pointer to current location in receivedItemHashes.
                let
                    considerationHashesPtr
                := BasicOrder_considerationHashesArray_ptr

                // Write item type, token, & identifier for additional recipient
                // to memory; these values will be reused for each recipient.
                mstore(
                    BasicOrder_considerationItem_itemType_ptr,
                    additionalRecipientsItemType
                )
                mstore(
                    BasicOrder_considerationItem_token_ptr,
                    additionalRecipientsToken
                )
                mstore(BasicOrder_considerationItem_identifier_ptr, 0)

                // Read length of the additionalRecipients array and iterate.
                len := calldataload(
                    BasicOrder_totalOriginalAdditionalRecipients_cdPtr
                )
                let i := 0
                for {

                } lt(i, len) {
                    i := add(i, 1)
                } {
                    // Retrieve pointer for additional recipient in question.
                    let additionalRecipientCdPtr := add(
                        BasicOrder_additionalRecipients_data_cdPtr,
                        mul(AdditionalRecipients_size, i)
                    )

                    // a. Write ConsiderationItem hash to consideration array.
                    // Copy startAmount from calldata.
                    calldatacopy(
                        BasicOrder_considerationItem_startAmount_ptr,
                        additionalRecipientCdPtr,
                        0x20
                    )

                    // Copy endAmount and recipient from calldata.
                    calldatacopy(
                        BasicOrder_considerationItem_endAmount_ptr,
                        additionalRecipientCdPtr,
                        AdditionalRecipients_size
                    )

                    // Add 1 word to the pointer as part of each loop to reduce
                    // operations needed to get local offset into the array.
                    considerationHashesPtr := add(considerationHashesPtr, 0x20)

                    // Set keccak256(abi.encode(receivedItem)) as next hash.
                    mstore(
                        considerationHashesPtr,
                        keccak256(
                            BasicOrder_considerationItem_typeHash_ptr,
                            EIP712_ConsiderationItem_size
                        )
                    )

                    // b. Write ReceivedItem to OrderFulfilled data.
                    // At this point, eventArrPtr points to the beginning of the
                    // ReceivedItem struct of the previous element in the array.
                    eventArrPtr := add(eventArrPtr, ReceivedItem_size)

                    // Set item type at start of the ReceivedItem memory region.
                    mstore(eventArrPtr, additionalRecipientsItemType)

                    // Set token at next word in the ReceivedItem memory region.
                    mstore(add(eventArrPtr, 0x20), additionalRecipientsToken)

                    // Copy endAmount and recipient to remaining memory region.
                    calldatacopy(
                        add(eventArrPtr, ReceivedItem_amount_offset),
                        additionalRecipientCdPtr,
                        0x40
                    )
                }

                // 4. Hash packed array of ConsiderationItem EIP712 hashes:
                //   `keccak256(abi.encodePacked(receivedItemHashes))`
                // Note that it is set at 0x60 — all other memory begins at
                // 0x80. 0x60 is the "zero slot" and will be restored at the end
                // of the assembly section and before required by the compiler.
                mstore(
                    receivedItemsHash_ptr,
                    keccak256(
                        BasicOrder_considerationHashesArray_ptr,
                        mul(add(len, 1), 32)
                    )
                )

                // 5. Write tips to event data.
                len := calldataload(
                    BasicOrder_additionalRecipients_length_cdPtr
                )
                for {

                } lt(i, len) {
                    i := add(i, 1)
                } {
                    // Retrieve pointer for additional recipient in question.
                    let additionalRecipientCdPtr := add(
                        BasicOrder_additionalRecipients_data_cdPtr,
                        mul(AdditionalRecipients_size, i)
                    )

                    // b. Write ReceivedItem to OrderFulfilled data
                    // At this point, eventArrPtr points to the beginning of the
                    // ReceivedItem struct of the previous element in the array.
                    eventArrPtr := add(eventArrPtr, ReceivedItem_size)

                    // Set item type at start of the ReceivedItem memory region.
                    mstore(eventArrPtr, additionalRecipientsItemType)

                    // Set token at next word in the ReceivedItem memory region.
                    mstore(add(eventArrPtr, 0x20), additionalRecipientsToken)

                    // Copy endAmount and recipient to remaining memory region.
                    calldatacopy(
                        add(eventArrPtr, ReceivedItem_amount_offset),
                        additionalRecipientCdPtr,
                        0x40
                    )
                }
            }
        }

        {
            /**
             * Next, handle offered items. Memory Layout:
             *  EIP712 data for OfferItem
             *   - 0x80:  OfferItem EIP-712 typehash (constant)
             *   - 0xa0:  itemType
             *   - 0xc0:  token
             *   - 0xe0:  identifier (reused for offeredItemsHash)
             *   - 0x100: startAmount
             *   - 0x120: endAmount
             */

            // Load offer item typehash from runtime code and place on stack.
            bytes32 typeHash = _OFFER_ITEM_TYPEHASH;

            // Utilize assembly to enable reuse of memory regions when possible.
            assembly {
                // 1. Calculate OfferItem EIP712 hash
                // Write OfferItem type hash and item type to memory.
                mstore(BasicOrder_offerItem_typeHash_ptr, typeHash) // _OFFERED_ITEM_TYPEHASH
                mstore(BasicOrder_offerItem_itemType_ptr, offeredItemType) // itemType

                // Copy calldata region with token, identifier, and startAmount.
                calldatacopy(
                    BasicOrder_offerItem_token_ptr,
                    BasicOrder_offerToken_cdPtr,
                    0x60
                )

                // Copy endAmount from calldata; reuses last word of prior copy.
                calldatacopy(
                    BasicOrder_offerItem_endAmount_ptr,
                    BasicOrder_offerAmount_cdPtr,
                    0x20
                )

                // Compute offer item hash and write result to scratch space:
                //   `keccak256(abi.encode(offeredItem))`
                mstore(
                    0x00,
                    keccak256(
                        BasicOrder_offerItem_typeHash_ptr,
                        EIP712_OfferItem_size
                    )
                )

                // 2. Calculate hash of array of EIP712 hashes and write the
                // result to the corresponding offer struct memory region:
                //   `keccak256(abi.encodePacked(offeredItemHashes))`
                mstore(BasicOrder_order_offerHashes_ptr, keccak256(0x00, 0x20))

                // 3. Write SpentItem array to event data.
                // 0x180 + len*32 = event data pointer, where the offer array
                // length is stored at 0x80 into the event data.
                let eventArrPtr := add(
                    OrderFulfilled_offer_length_baseOffset,
                    mul(
                        0x20,
                        calldataload(
                            BasicOrder_additionalRecipients_length_cdPtr
                        )
                    )
                )

                // Set a length of 1 for the offer array.
                mstore(eventArrPtr, 1)

                // Set offer item type at start of the SpentItem memory region.
                mstore(add(eventArrPtr, 0x20), offeredItemType)

                // Copy token, identifier, and startAmount to SpentItem region.
                calldatacopy(
                    add(eventArrPtr, AdditionalRecipients_size),
                    BasicOrder_offerToken_cdPtr,
                    ThreeWords
                )
            }
        }

        {
            /**
             * Once consideration items and offer items have been handled,
             * derive the final order hash. Memory Layout:
             *  0x80-0x1c0: EIP712 data for order
             *   - 0x80:   Order EIP-712 typehash (constant)
             *   - 0xa0:   orderParameters.offerer
             *   - 0xc0:   orderParameters.zone
             *   - 0xe0:   keccak256(abi.encodePacked(offerHashes))
             *   - 0x100:  keccak256(abi.encodePacked(considerationHashes))
             *   - 0x120:  orderParameters.basicOrderType (% 4 = orderType)
             *   - 0x140:  orderParameters.startTime
             *   - 0x160:  orderParameters.endTime
             *   - 0x180:  orderParameters.zoneHash
             *   - 0x1a0:  orderParameters.salt
             *   - 0x1c0:  orderParameters.conduit
             *   - 0x1e0:  _nonces[orderParameters.offerer] (from storage)
             */

            // Read the offerer from calldata and place on the stack.
            address offerer;
            assembly {
                offerer := calldataload(BasicOrder_offerer_cdPtr)
            }

            // Read offerer's current nonce from storage and place on the stack.
            uint256 nonce = _nonces[offerer];

            // Load order typehash from runtime code and place on stack.
            bytes32 typeHash = _ORDER_TYPEHASH;

            assembly {
                // Set the offer typehash in memory.
                mstore(BasicOrder_order_typeHash_ptr, typeHash)

                // Copy offerer and zone from calldata and set them in memory.
                calldatacopy(
                    BasicOrder_order_offerer_ptr,
                    BasicOrder_offerer_cdPtr,
                    TwoWords
                )

                // Copy receivedItemsHash from zero slot to the required region.
                mstore(
                    BasicOrder_order_considerationHashes_ptr,
                    mload(receivedItemsHash_ptr)
                )

                // Set the supplied order type in memory.
                mstore(BasicOrder_order_orderType_ptr, orderType)

                // Copy startTime, endTime, zoneHash, salt & conduit to memory.
                calldatacopy(
                    BasicOrder_order_startTime_ptr,
                    BasicOrder_startTime_cdPtr,
                    0xa0
                )

                // Take offerer's nonce retrieved from storage & set in memory.
                mstore(BasicOrder_order_nonce_ptr, nonce)

                // Compute the order hash.
                orderHash := keccak256(
                    BasicOrder_order_typeHash_ptr,
                    EIP712_Order_size
                )
            }
        }

        assembly {
            /**
             * After the order hash has been derived, emit OrderFulfilled event:
             *   event OrderFulfilled(
             *     bytes32 orderHash,
             *     address indexed offerer,
             *     address indexed zone,
             *     address fulfiller,
             *     SpentItem[] offer,
             *       > (itemType, token, id, amount)
             *     ReceivedItem[] consideration
             *       > (itemType, token, id, amount, recipient)
             *   )
             * topic0 - OrderFulfilled event signature
             * topic1 - offerer
             * topic2 - zone
             * data:
             *  - 0x00: orderHash
             *  - 0x20: fulfiller
             *  - 0x40: offer arr ptr (0x80)
             *  - 0x60: consideration arr ptr (0x120)
             *  - 0x80: offer arr len (1)
             *  - 0xa0: offer.itemType
             *  - 0xc0: offer.token
             *  - 0xe0: offer.identifier
             *  - 0x100: offer.amount
             *  - 0x120: 1 + recipients.length
             *  - 0x140: recipient 0
             */

            // Derive pointer from calldata via length of additional recipients.
            let eventDataPtr := add(
                OrderFulfilled_baseOffset,
                mul(
                    0x20,
                    calldataload(BasicOrder_additionalRecipients_length_cdPtr)
                )
            )

            // Write the order hash to the head of the event's data region.
            mstore(eventDataPtr, orderHash)

            // Write the fulfiller (i.e. the caller) next.
            mstore(add(eventDataPtr, OrderFulfilled_fulfiller_offset), caller())

            // Write the SpentItem and ReceivedItem array offsets (constants).
            mstore(
                // SpentItem array offset
                add(eventDataPtr, OrderFulfilled_offer_head_offset),
                OrderFulfilled_offer_body_offset
            )
            mstore(
                // ReceivedItem array offset
                add(eventDataPtr, OrderFulfilled_consideration_head_offset),
                OrderFulfilled_consideration_body_offset
            )

            // Derive total data size including SpentItem and ReceivedItem data.
            let dataSize := add(
                OrderFulfilled_baseSize,
                mul(
                    calldataload(BasicOrder_additionalRecipients_length_cdPtr),
                    ReceivedItem_size
                )
            )

            // Emit OrderFulfilled log with three topics (the event signature
            // as well as the two indexed arguments, the offerer and the zone).
            log3(
                // Supply the pointer for event data in memory.
                eventDataPtr,
                // Supply the size of event data in memory.
                dataSize,
                // Supply the OrderFulfilled event signature.
                0x9d9af8e38d66c62e2c12f0225249fd9d721c54b83f48d9352c97c6cacdcb6f31,
                // Supply the first topic (the offerer).
                calldataload(BasicOrder_offerer_cdPtr),
                // Supply the first topic (the zone).
                calldataload(BasicOrder_zone_cdPtr)
            )

            // Restore the zero slot.
            mstore(0x60, 0)
        }

        // Determine whether order is restricted and, if so, that it is valid.
        _assertRestrictedBasicOrderValidity(
            orderHash,
            parameters.zoneHash,
            orderType,
            parameters.offerer,
            parameters.zone
        );

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            orderHash,
            parameters.offerer,
            parameters.signature
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
                // Skip underflow check: denominator >= orderStatus.numerator
                unchecked {
                    // Reduce current numerator so it + supplied = denominator.
                    numerator = denominator - filledNumerator;
                }
            }

            // Skip overflow check: checked above unless numerator is reduced.
            unchecked {
                // Update order status and fill amount, packing struct values.
                _orderStatus[orderHash].isValidated = true;
                _orderStatus[orderHash].isCancelled = false;
                _orderStatus[orderHash].numerator = uint120(
                    filledNumerator + numerator
                );
                _orderStatus[orderHash].denominator = uint120(denominator);
            }
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
     * @param advancedOrder     The order to fulfill as well as the fraction to
     *                          fill. Note that all offer and consideration
     *                          components must divide with no remainder in
     *                          order for the partial fill to be valid.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the order's merkle
     *                          root. Note that a criteria of zero indicates
     *                          that any (transferrable) token identifier is
     *                          valid and that no proof needs to be supplied.
     * @param fulfillerConduit  An address indicating what conduit, if any, to
     *                          source the fulfiller's token approvals from. The
     *                          null address signifies that no conduit should be
     *                          used (and direct approvals set on Consideration)
     *                          and `address(1)` signifies to utilize the legacy
     *                          user proxy for the fulfiller.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        address fulfillerConduit
    ) internal returns (bool) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Declare empty bytes32 array (unused, will remain empty).
        bytes32[] memory priorOrderHashes;

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint256 fillNumerator,
            uint256 fillDenominator
        ) = _validateOrderAndUpdateStatus(
                advancedOrder,
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
            orderParameters.conduit,
            fulfillerConduit
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

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;

        return true;
    }

    /**
     * @dev Internal function to transfer each item contained in a given single
     *      order fulfillment after applying a respective fraction to the amount
     *      being transferred.
     *
     * @param orderParameters  The parameters for the fulfilled order.
     * @param numerator        A value indicating the portion of the order that
     *                         should be filled.
     * @param denominator      A value indicating the total size of the order.
     * @param offererConduit   An address indicating what conduit, if any, to
     *                         source the offerer's token approvals from. The
     *                         null address signifies that no conduit should be
     *                         used (and direct approvals set on Consideration)
     *                         and `address(1)` signifies to utilize the legacy
     *                         user proxy for the offerer.
     * @param fulfillerConduit An address indicating what conduit, if any, to
     *                         source the fulfiller's token approvals from. The
     *                         null address signifies that no conduit should be
     *                         used (and direct approvals set on Consideration)
     *                         and `address(1)` signifies to utilize the legacy
     *                         user proxy for the fulfiller.
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        address offererConduit,
        address fulfillerConduit
    ) internal {
        // @todo - add better comments
        // Derive order duration, time elapsed, and time remaining.
        uint256 duration = orderParameters.endTime - orderParameters.startTime;
        uint256 elapsed = block.timestamp - orderParameters.startTime;
        uint256 remaining = duration - elapsed;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

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

        // Declare a nested scope to access function pointers directly (required
        // as of solidity 0.6.x) in order to override _transfer argument types.
        {
            // Declare a virtual function pointer taking an OfferItem argument.
            function(OfferItem memory, address, address)
                internal _transferOfferItem;

            // Assign _transfer function to a new function pointer (it takes a
            /// ReceivedItem as its initial argument), allocating memory.
            function(ReceivedItem memory, address, address)
                internal _transferReceivedItem = _transfer;

            // Utilize assembly to override the virtual function pointer.
            assembly {
                // Cast initial ReceivedItem argument type to an OfferItem type.
                _transferOfferItem := _transferReceivedItem
            }

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < orderParameters.offer.length; ) {
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

                    // Skip underflow check as a comparison has just been made.
                    unchecked {
                        etherRemaining -= amount;
                    }
                }

                // Transfer the item from the offerer to the caller.
                _transferOfferItem(
                    offerItem,
                    orderParameters.offerer,
                    offererConduit
                );

                // Skip overflow check as for loop is indexed starting at zero.
                unchecked {
                    ++i;
                }
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

        // Declare a new nested scope to perform a type cast via function
        // pointer assignment in order to override _transfer argument types.
        {
            // Declare virtual function pointer with ConsiderationItem argument.
            function(ConsiderationItem memory, address, address)
                internal _transferConsiderationItem;

            // Reassign _transfer function to a new function pointer (it takes a
            /// ReceivedItem as its initial argument), allocating memory.
            function(ReceivedItem memory, address, address)
                internal _transferReceivedItem = _transfer;

            // Utilize assembly to override the virtual function pointer.
            assembly {
                // Cast ReceivedItem argument type to ConsiderationItem type.
                _transferConsiderationItem := _transferReceivedItem
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < orderParameters.consideration.length; ) {
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

                    // Skip underflow check as a comparison has just been made.
                    unchecked {
                        etherRemaining -= amount;
                    }
                }

                // Transfer item from caller to recipient specified by the item.
                _transferConsiderationItem(
                    considerationItem,
                    msg.sender,
                    fulfillerConduit
                );

                // Skip overflow check as for loop is indexed starting at zero.
                unchecked {
                    ++i;
                }
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
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid
    ) internal {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Read length of orders array and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Track the order hash for each order being fulfilled.
        bytes32[] memory orderHashes = new bytes32[](totalOrders);

        // Override orderHashes length to zero after memory has been allocated.
        assembly {
            mstore(orderHashes, 0)
        }

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each order.
            for (uint256 i = 0; i < totalOrders; ++i) {
                // Retrieve the current order.
                AdvancedOrder memory advancedOrder = advancedOrders[i];

                // Validate it, update status, and determine fraction to fill.
                (
                    bytes32 orderHash,
                    uint256 numerator,
                    uint256 denominator
                ) = _validateOrderAndUpdateStatus(
                        advancedOrder,
                        revertOnInvalid,
                        orderHashes
                    );

                // Update the length of the orderHashes array.
                assembly {
                    mstore(orderHashes, add(i, 1))
                }

                // Place the start time for the order on the stack.
                uint256 startTime = advancedOrder.parameters.startTime;

                // Derive the duration for the order and place it on the stack.
                uint256 duration = advancedOrder.parameters.endTime - startTime;

                // Derive time elapsed since the order started & place on stack.
                uint256 elapsed = block.timestamp - startTime;

                // Derive time remaining until order expires and place on stack.
                uint256 remaining = duration - elapsed;

                // Do not track hash or adjust prices if order is not fulfilled.
                if (numerator == 0) {
                    // Mark fill fraction as zero if the order is not fulfilled.
                    advancedOrder.numerator = 0;

                    // Continue iterating through the remaining orders.
                    continue;
                }

                // Otherwise, track the order hash in question.
                orderHashes[i] = orderHash;

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
                    ConsiderationItem memory considerationItem = (
                        consideration[j]
                    );

                    // Apply fraction to consideration item end amount.
                    uint256 endAmount = _getFraction(
                        numerator,
                        denominator,
                        considerationItem.endAmount
                    );

                    // Reuse same fraction if start and end amounts are equal.
                    if (
                        considerationItem.startAmount ==
                        considerationItem.endAmount
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
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(advancedOrders, criteriaResolvers);

        // Determine the fulfiller (revertOnInvalid ? address(0) : msg.sender).
        address fulfiller;

        // Utilize assembly to operate on revertOnInvalid boolean as an integer.
        assembly {
            // Set the fulfiller to the caller if revertOnValid is false.
            fulfiller := mul(iszero(revertOnInvalid), caller())
        }

        // Emit an event for each order signifying that it has been fulfilled.
        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
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
        // Allocate executions by fulfillment and apply them to each execution.
        Execution[] memory executions = new Execution[](fulfillments.length);

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Track number of filtered executions.
            uint256 totalFilteredExecutions = 0;

            // Iterate over each fulfillment.
            for (uint256 i = 0; i < fulfillments.length; ++i) {
                /// Retrieve the fulfillment in question.
                Fulfillment memory fulfillment = fulfillments[i];

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
    function _fulfillAvailableOrders(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        address fulfillerConduit
    )
        internal
        returns (
            bool[] memory availableOrders,
            Execution[] memory standardExecutions,
            BatchExecution[] memory batchExecutions
        )
    {
        // Allocate an execution for each offer and consideration fulfillment.
        Execution[] memory executions = new Execution[](
            offerFulfillments.length + considerationFulfillments.length
        );

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Track number of filtered executions.
            uint256 totalFilteredExecutions = 0;

            // Iterate over each offer fulfillment.
            for (uint256 i = 0; i < offerFulfillments.length; ++i) {
                /// Retrieve the offer fulfillment components in question.
                FulfillmentComponent[] memory components = offerFulfillments[i];

                // Derive aggregated execution corresponding with fulfillment.
                Execution memory execution = _aggregateAvailable(
                    advancedOrders,
                    Side.OFFER,
                    components,
                    fulfillerConduit
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
            for (uint256 i = 0; i < considerationFulfillments.length; ++i) {
                /// Retrieve consideration fulfillment components in question.
                FulfillmentComponent[] memory components = (
                    considerationFulfillments[i]
                );

                // Derive aggregated execution corresponding with fulfillment.
                Execution memory execution = _aggregateAvailable(
                    advancedOrders,
                    Side.CONSIDERATION,
                    components,
                    fulfillerConduit
                );

                // If offerer and recipient on the execution are the same...
                if (execution.item.recipient == execution.offerer) {
                    // increment total filtered executions.
                    totalFilteredExecutions += 1;
                } else {
                    // Otherwise, assign the execution to the executions array.
                    executions[
                        i + offerFulfillments.length - totalFilteredExecutions
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

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
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
        }

        // Split executions into "standard" (no batch) and "batch" executions.
        (standardExecutions, batchExecutions) = _compressExecutions(executions);

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each standard execution.
        for (uint256 i = 0; i < standardExecutions.length; ) {
            // Retrieve the execution and the associated received item.
            Execution memory execution = standardExecutions[i];
            ReceivedItem memory item = execution.item;

            // If execution transfers native tokens, reduce value available.
            if (item.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= item.amount;
                }
            }

            // Transfer the item specified by the execution.
            _transfer(item, execution.offerer, execution.conduit);

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

        // Return arrays with available orders and triggered executions.
        return (availableOrders, standardExecutions, batchExecutions);
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item    The item to transfer, including an amount and recipient.
     * @param offerer The account offering the item, i.e. the from address.
     * @param conduit An address indicating what conduit, if any, to source
     *                token approvals from. The null address signifies that no
     *                conduit should be used (and direct approvals set on
     *                Consideration) and `address(1)` signifies to utilize the
     *                legacy user proxy for the transfer.
     */
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        address conduit
    ) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // transfer the native tokens to the recipient.
            _transferEth(item.recipient, item.amount);
        } else if (item.itemType == ItemType.ERC20) {
            // For an ERC20 item...
            // Transfer ERC20 token from the offerer to the recipient.
            _transferERC20(item.token, offerer, item.recipient, item.amount);
        } else {
            // Otherwise, transfer item based on item type & conduit preference.
            if (item.itemType == ItemType.ERC721) {
                // Transfer ERC721 token from the offerer to the recipient.
                _transferERC721(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    item.amount,
                    conduit
                );
            } else {
                // Transfer ERC1155 token from the offerer to the recipient.
                _transferERC1155(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    item.amount,
                    conduit
                );
            }
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
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        // If the call fails...
        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            revert EtherTransferGenericFailure(to, amount);
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on this
     *      contract (note that proxies are not utilized for ERC20 items).
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // Write calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write calldata into memory, starting with function selector.
            mstore(
                0,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(0x04, from) // Append the "from" argument.
            mstore(0x24, to) // Append the "to" argument.
            mstore(0x44, amount) // Append the "amount" argument.

            // Use 100 as the length of calldata equals 4 + 32 * 3. Use 0 and 32
            // to copy up to 32 bytes of return data to scratch space.
            let callStatus := call(gas(), token, 0, 0, 0x64, 0, 0x20)

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.

            let success := and(
                // Set success to whether the call reverted, if not check it
                // either returned exactly 1 (can't just be non-zero data), or
                // had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                callStatus
            )

            // If the transfer failed or it returned nothing:
            // Group these because they should be uncommon.
            if iszero(and(success, iszero(iszero(returndatasize())))) {
                // If the token has no code or the transfer failed:
                if iszero(and(iszero(iszero(extcodesize(token))), success)) {
                    // If the transfer failed:
                    if iszero(success) {
                        // If it was due to a revert:
                        if iszero(callStatus) {
                            // If it returned a message, bubble it up:
                            if returndatasize() {
                                // Copy returndata to memory; overwrite existing memory.
                                returndatacopy(0, 0, returndatasize())

                                // Revert, specifying memory region with copied returndata.
                                revert(0, returndatasize())
                            }

                            // Otherwise revert with a generic error message.
                            mstore(
                                0,
                                // abi.encodeWithSignature("TokenTransferGenericFailure(address,address,address,uint256,uint256)")
                                0xf486bc8700000000000000000000000000000000000000000000000000000000
                            )
                            mstore(0x04, token)
                            mstore(0x24, from)
                            mstore(0x44, to)
                            mstore(0x64, 0)
                            mstore(0x84, amount)

                            revert(0, 0xA4) // Use 164 because its the result of 4 + 32 * 5.
                        }

                        // Otherwise revert with a message about the token returning false.
                        mstore(
                            0,
                            // abi.encodeWithSignature("BadReturnValueFromERC20OnTransfer(address,address,address,uint256)")
                            0x9889192300000000000000000000000000000000000000000000000000000000
                        )
                        mstore(0x04, token)
                        mstore(0x24, from)
                        mstore(0x44, to)
                        mstore(0x64, amount)

                        revert(0, 0x84) // Use 132 because its the result of 4 + 32 * 4.
                    }

                    // Otherwise revert with a generic error message.
                    mstore(
                        0,
                        // abi.encodeWithSignature("TokenTransferGenericFailure(address,address,address,uint256,uint256)")
                        0xf486bc8700000000000000000000000000000000000000000000000000000000
                    )
                    mstore(0x04, token)

                    revert(0, 0x24) // Use 36 because its the result of 4 + 32.
                }

                // Otherwise the token just returned nothing but otherwise
                // succeeded — no need to optimize for this as it's not
                // technically ERC20 compliant.
            }
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
     * @param conduit    An address indicating what conduit, if any, to source
     *                   token approvals from. The null address signifies that
     *                   no conduit should be used (and direct approvals set on
     *                   Consideration) and `address(1)` signifies to utilize
     *                   the legacy user proxy for the transfer.
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address conduit
    ) internal {
        // Ensure that exactly one 721 item is being transferred.
        if (amount != 1) {
            revert InvalidERC721TransferAmount();
        }

        // If no conduit has been specified...
        if (conduit == address(0)) {
            // Perform transfer via the token contract directly.
            assembly {
                // If the token has no code, revert.
                if iszero(extcodesize(token)) {
                    mstore(
                        0,
                        // abi.encodeWithSignature("NoContract(address)")
                        0x5f15d67200000000000000000000000000000000000000000000000000000000
                    )
                    mstore(4, token)

                    revert(0, 0x24) // Use 36 because it equals 4 + 32.
                }

                // We'll write calldata to this slot.
                let memPointer := mload(0x40)

                // Write calldata into memory starting with function selector.
                mstore(
                    memPointer,
                    0x23b872dd00000000000000000000000000000000000000000000000000000000
                )
                mstore(add(memPointer, 0x04), from) // Append "from" argument.
                mstore(add(memPointer, 0x24), to) // Append the "to" argument.
                mstore(add(memPointer, 0x44), identifier) // Append identifier.

                // Use 100 as length of calldata equals 4 + 32 * 3. Use 0 and 32
                // to copy up to 32 bytes of return data into scratch space.
                let success := call(gas(), token, 0, memPointer, 0x64, 0, 0)

                // If the transfer reverted:
                if iszero(success) {
                    // If it returned a message, bubble it up:
                    if returndatasize() {
                        // Copy returndata to memory; overwrite existing memory.
                        returndatacopy(0, 0, returndatasize())

                        // Revert, specifying memory region with returndata.
                        revert(0, returndatasize())
                    }

                    // Otherwise revert with a generic error message.
                    mstore(
                        0,
                        // abi.encodeWithSignature("TokenTransferGenericFailure(address,address,address,uint256,uint256)")
                        0xf486bc8700000000000000000000000000000000000000000000000000000000
                    )
                    mstore(0x04, token)
                    mstore(0x24, from)
                    mstore(0x44, to)
                    mstore(0x64, identifier)
                    mstore(0x84, amount)

                    revert(0, 0xa4) // Use 164 as it equals 4 + 32 * 5.
                }
            }
        } else if (conduit == address(1)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            bool success = _callProxy(
                from,
                token,
                abi.encodeCall(
                    ERC721Interface.transferFrom,
                    (from, to, identifier)
                )
            );

            // Ensure that the transfer succeeded.
            _assertValidTokenTransfer(
                success,
                token,
                from,
                to,
                identifier,
                amount
            );
        } else {
            revert("Not yet implemented");
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
     * @param conduit    An address indicating what conduit, if any, to source
     *                   token approvals from. The null address signifies that
     *                   no conduit should be used (and direct approvals set on
     *                   Consideration) and `address(1)` signifies to utilize
     *                   the legacy user proxy for the transfer.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address conduit
    ) internal {
        // If no conduit has been specified...
        if (conduit == address(0)) {
            // Perform transfer via the token contract directly.
            assembly {
                // If the token has no code, revert.
                if iszero(extcodesize(token)) {
                    mstore(
                        0,
                        // abi.encodeWithSignature("NoContract(address)")
                        0x5f15d67200000000000000000000000000000000000000000000000000000000
                    )
                    mstore(4, token)

                    revert(0, 36) // Use 36 as it equals 4 + 32.
                }

                // We'll write calldata to this slot.
                let memPointer := mload(0x40)

                // Write calldata into memory, beginning with function selector.
                mstore(
                    memPointer,
                    0xf242432a00000000000000000000000000000000000000000000000000000000
                )
                mstore(add(memPointer, 0x04), from) // Append the "from" argument.
                mstore(add(memPointer, 0x24), to) // Append the "to" argument.
                mstore(add(memPointer, 0x44), identifier) // Append the "identifier" argument.
                mstore(add(memPointer, 0x64), amount) // Append the "amount" argument.
                mstore(add(memPointer, 0x84), 0xa0) // Append "data" argument offset.
                mstore(add(memPointer, 0xa4), 0) // Append "data" argument length.

                // Use 164 because length of calldata equals 4 + 32 * 6.
                let success := call(gas(), token, 0, memPointer, 0xc4, 0, 0)

                // If the transfer reverted:
                if iszero(success) {
                    // If it returned a message, bubble it up:
                    if returndatasize() {
                        // Copy returndata to memory, overwriting existing memory.
                        returndatacopy(0, 0, returndatasize())

                        // Revert, specifying memory region with copied returndata.
                        revert(0, returndatasize())
                    }

                    // Otherwise revert with a generic error message.
                    mstore(
                        0,
                        // abi.encodeWithSignature("TokenTransferGenericFailure(address,address,address,uint256,uint256)")
                        0xf486bc8700000000000000000000000000000000000000000000000000000000
                    )
                    mstore(0x04, token)
                    mstore(0x24, from)
                    mstore(0x44, to)
                    mstore(0x64, identifier)
                    mstore(0x84, amount)

                    revert(0, 0xa4) // Use 164 as it equals 4 + 32 * 5.
                }
            }
        } else if (conduit == address(1)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            bool success = _callProxy(
                from,
                token,
                abi.encodeWithSelector(
                    ERC1155Interface.safeTransferFrom.selector,
                    from,
                    to,
                    identifier,
                    amount,
                    ""
                )
            );

            // Ensure that the transfer succeeded.
            _assertValidTokenTransfer(
                success,
                token,
                from,
                to,
                identifier,
                amount
            );
        } else {
            revert("Not yet implemented");
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
        address conduit = batchExecution.conduit;
        address token = batchExecution.token;
        address from = batchExecution.from;
        address to = batchExecution.to;

        // Retrieve the tokenIds and amounts.
        uint256[] memory tokenIds = batchExecution.tokenIds;
        uint256[] memory amounts = batchExecution.amounts;

        bool success;

        // If no conduit has been specified...
        if (conduit == address(0)) {
            // Perform transfer via the token contract directly.
            (success, ) = token.call(
                abi.encodeWithSelector(
                    ERC1155Interface.safeBatchTransferFrom.selector,
                    from,
                    to,
                    tokenIds,
                    amounts,
                    ""
                )
            );
        } else if (conduit == address(1)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            success = _callProxy(
                from,
                token,
                abi.encodeWithSelector(
                    ERC1155Interface.safeBatchTransferFrom.selector,
                    from,
                    to,
                    tokenIds,
                    amounts,
                    ""
                )
            );
        } else {
            revert("Not yet implemented");
        }

        // If the call fails...
        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic 1155 batch transfer error.
            revert ERC1155BatchTransferGenericFailure(
                token,
                from,
                to,
                tokenIds,
                amounts
            );
        }

        // Ensure that a contract is deployed to the token address.
        _assertContractIsDeployed(token);
    }

    /**
     * @dev Internal function to trigger a call to a proxy contract. The proxy
     *      contract must be registered on the legacy proxy registry for the
     *      given proxy owner and must declare that its implementation matches
     *      the required proxy implementation in accordance with EIP-897.
     *
     * @param proxyOwner The original owner of the proxy in question. Note that
     *                   this owner may have been modified since the proxy was
     *                   originally deployed.
     * @param target     The account that should be called by the proxy.
     * @param callData   The calldata to supply when calling the target from the
     *                   proxy.
     *
     * @return success The status of the call to the proxy.
     */
    function _callProxy(
        address proxyOwner,
        address target,
        bytes memory callData
    ) internal returns (bool success) {
        // Retrieve the user proxy from the registry assuming one is set.
        address proxy = _LEGACY_PROXY_REGISTRY.proxies(proxyOwner);

        // Assert that the user proxy has the correct implementation.
        if (
            ProxyInterface(proxy).implementation() !=
            _REQUIRED_PROXY_IMPLEMENTATION
        ) {
            revert InvalidProxyImplementation();
        }

        // perform call to proxy via proxyAssert and HowToCall = CALL (value 0).
        (success, ) = proxy.call(
            abi.encodeWithSelector(
                ProxyInterface.proxyAssert.selector,
                target,
                0,
                callData
            )
        );
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
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ) {
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

            // Skip underflow check as subtracted value is less than remaining.
            unchecked {
                // Reduce ether value available.
                etherRemaining -= additionalRecipientAmount;
            }

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Ensure that sufficient Ether is still available.
        if (amount > etherRemaining) {
            revert InsufficientEtherSupplied();
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

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
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
        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ) {
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
                additionalRecipient.amount
            );

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                ++i;
            }
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(erc20Token, from, to, amount);

        // Clear the reentrancy guard.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Internal function to ensure that the sentinel value for the
     *      reentrancy guard is not currently set and, if not, to set the
     *      sentinel value for the reentrancy guard.
     */
    function _setReentrancyGuard() internal {
        // Ensure that the reentrancy guard is not already set.
        _assertNonReentrant();

        // Set the reentrancy guard.
        _reentrancyGuard = _ENTERED;
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
