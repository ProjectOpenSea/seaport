// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { Side } from "./ConsiderationEnums.sol";

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import { ProxyInterface } from "../interfaces/AbridgedProxyInterfaces.sol";

import {
    OrderType,
    ItemType
} from "./ConsiderationEnums.sol";

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
    BatchExecution,
    FulfillmentDetail
} from "./ConsiderationStructs.sol";

import { ConsiderationInternalView } from "./ConsiderationInternalView.sol";

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
    ) ConsiderationInternalView(
        legacyProxyRegistry,
        requiredProxyImplementation
    ) {}

  /**
   * @dev Internal function to prepare fulfillment of a basic order with manual
   *      calldata and memory access. This calculates the order hash, emits an
   *      OrderFulfilled event, and asserts basic order validity. Note that
   *      calldata offsets must be validated as this function accesses constant
   *      calldata pointers for dynamic types that match default ABI encoding,
   *      but valid ABI encoding can use arbitrary offsets. Checking that the
   *      offsets were produced by default encoding will ensure that other
   *      functions using Solidity's calldata accessors (which calculate
   *      pointers from the stored offsets) are reading the same data as the
   *      order hash is derived from. Also note that This function accesses
   *      memory directly. It does not clear the expanded memory regions used,
   *      nor does it update the free memory pointer, so other direct memory
   *      access must not assume that unused memory is empty.
   */
  function _prepareBasicFulfillmentFromCalldata(
    BasicOrderParameters calldata parameters,
    ItemType receivedItemType,
    ItemType additionalRecipientsItemType,
    address additionalRecipientsToken,
    ItemType offeredItemType
  ) internal returns (bytes32 orderHash, bool useOffererProxy) {
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

    { // Load consideration item typehash from runtime code and place on stack.
      bytes32 typeHash = _CONSIDERATION_ITEM_TYPEHASH;

      assembly {
        /* Memory Layout
         * 0x60: hash of considerations array
         * 0x80-0x160: reused space for EIP712 hashing of considerations
         * - 0x80: _RECEIVED_ITEM_TYPEHASH
         * - 0xa0: itemType
         * - 0xc0: token
         * - 0xe0: identifier
         * - 0x100: startAmount
         * - 0x120: endAmount
         * - 0x140: recipient
         * - 0x160-END_ARR: array of consideration hashes
         *                  (END_ARR = 0x180 + RECIPIENTS_LENGTH * 0x20)
         * - 0x160: EIP712 hash of primary consideration
         * - 0x180-END_ARR: EIP712 hashes of additional recipient considerations
         * END_ARR: beginning of data for OrderFulfilled event
         * END_ARR + 0x120: length of ReceivedItem array
         * END_ARR + 0x140: beginning of data for first ReceivedItem
         */
        /* 1. Write first ReceivedItem hash to order's considerations array */
        // Write type hash and item type
        mstore(0x80, typeHash)
        mstore(0xa0, receivedItemType)
        // Copy (token, identifier, startAmount)
        calldatacopy(0xc0, 0x24, 0x60)
        // Copy (endAmount, recipient)
        calldatacopy(0x120, 0x64, 0x40)
        // receivedItemHashes[0] = keccak256(abi.encode(receivedItem))
        mstore(0x160, keccak256(0x80, 0xe0))

        /* 2. Write first ReceivedItem to OrderFulfilled data */
        let len := calldataload(0x224)
        // END_ARR + 0x120 = 0x2a0 + len*0x20
        let eventArrPtr := add(0x2a0, mul(0x20, len))
        mstore(eventArrPtr, add(calldataload(0x224), 1)) // length
        // Set ptr to data portion of first ReceivedItem
        eventArrPtr := add(eventArrPtr, 0x20)
        // Write item type
        mstore(eventArrPtr, receivedItemType)
        // Copy (token, identifier, amount, recipient)
        calldatacopy(add(eventArrPtr, 0x20), 0x24, 0x80)

        /* 3. Handle additional recipients */
        // ptr to current place in receivedItemHashes
        let considerationHashesPtr := 0x160
        // Write type, token, identifier for additional recipients memory
        // which will be reused for each recipient
        mstore(0xa0, additionalRecipientsItemType)
        mstore(0xc0, additionalRecipientsToken)
        mstore(0xe0, 0)
        len := calldataload(0x1c4)
        let i := 0
        for {} lt(i, len) {i := add(i, 1)} {
          let additionalRecipientCdPtr := add(0x244, mul(0x40, i))

          /* a. Write ConsiderationItem hash to order's considerations array */
          // Copy startAmount
          calldatacopy(0x100, additionalRecipientCdPtr, 0x20)
          // Copy endAmount, recipient
          calldatacopy(0x120, additionalRecipientCdPtr, 0x40)
          // note: Add 1 word to the pointer each loop to reduce ops
          // needed to get local offset into the array
          considerationHashesPtr := add(considerationHashesPtr, 0x20)
          // receivedItemHashes[i + 1] = keccak256(abi.encode(receivedItem))
          mstore(considerationHashesPtr, keccak256(0x80, 0xe0))

          /* b. Write ReceivedItem to OrderFulfilled data */
          // At this point, eventArrPtr points to the beginning of the
          // ReceivedItem struct for the previous element in the array.
          eventArrPtr := add(eventArrPtr, 0xa0)
          // Write item type
          mstore(eventArrPtr, additionalRecipientsItemType)
          // Write token
          mstore(add(eventArrPtr, 0x20), additionalRecipientsToken)
          // Copy endAmount, recipient
          calldatacopy(add(eventArrPtr, 0x60), additionalRecipientCdPtr, 0x40)
        }
        /* 4. Hash packed array of ConsiderationItem EIP712 hashes */
        // note: Store at 0x60 - all other memory begins at 0x80
        // keccak256(abi.encodePacked(receivedItemHashes))
        mstore(0x60, keccak256(0x160, mul(add(len, 1), 32)))
        /* 5. Write tips to event data */
        len := calldataload(0x224)
        for {} lt(i, len) {i := add(i, 1)} {
          let additionalRecipientCdPtr := add(0x244, mul(0x40, i))

          /* b. Write ReceivedItem to OrderFulfilled data */
          // At this point, eventArrPtr points to the beginning of the
          // ReceivedItem struct for the previous element in the array.
          eventArrPtr := add(eventArrPtr, 0xa0)
          // Write item type
          mstore(eventArrPtr, additionalRecipientsItemType)
          // Write token
          mstore(add(eventArrPtr, 0x20), additionalRecipientsToken)
          // Copy endAmount, recipient
          calldatacopy(add(eventArrPtr, 0x60), additionalRecipientCdPtr, 0x40)
        }
      }
    }

    { // Handle offered items
      /* Memory Layout
       * EIP712 data for OfferItem
       * - 0x80:  _OFFERED_ITEM_TYPEHASH
       * - 0xa0:  itemType
       * - 0xc0:  token
       * - 0xe0:  identifier (reused for offeredItemsHash)
       * - 0x100: startAmount
       * - 0x120: endAmount
       */
      bytes32 typeHash = _OFFER_ITEM_TYPEHASH;
      assembly {
        /* 1. Calculate OfferItem EIP712 hash*/
        mstore(0x80, typeHash) // _OFFERED_ITEM_TYPEHASH
        mstore(0xa0, offeredItemType) // itemType
        calldatacopy(0xc0, 0xc4, 0x60) // (token, identifier, startAmount)
        calldatacopy(0x120, 0x104, 0x20) // endAmount
        // note: Write offered item hash to scratch space
        // keccak256(abi.encode(offeredItem))
        mstore(0x00, keccak256(0x80, 0xc0))
        /* 2. Calculate hash of array of EIP712 hashes */
        // note: Write offeredItemsHash to offer struct
        // keccak256(abi.encodePacked(offeredItemHashes))
        mstore(0xe0, keccak256(0x00, 0x20))
        /* 3. Write SpentItem array to event data */
        // 0x180 + len*32 = event data ptr
        // offers array length is stored at 0x80 into the event data
        let eventArrPtr := add(0x200, mul(0x20, calldataload(0x224)))
        mstore(eventArrPtr, 1)
        mstore(add(eventArrPtr, 0x20), offeredItemType)
        // Copy token, identifier, startAmount to SpentItem
        calldatacopy(
          add(eventArrPtr, 0x40),
          0xc4,
          0x60
        )
      }
    }
    { // Calculate order hash
      address offerer;
      address zone;
      assembly {
        offerer := calldataload(0x84)
        zone := calldataload(0xa4)
      }
      uint256 nonce = _nonces[offerer][zone];
      bytes32 typeHash = _ORDER_HASH;
      assembly {
        /* Memory Layout
         * 0x80-0x1c0: EIP712 data for order
         * - 0x80:    _ORDER_HASH,
         * - 0xa0:    orderParameters.offerer,
         * - 0xc0:    orderParameters.zone,
         * - 0xe0:    keccak256(abi.encodePacked(offerHashes)),
         * - 0x100:   keccak256(abi.encodePacked(considerationHashes)),
         * - 0x120:   orderParameters.orderType,
         * - 0x140:   orderParameters.startTime,
         * - 0x160:   orderParameters.endTime,
         * - 0x180:   orderParameters.salt,
         * - 0x1a0:   nonce
         */
        mstore(0x80, typeHash)
        // Copy offerer and zone
        calldatacopy(0xa0, 0x84, 0x40)
        // load receivedItemsHash from zero slot
        mstore(0x100, mload(0x60))
        // orderType, startTime, endTime, salt
        calldatacopy(0x120, 0x124, 0x80)
        mstore(0x1a0, nonce) // nonce
        orderHash := keccak256(0x80, 0x140)
      }
    }
    /* event OrderFulfilled(
     *   bytes32 orderHash,
     *   address indexed offerer,
     *   address indexed zone,
     *   address fulfiller,
     *   SpentItem[] offer, (itemType, token, id, amount)
     *   ReceivedItem[] consideration (itemType, token, id, amount, recipient)
     * )
     * topic0 - OrderFulfilled event signature
     * topic1 - offerer
     * topic2 - zone
     * data
     * 0x00: orderHash
     * 0x20: fulfiller
     * 0x40: offer arr ptr (0x80)
     * 0x60: consideration arr ptr (0x120)
     * 0x80: offer arr len (1)
     * 0xa0: offer.itemType
     * 0xc0: offer.token
     * 0xe0: offer.identifier
     * 0x100: offer.amount
     * 0x120: 1 + recipients.length
     * 0x140: recipient 0
     */
    assembly {
      let eventDataPtr := add(0x180, mul(0x20, calldataload(0x224)))
      mstore(eventDataPtr, orderHash)           // orderHash
      mstore(add(eventDataPtr, 0x20), caller()) // fulfiller
      mstore(add(eventDataPtr, 0x40), 0x80)     // SpentItem array pointer
      mstore(add(eventDataPtr, 0x60), 0x120)    // ReceivedItem array pointer
      let dataSize := add(0x1e0, mul(calldataload(0x224), 0xa0))
      log3(
        eventDataPtr,
        dataSize,
        // OrderFulfilled event signature
        0x9d9af8e38d66c62e2c12f0225249fd9d721c54b83f48d9352c97c6cacdcb6f31,
        // topic1 - offerer
        calldataload(0x84),
        // topic2 - zone
        calldataload(0xa4)
      )
      /* Restore the zero slot */
      mstore(0x60, 0)
    }

    // Verify and update the status of the derived order.
    _validateBasicOrderAndUpdateStatus(
        orderHash,
        parameters.offerer,
        parameters.signature
    );

    // Determine if a proxy should be utilized and ensure a valid submitter.
    useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
        parameters.orderType,
        parameters.offerer,
        parameters.zone
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
            _verifySignature(
                offerer, orderHash, signature
            );
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
     * @param advancedOrder   The order to fulfill as well as the fraction to
     *                        fill. Note that all offer and consideration
     *                        amounts must divide with no remainder in order for
     *                        a partial fill to be valid.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order is invalid due to the time or order status.
     *
     * @return orderHash       The order hash.
     * @return newNumerator    A value indicating the portion of the order that
     *                         will be filled.
     * @return newDenominator  A value indicating the total size of the order.
     * @return useOffererProxy A boolean indicating whether to utilize the
     *                         offerer's proxy.
     */
    function _validateOrderAndUpdateStatus(
        AdvancedOrder memory advancedOrder,
        bool revertOnInvalid
    ) internal returns (
        bytes32 orderHash,
        uint256 newNumerator,
        uint256 newDenominator,
        bool useOffererProxy
    ) {
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
            return (bytes32(0), 0, 0, false);
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
            revert PartialFillsNotEnabledForOrder();
        }

        // Retrieve current nonce and use it w/ parameters to derive order hash.
        orderHash = _assertConsiderationLengthAndGetNoncedOrderHash(
            orderParameters
        );

        // Determine if a proxy should be utilized and ensure a valid submitter.
        useOffererProxy = _determineProxyUtilizationAndEnsureValidSubmitter(
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
            return (orderHash, 0, 0, useOffererProxy);
        }

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                orderParameters.offerer, orderHash, advancedOrder.signature
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
            } // Otherwise, if supplied denominator differs from current one...
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
        return (orderHash, numerator, denominator, useOffererProxy);
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
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) internal returns (bool) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Validate order, update status, and determine fraction to fill.
        (
            bytes32 orderHash,
            uint256 fillNumerator,
            uint256 fillDenominator,
            bool useOffererProxy
        ) = _validateOrderAndUpdateStatus(advancedOrder, true);

        // Apply criteria resolvers (requires array of orders to be supplied).
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = advancedOrder;
        _applyCriteriaResolvers(orders, criteriaResolvers);

        // Retrieve the parameters of the order.
        OrderParameters memory orderParameters = orders[0].parameters;

        // Perform each item transfer with the appropriate fractional amount.
        _applyFractionsAndTransferEach(
            orderParameters,
            fillNumerator,
            fillDenominator,
            useOffererProxy,
            useFulfillerProxy
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
     * @param orderParameters   The parameters for the fulfilled order.
     * @param numerator         A value indicating the portion of the order that
     *                          should be filled.
     * @param denominator       A value indicating the total size of the order.
     * @param useOffererProxy   A flag indicating whether to source approvals
     *                          for offered tokens from an associated proxy.
     * @param useFulfillerProxy A flag indicating whether to source approvals
     *                          for fulfilled tokens from an associated proxy.
     */
    function _applyFractionsAndTransferEach(
        OrderParameters memory orderParameters,
        uint256 numerator,
        uint256 denominator,
        bool useOffererProxy,
        bool useFulfillerProxy
    ) internal {
        // Derive order duration, time elapsed, and time remaining.
        uint256 duration = orderParameters.endTime - orderParameters.startTime;
        uint256 elapsed = block.timestamp - orderParameters.startTime;
        uint256 remaining = duration - elapsed;

        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < orderParameters.offer.length;) {
            // Retrieve the offer item.
            OfferItem memory offerItem = orderParameters.offer[i];

            // Derive amount to transfer of offer item and return received item.
            ReceivedItem memory item = _applyFractionToOfferItem(
                offerItem,
                numerator,
                denominator,
                elapsed,
                remaining,
                duration
            );

            // If offer expects ETH or a native token, reduce value available.
            if (offerItem.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= item.amount;
                }
            }

            // Transfer the item from the offerer to the caller.
            _transfer(
                item,
                orderParameters.offerer,
                useOffererProxy
            );

            // Update offer amount so that an accurate event can be emitted.
            offerItem.endAmount = item.amount;

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // Iterate over each consideration on the order.
        for (uint256 i = 0; i < orderParameters.consideration.length;) {
            // Retrieve the consideration item.
            ConsiderationItem memory considerationItem = (
                orderParameters.consideration[i]
            );

            // Get consideration item transfer amount and return received item.
            ReceivedItem memory item = _applyFractionToConsiderationItem(
                considerationItem,
                numerator,
                denominator,
                elapsed,
                remaining,
                duration
            );

            // If item expects ETH or a native token, reduce value available.
            if (considerationItem.itemType == ItemType.NATIVE) {
                // Ensure that sufficient native tokens are still available.
                if (item.amount > etherRemaining) {
                    revert InsufficientEtherSupplied();
                }

                // Skip underflow check as amount is less than ether remaining.
                unchecked {
                    etherRemaining -= item.amount;
                }
            }

            // Transfer the item from the caller to the consideration recipient.
            _transfer(
                item,
                msg.sender,
                useFulfillerProxy
            );

            // Update consideration item amount for use in the emitted event.
            considerationItem.endAmount = item.amount;

            // Skip overflow check as for loop is indexed starting at zero.
            unchecked {
                 ++i;
            }
        }

        // If any ether remains after fulfillments, return it to the caller.
        if (etherRemaining != 0) {
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
     * @param revertOnInvalid   A boolean indicating whether to revert if the
     *                          order is invalid due to the time or order
     *                          status.
     *
     * @return fulfillOrdersAndUseProxy A array of FulfillmentDetail structs,
     *                                  each indicating whether to fulfill the
     *                                  order and whether to use a proxy for it.
     */
    function _validateOrdersAndPrepareToFulfill(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers,
        bool revertOnInvalid
    ) internal returns (FulfillmentDetail[] memory fulfillOrdersAndUseProxy) {
        // Ensure this function cannot be triggered during a reentrant call.
        _setReentrancyGuard();

        // Read length of orders array and place on the stack.
        uint256 totalOrders = advancedOrders.length;

        // Use total orders to declare memory region for order fulfillment info.
        fulfillOrdersAndUseProxy = new FulfillmentDetail[](totalOrders);

        // Track the order hash for each order being fulfilled.
        bytes32[] memory orderHashes = new bytes32[](totalOrders);

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
                    uint256 denominator,
                    bool useOffererProxy
                ) = _validateOrderAndUpdateStatus(
                    advancedOrder,
                    revertOnInvalid
                );

                // Determine if order should be fulfilled based on numerator.
                bool shouldBeFulfilled = numerator != 0;

                // Mark whether to fulfill the order and to use offerer's proxy.
                fulfillOrdersAndUseProxy[i] = FulfillmentDetail(
                    shouldBeFulfilled,
                    useOffererProxy
                );

                // Do not track hash or adjust prices if order is not fulfilled.
                if (!shouldBeFulfilled) {
                    continue;
                }

                // Otherwise, track the order hash in question.
                orderHashes[i] = orderHash;

                // Retrieve offer items and consideration items on the order.
                OfferItem[] memory offer = advancedOrder.parameters.offer;
                ConsiderationItem[] memory consideration = (
                    advancedOrder.parameters.consideration
                );

                // Iterate over each offer item on the order.
                for (uint256 j = 0; j < offer.length; ++j) {
                    // Retrieve the offer item.
                    OfferItem memory item = offer[j];

                    // Reuse same fraction if start and end amounts are equal.
                    if (item.startAmount == item.endAmount) {
                        // Derive the fractional amount based on the end amount.
                        uint256 amount = _getFraction(
                            numerator, denominator, item.endAmount
                        );

                        // Apply derived amount to both start and end amount.
                        item.startAmount = amount;
                        item.endAmount = amount;
                    } else {
                        // Apply order fill fraction to offer item start amount.
                        item.startAmount = _getFraction(
                            numerator, denominator, item.startAmount
                        );

                        // Apply order fill fraction to offer item end amount.
                        item.endAmount = _getFraction(
                            numerator, denominator, item.endAmount
                        );
                    }
                }

                // Iterate over each consideration item on the order.
                for (uint256 j = 0; j < consideration.length; ++j) {
                    // Retrieve the consideration item.
                    ConsiderationItem memory item = consideration[j];

                    // Reuse same fraction if start and end amounts are equal.
                    if (item.startAmount == item.endAmount) {
                        // Derive the fractional amount based on the end amount.
                        uint256 amount = _getFraction(
                            numerator, denominator, item.endAmount
                        );

                        // Apply derived amount to both start and end amount.
                        item.startAmount = amount;
                        item.endAmount = amount;
                    } else {
                        // Apply fraction to consideration item start amount.
                        item.startAmount = _getFraction(
                            numerator, denominator, item.startAmount
                        );

                        // Apply fraction to consideration item end amount.
                        item.endAmount = _getFraction(
                            numerator, denominator, item.endAmount
                        );
                    }
                }

                // Adjust prices based on time, start amount, and end amount.
                _adjustAdvancedOrderPrice(advancedOrder);
            }
        }

        // Apply criteria resolvers to each order as applicable.
        _applyCriteriaResolvers(advancedOrders, criteriaResolvers);

        // Emit an event for each order signifying that it has been fulfilled.
        unchecked {
            for (uint256 i = 0; i < totalOrders; ++i) {
                // Do not emit an event if no order hash is present.
                if (orderHashes[i] == bytes32(0)) {
                    continue;
                }

                // Retrieve parameters for the order in question.
                OrderParameters memory orderParameters = (
                    advancedOrders[i].parameters
                );

                // Emit an OrderFulfilled event (supply fulfiller on no revert).
                _emitOrderFulfilledEvent(
                    orderHashes[i],
                    orderParameters.offerer,
                    orderParameters.zone,
                    revertOnInvalid ? address(0) : msg.sender,
                    orderParameters.offer,
                    orderParameters.consideration
                );
            }
        }

        // Return memory region tracking orders to fulfill and use proxies for.
        return fulfillOrdersAndUseProxy;
    }

    /**
     * @dev Internal function to fulfill an arbitrary number of orders, either
     *      full or partial, after validating, adjusting amounts, and applying
     *      criteria resolvers.
     *
     * @param advancedOrders           The orders to match, including a fraction
     *                                 to attempt to fill for each order.
     * @param fulfillments             An array of elements allocating offer
     *                                 components to consideration components.
     *                                 Note that the end amount of each
     *                                 consideration component must be zero in
     *                                 order for a match operation to be valid.
     * @param fulfillOrdersAndUseProxy An array of FulfillmentDetail structs
     *                                 indicating whether to fulfill the order
     *                                 and whether to source approvals for the
     *                                 fulfilled tokens on each order from their
     *                                 respective proxy. Note that all orders
     *                                 will fulfill on calling this function.
     *
     * @return An array of elements indicating the sequence of non-batch
     *         transfers performed as part of matching the given orders.
     * @return An array of elements indicating the sequence of batch transfers
     *         performed as part of matching the given orders.
     */
    function _fulfillAdvancedOrders(
        AdvancedOrder[] memory advancedOrders,
        Fulfillment[] memory fulfillments,
        FulfillmentDetail[] memory fulfillOrdersAndUseProxy
    ) internal returns (Execution[] memory, BatchExecution[] memory) {
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
                    fulfillment.considerationComponents,
                    fulfillOrdersAndUseProxy
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

        // Perform final checks, compress executions, and return.
        return _performFinalChecksAndExecuteOrders(
            advancedOrders,
            executions,
            fulfillOrdersAndUseProxy
        );
    }

    // TODO: natspec
    function _fulfillAvailableOrders(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[][] memory offerFulfillments,
        FulfillmentComponent[][] memory considerationFulfillments,
        FulfillmentDetail[] memory fulfillOrdersAndUseProxy,
        bool useFulfillerProxy
    ) internal returns (Execution[] memory, BatchExecution[] memory) {
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
                    fulfillOrdersAndUseProxy,
                    useFulfillerProxy
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
                    fulfillOrdersAndUseProxy,
                    useFulfillerProxy
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

        // Perform final checks, compress executions, and return.
        return _performFinalChecksAndExecuteOrders(
            advancedOrders,
            executions,
            fulfillOrdersAndUseProxy
        );
    }

    /**
     * @dev Internal function to perform a final check that each consideration
     *      item for an arbitrary number of fulfilled orders has been met and to
     *      compress and trigger associated execututions, transferring the
     *      respective items.
     *
     * @param advancedOrders           The orders to check and perform
     *                                 executions for.
     * @param executions               An array of uncompressed elements
     *                                 indicating the sequence of transfers to
     *                                 perform when fulfilling the given orders.
     * @param fulfillOrdersAndUseProxy An array of FulfillmentDetail structs
     *                                 indicating whether to fulfill the order
     *                                 and whether to source approvals for the
     *                                 fulfilled tokens on each order from their
     *                                 respective proxy. Note that all orders
     *                                 will fulfill on calling this function.
     *
     * @return standardExecutions An array of elements indicating the sequence
     *                            of non-batch transfers performed as part of
     *                            fulfilling the given orders.
     * @return batchExecutions    An array of elements indicating the sequence
     *                            of batch transfers performed as part of
     *                            fulfilling the given orders.
     */
    function _performFinalChecksAndExecuteOrders(
        AdvancedOrder[] memory advancedOrders,
        Execution[] memory executions,
        FulfillmentDetail[] memory fulfillOrdersAndUseProxy
    ) internal returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    ) {
        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over orders to ensure all considerations are met.
            for (uint256 i = 0; i < advancedOrders.length; ++i) {
                // Skip consideration item checks for order if not fulfilled.
                if (!fulfillOrdersAndUseProxy[i].fulfillOrder) {
                    continue;
                }

                // Retrieve consideration items to ensure they are fulfilled.
                ConsiderationItem[] memory consideration = (
                    advancedOrders[i].parameters.consideration
                );

                // Iterate over each consideration item to ensure it is met.
                for (uint256 j = 0; j < consideration.length; ++j) {
                    // Retrieve remaining amount on the consideration item.
                    uint256 unmetAmount = consideration[j].endAmount;

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
        for (uint256 i = 0; i < standardExecutions.length;) {
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
            _transfer(
                item,
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
        return (standardExecutions, batchExecutions);
    }

    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item     The item to transfer, including an amount and recipient.
     * @param offerer  The account offering the item, i.e. the from address.
     * @param useProxy A boolean indicating whether to source approvals for the
     *                 fulfilled token from the offer's proxy.
     */
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        bool useProxy
    ) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // transfer the native tokens to the recipient.
            _transferEth(item.recipient, item.amount);
        // If the item type indicates an ERC20 item...
        } else if (item.itemType == ItemType.ERC20) {
            // Transfer ERC20 token from the offerer to the recipient.
            _transferERC20(
                item.token,
                offerer,
                item.recipient,
                item.amount
            );
        // Otherwise, transfer the item based on item type and proxy preference.
        } else {
            // Place proxy owner on stack (or null address if not using proxy).
            address proxyOwner = useProxy ? offerer : address(0);

            if (item.itemType == ItemType.ERC721) {
                // Transfer ERC721 token from the offerer to the recipient.
                _transferERC721(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    item.amount,
                    proxyOwner
                );
            } else {
                // Transfer ERC1155 token from the offerer to the recipient.
                _transferERC1155(
                    item.token,
                    offerer,
                    item.recipient,
                    item.identifier,
                    item.amount,
                    proxyOwner
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
        // Attempt to transfer the native tokens to the recipient.
        (bool success,) = to.call{value: amount}("");

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
        // Perform ERC20 transfer via the token contract directly.
        bool success = _call(
            token,
            abi.encodeCall(ERC20Interface.transferFrom, (from, to, amount))
        );

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            success,
            token,
            from,
            to,
            0,
            amount
        );

        // Extract result directly from returndata buffer if one is returned.
        bool result = true;
        assembly {
            // Only put result on the stack if return data is exactly 32 bytes.
            if eq(returndatasize(), 0x20) {
                // Copy directly from return data into memory in scratch space.
                returndatacopy(0, 0, 0x20)

                // Take the value from scratch space and place it on the stack.
                result := mload(0)
            }
        }

        // If a falsey result is extracted...
        if (!result) {
            // Revert with a "Bad Return Value" error.
            revert BadReturnValueFromERC20OnTransfer(
                token,
                from,
                to,
                amount
            );
        }
    }

    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The "amount" (this value must be equal to one).
     * @param proxyOwner An address indicating the owner of the proxy to utilize
     *                   when performing the transfer, or the null address if no
     *                   proxy should be utilized.
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Ensure that exactly one 721 item is being transferred.
        if (amount != 1) {
            revert InvalidERC721TransferAmount();
        }

        // Perform transfer, either directly or via proxy.
        bool success = _callDirectlyOrViaProxy(
            token,
            proxyOwner,
            abi.encodeCall(
                ERC721Interface.transferFrom, (from, to, identifier)
            )
        );

        // Ensure that the transfer succeeded.
        _assertValidTokenTransfer(
            success,
            token,
            from,
            to,
            identifier,
            1
        );
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective proxy or on this contract itself.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     * @param amount     The amount to transfer.
     * @param proxyOwner An address indicating the owner of the proxy to utilize
     *                   when performing the transfer, or the null address if no
     *                   proxy should be utilized.
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        address proxyOwner
    ) internal {
        // Perform transfer, either directly or via proxy.
        bool success = _callDirectlyOrViaProxy(
            token,
            proxyOwner,
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
    }

    /**
     * @dev Internal function to transfer a batch of ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective proxy or on this contract itself.
     *
     * @param batchExecution The batch of 1155 tokens to be transferred.
     */
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

        // Perform transfer, either directly or via proxy.
        bool success = _callDirectlyOrViaProxy(
            token,
            batchExecution.useProxy ? batchExecution.from : address(0),
            abi.encodeWithSelector(
                ERC1155Interface.safeBatchTransferFrom.selector,
                from,
                to,
                tokenIds,
                amounts,
                ""
            )
        );

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
     * @dev Internal function to trigger a call to a given token, either
     *      directly or via a proxy contract. The proxy contract must be
     *      registered on the legacy proxy registry for the given proxy owner
     *      and must declare that its implementation matches the required proxy
     *      implementation in accordance with EIP-897.
     *
     * @param token      The token contract to call.
     * @param proxyOwner The original owner of the proxy in question, or the
     *                   null address if no proxy contract should be used.
     * @param callData   The calldata to supply when calling the token contract.
     *
     * @return success The status of the call to the token contract.
     */
    function _callDirectlyOrViaProxy(
        address token,
        address proxyOwner,
        bytes memory callData
    ) internal returns (bool success) {
        // If a proxy owner has been specified...
        if (proxyOwner != address(0)) {
            // Perform transfer via a call to the proxy for the supplied owner.
            success = _callProxy(proxyOwner, token, callData);
        } else {
            // Otherwise, perform transfer via the token contract directly.
            success = _call(token, callData);
        }
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
        // Retrieve the user proxy from the registry.
        address proxy = _LEGACY_PROXY_REGISTRY.proxies(proxyOwner);

        // Assert that the user proxy has the correct implementation.
        if (
            ProxyInterface(
                proxy
            ).implementation() != _REQUIRED_PROXY_IMPLEMENTATION
        ) {
            revert InvalidProxyImplementation();
        }

        // perform call to proxy via proxyAssert and HowToCall = CALL (value 0).
        success = _call(
            proxy,
            abi.encodeWithSelector(
                ProxyInterface.proxyAssert.selector, target, 0, callData
            )
        );
    }

    /**
     * @dev Internal function to call an arbitrary target with given calldata.
     *      Note that no data is written to memory and no contract size check is
     *      performed.
     *
     * @param target   The account to call.
     * @param callData The calldata to supply when calling the target.
     *
     * @return success The status of the call to the target.
     */
    function _call(
        address target,
        bytes memory callData
    ) internal returns (bool success) {
        (success, ) = target.call(callData);
    }

    // todo: delete old version, add natspec, look into optimizations
    function _transferEthAndFinalize(
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) internal {
        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length;) {
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

    // todo: delete old version, add natspec, look into optimizations
    /**
     * @dev Internal function to transfer ERC20 tokens to a given recipient.
     *      Note that proxies are not utilized for ERC20 tokens.
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
        for (uint256 i = 0; i < parameters.additionalRecipients.length;) {
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
        _transferERC20(
            erc20Token,
            from,
            to,
            amount
        );

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

    // todo: delete
    function _emitOrderFulfilledEvent(
        bytes32 orderHash,
        address offerer,
        address zone,
        address fulfiller,
        OfferItem[] memory offer,
        ConsiderationItem[] memory consideration
    ) internal {
        // Designate memory regions for spent items as well as received items.
        SpentItem[] memory spentItems = new SpentItem[](offer.length);
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            consideration.length
        );

        // Skip overflow checks as for loop increments from zero.
        unchecked {
            // Iterate over each offer item.
            for (uint256 i = 0; i < offer.length; ++i) {
                // Retrieve the offer item in question.
                OfferItem memory offerItem = offer[i];

                // Convert to a spent item and store in spent items array.
                spentItems[i] = SpentItem(
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    offerItem.endAmount
                );
            }

            // Iterate over each consideration item.
            for (uint256 i = 0; i < consideration.length; ++i) {
                // Retrieve the consideration item in question.
                ConsiderationItem memory considerationItem = consideration[i];

                // Convert to a received item and store in received items array.
                receivedItems[i] = ReceivedItem(
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    considerationItem.endAmount,
                    considerationItem.recipient
                );
            }
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