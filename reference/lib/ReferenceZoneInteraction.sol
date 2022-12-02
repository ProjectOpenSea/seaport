// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ZoneInterface } from "contracts/interfaces/ZoneInterface.sol";

import { OrderType, ItemType } from "contracts/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    BasicOrderParameters,
    OrderParameters,
    ZoneParameters,
    OfferItem,
    ConsiderationItem,
    AdditionalRecipient
} from "contracts/lib/ConsiderationStructs.sol";

import "contracts/lib/ConsiderationConstants.sol";

import {
    ZoneInteractionErrors
} from "contracts/interfaces/ZoneInteractionErrors.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ReferenceZoneInteraction is ZoneInteractionErrors {
    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash             The hash of the order.
     * @param basicOrderParameters  The original basic order parameters.
     * @param offeredItemType       The type of the order.
     * @param receivedItemType      The offerer in question.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata basicOrderParameters,
        ItemType offeredItemType,
        ItemType receivedItemType
    ) internal {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) &&
            msg.sender != basicOrderParameters.zone &&
            msg.sender != basicOrderParameters.offerer
        ) {
            (
                OfferItem[] memory offer,
                ConsiderationItem[] memory consideration
            ) = _convertToOfferAndConsiderationItems(
                    basicOrderParameters,
                    offeredItemType,
                    receivedItemType
                );
            if (
                ZoneInterface(basicOrderParameters.zone).validateOrder(
                    ZoneParameters({
                        orderHash: orderHash,
                        fulfiller: msg.sender,
                        offerer: basicOrderParameters.offerer,
                        offer: offer,
                        consideration: consideration,
                        extraData: "",
                        orderHashes: new bytes32[](0),
                        startTime: basicOrderParameters.startTime,
                        endTime: basicOrderParameters.endTime,
                        zoneHash: basicOrderParameters.zoneHash
                    })
                ) != ZoneInterface.validateOrder.selector
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
        bytes32[] memory priorOrderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) &&
            msg.sender != zone &&
            msg.sender != offerer
        ) {
            if (
                ZoneInterface(zone).validateOrder(
                    ZoneParameters({
                        orderHash: orderHash,
                        fulfiller: msg.sender,
                        offerer: offerer,
                        offer: advancedOrder.parameters.offer,
                        consideration: advancedOrder.parameters.consideration,
                        extraData: advancedOrder.extraData,
                        orderHashes: priorOrderHashes,
                        startTime: advancedOrder.parameters.startTime,
                        endTime: advancedOrder.parameters.endTime,
                        zoneHash: zoneHash
                    })
                ) != ZoneInterface.validateOrder.selector
            ) {
                revert InvalidRestrictedOrder(orderHash);
            }
        }
    }

    function _convertToOfferAndConsiderationItems(
        BasicOrderParameters calldata parameters,
        ItemType offerItemType,
        ItemType considerationItemType
    ) internal pure returns (OfferItem[] memory, ConsiderationItem[] memory) {
        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem({
            itemType: offerItemType,
            token: parameters.offerToken,
            startAmount: parameters.offerAmount,
            endAmount: parameters.offerAmount,
            identifierOrCriteria: parameters.offerIdentifier
        });

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1 + parameters.additionalRecipients.length
        );
        address token = parameters.considerationToken;
        uint256 amount = parameters.considerationAmount;
        uint256 identifierOrCriteria = parameters.considerationIdentifier;
        considerationItems[0] = ConsiderationItem({
            itemType: considerationItemType,
            token: token,
            startAmount: amount,
            endAmount: amount,
            identifierOrCriteria: identifierOrCriteria,
            recipient: parameters.offerer
        });
        for (uint256 i = 0; i < parameters.additionalRecipients.length; i++) {
            AdditionalRecipient calldata additionalRecipient = parameters
                .additionalRecipients[i];
            amount = additionalRecipient.amount;
            considerationItems[i + 1] = ConsiderationItem({
                itemType: considerationItemType,
                token: token,
                startAmount: amount,
                endAmount: amount,
                identifierOrCriteria: identifierOrCriteria,
                recipient: additionalRecipient.recipient
            });
        }

        return (offerItems, considerationItems);
    }
}
