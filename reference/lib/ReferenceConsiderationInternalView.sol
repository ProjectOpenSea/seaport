// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import { EIP1271Interface } from "contracts/interfaces/EIP1271Interface.sol";

// prettier-ignore
import {
    SignatureVerificationErrors
} from "contracts/interfaces/SignatureVerificationErrors.sol";

import { ZoneInterface } from "contracts/interfaces/ZoneInterface.sol";

// prettier-ignore
import {
    OrderType,
    ItemType,
    Side
} from "contracts/lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Order,
    AdvancedOrder,
    CriteriaResolver,
    OrderStatus,
    Execution,
    FulfillmentComponent
} from "contracts/lib/ConsiderationStructs.sol";

import { ReferenceConsiderationPure } from "./ReferenceConsiderationPure.sol";

import "./ReferenceConsiderationConstants.sol";

import { OrderToExecute } from "./ReferenceConsiderationStructs.sol";

// prettier-ignore
import {
    ZoneInteractionErrors
} from "contracts/interfaces/ZoneInteractionErrors.sol";

/**
 * @title ReferenceConsiderationInternalView
 * @author 0age
 * @notice ConsiderationInternal contains all internal view functions.
 */
contract ReferenceConsiderationInternalView is
    ReferenceConsiderationPure,
    SignatureVerificationErrors,
    ZoneInteractionErrors
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
        ReferenceConsiderationPure(conduitController)
    {}

    /**
     * @dev Internal view function to ensure that the current time falls within
     *      an order's valid timespan.
     *
     * @param startTime       The time at which the order becomes active.
     * @param endTime         The time at which the order becomes inactive.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order is not active.
     *
     * @return valid A boolean indicating whether the order is active.
     */
    function _verifyTime(
        uint256 startTime,
        uint256 endTime,
        bool revertOnInvalid
    ) internal view returns (bool valid) {
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime <= block.timestamp) {
            // Only revert if revertOnInvalid has been supplied as true.
            if (revertOnInvalid) {
                revert InvalidTime();
            }

            // Return false as the order is invalid.
            return false;
        }

        // Return true as the order time is valid.
        valid = true;
    }

    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 32 or 33 bytes or if the recovered signer does not match the
     *      supplied offerer. Note that in cases where a 32 or 33 byte signature
     *      is supplied, only standard ECDSA signatures that recover to a
     *      non-zero address are supported.
     *
     * @param offerer   The offerer for the order.
     * @param orderHash The order hash.
     * @param signature A signature from the offerer indicating that the order
     *                  has been approved.
     */
    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
        // Skip signature verification if the offerer is the caller.
        if (offerer == msg.sender) {
            return;
        }

        // Derive EIP-712 digest using the domain separator and the order hash.
        bytes32 digest = _hashDigest(_domainSeparator(), orderHash);

        // Declare r, s, and v signature parameters.
        bytes32 r;
        bytes32 s;
        uint8 v;

        // If signature contains 64 bytes, parse as EIP-2098 signature. (r+s&v)
        if (signature.length == 64) {
            // Declare temporary vs that will be decomposed into s and v.
            bytes32 vs;

            (r, vs) = abi.decode(signature, (bytes32, bytes32));

            s = vs & EIP2098_allButHighestBitMask;

            v = uint8(uint256(vs >> 255)) + 27;
        } else if (signature.length == 65) {
            (r, s) = abi.decode(signature, (bytes32, bytes32));
            v = uint8(signature[64]);

            // Ensure v value is properly formatted.
            if (v != 27 && v != 28) {
                revert BadSignatureV(v);
            }
        } else {
            // For all other signature lengths, try verification via EIP-1271.
            // Attempt EIP-1271 static call to offerer in case it's a contract.
            _verifySignatureViaERC1271(offerer, digest, signature);

            // Return early if the ERC-1271 signature check succeeded.
            return;
        }

        // Attempt to recover signer using the digest and signature parameters.
        address signer = ecrecover(digest, v, r, s);

        // Disallow invalid signers.
        if (signer == address(0)) {
            revert InvalidSignature();
            // Should a signer be recovered, but it doesn't match the offerer...
        } else if (signer != offerer) {
            // Attempt EIP-1271 static call to offerer in case it's a contract.
            _verifySignatureViaERC1271(offerer, digest, signature);
        }
    }

    /**
     * @dev Internal view function to verify the signature of an order using
     *      ERC-1271 (i.e. contract signatures via `isValidSignature`).
     *
     * @param offerer   The offerer for the order.
     * @param digest    The signature digest, derived from the domain separator
     *                  and the order hash.
     * @param signature A signature (or other data) used to validate the digest.
     */
    function _verifySignatureViaERC1271(
        address offerer,
        bytes32 digest,
        bytes memory signature
    ) internal view {
        if (
            EIP1271Interface(offerer).isValidSignature(digest, signature) !=
            EIP1271Interface.isValidSignature.selector
        ) {
            revert InvalidSigner();
        }
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     */
    function _domainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator(_EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH);
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for an offer item.
     * @param offerItem The offered item to hash.
     * @return The hash.
     */
    function _hashOfferItem(OfferItem memory offerItem)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _OFFER_ITEM_TYPEHASH,
                    offerItem.itemType,
                    offerItem.token,
                    offerItem.identifierOrCriteria,
                    offerItem.startAmount,
                    offerItem.endAmount
                )
            );
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for a consideration item.
     * @param considerationItem The consideration item to hash.
     * @return The hash.
     */
    function _hashConsiderationItem(ConsiderationItem memory considerationItem)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _CONSIDERATION_ITEM_TYPEHASH,
                    considerationItem.itemType,
                    considerationItem.token,
                    considerationItem.identifierOrCriteria,
                    considerationItem.startAmount,
                    considerationItem.endAmount,
                    considerationItem.recipient
                )
            );
    }

    /**
     * @dev Internal view function to derive the order hash for a given order.
     *      Note that only the original consideration items are included in the
     *      order hash, as additional consideration items may be supplied by the
     *      caller.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param nonce           The nonce of the order to hash.
     *
     * @return orderHash The hash.
     */
    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) internal view returns (bytes32 orderHash) {
        // Designate new memory regions for offer and consideration item hashes.
        bytes32[] memory offerHashes = new bytes32[](
            orderParameters.offer.length
        );
        bytes32[] memory considerationHashes = new bytes32[](
            orderParameters.totalOriginalConsiderationItems
        );

        // Iterate over each offer on the order.
        for (uint256 i = 0; i < orderParameters.offer.length; ++i) {
            // Hash the offer and place the result into memory.
            offerHashes[i] = _hashOfferItem(orderParameters.offer[i]);
        }

        // Iterate over each consideration on the order.
        for (
            uint256 i = 0;
            i < orderParameters.totalOriginalConsiderationItems;
            ++i
        ) {
            // Hash the consideration and place the result into memory.
            considerationHashes[i] = _hashConsiderationItem(
                orderParameters.consideration[i]
            );
        }

        // Derive and return the order hash as specified by EIP-712.

        return
            keccak256(
                abi.encode(
                    _ORDER_TYPEHASH,
                    orderParameters.offerer,
                    orderParameters.zone,
                    keccak256(abi.encodePacked(offerHashes)),
                    keccak256(abi.encodePacked(considerationHashes)),
                    orderParameters.orderType,
                    orderParameters.startTime,
                    orderParameters.endTime,
                    orderParameters.zoneHash,
                    orderParameters.salt,
                    orderParameters.conduitKey,
                    nonce
                )
            );
    }

    /**
     * @dev Internal view function to to ensure that the supplied consideration
     *      array length on a given set of order parameters is not less than the
     *      original consideration array length for that order and to retrieve
     *      the current nonce for a given order's offerer and zone and use it to
     *      derive the order hash.
     *
     * @param orderParameters The parameters of the order to hash.
     *
     * @return The hash.
     */
    function _assertConsiderationLengthAndGetNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            orderParameters.consideration.length,
            orderParameters.totalOriginalConsiderationItems
        );

        // Derive and return order hash using current nonce for the offerer.
        return _getOrderHash(orderParameters, _nonces[orderParameters.offerer]);
    }

    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash The hash of the order.
     * @param zoneHash  The hash to provide upon calling the zone.
     * @param orderType The type of the order.
     * @param offerer   The offerer in question.
     * @param zone      The zone in question.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal view {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            uint256(orderType) > 1 &&
            msg.sender != zone &&
            msg.sender != offerer
        ) {
            if (
                ZoneInterface(zone).isValidOrder(
                    orderHash,
                    msg.sender,
                    offerer,
                    zoneHash
                ) != ZoneInterface.isValidOrder.selector
            ) {
                revert InvalidRestrictedOrder(orderHash);
            }
        }
    }

    /**
     * @dev Internal view function to determine if a proxy should be utilized
     *      for a given order and to ensure that the submitter is allowed by the
     *      order type.
     *
     * @param advancedOrder     The order in question.
     * @param criteriaResolvers An array where each element contains a reference
     *                          to a specific offer or consideration, a token
     *                          identifier, and a proof that the supplied token
     *                          identifier is contained in the order's merkle
     *                          root. Note that a criteria of zero indicates
     *                          that any (transferrable) token identifier is
     *                          valid and that no proof needs to be supplied.
     * @param priorOrderHashes  The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment (e.g. this array will be
     *                          empty for single or "fulfill available").
     * @param orderHash         The hash of the order.
     * @param zoneHash          The hash to provide upon calling the zone.
     * @param orderType         The type of the order.
     * @param offerer           The offerer in question.
     * @param zone              The zone in question.

     */
    function _assertRestrictedAdvancedOrderValidity(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bytes32[] memory priorOrderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal view {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            uint256(orderType) > 1 &&
            msg.sender != zone &&
            msg.sender != offerer
        ) {
            // If no extraData or criteria resolvers are supplied...
            if (
                advancedOrder.extraData.length == 0 &&
                criteriaResolvers.length == 0
            ) {
                if (
                    ZoneInterface(zone).isValidOrder(
                        orderHash,
                        msg.sender,
                        offerer,
                        zoneHash
                    ) != ZoneInterface.isValidOrder.selector
                ) {
                    revert InvalidRestrictedOrder(orderHash);
                }
            } else {
                if (
                    ZoneInterface(zone).isValidOrderIncludingExtraData(
                        orderHash,
                        msg.sender,
                        advancedOrder,
                        priorOrderHashes,
                        criteriaResolvers
                    ) != ZoneInterface.isValidOrder.selector
                ) {
                    revert InvalidRestrictedOrder(orderHash);
                }
            }
        }
    }

    /**
     * @dev Internal view function to match offer items to consideration items
     *      on a group of orders via a supplied fulfillment.
     *
     * @param ordersToExecute         The orders to match.
     * @param offerComponents         An array designating offer components to
     *                                match to consideration components.
     * @param considerationComponents An array designating consideration
     *                                components to match to offer components.
     *                                Note that each consideration amount must
     *                                be zero in order for the match operation
     *                                to be valid.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _applyFulfillment(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] calldata offerComponents,
        FulfillmentComponent[] calldata considerationComponents
    ) internal view returns (Execution memory execution) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            offerComponents.length == 0 || considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Validate and aggregate consideration items and store the result as a
        // ReceivedItem.
        ReceivedItem memory considerationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                ordersToExecute,
                considerationComponents,
                0
            )
        );

        // Validate & aggregate offer items and store result as an Execution.
        (
            execution
            /**
             * ItemType itemType,
             * address token,
             * uint256 identifier,
             * address offerer,
             * bytes32 conduitKey,
             * uint256 offerAmount
             */
        ) = _aggregateValidFulfillmentOfferItems(
            ordersToExecute,
            offerComponents,
            0
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            execution.item.itemType != considerationItem.itemType ||
            execution.item.token != considerationItem.token ||
            execution.item.identifier != considerationItem.identifier
        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents();
        }

        // If total consideration amount exceeds the offer amount...
        if (considerationItem.amount > execution.item.amount) {
            // Retrieve the first consideration component from the fulfillment.
            FulfillmentComponent memory targetComponent = (
                considerationComponents[0]
            );

            // Add excess consideration item amount to original array of orders.
            ordersToExecute[targetComponent.orderIndex]
                .receivedItems[targetComponent.itemIndex]
                .amount = considerationItem.amount - execution.item.amount;

            // Reduce total consideration amount to equal the offer amount.
            considerationItem.amount = execution.item.amount;
        } else {
            // Retrieve the first offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = (offerComponents[0]);

            // Add excess offer item amount to the original array of orders.
            ordersToExecute[targetComponent.orderIndex]
                .spentItems[targetComponent.itemIndex]
                .amount = execution.item.amount - considerationItem.amount;
        }

        // Reuse execution struct with consideration amount and recipient.
        execution.item.amount = considerationItem.amount;
        execution.item.recipient = considerationItem.recipient;

        // Return the final execution that will be triggered for relevant items.
        return execution; // Execution(considerationItem, offerer, conduitKey);
    }

    /**
     * @dev Internal view function to aggregate offer or consideration items
     *      from a group of orders into a single execution via a supplied array
     *      of fulfillment components. Items that are not available to aggregate
     *      will not be included in the aggregated execution.
     *
     * @param ordersToExecute       The orders to aggregate.
     * @param side                  The side (i.e. offer or consideration).
     * @param fulfillmentComponents An array designating item components to
     *                              aggregate if part of an available order.
     * @param fulfillerConduitKey   A bytes32 value indicating what conduit, if
     *                              any, to source the fulfiller's token
     *                              approvals from. The zero hash signifies that
     *                              no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(1)` signifies to utilize the legacy
     *                               user proxy for the fulfiller.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateAvailable(
        OrderToExecute[] memory ordersToExecute,
        Side side,
        FulfillmentComponent[] memory fulfillmentComponents,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Retrieve orders array length and place on the stack.
        uint256 totalOrders = ordersToExecute.length;

        // Retrieve fulfillment components array length and place on stack.
        uint256 totalFulfillmentComponents = fulfillmentComponents.length;

        // Ensure at least one fulfillment component has been supplied.
        if (totalFulfillmentComponents == 0) {
            revert MissingFulfillmentComponentOnAggregation(side);
        }

        // Determine component index after first available (0 implies none).
        uint256 nextComponentIndex = 0;

        // Iterate over components until finding one with a fulfilled order.
        for (uint256 i = 0; i < totalFulfillmentComponents; ++i) {
            // Retrieve the fulfillment component index.
            uint256 orderIndex = fulfillmentComponents[i].orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= totalOrders) {
                revert InvalidFulfillmentComponentData();
            }

            // If order is being fulfilled (i.e. it is still available)...
            if (ordersToExecute[orderIndex].numerator != 0) {
                // Update the next potential component index.
                nextComponentIndex = i + 1;

                // Exit the loop.
                break;
            }
        }

        // If no available order was located...
        if (nextComponentIndex == 0) {
            // Return with an empty execution element that will be filtered.
            // prettier-ignore
            return Execution(
                ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    0,
                    payable(address(0))
                ),
                address(0),
                bytes32(0)
            );
        }

        // If the fulfillment components are offer components...
        if (side == Side.OFFER) {
            // Return execution for aggregated items provided by offerer.
            // prettier-ignore
            return _aggregateValidFulfillmentOfferItems(
                ordersToExecute,
                fulfillmentComponents,
                nextComponentIndex - 1
            );
        } else {
            // Otherwise, fulfillment components are consideration
            // components. Return execution for aggregated items provided by
            // the fulfiller.
            // prettier-ignore
            return _aggregateConsiderationItems(
                ordersToExecute,
                fulfillmentComponents,
                nextComponentIndex - 1,
                fulfillerConduitKey
            );
        }
    }

    /**
     * @dev Internal pure function to check the indicated offer item matches original item.
     *
     * @param orderToExecute  The order to compare.
     * @param offer The offer to compare
     * @param execution  The aggregated offer item
     *
     * @return invalidFulfillment A boolean indicating whether the fulfillment is invalid.
     */
    function _checkMatchingOffer(
        OrderToExecute memory orderToExecute,
        SpentItem memory offer,
        Execution memory execution
    ) internal pure returns (bool invalidFulfillment) {
        return
            execution.item.identifier != offer.identifier ||
            execution.offerer != orderToExecute.offerer ||
            execution.conduitKey != orderToExecute.conduitKey ||
            execution.item.itemType != offer.itemType ||
            execution.item.token != offer.token;
    }

    /**
     * @dev Internal pure function to aggregate a group of offer items using
     *      supplied directives on which component items are candidates for
     *      aggregation, skipping items on orders that are not available.
     *
     * @param ordersToExecute The orders to aggregate offer items from.
     * @param offerComponents An array of FulfillmentComponent structs
     *                        indicating the order index and item index of each
     *                        candidate offer item for aggregation.
     * @param startIndex      The initial order index to begin iteration on when
     *                        searching for offer items to aggregate.
     *
     * @return execution The aggregated offer items.
     */
    function _aggregateValidFulfillmentOfferItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory offerComponents,
        uint256 startIndex
    ) internal view returns (Execution memory execution) {
        // Get the order index and item index of the offer component.
        uint256 orderIndex = offerComponents[startIndex].orderIndex;
        uint256 itemIndex = offerComponents[startIndex].itemIndex;

        // Declare a variable indicating whether the aggregation is invalid.
        // Ensure that the order index is not out of range.
        bool invalidFulfillment = (orderIndex >= ordersToExecute.length);
        if (!invalidFulfillment) {
            // Get the order based on offer components order index.
            OrderToExecute memory orderToExecute = ordersToExecute[orderIndex];
            // Ensure that the item index is not out of range.
            invalidFulfillment =
                invalidFulfillment ||
                (itemIndex >= orderToExecute.spentItems.length);

            if (!invalidFulfillment) {
                // Get the spent item based on the offer components item index.
                SpentItem memory offer = orderToExecute.spentItems[itemIndex];

                // Create the Executio0n.
                execution = Execution(
                    ReceivedItem(
                        offer.itemType,
                        offer.token,
                        offer.identifier,
                        offer.amount,
                        payable(msg.sender)
                    ),
                    orderToExecute.offerer,
                    orderToExecute.conduitKey
                );

                // Zero out amount on original offerItem to indicate it is spent
                offer.amount = 0;

                // Loop through the offer components, checking for validity.
                for (
                    uint256 i = startIndex + 1;
                    i < offerComponents.length;
                    ++i
                ) {
                    // Get the order index and item index of the offer component.
                    orderIndex = offerComponents[i].orderIndex;
                    itemIndex = offerComponents[i].itemIndex;

                    // Ensure that the order index is not out of range.
                    invalidFulfillment = orderIndex >= ordersToExecute.length;
                    // Break if invalid
                    if (invalidFulfillment) {
                        break;
                    }
                    // Get the order based on offer components order index.
                    orderToExecute = ordersToExecute[orderIndex];
                    if (orderToExecute.numerator != 0) {
                        // Ensure that the item index is not out of range.
                        invalidFulfillment = (itemIndex >=
                            orderToExecute.spentItems.length);
                        // Break if invalid
                        if (invalidFulfillment) {
                            break;
                        }
                        // Get the spent item based on the offer components item index.
                        offer = orderToExecute.spentItems[itemIndex];
                        // Update the Received Item Amount.
                        execution.item.amount =
                            execution.item.amount +
                            offer.amount;
                        // Zero out amount on original offerItem to indicate it is spent,
                        offer.amount = 0;
                        // Ensure the indicated offer item matches original item.
                        invalidFulfillment = _checkMatchingOffer(
                            orderToExecute,
                            offer,
                            execution
                        );
                    }
                }
            }
        }
        // Revert if an order/item was out of range or was not aggregatable.
        if (invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
        }
    }

    /**
     * @dev Internal view function to aggregate consideration items from a group
     *      of orders into a single execution via a supplied components array.
     *      Consideration items that are not available to aggregate will not be
     *      included in the aggregated execution.
     *
     * @param ordersToExecute         The orders to aggregate.
     * @param considerationComponents An array designating consideration
     *                                components to aggregate if part of an
     *                                available order.
     * @param nextComponentIndex      The index of the next potential
     *                                consideration component.
     * @param fulfillerConduitKey     A bytes32 value indicating what conduit,
     *                                if any, to source the fulfiller's token
     *                                approvals from. The zero hash signifies
     *                                that no conduit should be used (and direct
     *                                approvals set on Consideration) and
     *                                `bytes32(1)` signifies to utilize the
     *                                legacy user proxy for the fulfiller.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateConsiderationItems(
        OrderToExecute[] memory ordersToExecute,
        FulfillmentComponent[] memory considerationComponents,
        uint256 nextComponentIndex,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Validate and aggregate consideration items on available orders and
        // store result as a ReceivedItem.
        ReceivedItem memory receiveConsiderationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                ordersToExecute,
                considerationComponents,
                nextComponentIndex
            )
        );

        // Return execution for aggregated items provided by the fulfiller.
        execution = Execution(
            receiveConsiderationItem,
            msg.sender,
            fulfillerConduitKey
        );
    }

    /**
     * @dev Internal view function to derive the address of a given conduit
     *      using a corresponding conduit key.
     *
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. This value is
     *                   the "salt" parameter supplied by the deployer (i.e. the
     *                   conduit controller) when deploying the given conduit.
     *
     * @return conduit The address of the conduit associated with the given
     *                 conduit key.
     */
    function _deriveConduit(bytes32 conduitKey)
        internal
        view
        returns (address conduit)
    {
        // Derive the address of the conduit.
        conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(_CONDUIT_CONTROLLER),
                            conduitKey,
                            _CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
