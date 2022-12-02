// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { ItemType, OrderType } from "./ConsiderationEnums.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    AdditionalRecipient,
    ZoneParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "./ConsiderationStructs.sol";

import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

import { LowLevelHelpers } from "./LowLevelHelpers.sol";

import "./ConsiderationErrors.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ZoneInteraction is ZoneInteractionErrors, LowLevelHelpers {
    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash                    The hash of the order.
     * @param parameters                   The parameters of the basic order.
     * @param orderType                    The order type.
     * @param receivedItemType             The item type of the initial
     *                                     consideration item on the order.
     * @param additionalRecipientsItemType The item type of any additional
     *                                     consideration item on the order.
     * @param additionalRecipientsToken    The ERC20 token contract address (if
     *                                     applicable) for any additional
     *                                     consideration item on the order.
     * @param offeredItemType              The item type of the offered item on
     *                                     the order.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata parameters,
        ItemType receivedItemType,
        ItemType additionalRecipientsItemType,
        address additionalRecipientsToken,
        ItemType offeredItemType
    ) internal {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        bool isRestricted;
        assembly {
            isRestricted := or(eq(orderType, 2), eq(orderType, 3))
        }
        if (
            isRestricted &&
            !_unmaskedAddressComparison(msg.sender, parameters.zone) &&
            !_unmaskedAddressComparison(msg.sender, parameters.offerer)
        ) {
            // TODO: optimize (copy relevant arguments directly for calldata)
            bytes32[] memory orderHashes = new bytes32[](1);
            orderHashes[0] = orderHash;

            SpentItem[] memory offer = new SpentItem[](1);
            SpentItem memory offerItem = SpentItem(
                offeredItemType,
                parameters.offerToken,
                parameters.offerIdentifier,
                parameters.offerAmount
            );
            offer[0] = offerItem;

            ReceivedItem[] memory consideration = new ReceivedItem[](
                parameters.additionalRecipients.length + 1
            );

            {
                // Create Consideration item.
                ConsiderationItem memory primaryConsiderationItem = (
                    ConsiderationItem(
                        receivedItemType,
                        parameters.considerationToken,
                        parameters.considerationIdentifier,
                        parameters.considerationAmount,
                        parameters.considerationAmount,
                        parameters.offerer
                    )
                );

                // Declare memory for additionalReceivedItem and
                // additionalRecipientItem.
                ReceivedItem memory additionalReceivedItem;

                // Create Received item.
                ReceivedItem memory primaryReceivedItem = ReceivedItem(
                    receivedItemType,
                    primaryConsiderationItem.token,
                    primaryConsiderationItem.identifierOrCriteria,
                    primaryConsiderationItem.endAmount,
                    primaryConsiderationItem.recipient
                );

                consideration[0] = primaryReceivedItem;
                for (
                    uint256 recipientCount = 0;
                    recipientCount < parameters.additionalRecipients.length;
                    ++recipientCount
                ) {
                    AdditionalRecipient memory additionalRecipient = (
                        parameters.additionalRecipients[recipientCount]
                    );

                    additionalReceivedItem = ReceivedItem(
                        additionalRecipientsItemType,
                        additionalRecipientsToken,
                        0,
                        additionalRecipient.amount,
                        additionalRecipient.recipient
                    );

                    consideration[recipientCount + 1] = additionalReceivedItem;
                }
            }

            bytes memory extraData;

            _callAndCheckStatus(
                orderHash,
                orderHashes,
                parameters.zoneHash,
                parameters.offerer,
                parameters.zone,
                offer,
                consideration,
                extraData,
                parameters.startTime,
                parameters.endTime
            );
        }
    }

    /**
     * @dev Internal view function to determine whether an order is a restricted
     *      order and, if so, to ensure that it was either submitted by the
     *      offerer or the zone for the order, or that the zone returns the
     *      expected magic value upon performing a staticcall to `isValidOrder`
     *      or `isValidOrderIncludingExtraData` depending on whether the order
     *      fulfillment specifies extra data or criteria resolvers.
     *
     * @param advancedOrder     The advanced order in question.
     * @param orderHashes       The order hashes of each order supplied prior to
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
        bytes32[] memory orderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        bool isRestricted;
        assembly {
            isRestricted := or(eq(orderType, 2), eq(orderType, 3))
        }
        if (
            isRestricted &&
            !_unmaskedAddressComparison(msg.sender, zone) &&
            !_unmaskedAddressComparison(msg.sender, offerer)
        ) {
            _callAndCheckStatus(
                orderHash,
                orderHashes,
                zoneHash,
                offerer,
                zone,
                _convertOffer(advancedOrder.parameters.offer),
                _convertConsideration(advancedOrder.parameters.consideration),
                advancedOrder.extraData,
                advancedOrder.parameters.startTime,
                advancedOrder.parameters.endTime
            );
        }
    }

    function _callAndCheckStatus(
        bytes32 orderHash,
        bytes32[] memory orderHashes,
        bytes32 zoneHash,
        address offerer,
        address zone,
        SpentItem[] memory offer,
        ReceivedItem[] memory consideration,
        bytes memory extraData,
        uint256 startTime,
        uint256 endTime
    ) internal {
        // TODO: optimize (conversion is temporary to get it to compile)
        // TODO: make it stateful
        bool success = _call(
            zone,
            abi.encodeWithSelector(
                ZoneInterface.validateOrder.selector,
                ZoneParameters({
                    orderHash: orderHash,
                    fulfiller: msg.sender,
                    offerer: offerer,
                    offer: offer,
                    consideration: consideration,
                    extraData: extraData,
                    orderHashes: orderHashes,
                    startTime: startTime,
                    endTime: endTime,
                    zoneHash: zoneHash
                })
            )
        );

        // Ensure call was successful and returned correct magic value.
        _assertIsValidOrderCallSuccess(success, orderHash);
    }

    function _convertOffer(OfferItem[] memory offer)
        internal
        pure
        returns (SpentItem[] memory spentItems)
    {
        // Create an array of spent items equal to the offer length.
        spentItems = new SpentItem[](offer.length);

        // Iterate over each offer item on the order.
        for (uint256 i = 0; i < offer.length; ++i) {
            // Retrieve the offer item.
            OfferItem memory offerItem = offer[i];

            // Create spent item for event based on the offer item.
            SpentItem memory spentItem = SpentItem(
                offerItem.itemType,
                offerItem.token,
                offerItem.identifierOrCriteria,
                offerItem.startAmount
            );

            // Add to array of spent items.
            spentItems[i] = spentItem;
        }
    }

    function _convertConsideration(ConsiderationItem[] memory consideration)
        internal
        pure
        returns (ReceivedItem[] memory receivedItems)
    {
        // Create an array of received items equal to the consideration length.
        receivedItems = new ReceivedItem[](consideration.length);

        // Iterate over each consideration item on the order.
        for (uint256 i = 0; i < consideration.length; ++i) {
            // Retrieve the consideration item.
            ConsiderationItem memory considerationItem = (consideration[i]);

            // Create received item for event based on the consideration item.
            ReceivedItem memory receivedItem = ReceivedItem(
                considerationItem.itemType,
                considerationItem.token,
                considerationItem.identifierOrCriteria,
                considerationItem.startAmount,
                considerationItem.recipient
            );

            // Add to array of received items.
            receivedItems[i] = receivedItem;
        }
    }

    /**
     * @dev Internal view function to ensure that a call to `validateOrder`
     *      as part of validating a restricted order that was not submitted by
     *      the named zone was successful and returned the required magic value.
     *
     * @param success   A boolean indicating the status of the staticcall.
     * @param orderHash The order hash of the order in question.
     */
    function _assertIsValidOrderCallSuccess(bool success, bytes32 orderHash)
        internal
        view
    {
        // If the call failed...
        if (!success) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            _revertInvalidRestrictedOrder(orderHash);
        }

        // Ensure result was extracted and matches isValidOrder magic value.
        if (_doesNotMatchMagic(ZoneInterface.validateOrder.selector)) {
            _revertInvalidRestrictedOrder(orderHash);
        }
    }
}
